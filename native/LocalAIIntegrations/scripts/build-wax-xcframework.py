#!/usr/bin/env python3
"""Build the explicit verified Wax graph into a static evaluation XCFramework."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

BUNDLES = {"Wax_Wax.bundle", "Wax_WaxVectorSearch.bundle", "MetalANNS_MetalANNSCore.bundle",
           "GRDB_GRDB.bundle", "swift-crypto_Crypto.bundle"}
SLICES = [("simulator", "iphonesimulator", "arm64-apple-ios18.0-simulator", "Release-iphonesimulator", "arm64-apple-ios-simulator"),
          ("device", "iphoneos", "arm64-apple-ios18.0", "Release-iphoneos", "arm64-apple-ios"),
          ("macos", "macosx", "arm64-apple-macos14.0", "Release", "arm64-apple-macos")]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--package", required=True, type=Path, help="Explicit temporary graph with adapter-only library evolution flags")
    p.add_argument("--build-root", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--evidence", required=True, type=Path)
    p.add_argument("--source-provenance", required=True, type=Path, help="Reviewed exact source and SDK manifest hashes")
    args = p.parse_args()
    root, build, output, evidence = (x.resolve() for x in [args.package, args.build_root, args.output, args.evidence])
    provenance = json.loads(args.source_provenance.read_text())
    repository = Path(__file__).resolve().parents[3]
    def verify_sources():
        if digest(root / "Package.swift") != provenance["temporary_root_manifest_sha256"]:
            raise RuntimeError("Explicit build manifest differs from source provenance")
        for row in provenance["source_files"]:
            if digest(repository / row["path"]) != row["sha256"]:
                raise RuntimeError("App-owned source changed: " + row["path"])
        for row in provenance["sdks"]:
            if digest(Path(row["path"]) / "Package.swift") != row["manifest_sha256"]:
                raise RuntimeError("SDK manifest changed: " + row["identity"])
    verify_sources()
    if output.exists():
        p.error("Output already exists; preserve it and choose a new output.")
    output.mkdir(parents=True)
    evidence.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(PATH="/usr/bin:/bin:/usr/sbin:/sbin", GIT_NO_LAZY_FETCH="1", GIT_ALLOW_PROTOCOL="none")
    records, frameworks = {}, []
    for name, sdk, triple, configuration, module_triple in SLICES:
        scratch = build / name
        sdk_path = subprocess.check_output(["/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        command = ["/usr/bin/swift", "build", "--package-path", str(root), "--scratch-path", str(scratch),
                   "-c", "release", "--target", "WaxEvaluationAdapter", "--triple", triple, "--sdk", sdk_path, "--jobs", "4"]
        start = time.time()
        with (evidence / ("xcframework-" + name + "-build.log")).open("w") as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError("Actual slice build failed: " + name)
        verify_sources()
        framework = output / "Slices" / name / "WaxEvaluationAdapter.framework"
        modules = framework / "Modules/WaxEvaluationAdapter.swiftmodule"
        modules.mkdir(parents=True)
        objects = sorted(f for f in scratch.rglob("*.o") if "/" + configuration + "/" in str(f)
                         and "/Objects-normal/arm64/" in str(f)
                         and not any("AIEvaluationCore" in part for part in f.parts))
        if not objects or any("Tests" in str(f) or "CLI" in str(f) for f in objects):
            raise RuntimeError("Unexpected static archive input graph")
        interfaces = list(scratch.rglob("WaxEvaluationAdapter.swiftinterface"))
        if len(interfaces) != 1:
            raise RuntimeError("Expected one actual adapter public interface")
        interface = interfaces[0].read_text()
        if any("import " + vendor in interface for vendor in ["Wax", "MetalANNS", "GRDB", "Crypto", "SwiftASN1"]):
            raise RuntimeError("Vendor module escaped into public interface")
        shutil.copy2(interfaces[0], modules / (module_triple + ".swiftinterface"))
        filelist = evidence / ("xcframework-" + name + "-objects.txt")
        filelist.write_text("\n".join(str(f) for f in objects) + "\n")
        subprocess.run(["/usr/bin/xcrun", "libtool", "-static", "-o", str(framework / "WaxEvaluationAdapter"),
                        "-filelist", str(filelist)], env=env, check=True)
        info = dict(CFBundleDevelopmentRegion="en", CFBundleExecutable="WaxEvaluationAdapter",
                    CFBundleIdentifier="com.eros.memoryos.evaluation.wax", CFBundleInfoDictionaryVersion="6.0",
                    CFBundleName="WaxEvaluationAdapter", CFBundlePackageType="FMWK",
                    CFBundleShortVersionString="0.1.47", CFBundleVersion="1",
                    CFBundleSupportedPlatforms=[{"macosx": "MacOSX", "iphoneos": "iPhoneOS", "iphonesimulator": "iPhoneSimulator"}[sdk]])
        info["LSMinimumSystemVersion" if sdk == "macosx" else "MinimumOSVersion"] = "14.0" if sdk == "macosx" else "18.0"
        (framework / "Info.plist").write_bytes(plistlib.dumps(info))
        resources = scratch / "out/Products" / configuration
        actual = {f.name for f in resources.glob("*.bundle")}
        if actual != BUNDLES:
            raise RuntimeError("Unexpected SDK resource bundles: " + str(actual))
        source_files = []
        for bundle in sorted(actual):
            destination = output / "Resources" / sdk / bundle
            shutil.copytree(resources / bundle, destination)
            for f in sorted(destination.rglob("*")):
                if f.is_symlink():
                    raise RuntimeError("Unexpected resource symlink")
                if f.is_file():
                    source_files.append(dict(path=str(f.relative_to(output / "Resources" / sdk)), sha256=digest(f), bytes=f.stat().st_size))
        platform_resources = output / "Resources" / sdk
        inputs = [platform_resources] + sorted(platform_resources.rglob("*"))
        (output / "Resources" / (sdk + ".xcfilelist")).write_text("\n".join(str(f) for f in inputs) + "\n")
        records[sdk] = dict(triple=triple, argv=command, build_seconds=time.time() - start,
                            static_object_count=len(objects), excluded_core_objects=True,
                            selected_object_targets=sorted({part.removesuffix("-t.build") for f in objects for part in f.parts if part.endswith("-t.build")}),
                            framework=str(framework.relative_to(output)), binary_sha256=digest(framework / "WaxEvaluationAdapter"),
                            interface_sha256=digest(modules / (module_triple + ".swiftinterface")),
                            resources_directory="Resources/" + sdk, resource_files=source_files)
        frameworks.append(framework)
        print(json.dumps({"completed_slice": name, "objects": len(objects), "seconds": time.time() - start}), flush=True)
    command = ["/usr/bin/xcodebuild", "-create-xcframework"]
    for framework in frameworks:
        command += ["-framework", str(framework)]
    command += ["-output", str(output / "WaxEvaluationAdapter.xcframework")]
    subprocess.run(command, check=True, env=env)
    licenses = []
    for package in provenance["sdks"]:
        source = Path(package["path"])
        for f in source.iterdir():
            if f.is_file() and f.name.lower() in ["license", "license.txt", "notice", "notice.txt", "copying"]:
                target = output / "Licenses" / package["identity"] / f.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, target)
                licenses.append(dict(path=str(target.relative_to(output)), sha256=digest(target)))
    shutil.copy2(args.source_provenance, output / "source-provenance.json")
    receipt = dict(format_version=1, purpose="Personal experimental evaluation; not a release artifact",
                   upstream_revision="e4587f8cebb76aa92ece008253f13c66b756e68b",
                   patch_sha256=digest(Path(__file__).resolve().parents[1] / "Patches/wax-0.1.47-ios-desktop-guards.patch"),
                   temporary_root_manifest_sha256=digest(root / "Package.swift"),
                   required_resource_bundles=sorted(BUNDLES), platforms=records,
                   source_provenance_sha256=digest(output / "source-provenance.json"), license_files=licenses,
                   core_binary_abi="Exact recorded source/toolchain only; AIEvaluationCore not built as a stable external binary library.",
                   toolchain=subprocess.check_output(["/usr/bin/swift", "--version"], text=True).strip())
    (output / "packaging-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(output / "packaging-receipt.json", flush=True)


if __name__ == "__main__":
    main()
