#!/usr/bin/env python3
"""Bundle the reviewed Cactus embedding asset from local cache; never download."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

MANIFEST = ".memoryos-asset-manifest.json"
MANIFEST_SHA = "229ba9eb5d361209c7f01d34cac0db77a623a33bb845c2eb90050ccc831c60af"


def digest(path):
    with path.open("rb") as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
        return value.hexdigest()


def verify(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError("Embedding model directory missing or symlinked")
    manifest = root / MANIFEST
    if manifest.is_symlink() or digest(manifest) != MANIFEST_SHA:
        raise ValueError("Embedding model manifest differs from reviewed identity")
    files = json.loads(manifest.read_text())["files"]
    for relative, expected in files.items():
        path = root / relative
        if Path(relative).is_absolute() or ".." in Path(relative).parts:
            raise ValueError("Invalid manifest path")
        if path.is_symlink() or not path.is_file() or digest(path) != expected:
            raise ValueError("Embedding model file failed verification")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    args = parser.parse_args()
    files = verify(args.source)
    try:
        verify(args.destination)
        print("Verified existing bundled offline embedding model")
        return
    except (ValueError, OSError):
        pass
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="memory-model-", dir=args.destination.parent) as temp:
        candidate = Path(temp) / "Cactus"
        candidate.mkdir()
        for name in [MANIFEST, *files]:
            target = candidate / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(args.source / name, target)
        verify(candidate)
        if args.destination.is_symlink():
            raise ValueError("Refusing symlinked bundle destination")
        if args.destination.exists():
            shutil.rmtree(args.destination)
        candidate.rename(args.destination)
    print("Verified bundled offline Cactus embedding model")


if __name__ == "__main__":
    main()
