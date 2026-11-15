#!/usr/bin/env python3
"""Stage the real SDK-compiled Metal library at MLX's supported colocated lookup paths."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--products", type=Path, required=True)
parser.add_argument("--receipt", type=Path)
arguments = parser.parse_args()
products = arguments.products.resolve()
source = products / "mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib"
if not source.is_file() or source.read_bytes()[:4] != b"MTLB":
    raise SystemExit("Build the real host MLX Metal resource before staging it.")
identity = hashlib.sha256(source.read_bytes()).hexdigest()
targets = [products / "mlx.metallib"]
for bundle in products.glob("*.xctest"):
    binary_directory = bundle / "Contents/MacOS"
    if binary_directory.is_dir():
        targets.append(binary_directory / "mlx.metallib")
for target in targets:
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != identity:
        raise SystemExit("Preserved a conflicting Metal library: " + str(target))
    if not target.exists():
        shutil.copy2(source, target)
receipt = {
    "source": str(source), "sha256": identity, "bytes": source.stat().st_size,
    "stagedPaths": [str(path) for path in targets],
    "reason": "The SwiftBuild test runner did not resolve the SDK resource bundle. The original pinned MLX device.cpp supports colocated mlx.metallib.",
    "sdkSourcePatched": False,
}
evidence = Path(__file__).resolve().parents[1].parent / "verification/local-ai-step1/resume"
receipt_path = arguments.receipt or evidence / "mlx-host-metal-staging.json"
body = json.dumps(receipt, indent=2) + "\n"
if receipt_path.exists() and receipt_path.read_text() != body:
    raise SystemExit("Preserved an existing resource receipt. Supply a new --receipt path.")
receipt_path.write_text(body)
print(json.dumps(receipt, indent=2))
