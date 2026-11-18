import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

REPOSITORY = Path(__file__).resolve().parents[4]
SCRIPT = REPOSITORY / "native/LocalAIIntegrations/scripts/verify-wax-runtime.py"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RuntimeArtifactGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="memoryos-retrieval-adapter-guard-")
        self.root = Path(self.temporary.name)
        self.framework = self.root / "WaxMemoryRuntime.xcframework/ios-arm64-simulator/WaxMemoryRuntime.framework"
        self.framework.mkdir(parents=True)
        self.binary = self.framework / "WaxMemoryRuntime"
        self.binary.write_bytes(b"Fictional compiled archive")
        self.interface = self.framework / "Modules/WaxMemoryRuntime.swiftmodule/arm64-apple-ios-simulator.swiftinterface"
        self.interface.parent.mkdir(parents=True)
        self.interface.write_bytes(b"Fictional public interface")
        resource = self.root / "Resources/iphonesimulator/Wax_Wax.bundle/fictional.txt"
        resource.parent.mkdir(parents=True)
        resource.write_bytes(b"Fictional resource")
        self.resource = resource
        (self.root / "WaxMemoryRuntime.xcframework/Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [{"SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator", "SupportedArchitectures": ["arm64"], "LibraryIdentifier": "ios-arm64-simulator", "LibraryPath": "WaxMemoryRuntime.framework"}]}))
        source = "native/LocalRetrievalCore/Sources/RetrievalCore/Contracts.swift"
        self.provenance = {"source_files": [{"path": source, "sha256": sha(REPOSITORY / source)}]}
        self.receipt = {"module": "WaxMemoryRuntime", "upstream_revision": "e4587f8cebb76aa92ece008253f13c66b756e68b", "patch_sha256": sha(REPOSITORY / "native/LocalAIIntegrations/Patches/wax-0.1.47-ios-desktop-guards.patch"), "platforms": {"iphonesimulator": {"binary_sha256": sha(self.binary), "interface_sha256": sha(self.interface), "resources_directory": "Resources/iphonesimulator", "resource_files": [{"path": "Wax_Wax.bundle/fictional.txt", "sha256": sha(self.resource)}]}}}
        self.receipt["license_files"] = []
        self.receipt["toolchain"] = subprocess.check_output(["/usr/bin/xcrun", "swift", "--version"], text=True, stderr=subprocess.DEVNULL).strip()
        self.write_receipts()

    def tearDown(self):
        self.temporary.cleanup()

    def write_receipts(self):
        path = self.root / "source-provenance.json"
        path.write_text(json.dumps(self.provenance))
        self.receipt["source_provenance_sha256"] = sha(path)
        (self.root / "packaging-receipt.json").write_text(json.dumps(self.receipt))

    def run_guard(self, platform="iphonesimulator"):
        return subprocess.run(["python3", str(SCRIPT), "--artifacts", str(self.root), "--platform", platform], capture_output=True, text=True)

    def test_matching_source_and_binary_pass(self):
        self.assertEqual(self.run_guard().returncode, 0)

    def test_changed_binary_fails(self):
        self.binary.write_bytes(b"Different archive")
        result = self.run_guard()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("binary differs", result.stderr)

    def test_stale_source_contract_fails(self):
        self.provenance["source_files"][0]["sha256"] = "0" * 64
        self.write_receipts()
        result = self.run_guard()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source changed", result.stderr)

    def test_changed_public_interface_fails(self):
        self.interface.write_bytes(b"Different interface")
        self.assertNotEqual(self.run_guard().returncode, 0)

    def test_missing_resources_fail(self):
        self.resource.unlink()
        self.assertNotEqual(self.run_guard().returncode, 0)

    def test_changed_toolchain_fails(self):
        self.receipt["toolchain"] = "Different Swift toolchain"
        self.write_receipts()
        self.assertNotEqual(self.run_guard().returncode, 0)

    def test_missing_platform_fails(self):
        self.assertNotEqual(self.run_guard("iphoneos").returncode, 0)


if __name__ == "__main__":
    unittest.main()
