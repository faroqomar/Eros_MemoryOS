#!/usr/bin/env python3
"""Create a patched source snapshot from the reviewed upstream checkout. No network."""
import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tarfile

REVISION = "e4587f8cebb76aa92ece008253f13c66b756e68b"
BASE_HASHES = {
    "Sources/Wax/Broker/AgentBrokerClient.swift": "5a07d524f549ce2979694a886b6a014d049023245ab92078c3eb569b2138e983",
    "Sources/Wax/MemorySemantics.swift": "7867b423957b42dfbd8c678bc66649cc4a37c88e3cdcef04efdd378ef454cb3b",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=pathlib.Path,
                        help="A real upstream Git checkout at the reviewed revision")
    parser.add_argument("--destination", required=True, type=pathlib.Path,
                        help="A new directory outside app source")
    args = parser.parse_args()
    source, destination = args.source.resolve(), args.destination.resolve()
    repository = pathlib.Path(__file__).resolve().parents[3]
    if destination == repository or repository in destination.parents:
        parser.error("Keep upstream source outside the app repository.")
    if destination.exists() or destination == source or source in destination.parents:
        parser.error("Destination must be a new directory outside the source checkout.")
    env = os.environ.copy()
    env.update(GIT_NO_LAZY_FETCH="1", GIT_ALLOW_PROTOCOL="none")
    def git(*arguments):
        return subprocess.check_output(["/usr/bin/git", "--no-lazy-fetch", "-C", str(source), *arguments],
                                       env=env, text=True).strip()
    if git("rev-parse", "HEAD") != REVISION:
        parser.error("Source HEAD differs from the reviewed Wax 0.1.47 commit.")
    if git("status", "--porcelain", "--untracked-files=no"):
        parser.error("Source has tracked changes; preserve them and use a clean checkout.")
    for name, expected in BASE_HASHES.items():
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != expected:
            parser.error("Upstream file hash mismatch: " + name)
    destination.mkdir(parents=True)
    command = ["/usr/bin/git", "--no-lazy-fetch", "-C", str(source), "archive", REVISION]
    process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE)
    with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
        for entry in archive:
            target = (destination / entry.name).resolve()
            if target != destination and destination not in target.parents:
                raise RuntimeError("Archive path escapes destination: " + entry.name)
            if entry.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif entry.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(entry) as incoming, target.open("wb") as outgoing:
                    while chunk := incoming.read(1024 * 1024):
                        outgoing.write(chunk)
                target.chmod(entry.mode & 0o777)
            else:
                raise RuntimeError("Unsupported archive entry: " + entry.name)
    if process.wait() != 0:
        raise RuntimeError("Git archive failed; retain the incomplete destination for diagnosis.")
    patch = pathlib.Path(__file__).resolve().parents[1] / "Patches/wax-0.1.47-ios-desktop-guards.patch"
    subprocess.run(["/usr/bin/patch", "--batch", "--forward", "-p1", "-i", str(patch)],
                   cwd=destination, check=True)
    receipt = {
        "upstream_url": "https://github.com/christopherkarani/Wax.git",
        "upstream_revision": REVISION,
        "source": str(source), "destination": str(destination),
        "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
        "patched_files": {name: hashlib.sha256((destination / name).read_bytes()).hexdigest()
                          for name in BASE_HASHES},
        "dependency_override_applied": False,
    }
    receipt_path = destination.parent / (destination.name + "-patch-receipt.json")
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(receipt_path)


if __name__ == "__main__":
    main()
