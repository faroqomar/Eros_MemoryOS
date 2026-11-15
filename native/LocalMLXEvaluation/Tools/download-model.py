#!/usr/bin/env python3
"""Fetch the reviewed MLX fixture into the reusable evaluation cache, then verify each byte."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys

MODEL_ID = "mlx-community/Qwen3-0.6B-4bit"
REVISION = "73e3e38d981303bc594367cd910ea6eb48349da8"
CACHE = Path.home() / "Library/Caches/MemoryOS-AI-Evaluation/models/mlx-qwen3-0.6b-4bit-73e3e38d"
EXPECTED_MODEL_SHA256 = "392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2"
# Reviewed immutable Hugging Face API metadata. Avoid a moving branch or a network metadata dependency.
FILES = [
    {"rfilename": "model.safetensors", "size": 335450584, "lfs": {"sha256": EXPECTED_MODEL_SHA256}},
    {"rfilename": "tokenizer.json", "size": 11422654, "lfs": {"sha256": "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"}},
    {"rfilename": "README.md", "size": 873, "blobId": "347f24b0faf9b91a5f37326cf2c4595522521ec5"},
    {"rfilename": "added_tokens.json", "size": 707, "blobId": "b54f9135e44c1e81047e8d05cb027af8bc039eed"},
    {"rfilename": "config.json", "size": 937, "blobId": "6c974b02334f2f5f68de4cb2796ee4fe80bfc712"},
    {"rfilename": "merges.txt", "size": 1671853, "blobId": "31349551d90c7606f325fe0f11bbb8bd5fa0d7c7"},
    {"rfilename": "model.safetensors.index.json", "size": 49731, "blobId": "e743a6a7d2ba4fd21b2256d739117cbf31345297"},
    {"rfilename": "special_tokens_map.json", "size": 613, "blobId": "ac23c0aaa2434523c494330aeb79c58395378103"},
    {"rfilename": "tokenizer_config.json", "size": 9706, "blobId": "7345216a0785dc7086e8c245b2a9d3896ce2b756"},
    {"rfilename": "vocab.json", "size": 2776833, "blobId": "4783fe10ac3adce15ac8f358ef5462739852c569"},
]


def digest(path, algorithm="sha256"):
    result = hashlib.new(algorithm)
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    receipts = []
    for item in FILES:
        name = item["rfilename"]
        if name == ".gitattributes":
            continue
        if Path(name).name != name:
            raise RuntimeError("Unexpected nested model file.")
        target = CACHE / name
        url = f"https://huggingface.co/{MODEL_ID}/resolve/{REVISION}/{name}?download=true"
        expected_size = item["size"]
        if not target.exists() or target.stat().st_size != expected_size:
            partial = target.with_name(target.name + ".partial")
            print(f"Downloading {name}, expected {expected_size:,} bytes", flush=True)
            if "lfs" in item and expected_size > 8 * 1024 * 1024:
                helper = Path(__file__).resolve().parents[3] / "scripts/fetch-evaluation-asset.py"
                subprocess.run([
                    sys.executable, str(helper), "--url", url.split("?")[0], "--output", str(target),
                    "--bytes", str(expected_size), "--sha256", item["lfs"]["sha256"], "--workers", "4"
                ], check=True)
                partial = target
            else:
                subprocess.run(
                    ["curl", "--fail", "--location", "--retry", "8", "--retry-all-errors", "--continue-at", "-", "--output", str(partial), url],
                    check=True,
                )
            if partial.stat().st_size != expected_size:
                raise RuntimeError(f"Size mismatch for {name}; retained the partial file.")
            if partial != target:
                partial.rename(target)
        sha256 = digest(target)
        if "lfs" in item:
            if sha256 != item["lfs"]["sha256"]:
                raise RuntimeError(f"SHA-256 mismatch for {name}.")
        else:
            content = target.read_bytes()
            git_blob = hashlib.sha1(f"blob {len(content)}\0".encode() + content).hexdigest()
            if git_blob != item["blobId"]:
                raise RuntimeError(f"Git blob hash mismatch for {name}.")
        if name == "model.safetensors" and sha256 != EXPECTED_MODEL_SHA256:
            raise RuntimeError("The weight SHA-256 differs from the reviewed weight file.")
        receipts.append({"file": name, "bytes": expected_size, "sha256": sha256, "url": url})
        print(f"Verified {name}: {sha256}", flush=True)
    receipt = {
        "modelID": MODEL_ID,
        "revision": REVISION,
        "modelCardLicense": "Apache-2.0",
        "sourceModel": "Qwen/Qwen3-0.6B",
        "format": "MLX 4-bit safetensors; not GGUF Q4_K_M",
        "files": receipts,
    }
    (CACHE / "memoryos-asset-manifest.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Local model directory: {CACHE}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Download/verification failed: {error}", file=sys.stderr)
        sys.exit(1)
