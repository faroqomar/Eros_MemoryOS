#!/usr/bin/env python3
"""Package the reviewed offline speech model. Never download at build or runtime."""
import argparse
import hashlib
from pathlib import Path
import shutil
import sys

MODELS = {
    "tiny": "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
    "small-q5_1": "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
}


def digest(path):
    with path.open("rb") as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
        return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--model", choices=MODELS, default="tiny")
    args = parser.parse_args()
    expected_hash = MODELS[args.model]
    filename = f"ggml-{args.model}.bin"
    source = args.source.expanduser()
    if not source.is_file() or source.is_symlink():
        sys.exit(f"Speech model missing. Prepare the pinned {args.model} asset and set MEMORYOS_SPEECH_MODEL to {filename}.")
    if digest(source) != expected_hash:
        sys.exit("Speech model SHA-256 mismatch; refusing to package unreviewed weights.")
    args.destination.mkdir(parents=True, exist_ok=True)
    target = args.destination / filename
    if not target.is_file() or digest(target) != expected_hash:
        temporary = target.with_suffix(".tmp")
        try:
            shutil.copyfile(source, temporary)
            if digest(temporary) != expected_hash:
                sys.exit("Copied speech model failed SHA-256 verification.")
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
    manifest = args.destination / "model-kind.txt"
    temporary_manifest = manifest.with_suffix(".tmp")
    temporary_manifest.write_text(args.model + "\n")
    temporary_manifest.replace(manifest)
    # Only remove an older known bundled variant after the replacement is verified.
    for variant in MODELS:
        if variant != args.model:
            (args.destination / f"ggml-{variant}.bin").unlink(missing_ok=True)
    print(f"Verified bundled offline speech model: multilingual {args.model}")


if __name__ == "__main__":
    main()
