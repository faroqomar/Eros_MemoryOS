#!/usr/bin/env python3
"""Prepare an explicit offline runtime-only Wax build graph from reviewed external sources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

REVISION = "e4587f8cebb76aa92ece008253f13c66b756e68b"
PINS = {
    "MetalANNS": "13960499c40abd3f06443eb80258e08a6b777da4",
    "GRDB.swift": "92a554cd0d5e8d67cb18993c6054e73fe42c066c",
    "swift-crypto": "95ba0316a9b733e92bb6b071255ff46263bbe7dc",
    "swift-asn1": "917b472dbe53ba699cbb0495f9a95a084bc6364d",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(path):
    value = hashlib.sha256()
    for item in sorted(path.rglob("*")):
        relative = item.relative_to(path)
        if any(part in {".git", ".build", ".swiftpm"} for part in relative.parts):
            continue
        if item.is_symlink():
            # Reviewed upstream test/source aliases must stay inside their own checkout.
            resolved = item.resolve()
            if resolved != path and path not in resolved.parents:
                raise RuntimeError("SDK symlink escapes its checkout: " + str(item))
            value.update(str(relative).encode() + b"\0link\0" + str(item.readlink()).encode())
            continue
        if item.is_file():
            value.update(str(relative).encode() + b"\0" + bytes.fromhex(digest(item)))
    return value.hexdigest()


def verify_patched_tree(wax, receipt, patch):
    source = Path(receipt["source"])
    allowed = {"Sources/Wax/Broker/AgentBrokerClient.swift", "Sources/Wax/MemorySemantics.swift"}
    if set(receipt["patched_files"]) != allowed:
        raise RuntimeError("Wax receipt changes files outside the reviewed mobile guard patch.")
    with tempfile.TemporaryDirectory(prefix="memoryos-retrieval-adapter-patch-check-") as temporary:
        base = Path(temporary)
        for name in allowed:
            output = base / name
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(subprocess.check_output(["git", "-C", str(source), "show", REVISION + ":" + name]))
        subprocess.run(["/usr/bin/patch", "--batch", "--forward", "-p1", "-i", str(patch)], cwd=base, check=True, stdout=subprocess.DEVNULL)
        if {name: digest(base / name) for name in allowed} != receipt["patched_files"]:
            raise RuntimeError("Wax receipt does not represent the exact reviewed patch applied to the pinned tree.")
    entries = subprocess.check_output(["git", "-C", str(source), "ls-tree", "-r", "-z", REVISION]).split(b"\0")
    expected = {}
    for entry in entries:
        if not entry:
            continue
        metadata, raw_name = entry.split(b"\t", 1)
        mode, kind, object_id = metadata.decode().split()
        if kind != "blob" or mode not in {"100644", "100755"}:
            raise RuntimeError("Wax archive entry requires separate review: " + raw_name.decode())
        expected[raw_name.decode()] = (mode, object_id)
    actual = {str(item.relative_to(wax)) for item in wax.rglob("*") if item.is_file() or item.is_symlink()}
    if actual != set(expected):
        raise RuntimeError("Wax prepared tree contains missing or unexpected files.")
    for name, (mode, object_id) in expected.items():
        item = wax / name
        if item.is_symlink() or bool(item.stat().st_mode & 0o111) != (mode == "100755"):
            raise RuntimeError("Wax source type/mode differs from the pinned tree: " + name)
        content = item.read_bytes()
        if name in receipt["patched_files"]:
            if hashlib.sha256(content).hexdigest() != receipt["patched_files"][name]:
                raise RuntimeError("Wax mobile patch bytes changed: " + name)
        elif hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest() != object_id:
            raise RuntimeError("Wax file differs from the pinned tree: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wax-source", required=True, type=Path)
    parser.add_argument("--dependency-checkouts", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    wax, dependencies, destination = args.wax_source.resolve(), args.dependency_checkouts.resolve(), args.destination.resolve()
    if (destination.exists() and not args.verify_only) or destination == repo or repo in destination.parents:
        parser.error("Use a new temporary directory outside the app repository.")
    receipt = json.loads((wax.parent / (wax.name + "-patch-receipt.json")).read_text())
    patch = repo / "native/LocalAIIntegrations/Patches/wax-0.1.47-ios-desktop-guards.patch"
    if receipt["upstream_revision"] != REVISION or receipt["patch_sha256"] != digest(patch):
        parser.error("Wax source receipt does not match the reviewed patch and revision.")
    for name, expected in receipt["patched_files"].items():
        if digest(wax / name) != expected:
            parser.error("Patched Wax source changed: " + name)
    verify_patched_tree(wax, receipt, patch)
    sdks = [{"identity": "wax", "path": str(wax), "revision": REVISION, "manifest_sha256": digest(wax / "Package.swift"), "tree_sha256": tree_digest(wax)}]
    for name, revision in PINS.items():
        path = dependencies / name
        head = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
        status = subprocess.check_output(["git", "-C", str(path), "status", "--porcelain", "--untracked-files=no"], text=True).strip()
        untracked = subprocess.check_output(["git", "-C", str(path), "ls-files", "--others", "--exclude-standard"], text=True).splitlines()
        ignored = subprocess.check_output(["git", "-C", str(path), "ls-files", "--others", "--ignored", "--exclude-standard"], text=True).splitlines()
        unexpected = [name for name in untracked + ignored if not name.startswith((".build/", ".swiftpm/")) and not name.endswith(".DS_Store")]
        if head != revision or status or unexpected:
            parser.error("Dependency checkout is not the reviewed clean revision: " + name)
        sdks.append({"identity": name.lower(), "path": str(path), "revision": revision, "manifest_sha256": digest(path / "Package.swift"), "tree_sha256": tree_digest(path)})
    if args.verify_only:
        print(json.dumps({"verified_pinned_tree_and_patch": True, "sdk_tree_hashes": {sdk["identity"]: sdk["tree_sha256"] for sdk in sdks}}, sort_keys=True))
        return
    destination.mkdir(parents=True)
    source = repo / "native/LocalAIIntegrations/Sources/WaxMemoryRuntime/WaxRecallIndex.swift"
    target = destination / "Sources/WaxMemoryRuntime/WaxRecallIndex.swift"
    target.parent.mkdir(parents=True)
    shutil.copy2(source, target)
    paths = [str(wax)] + [str(dependencies / name) for name in PINS]
    sdk_dependencies = ",\n".join('    .package(path: ' + json.dumps(path) + (', traits: [])' if index == 0 else ')') for index, path in enumerate(paths))
    manifest = '''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "WaxRuntimePackaging", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "WaxMemoryRuntime", targets: ["WaxMemoryRuntime"])],
  dependencies: [
    .package(path: CORE),
SDK
  ],
  targets: [.target(name: "WaxMemoryRuntime", dependencies: [.product(name: "RetrievalCore", package: "LocalRetrievalCore"), .product(name: "Wax", package: "Wax")], swiftSettings: [.unsafeFlags(["-enable-library-evolution", "-emit-module-interface"])])], swiftLanguageModes: [.v6])
'''.replace("CORE", json.dumps(str(repo / "native/LocalRetrievalCore"))).replace("SDK", sdk_dependencies)
    (destination / "Package.swift").write_text(manifest)
    source_paths = [source, repo / "native/LocalRetrievalCore/Sources/RetrievalCore/Contracts.swift", repo / "native/LocalRetrievalCore/Package.swift"]
    provenance = {"temporary_root_manifest_sha256": digest(destination / "Package.swift"), "source_files": [{"path": str(path.relative_to(repo)), "sha256": digest(path), **({"temporary_path": str(target)} if path == source else {})} for path in source_paths], "sdks": sdks, "patch_sha256": digest(patch)}
    output = destination / "source-provenance.json"
    output.write_text(json.dumps(provenance, indent=2) + "\n")
    print(output)


if __name__ == "__main__":
    main()
