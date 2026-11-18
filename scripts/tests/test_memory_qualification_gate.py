"""The full-run launch guard must reject bad prerequisites without running inference."""
import copy
import importlib.util
import json
import os
import signal
import time
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'run-memory-qualification.py'
spec = importlib.util.spec_from_file_location('qualification_gate', SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class QualificationGateTests(unittest.TestCase):
    def receipt(self, identity='current'):
        return {
            'hold': False, 'source_identity': identity, 'reviewed_source_identity': identity,
            'configuration': gate.CONFIG.copy(), 'model_sha256': gate.MODEL_SHA,
            'command': ['reviewed'], 'model_path': '/reviewed/model',
            'environment': {'MEMORYOS_GRAMMAR_MEMORY_MODEL': '/reviewed/model'},
            'regressions': {key: {
                'passed': True, 'source_identity': identity, 'accepted_mistakes': 0,
            } for key in gate.REQUIRED},
        }

    def test_only_current_reviewed_complete_green_receipt_passes(self):
        gate.preflight(self.receipt(), 'current')
        edits = [
            lambda r: r.update(hold=True),
            lambda r: r.update(source_identity='old'),
            lambda r: r.update(reviewed_source_identity='old'),
            lambda r: r.update(model_sha256='wrong'),
            lambda r: r['configuration'].update(context=4096),
            lambda r: r['regressions'].pop('grammar-11'),
            lambda r: r['regressions']['grammar-11'].update(passed=False),
            lambda r: r['regressions']['grammar-11'].update(source_identity='old'),
            lambda r: r['regressions']['grammar-11'].update(accepted_mistakes=1),
            lambda r: r['regressions']['grammar-11'].update(accepted_mistakes=False),
        ]
        for edit in edits:
            with self.subTest(edit=edits.index(edit)):
                receipt = copy.deepcopy(self.receipt())
                edit(receipt)
                with self.assertRaises(ValueError):
                    gate.preflight(receipt, 'current')

    def test_command_and_model_environment_must_match_review(self):
        receipt = self.receipt()
        with self.assertRaises(ValueError):
            gate.launch_environment(receipt, ['different'])
        receipt['environment']['MEMORYOS_GRAMMAR_MEMORY_MODEL'] = '/stale/model'
        with self.assertRaises(ValueError):
            gate.launch_environment(receipt, ['reviewed'])
        receipt = self.receipt()
        os.environ['MEMORYOS_OTHER_MODEL'] = '/stale/model'
        try:
            environment = gate.launch_environment(receipt, ['reviewed'])
            self.assertNotIn('MEMORYOS_OTHER_MODEL', environment)
            self.assertEqual(environment['MEMORYOS_GRAMMAR_MEMORY_MODEL'], '/reviewed/model')
        finally:
            del os.environ['MEMORYOS_OTHER_MODEL']

    def test_term_stops_the_owned_dummy_process_and_releases_lock(self):
        with tempfile.TemporaryDirectory(prefix='memoryos-gate-signal-') as directory:
            root = Path(directory)
            model, receipt, lock, pidfile = [root / name for name in ('model', 'receipt', 'lock', 'pid')]
            model.write_bytes(b'fictional model fixture, never used for inference')
            command = [sys.executable, '-c',
                       f'import os,signal; from pathlib import Path; Path({str(pidfile)!r}).write_text(str(os.getpid())); signal.pause()']
            row = self.receipt()
            row.update(model_path=str(model), command=command,
                       model_sha256=gate.hashlib.sha256(model.read_bytes()).hexdigest(),
                       environment={'MEMORYOS_GRAMMAR_MEMORY_MODEL': str(model)})
            receipt.write_text(json.dumps(row))
            bootstrap = (
                'import importlib.util,sys; '
                f's=importlib.util.spec_from_file_location("gate", {str(SCRIPT)!r}); '
                'g=importlib.util.module_from_spec(s); s.loader.exec_module(g); '
                f'g.MODEL_SHA={row["model_sha256"]!r}; g.source_identity=lambda: "current"; '
                f'sys.argv=["gate","--receipt",{str(receipt)!r},"--lock",{str(lock)!r},"--"]+{command!r}; '
                'sys.exit(g.main())')
            owner = subprocess.Popen([sys.executable, '-c', bootstrap], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            child_pid = None
            try:
                deadline = time.monotonic() + 5
                while not pidfile.exists() and owner.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(pidfile.exists())
                child_pid = int(pidfile.read_text())
                owner.send_signal(signal.SIGTERM)
                owner.communicate(timeout=7)
                self.assertNotEqual(owner.returncode, 0)
                self.assertFalse(lock.exists())
                with self.assertRaises(ProcessLookupError):
                    os.kill(child_pid, 0)
            finally:
                if owner.poll() is None:
                    owner.kill()
                    owner.communicate()
                if child_pid is not None:
                    try:
                        os.kill(child_pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass

    def test_held_or_duplicate_launch_cannot_execute_a_command(self):
        identity = gate.source_identity()
        with tempfile.TemporaryDirectory(prefix='memoryos-gate-test-') as directory:
            root = Path(directory)
            receipt, lock, marker = root / 'receipt.json', root / 'owner.lock', root / 'ran'
            lock.write_text('existing owner')
            for held in (True, False):
                row = self.receipt(identity)
                row['hold'] = held
                command = [sys.executable, '-c', f'from pathlib import Path; Path({str(marker)!r}).touch()']
                row['command'] = command
                receipt.write_text(json.dumps(row))
                result = subprocess.run([
                    sys.executable, str(SCRIPT), '--receipt', str(receipt), '--lock', str(lock),
                    '--', *command,
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(marker.exists())
                self.assertEqual(lock.read_text(), 'existing owner')
                self.assertIn('hold' if held else 'File exists', result.stderr)


if __name__ == '__main__':
    unittest.main()
