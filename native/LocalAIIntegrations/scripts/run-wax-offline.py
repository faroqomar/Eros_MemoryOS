#!/usr/bin/env python3
"""Run the real Wax binary corpus under macOS deny-network policy; keep raw output."""
import argparse
import datetime
import errno
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

POLICY = '(version 1)\n(allow default)\n(deny network*)\n'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def probe_and_exec(state_path):
    state = json.loads(Path(state_path).read_text())
    proof = dict(pid=os.getpid(), probe='AF_INET TCP connect to 127.0.0.1:9; no payload sent')
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
            connection.settimeout(1)
            connection.connect(('127.0.0.1', 9))
    except OSError as error:
        proof.update(errno=error.errno, network_denied=error.errno in [errno.EPERM, errno.EACCES])
    else:
        proof.update(errno=None, network_denied=False)
    Path(state['probe_receipt']).write_text(json.dumps(proof, indent=2) + '\n')
    if not proof['network_denied']:
        raise SystemExit('Network probe was not denied by the OS; SDK run was not started.')
    # exec keeps this process and its kernel sandbox policy; no unsandboxed SDK child.
    os.execv(state['runner_argv'][0], state['runner_argv'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--packaging-receipt', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    executable = args.binary.resolve()
    packaging = args.packaging_receipt.resolve()
    report, receipt_path = args.report.resolve(), args.receipt.resolve()
    if report.exists() or receipt_path.exists():
        parser.error('Preserve existing results; choose new report and receipt paths.')
    report.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    package = json.loads(packaging.read_text())
    packaging_hash = digest(packaging)
    binary_hash = digest(executable)
    source_identity = 'sha256:' + packaging_hash
    toolchain = subprocess.check_output(['/usr/bin/swift', '--version'], text=True).strip()
    runner = [str(executable), '--source-identity', source_identity, '--toolchain', toolchain,
              '--sdk-patch-sha256', package['patch_sha256']]
    stderr_path = report.with_suffix('.stderr.log')
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    start = time.time()
    with tempfile.TemporaryDirectory(prefix='memoryos-wax-deny-network-') as directory:
        state_path, proof_path = Path(directory) / 'state.json', Path(directory) / 'probe.json'
        state_path.write_text(json.dumps(dict(runner_argv=runner, probe_receipt=str(proof_path))))
        launcher = ['/usr/bin/sandbox-exec', '-p', POLICY, '/usr/bin/python3',
                    str(Path(__file__).resolve()), '--probe-and-exec', str(state_path)]
        with report.open('wb') as out, stderr_path.open('wb') as err:
            result = subprocess.run(launcher, stdout=out, stderr=err)
        probe = json.loads(proof_path.read_text()) if proof_path.exists() else None
    parse_error = None
    try:
        parsed = json.loads(report.read_text()) if report.stat().st_size else None
    except (ValueError, UnicodeError) as error:
        parsed, parse_error = None, str(error)
    raw = parsed.get('report', parsed) if isinstance(parsed, dict) else None
    results = raw.get('results', []) if isinstance(raw, dict) else []
    completed = sum(r.get('retrievalStatus') == 'completed' for r in results if isinstance(r, dict))
    context = raw.get('context', {}) if isinstance(raw, dict) else {}
    proof = dict(format_version=1, started_at=started,
                 finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 duration_seconds=time.time() - start, launcher_argv=launcher,
                 launcher_source_sha256=digest(__file__), binary_path=str(executable), binary_sha256=binary_hash, binary_unchanged=digest(executable) == binary_hash,
                 packaging_receipt_path=str(packaging), packaging_receipt_sha256=packaging_hash, packaging_receipt_unchanged=digest(packaging) == packaging_hash,
                 source_identity=source_identity, source_provenance_sha256=package.get('source_provenance_sha256'),
                 raw_report_path=str(report), raw_report_sha256=digest(report), stderr_path=str(stderr_path),
                 runner_exit_code=result.returncode, os_probe=probe,
                 same_process_exec_inherits_policy=True, raw_report_was_not_modified=True,
                 raw_context_offline_confirmed=context.get('offlineConfirmed'), raw_parse_error=parse_error,
                 offline_evidence_authority='This launcher OS policy/probe receipt; the unchanged CLI has no sandbox attestation argument',
                 retrieval_cases=len(results), retrieval_completed=completed,
                 raw_source_identity_matches=context.get('sourceIdentity') == source_identity)
    receipt_path.write_text(json.dumps(proof, indent=2) + '\n')
    if (result.returncode or not probe or not probe['network_denied'] or len(results) != 15 or completed != 15
            or not proof['binary_unchanged'] or not proof['packaging_receipt_unchanged']
            or not proof['raw_source_identity_matches']):
        raise SystemExit('Sandbox run did not pass; inspect the preserved raw output and receipt.')
    print(receipt_path)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--probe-and-exec':
        probe_and_exec(sys.argv[2])
    else:
        main()
