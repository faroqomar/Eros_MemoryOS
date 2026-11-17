#!/usr/bin/env python3
"""Reject mixed GGML/GGUF linkage in a built MemoryOS app (no device access)."""
import argparse
from pathlib import Path
import re
import subprocess


def output(*arguments):
    return subprocess.check_output(arguments, text=True)


def check(app):
    binary = app / "MemoryOS"
    symbols = output("nm", "-m", str(binary))
    mixed = [line.strip() for line in symbols.splitlines()
             if re.search(r"external _(?:ggml|gguf)_", line)]
    if mixed:
        raise ValueError(f"App exposes or imports {len(mixed)} GGML/GGUF symbols: {mixed[0]}")
    if not re.search(r"\(undefined\).*_llama_model_load_from_file .*\(from llama\)", symbols):
        raise ValueError("App does not import model loading from isolated llama.framework")
    if not re.search(r"\(undefined\).*_whisper_init_from_file_with_params .*\(from whisper\)", symbols):
        raise ValueError("App does not import transcription from whisper.framework")
    framework = app / "Frameworks/llama.framework/llama"
    header = output("otool", "-hv", str(framework))
    if "DYLIB" not in header or "TWOLEVEL" not in header:
        raise ValueError("Embedded llama must be a two-level dynamic library")
    if "@rpath/llama.framework/llama" not in output("otool", "-D", str(framework)):
        raise ValueError("Unexpected llama install name")
    exports = output("nm", "-gUj", str(framework)).splitlines()
    if not exports or any(not name.startswith("_llama_") for name in exports):
        raise ValueError("Embedded llama exports non-public engine symbols")
    imports = output("nm", "-m", "-u", str(framework))
    if re.search(r"_(?:ggml|gguf|whisper)_", imports):
        raise ValueError("Embedded llama imports another engine's internals")
    print("PASS: separate llama/whisper APIs, private GGML/GGUF, embedded dynamic llama")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Built MemoryOS.app")
    try:
        check(parser.parse_args().app)
    except (ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"FAIL: {error}")
