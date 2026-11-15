#!/usr/bin/env python3
"""Materialize the pinned CPU SDK subset in its separate upstream checkout.

Every file must match its Git blob identity. No engine source enters the app tree.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

PIN = "a956a852c9c8bc1fb07206364838ddef299178c0"
ROOT = Path("/Users/eros/Dev/Tools/MemoryOS-Evaluation-Upstream/llama.cpp")
SKIP = ("ggml-cuda", "ggml-sycl", "ggml-vulkan", "ggml-cann", "ggml-metal", "ggml-webgpu",
        "ggml-rpc", "ggml-hexagon", "ggml-opencl", "ggml-musa", "ggml-zdnn", "ggml-openvino")


def wanted(name):
    if name in ("CMakeLists.txt", "LICENSE", "ggml/CMakeLists.txt", "ggml/LICENSE", "vendor/CMakeLists.txt"):
        return True
    if name.startswith("vendor/") and name.endswith("CMakeLists.txt"):
        return True
    if name.startswith("vendor/hash/"):
        return True
    if name.startswith(("cmake/", "src/", "include/", "ggml/include/", "ggml/cmake/")):
        return True
    return name.startswith("ggml/src/") and not any(name.startswith("ggml/src/" + item + "/") for item in SKIP)


def main():
    tree = subprocess.check_output(["git", "-C", str(ROOT), "ls-tree", "-r", PIN],
                                  text=True, env=dict(os.environ, GIT_NO_LAZY_FETCH="1"))
    entries = []
    for line in tree.splitlines():
        header, path = line.split("\t", 1)
        mode, kind, digest = header.split()
        if kind == "blob" and wanted(path):
            if mode not in ("100644", "100755"):
                raise SystemExit("Unexpected SDK symlink: " + path)
            entries.append((path, digest))

    def fetch(entry):
        name, expected = entry
        path = ROOT / name
        if path.exists():
            content = path.read_bytes()
            actual = hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()
            if actual != expected:
                raise RuntimeError("Preserved existing modified upstream file: " + name)
            return name, hashlib.sha256(content).hexdigest()
        attempt = 0
        while True:
            attempt += 1
            try:
                url = "https://raw.githubusercontent.com/ggml-org/llama.cpp/" + PIN + "/" + urllib.parse.quote(name)
                content = urllib.request.urlopen(url, timeout=120).read()
                actual = hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()
                if actual != expected:
                    raise ValueError("Git blob mismatch")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
                print(json.dumps({"verified": name, "bytes": len(content)}), flush=True)
                return name, hashlib.sha256(content).hexdigest()
            except Exception as error:
                print(json.dumps({"retry": name, "attempt": attempt, "errorType": type(error).__name__}), flush=True)
                time.sleep(min(30, attempt * 2))

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        verified = dict(pool.map(fetch, entries))
    receipt = {"revision": PIN, "source": "https://github.com/ggml-org/llama.cpp",
               "scope": "Exact upstream CPU library sources; non-CPU backends and examples excluded.",
               "verification": "Each materialized file matches its pinned Git blob identity.", "files": verified}
    (ROOT / ".memoryos-upstream-source.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"event": "complete", "files": len(verified), "revision": PIN}), flush=True)


if __name__ == "__main__":
    main()
