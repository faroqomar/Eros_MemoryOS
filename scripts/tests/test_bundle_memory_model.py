import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bundle_memory", Path(__file__).parents[1] / "bundle-memory-model.py")
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class BundleMemoryTests(unittest.TestCase):
    def test_copies_only_verified_files_and_rejects_modified_weights(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "source"
            source.mkdir()
            (source / "weights").write_bytes(b"fictional weights")
            (source / "unreviewed").write_bytes(b"not in manifest")
            manifest = source / bundle.MANIFEST
            manifest.write_text(json.dumps({"files": {"weights": bundle.digest(source / "weights")}}))
            target = root / "destination"
            with patch.object(bundle, "MANIFEST_SHA", bundle.digest(manifest)):
                with patch("sys.argv", ["bundle", "--source", str(source), "--destination", str(target)]):
                    bundle.main()
                    bundle.main()
                self.assertEqual((target / "weights").read_bytes(), b"fictional weights")
                self.assertFalse((target / "unreviewed").exists())
                (source / "weights").write_bytes(b"changed")
                with self.assertRaises(ValueError):
                    bundle.verify(source)
                self.assertEqual((target / "weights").read_bytes(), b"fictional weights")

    def test_rejects_symlink_and_traversal(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "source"
            source.mkdir()
            (root / "outside").write_bytes(b"outside")
            (source / "link").symlink_to(root / "outside")
            for name in ["link", "../outside"]:
                manifest = source / bundle.MANIFEST
                manifest.write_text(json.dumps({"files": {name: hashlib.sha256(b"outside").hexdigest()}}))
                with patch.object(bundle, "MANIFEST_SHA", bundle.digest(manifest)):
                    with self.assertRaises(ValueError):
                        bundle.verify(source)


if __name__ == "__main__":
    unittest.main()
