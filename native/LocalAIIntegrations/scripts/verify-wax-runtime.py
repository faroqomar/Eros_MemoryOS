#!/usr/bin/env python3
"""Reject a stale runtime archive before linking it with the app-owned source contract."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", required=True, type=Path)
    parser.add_argument("--platform", required=True, choices=["macosx", "iphoneos", "iphonesimulator"])
    args = parser.parse_args()
    artifacts = args.artifacts.resolve()
    repo = Path(__file__).resolve().parents[3]
    receipt = json.loads((artifacts / "packaging-receipt.json").read_text())
    current_toolchain = subprocess.check_output(["/usr/bin/xcrun", "swift", "--version"], text=True, stderr=subprocess.DEVNULL).strip()
    normalize = lambda value: " ".join(value.split())
    if normalize(current_toolchain) != normalize(receipt.get("toolchain", "")):
        raise RuntimeError("Wax runtime toolchain differs; rebuild the artifact before linking its source contract.")
    provenance_file = artifacts / "source-provenance.json"
    if receipt.get("module") != "WaxMemoryRuntime" or receipt.get("upstream_revision") != "e4587f8cebb76aa92ece008253f13c66b756e68b":
        raise RuntimeError("Unexpected Wax runtime identity.")
    if digest(provenance_file) != receipt["source_provenance_sha256"]:
        raise RuntimeError("Wax source provenance changed.")
    patch = repo / "native/LocalAIIntegrations/Patches/wax-0.1.47-ios-desktop-guards.patch"
    if digest(patch) != receipt["patch_sha256"]:
        raise RuntimeError("Wax mobile guard patch changed; rebuild the artifact.")
    provenance = json.loads(provenance_file.read_text())
    for row in provenance["source_files"]:
        source = (repo / row["path"]).resolve()
        if repo not in source.parents or digest(source) != row["sha256"]:
            raise RuntimeError("Wax adapter/core source changed; rebuild the artifact: " + row["path"])
    xcframework = artifacts / "WaxMemoryRuntime.xcframework"
    info = plistlib.loads((xcframework / "Info.plist").read_bytes())
    platform, variant = {"macosx": ("macos", None), "iphoneos": ("ios", None), "iphonesimulator": ("ios", "simulator")}[args.platform]
    rows = [row for row in info["AvailableLibraries"] if row["SupportedPlatform"] == platform and row.get("SupportedPlatformVariant") == variant and row["SupportedArchitectures"] == ["arm64"]]
    if len(rows) != 1:
        raise RuntimeError("Missing or ambiguous Wax runtime architecture slice.")
    row = rows[0]
    framework = xcframework / row["LibraryIdentifier"] / row["LibraryPath"]
    if digest(framework / "WaxMemoryRuntime") != receipt["platforms"][args.platform]["binary_sha256"]:
        raise RuntimeError("Wax runtime binary differs from its build receipt.")
    record = receipt["platforms"][args.platform]
    interfaces = list((framework / "Modules/WaxMemoryRuntime.swiftmodule").glob("*.swiftinterface"))
    if len(interfaces) != 1 or digest(interfaces[0]) != record["interface_sha256"]:
        raise RuntimeError("Wax runtime public interface differs from its build receipt.")
    resources = artifacts / record["resources_directory"]
    expected = {row["path"]: row["sha256"] for row in record["resource_files"]}
    actual = {}
    for item in resources.rglob("*"):
        if item.is_symlink():
            raise RuntimeError("Unexpected Wax resource symlink.")
        if item.is_file():
            actual[str(item.relative_to(resources))] = digest(item)
    if actual != expected:
        raise RuntimeError("Wax runtime resources differ from their build receipt.")
    for license in receipt["license_files"]:
        source = artifacts / license["path"]
        if digest(source) != license["sha256"]:
            raise RuntimeError("Wax runtime license differs from its build receipt.")
        bundled = artifacts.parent / "Sources/WaxMemoryRuntimeDependencies/Resources" / Path(license["path"]).relative_to("Licenses")
        if digest(bundled) != license["sha256"]:
            raise RuntimeError("Wax runtime bundled license differs from its build receipt.")
    print("Verified Wax runtime source contract, interface, resources, licenses and " + args.platform + " archive.")


if __name__ == "__main__":
    main()
