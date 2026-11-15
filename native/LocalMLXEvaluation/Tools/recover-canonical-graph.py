#!/usr/bin/env python3
"""Recover genuine complete caches for the reviewed graph, through four bounded HTTP workers."""

import concurrent.futures
import json
from pathlib import Path
import subprocess
import sys

package = Path(__file__).resolve().parents[1]
evidence = package.parent / "verification/local-ai-step1/resume"
cache = Path.home() / "Library/Caches/MemoryOS-AI-Evaluation"
repositories = package / ".build/repositories"
specifications = [
    ("swift-numerics", "swift-numerics-d936ec6c", "apple/swift-numerics", "1.1.1", "1.1.1"),
    ("EventSource", "EventSource-24732f58", "mattt/EventSource", "1.6.0", "1.6.0"),
    ("swift-jinja", "swift-jinja-c9e03d9c", "huggingface/swift-jinja", "3.1.0", "3.1.0"),
    ("swift-asn1", "swift-asn1-7065ad2c", "apple/swift-asn1", "1.7.4", "1.7.4"),
    ("swift-transformers", "swift-transformers-e50307c3", "huggingface/swift-transformers", "402a8a1105f52038b0949d9596981fc9e32bed17", None),
    ("mlx-swift", "mlx-swift-eecb5611", "ml-explore/mlx-swift", "0.32.3", "0.32.3"),
    ("swift-huggingface", "swift-huggingface-ffa527b1", "huggingface/swift-huggingface", "1.0.0", "1.0.0"),
    ("swift-collections", "swift-collections-9a58d5cf", "apple/swift-collections", "1.7.6", "1.7.6"),
    ("swift-syntax", "swift-syntax-e1f983d3", "swiftlang/swift-syntax", "603.0.2", "603.0.2"),
    ("yyjson-0.13.0", "yyjson-04ab5379", "ibireme/yyjson", "0.13.0", "0.13.0"),
    ("swift-crypto", "swift-crypto-7e0614ea", "apple/swift-crypto", "3.15.1", "3.15.1"),
    ("mlx-cpp-core", str(cache / "upstream/mlx-submodules/mlx-core.git"), "ml-explore/mlx", "1f8e74e3f12f31365464a6867c6579f0e9b29d85", None),
    ("mlx-c-api", str(cache / "upstream/mlx-submodules/mlx-c.git"), "ml-explore/mlx-c", "ebc88f10caa1b625e6b581437a8dea6df8a70085", None),
]


def recover(specification):
    identity, source, upstream, revision, tag = specification
    receipt = evidence / ("mlx-complete-cache-" + identity + ".json")
    if receipt.exists():
        print(json.dumps({"identity": identity, "alreadyRecovered": True}), flush=True)
        return
    command = [sys.executable, str(package / "Tools/recover-complete-git-cache.py"),
               "--identity", identity, "--source-cache", str(repositories / source),
               "--upstream", upstream, "--revision", revision]
    if tag:
        command += ["--tag", tag]
    print(json.dumps({"identity": identity, "started": True}), flush=True)
    with (evidence / ("mlx-complete-cache-" + identity + ".log")).open("w") as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    print(json.dumps({"identity": identity, "recovered": True}), flush=True)


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    list(executor.map(recover, specifications))
print(json.dumps({"completeReviewedCaches": True, "canonicalResolutionVerified": False}), flush=True)
