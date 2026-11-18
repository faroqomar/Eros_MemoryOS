#!/usr/bin/env python3
"""Bundle the existing reviewed local conversation/relevance model; never download."""
import argparse
import hashlib
from pathlib import Path
import os
import shutil
import tempfile

SHA256 = "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5"
SIZE = 2497280256


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def copy_verified(source, destination, expected=SHA256, size=SIZE):
    if source.is_symlink() or not source.is_file() or source.stat().st_size != size:
        raise ValueError("Missing or unexpected local conversation/relevance model file")
    if digest(source) != expected:
        raise ValueError("Local relevance model SHA-256 mismatch")
    if destination.is_symlink():
        raise ValueError("Relevance model destination must not be a symlink")
    if destination.exists() and destination.stat().st_size == size and digest(destination) == expected:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".relevance-", dir=destination.parent)
    os.close(descriptor)
    candidate = Path(name)
    try:
        shutil.copyfile(source, candidate)
        if candidate.stat().st_size != size or digest(candidate) != expected:
            raise ValueError("Copied relevance model did not match the reviewed asset")
        candidate.chmod(0o644)
        candidate.replace(destination)
    finally:
        candidate.unlink(missing_ok=True)


def remove_obsolete_bundled_model(destination):
    # Only build output beside the new model, never Documents or the download cache.
    old = destination.parent / "Qwen3-1.7B-Q4_K_M.gguf"
    if old.is_file() and not old.is_symlink() and digest(old) == "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897":
        old.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    copy_verified(args.source, args.destination)
    remove_obsolete_bundled_model(args.destination)
