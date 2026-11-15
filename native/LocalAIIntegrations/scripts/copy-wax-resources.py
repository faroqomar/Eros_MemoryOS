#!/usr/bin/env python3
"""Copy only receipt-verified Wax bundles into an app's resource root."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

BUNDLES = {"Wax_Wax.bundle", "Wax_WaxVectorSearch.bundle", "MetalANNS_MetalANNSCore.bundle",
           "GRDB_GRDB.bundle", "swift-crypto_Crypto.bundle"}
MARKER = ".memoryos-wax-resource-ownership.json"


def inventory(root):
    result = {}
    for f in sorted(root.rglob("*")):
        if f.is_symlink():
            raise RuntimeError("Resource symlink is not allowed: " + str(f))
        if f.is_file():
            result[str(f.relative_to(root))] = hashlib.sha256(f.read_bytes()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform-source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--staging-root", type=Path, help="Optional declared Xcode sandbox output directory")
    args = parser.parse_args()
    source, destination, receipt_path = (x.resolve() for x in [args.platform_source, args.destination, args.receipt])
    receipt = json.loads(receipt_path.read_text())
    if receipt.get("format_version") != 1 or set(receipt.get("required_resource_bundles", [])) != BUNDLES:
        raise RuntimeError("Unsupported resource receipt")
    matching = [(key, value) for key, value in receipt["platforms"].items()
                if (receipt_path.parent / value["resources_directory"]).resolve() == source]
    if len(matching) != 1:
        raise RuntimeError("Platform source does not match this packaging receipt")
    platform, record = matching[0]
    if source == destination or source in destination.parents or destination in source.parents:
        raise RuntimeError("Source and app resource destination must be separate")
    if {f.name for f in source.iterdir()} != BUNDLES:
        raise RuntimeError("Unexpected platform resource directory contents")
    expected = {row["path"]: row["sha256"] for row in record["resource_files"]}
    actual_source = inventory(source)
    if actual_source != expected:
        details = {
            "missing": sorted(set(expected) - set(actual_source)),
            "extra": sorted(set(actual_source) - set(expected)),
            "changed": sorted(k for k in set(actual_source) & set(expected) if actual_source[k] != expected[k]),
        }
        raise RuntimeError("Source resource hashes differ from packaging receipt: " + json.dumps(details))
    if not destination.exists():
        destination.mkdir(parents=True)
    elif not destination.is_dir():
        raise RuntimeError("App resource destination is not a directory")
    marker = destination / MARKER
    prior = json.loads(marker.read_text()) if marker.exists() else {}
    owned = prior.get("resource_files", {})
    for name in BUNDLES:
        existing = destination / name
        if existing.exists():
            if not existing.is_dir() or existing.is_symlink():
                raise RuntimeError("Conflicting app resource: " + name)
            actual = {name + "/" + k: v for k, v in inventory(existing).items()}
            wanted = {k: v for k, v in expected.items() if k.startswith(name + "/")}
            previous = {k: v for k, v in owned.items() if k.startswith(name + "/")}
            if actual != wanted and (not previous or actual != previous):
                raise RuntimeError("Preserving app resources with no matching Wax ownership: " + name)
    staging_root = args.staging_root.resolve() if args.staging_root else destination.parent
    if source == staging_root or source in staging_root.parents or staging_root == destination or destination in staging_root.parents:
        raise RuntimeError("Staging must stay outside source and app resource roots")
    if not staging_root.exists():
        staging_root.mkdir(parents=True)
    staging = Path(tempfile.mkdtemp(prefix="memoryos-wax-copy-", dir=staging_root))
    changed = []
    try:
        for name in BUNDLES:
            shutil.copytree(source / name, staging / "incoming" / name)
        if inventory(staging / "incoming") != expected:
            raise RuntimeError("Staged resource verification failed")
        for name in sorted(BUNDLES):
            existing, backup = destination / name, staging / "previous" / name
            if existing.exists():
                backup.parent.mkdir(exist_ok=True)
                existing.rename(backup)
            changed.append(name)
            (staging / "incoming" / name).rename(existing)
        metadata = dict(platform=platform, packaging_receipt_sha256=hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
                        resource_files=expected)
        pending = staging / "ownership.json"
        pending.write_text(json.dumps(metadata, indent=2) + "\n")
        pending.replace(marker)
    except BaseException:
        for name in reversed(changed):
            existing, backup = destination / name, staging / "previous" / name
            if existing.exists():
                shutil.rmtree(existing)
            if backup.exists():
                backup.rename(existing)
        raise
    finally:
        shutil.rmtree(staging)
    print("Verified and copied five Wax resource bundles for " + platform)


if __name__ == "__main__":
    main()
