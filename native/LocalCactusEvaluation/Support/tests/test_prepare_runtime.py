"""Exercise the source gate with real temporary Git worktrees and git apply."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "prepare_runtime.py"
SPEC = importlib.util.spec_from_file_location("cactus_prepare_runtime", SCRIPT)
runtime = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime)


class BuildReached(Exception):
    """Stop a clean fixture before any SDK/compiler invocation."""


class SourceVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cactus-source-contract-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.upstream = self.root / "upstream"
        self.upstream.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Fictional fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.originals = {
            "cactus/CMakeLists.txt": b"add_library(cactus engine.cpp)\n",
            "cactus/engine.cpp": b"int value() { return 1; }\n",
            "cactus/other.cpp": b"int other() { return 2; }\n",
            "libs/audio/helper.h": b"#define FIXTURE 1\n",
            "LICENSE": b"Fictional test license\n",
        }
        for name, data in self.originals.items():
            self.write(name, data)
        self.git("add", ".")
        self.git("commit", "-qm", "Fictional pinned source")
        self.pin = self.git("rev-parse", "HEAD").decode().strip()
        self.package = self.root / "package"
        (self.package / "Support").mkdir(parents=True)
        self.patch = self.package / "Support/upstream-v114-local-only.patch"
        self.patch.write_text(
            "--- a/cactus/engine.cpp\n"
            "+++ b/cactus/engine.cpp\n"
            "@@ -1 +1 @@\n"
            "-int value() { return 1; }\n"
            "+int value() { return 3; }\n"
            "--- /dev/null\n"
            "+++ b/cactus/local_only.cpp\n"
            "@@ -0,0 +1 @@\n"
            "+int local_only() { return 1; }\n"
        )
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(runtime, "PIN", self.pin).start()

    def git(self, *arguments):
        return subprocess.check_output(
            ["git", *arguments], cwd=self.upstream, stderr=subprocess.PIPE)

    def write(self, relative, data):
        path = self.upstream / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def apply_patch(self):
        self.git("apply", str(self.patch))

    def receipt_snapshot(self):
        receipt = {
            "revision": self.pin,
            "files": {name: hashlib.sha256(data).hexdigest()
                      for name, data in self.originals.items()},
        }
        (self.upstream / ".memoryos-upstream-source.json").write_text(json.dumps(receipt))
        # The receipt flow intentionally has no Git metadata.
        (self.upstream / ".git").rename(self.root / "fixture-git-metadata")

    def verify(self, patched=False):
        runtime.verify_source_subset(self.upstream, self.patch, patched)

    def assert_rejected(self, patched=False):
        before = self.patch.read_bytes()
        with self.assertRaises(SystemExit):
            self.verify(patched)
        self.assertEqual(self.patch.read_bytes(), before)

    def test_clean_git_checkout_without_receipt_is_supported(self):
        self.verify()

    def test_approved_patch_without_receipt_is_supported(self):
        self.apply_patch()
        self.verify(patched=True)

    def test_retained_patch_empty_preimage_additions_are_supported(self):
        # The real retained Cactus patch uses a/filename, not /dev/null,
        # for files whose original hunk has zero lines.
        self.patch.write_text(self.patch.read_text().replace(
            "--- /dev/null\n", "--- a/cactus/local_only.cpp\n"))
        self.verify()
        self.apply_patch()
        self.verify(patched=True)
        self.receipt_snapshot()
        self.verify(patched=True)

    def test_unstaged_source_edit_without_receipt_is_rejected(self):
        self.write("cactus/other.cpp", b"int other() { return 99; }\n")
        self.assert_rejected()

    def test_staged_source_edit_without_receipt_is_rejected(self):
        self.write("libs/audio/helper.h", b"#define FIXTURE 99\n")
        self.git("add", "libs/audio/helper.h")
        self.assert_rejected()

    def test_deleted_tracked_source_without_receipt_is_rejected(self):
        (self.upstream / "cactus/other.cpp").unlink()
        self.assert_rejected()

    def test_added_compiled_source_without_receipt_is_rejected(self):
        self.write("cactus/rogue.cpp", b"int rogue() { return 99; }\n")
        self.assert_rejected()

    def test_added_c_source_without_receipt_is_rejected(self):
        self.write("cactus/rogue.c", b"int rogue(void) { return 99; }\n")
        self.assert_rejected()

    def test_ignored_compiled_source_is_rejected(self):
        self.write(".git/info/exclude", b"cactus/rogue.cpp\n")
        self.write("cactus/rogue.cpp", b"int rogue() { return 99; }\n")
        self.assert_rejected()

    def test_already_patched_checkout_still_rejects_unrelated_edits(self):
        self.apply_patch()
        self.write("cactus/other.cpp", b"int other() { return 99; }\n")
        self.assert_rejected(patched=True)

    def test_source_symlink_is_rejected_even_with_identical_bytes(self):
        source = self.upstream / "cactus/other.cpp"
        source.unlink()
        outside = self.root / "outside.cpp"
        outside.write_bytes(self.originals["cactus/other.cpp"])
        source.symlink_to(outside)
        self.assert_rejected()

    def test_parent_directory_symlink_is_rejected(self):
        directory = self.upstream / "libs/audio"
        outside = self.root / "audio"
        directory.rename(outside)
        directory.symlink_to(outside, target_is_directory=True)
        self.assert_rejected()

    def test_patch_symlink_is_rejected(self):
        actual = self.root / "outside.patch"
        self.patch.rename(actual)
        self.patch.symlink_to(actual)
        self.assert_rejected()

    def test_patch_parent_directory_symlink_is_rejected(self):
        outside = self.root / "outside-support"
        self.patch.parent.rename(outside)
        self.patch.parent.symlink_to(outside, target_is_directory=True)
        self.assert_rejected()

    def test_modified_patch_added_source_is_rejected(self):
        self.apply_patch()
        self.write("cactus/local_only.cpp", b"int local_only() { return 99; }\n")
        self.assert_rejected(patched=True)

    def test_wrong_git_revision_is_rejected(self):
        with mock.patch.object(runtime, "PIN", "f" * 40):
            self.assert_rejected()

    def test_receipt_snapshot_remains_supported(self):
        self.receipt_snapshot()
        self.verify()
        self.apply_patch_without_git()
        self.verify(patched=True)

    def apply_patch_without_git(self):
        subprocess.run(["git", "apply", str(self.patch)], cwd=self.upstream, check=True)

    def test_receipt_snapshot_detects_source_edit(self):
        self.receipt_snapshot()
        self.write("cactus/other.cpp", b"int other() { return 99; }\n")
        self.assert_rejected()

    def test_receipt_snapshot_rejects_new_compiled_source(self):
        self.receipt_snapshot()
        self.write("cactus/rogue.c", b"int rogue(void) { return 99; }\n")
        self.assert_rejected()

    def test_receipt_snapshot_rejects_symlinked_source(self):
        self.receipt_snapshot()
        source = self.upstream / "cactus/other.cpp"
        source.unlink()
        outside = self.root / "outside.cpp"
        outside.write_bytes(self.originals["cactus/other.cpp"])
        source.symlink_to(outside)
        self.assert_rejected()

    def test_wrong_receipt_revision_is_rejected(self):
        self.receipt_snapshot()
        with mock.patch.object(runtime, "PIN", "f" * 40):
            self.assert_rejected()

    def test_missing_git_and_receipt_fail_closed(self):
        (self.upstream / ".git").rename(self.root / "fixture-git-metadata")
        self.assert_rejected()

    def test_main_refuses_existing_output_before_mutating_source(self):
        destination = self.root / 'existing-artifacts'
        destination.mkdir()
        retained = destination / 'keep.txt'
        retained.write_text('retained')
        with mock.patch.object(runtime, 'ROOT', self.package), mock.patch.object(
            sys, 'argv', [str(SCRIPT), '--upstream', str(self.upstream), '--output', str(destination)]
        ), mock.patch.object(runtime, 'run', wraps=runtime.run) as calls:
            with self.assertRaisesRegex(SystemExit, 'Refusing to replace'):
                runtime.main()
        self.assertEqual(retained.read_text(), 'retained')
        self.assertEqual((self.upstream / 'cactus/engine.cpp').read_bytes(), self.originals['cactus/engine.cpp'])
        self.assertEqual(calls.call_count, 0)

    def test_main_refuses_source_edit_before_patch_or_build(self):
        changed = self.write("cactus/other.cpp", b"int other() { return 99; }\n")
        with mock.patch.object(runtime, "ROOT", self.package), mock.patch.object(
            sys, "argv", [str(SCRIPT), "--upstream", str(self.upstream)]
        ), mock.patch.object(runtime, "run", wraps=runtime.run) as calls:
            with self.assertRaises(SystemExit):
                runtime.main()
        self.assertEqual(changed.read_bytes(), b"int other() { return 99; }\n")
        self.assertEqual((self.upstream / "cactus/engine.cpp").read_bytes(),
                         self.originals["cactus/engine.cpp"])
        self.assertFalse((self.upstream / "cactus/local_only.cpp").exists())
        self.assertFalse((self.package / "Artifacts").exists())
        self.assertEqual(calls.call_count, 0)

    def test_main_reuses_approved_patch_and_reaches_only_build_boundary(self):
        self.apply_patch()
        before = (self.upstream / "cactus/engine.cpp").read_bytes()
        actual_run = runtime.run

        def stop_before_build(arguments, cwd=None):
            if str(arguments[0]) == "git":
                return actual_run(arguments, cwd=cwd)
            raise BuildReached()

        with mock.patch.object(runtime, "ROOT", self.package), mock.patch.object(
            sys, "argv", [str(SCRIPT), "--upstream", str(self.upstream)]
        ), mock.patch.object(runtime, "run", side_effect=stop_before_build):
            with self.assertRaises(BuildReached):
                runtime.main()
        self.assertEqual((self.upstream / "cactus/engine.cpp").read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
