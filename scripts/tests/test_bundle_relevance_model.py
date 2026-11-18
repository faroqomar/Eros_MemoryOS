import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "relevance_bundle", Path(__file__).resolve().parents[1] / "bundle-relevance-model.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BundleRelevanceTests(unittest.TestCase):
    def test_verified_copy_and_repair_leave_source_intact(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, target = root / "source", root / "bundle" / "model"
            payload = b"fictional model fixture"
            source.write_bytes(payload)
            expected = hashlib.sha256(payload).hexdigest()
            module.copy_verified(source, target, expected, len(payload))
            self.assertEqual(target.read_bytes(), payload)
            target.write_bytes(b"damaged")
            module.copy_verified(source, target, expected, len(payload))
            self.assertEqual(target.read_bytes(), payload)
            self.assertEqual(source.read_bytes(), payload)
            self.assertEqual(list(target.parent.glob(".relevance-*")), [])

    def test_obsolete_cleanup_preserves_unknown_and_linked_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            old = root / "Qwen3-1.7B-Q4_K_M.gguf"
            old.write_bytes(b"unknown contents")
            module.remove_obsolete_bundled_model(root / "Qwen3-4B-Q4_K_M.gguf")
            self.assertEqual(old.read_bytes(), b"unknown contents")
            old.unlink()
            original = root / "source"
            original.write_bytes(b"keep")
            old.symlink_to(original)
            module.remove_obsolete_bundled_model(root / "Qwen3-4B-Q4_K_M.gguf")
            self.assertTrue(old.is_symlink())
            self.assertEqual(original.read_bytes(), b"keep")

    def test_bad_source_and_symlinks_do_not_replace_existing_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, target = root / "source", root / "target"
            source.write_bytes(b"abc")
            target.write_bytes(b"keep")
            with self.assertRaises(ValueError):
                module.copy_verified(source, target, "0" * 64, 3)
            self.assertEqual(target.read_bytes(), b"keep")
            link = root / "link"
            link.symlink_to(source)
            with self.assertRaises(ValueError):
                module.copy_verified(link, target, hashlib.sha256(b"abc").hexdigest(), 3)
            link.unlink()
            link.symlink_to(target)
            with self.assertRaises(ValueError):
                module.copy_verified(source, link, hashlib.sha256(b"abc").hexdigest(), 3)
            self.assertEqual(target.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
