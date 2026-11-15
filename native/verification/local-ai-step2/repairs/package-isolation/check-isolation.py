#!/usr/bin/env python3
"""Exercise main-app package isolation using a source-only temporary checkout."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    parser.add_argument("--build", action="store_true")
    arguments = parser.parse_args()
    evidence = Path(__file__).resolve().parent / arguments.phase
    evidence.mkdir(parents=True, exist_ok=False)
    repository = Path(__file__).resolve().parents[5]
    scratch = Path(tempfile.mkdtemp(prefix="memoryos-package-isolation-"))
    receipt = {
        "phase": arguments.phase,
        "scratch": str(scratch),
        "artifactsCopied": False,
        "sourceProjectSHA256": hashlib.sha256(
            (repository / "native/MemoryOS.xcodeproj/project.pbxproj").read_bytes()
        ).hexdigest(),
        "commands": [],
    }
    try:
        for name in [
            "MemoryOS.xcodeproj", "MemoryOS", "MemoryOSUITests", "MemoryOSTests",
            "LocalMemory", "LocalAIEvaluation", "LocalCactusEvaluation",
            "LocalTextEvaluation", "LocalAIIntegrations/BinaryIntegration",
            "LocalMLXEvaluation/SimulatorAvailability",
        ]:
            shutil.copytree(
                repository / "native" / name, scratch / "native" / name,
                ignore=shutil.ignore_patterns(".build", "Artifacts", "xcuserdata", "project.xcworkspace"),
            )
        shutil.copy2(
            scratch / "native/MemoryOS.xcodeproj/project.pbxproj",
            evidence / "project.pbxproj",
        )
        assert not list(scratch.rglob("*.xcframework"))
        base = [
            "xcodebuild", "-project", str(scratch / "native/MemoryOS.xcodeproj"),
            "-scheme", "MemoryOS", "-clonedSourcePackagesDirPath", str(scratch / "packages"),
        ]

        def run(name, command):
            start = time.monotonic()
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            (evidence / (name + ".log")).write_text(result.stdout)
            receipt["commands"].append({
                "name": name, "arguments": command, "exitCode": result.returncode,
                "seconds": time.monotonic() - start,
            })
            for match in re.findall(r"Writing error result bundle to (.+\.xcresult)", result.stdout):
                bundle = Path(match)
                if bundle.is_dir():
                    shutil.copytree(bundle, evidence / (name + "-error.xcresult"))
                    shutil.rmtree(bundle)
            return result

        resolution = run("resolve", base + ["-resolvePackageDependencies"])
        if arguments.phase == "before":
            assert resolution.returncode != 0
            assert all(name in resolution.stdout for name in [
                "cactus.xcframework", "llama.xcframework", "WaxEvaluationAdapter.xcframework",
            ])
            receipt["expectedMissingArtifactFailureReproduced"] = True
        else:
            assert resolution.returncode == 0
            assert "resolved source packages: LocalMemory" in resolution.stdout
            if arguments.build:
                result = run("release-build-analyze", base + [
                    "-configuration", "Release", "-sdk", "iphonesimulator",
                    "-destination", "generic/platform=iOS Simulator",
                    "-derivedDataPath", str(scratch / "DerivedData"),
                    "CODE_SIGNING_ALLOWED=NO", "build", "analyze",
                ])
                assert result.returncode == 0
                assert "BUILD SUCCEEDED" in result.stdout and "ANALYZE SUCCEEDED" in result.stdout
        receipt["passed"] = True
    finally:
        receipt["scratchLogicalBytes"] = sum(p.stat().st_size for p in scratch.rglob("*") if p.is_file())
        shutil.rmtree(scratch)
        receipt["scratchRemoved"] = not scratch.exists()
        (evidence / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
