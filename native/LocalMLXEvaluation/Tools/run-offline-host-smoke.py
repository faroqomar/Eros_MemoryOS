#!/usr/bin/env python3
"""Run the real host CLI under an OS network denial and retain its unmodified JSON plus receipt."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--binary", type=Path, required=True)
parser.add_argument("--model-dir", type=Path, required=True)
parser.add_argument("--source-manifest", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--receipt", type=Path, required=True)
arguments = parser.parse_args()
if arguments.output.exists() or arguments.receipt.exists():
    raise SystemExit("Preserved existing results. Supply new output and receipt paths for a rerun.")


def sha256(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


binary = arguments.binary.resolve(strict=True)
model = arguments.model_dir.resolve(strict=True)
source_manifest = arguments.source_manifest.resolve(strict=True)
asset_manifest = model / "memoryos-asset-manifest.json"
asset_hash = sha256(asset_manifest)
assets = json.loads(asset_manifest.read_text())
for asset in assets["files"]:
    path = model / asset["file"]
    if path.stat().st_size != asset["bytes"] or sha256(path) != asset["sha256"]:
        raise SystemExit("A reviewed local model asset changed before launch.")
policy = "(version 1)(allow default)(deny network*)"
probe_code = '''import errno,json,socket,sys
try:
    with socket.socket() as client:
        client.settimeout(2)
        client.connect(("1.1.1.1",443))
except OSError as error:
    denied=error.errno in (errno.EPERM,errno.EACCES)
    print(json.dumps({"networkDenied":denied,"errno":error.errno}))
    sys.exit(0 if denied else 1)
print(json.dumps({"networkDenied":False}))
sys.exit(1)
'''
probe = subprocess.run(["/usr/bin/sandbox-exec", "-p", policy, sys.executable, "-c", probe_code], capture_output=True, text=True)
if probe.returncode != 0:
    raise SystemExit("The OS network-denial probe did not pass; no model run started.")
probe_result = json.loads(probe.stdout)
source_record = json.loads(source_manifest.read_text())
for source_file in source_record["applicationSources"]:
    if sha256(Path(source_file["path"])) != source_file["sha256"]:
        raise SystemExit("An application source changed after the recorded build identity.")
source_hash = sha256(source_manifest)
binary_hash = sha256(binary)
command = ["/usr/bin/sandbox-exec", "-p", policy, str(binary), "--model-dir", str(model),
           "--source-identity", "sha256:" + source_hash, "--output", str(arguments.output.resolve())]
result = subprocess.run(command)
receipt = {
    "kind": "Real Mac host smoke under externally enforced OS network denial",
    "launcher": str(Path(__file__).resolve()), "launcherSHA256": sha256(Path(__file__)),
    "command": command, "sandboxPolicy": policy, "networkDenialProbe": probe_result,
    "binary": str(binary), "binarySHA256": binary_hash,
    "binaryUnchangedAfterRun": sha256(binary) == binary_hash,
    "sourceManifest": str(source_manifest), "sourceManifestSHA256": source_hash,
    "metallib": str(binary.parent / "mlx.metallib"),
    "metallibSHA256": sha256(binary.parent / "mlx.metallib"),
    "assetManifest": str(asset_manifest), "assetManifestSHA256": asset_hash,
    "assetCountVerifiedBeforeLaunch": len(assets["files"]),
    "assetManifestUnchangedAfterRun": sha256(asset_manifest) == asset_hash,
    "exitCode": result.returncode, "rawReport": str(arguments.output),
    "conditions": "Other source downloads may be active. Host timings do not establish simulator or phone performance. The CLI report keeps its default offlineConfirmed field; this separate receipt records OS enforcement without editing raw results.",
}
if arguments.output.is_file():
    report = json.loads(arguments.output.read_text())
    receipt["rawReportSHA256"] = sha256(arguments.output)
    receipt["rawReportOfflineConfirmed"] = report["context"]["offlineConfirmed"]
arguments.receipt.write_text(json.dumps(receipt, indent=2) + "\n")
raise SystemExit(result.returncode)
