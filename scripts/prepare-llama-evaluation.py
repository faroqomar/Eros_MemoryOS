#!/usr/bin/env python3
"""Build isolated llama.cpp CPU frameworks for Mac, iOS Simulator and iPhone.

Only llama's public C API is exported. Static linkage can resolve its GGML/GGUF
references against a different version exported by a speech framework.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

PIN = "a956a852c9c8bc1fb07206364838ddef299178c0"
SOURCE = Path("/Users/eros/Dev/Tools/MemoryOS-Evaluation-Upstream/llama.cpp")
CACHE = Path("/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/llama-build")
REPO = Path(__file__).resolve().parents[1]
DESTINATION = REPO / "native/LocalTextEvaluation/Artifacts/llama.xcframework"
CMAKE = Path("/Users/eros/Library/Android/sdk/cmake/3.22.1/bin/cmake")
NINJA = CMAKE.with_name("ninja")


def run(arguments):
    print("Running:", " ".join(map(str, arguments)), flush=True)
    subprocess.run(list(map(str, arguments)), check=True, env=dict(os.environ, GIT_NO_LAZY_FETCH="1"))


def main():
    receipt = json.loads((SOURCE / ".memoryos-upstream-source.json").read_text())
    if receipt["revision"] != PIN:
        raise SystemExit("Unexpected upstream source revision.")
    for name, expected in receipt["files"].items():
        if hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() != expected:
            raise SystemExit("Upstream source changed after verification: " + name)
    if not CMAKE.exists() or not NINJA.exists():
        raise SystemExit("The reviewed existing CMake/Ninja tools are unavailable.")
    CACHE.mkdir(parents=True, exist_ok=True)
    frameworks = []
    for platform, system, sdk, minimum in [
        ("macos", "Darwin", "macosx", "14.0"),
        ("simulator", "iOS", "iphonesimulator", "18.0"),
        ("device", "iOS", "iphoneos", "18.0"),
    ]:
        build = CACHE / platform
        sysroot = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        run([CMAKE, "-S", SOURCE, "-B", build, "-G", "Ninja",
             "-DCMAKE_MAKE_PROGRAM=" + str(NINJA), "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_SYSTEM_NAME=" + system, "-DCMAKE_SYSTEM_PROCESSOR=arm64", "-DCMAKE_OSX_SYSROOT=" + sysroot,
             "-DCMAKE_OSX_ARCHITECTURES=arm64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=" + minimum,
             "-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF", "-DGGML_LTO=OFF", "-DLLAMA_BUILD_COMMON=OFF", "-DLLAMA_BUILD_TESTS=OFF",
             "-DLLAMA_BUILD_TOOLS=OFF", "-DLLAMA_BUILD_EXAMPLES=OFF", "-DLLAMA_BUILD_SERVER=OFF",
             "-DLLAMA_BUILD_APP=OFF", "-DLLAMA_BUILD_MTMD=OFF", "-DLLAMA_BUILD_HTML=OFF",
             "-DLLAMA_OPENSSL=OFF", "-DLLAMA_BUILD_NUMBER=12387", "-DLLAMA_BUILD_COMMIT=" + PIN,
             "-DGGML_METAL=OFF", "-DGGML_OPENMP=OFF", "-DGGML_NATIVE=OFF",
             "-DGGML_CPU_KLEIDIAI=OFF", "-DGGML_ACCELERATE=ON", "-DGGML_BLAS=ON",
             "-DGGML_BLAS_VENDOR=Apple"])
        run([CMAKE, "--build", build, "--parallel", "2"])
        framework = CACHE / (platform + "-framework") / "llama.framework"
        if framework.exists():
            shutil.rmtree(framework)
        (framework / "Headers").mkdir(parents=True)
        (framework / "Modules").mkdir()
        libraries = [p for p in build.rglob("lib*.a") if p.name in {
            "libllama.a", "libggml.a", "libggml-base.a", "libggml-cpu.a", "libggml-blas.a"}]
        if not any(p.name == "libllama.a" for p in libraries):
            raise SystemExit("llama.cpp did not produce its real static library.")
        archive = build / "libmemoryos-llama.a"
        run(["xcrun", "libtool", "-static", "-o", archive, *sorted(libraries)])
        symbols = subprocess.check_output(["nm", "-gUj", archive], text=True).splitlines()
        exports = sorted({symbol for symbol in symbols if symbol.startswith("_llama_")})
        if "_llama_model_load_from_file" not in exports:
            raise SystemExit("The reviewed llama public API is missing.")
        export_file = build / "llama.exports"
        export_file.write_text("\n".join(exports) + "\n")
        target = {"macos": "arm64-apple-macos14.0", "simulator": "arm64-apple-ios18.0-simulator",
                  "device": "arm64-apple-ios18.0"}[platform]
        run(["xcrun", "clang++", "-dynamiclib", "-target", target, "-isysroot", sysroot,
             "-Wl,-all_load", archive, "-Wl,-exported_symbols_list," + str(export_file),
             "-Wl,-install_name,@rpath/llama.framework/llama", "-framework", "Accelerate",
             "-o", framework / "llama"])
        actual = set(subprocess.check_output(["nm", "-gUj", framework / "llama"], text=True).splitlines())
        if actual != set(exports):
            raise SystemExit("The llama framework must export only its public C API.")
        imports = subprocess.check_output(["nm", "-u", framework / "llama"], text=True)
        if any(name in imports for name in ("_ggml_", "_gguf_", "_whisper_")):
            raise SystemExit("The llama framework has unresolved engine internals.")
        for include in [SOURCE / "include", SOURCE / "ggml/include"]:
            for header in include.glob("*.h"):
                shutil.copy2(header, framework / "Headers" / header.name)
        (framework / "Modules/module.modulemap").write_text('framework module llama {\n  umbrella header "llama.h"\n  export *\n}\n')
        info = {"CFBundleIdentifier": "org.ggml.llama.memoryos-evaluation", "CFBundleName": "llama",
                "CFBundleExecutable": "llama", "CFBundlePackageType": "FMWK",
                "CFBundleVersion": "12387", "CFBundleShortVersionString": "1.0",
                "CFBundleSupportedPlatforms": [{"macos": "MacOSX", "simulator": "iPhoneSimulator", "device": "iPhoneOS"}[platform]],
                "MinimumOSVersion": minimum}
        (framework / "Info.plist").write_bytes(plistlib.dumps(info))
        frameworks.append(framework)
    staging = DESTINATION.with_name("llama.staging.xcframework")
    if staging.exists():
        shutil.rmtree(staging)
    staging.parent.mkdir(parents=True, exist_ok=True)
    command = ["xcodebuild", "-create-xcframework"]
    for framework in frameworks:
        command += ["-framework", framework]
    run([*command, "-output", staging])
    if DESTINATION.exists():
        shutil.rmtree(DESTINATION)
    staging.rename(DESTINATION)
    shutil.copy2(SOURCE / "LICENSE", DESTINATION / "LICENSE")
    result = {"revision": PIN, "release": "b12387", "patches": [],
              "linkage": "dynamic, two-level namespace; only llama_* exported; private GGML/GGUF",
              "backend": "CPU + Apple Accelerate; no Metal, curl, TLS or server features",
              "platforms": ["macOS arm64", "iOS Simulator arm64", "iOS device arm64"],
              "sourceReceipt": receipt, "sdkBinarySHA256": {
                  str(p.relative_to(DESTINATION)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in DESTINATION.rglob("llama") if p.is_file()}}
    (DESTINATION.parent / "llama-build-receipt.json").write_text(json.dumps(result, indent=2)+"\n")
    print("Verified-source CPU framework ready:", DESTINATION, flush=True)


if __name__ == "__main__":
    main()
