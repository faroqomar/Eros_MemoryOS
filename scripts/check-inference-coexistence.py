#!/usr/bin/env python3
"""Run both pinned native engines in one host process, in both initialization orders.

Requires existing reviewed models and a fictional mono 16 kHz 16-bit WAV fixture.
No downloads, device interaction or personal audio are needed.
"""
import argparse
import array
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
LLAMA = ROOT / "native/LocalTextEvaluation/Artifacts/llama.xcframework/macos-arm64"
WHISPER = ROOT / "native/LocalTranscription/Artifacts/whisper.xcframework/macos-arm64_x86_64"
SOURCES = ROOT / "scripts/tests/inference-coexistence"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("llama_model", type=Path)
    parser.add_argument("whisper_model", type=Path)
    parser.add_argument("fictional_wav", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="memoryos-coexistence-") as temporary:
        work = Path(temporary)
        with wave.open(str(args.fictional_wav), "rb") as audio:
            if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (1, 2, 16000):
                raise SystemExit("Use a mono 16 kHz signed 16-bit WAV fixture")
            samples = array.array("h", audio.readframes(audio.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        pcm = work / "fixture.f32"
        pcm.write_bytes(array.array("f", (sample / 32768 for sample in samples)).tobytes())
        objects = []
        for name, framework in [("llama", LLAMA), ("whisper", WHISPER)]:
            obj = work / f"{name}.o"
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-arch", "arm64",
                            "-mmacosx-version-min=14.0", "-c", str(SOURCES / f"{name}-probe.cpp"),
                            "-I", str(framework / f"{name}.framework/Headers"), "-o", str(obj)], check=True)
            objects.append(str(obj))
        executable = work / "coexistence"
        # Whisper first also reproduces static llama resolving internals from Whisper.
        subprocess.run(["xcrun", "clang++", "-arch", "arm64", "-mmacosx-version-min=14.0", *objects,
                        "-F", str(WHISPER), "-F", str(LLAMA), "-framework", "whisper",
                        "-framework", "llama", "-framework", "Accelerate",
                        f"-Wl,-rpath,{WHISPER}", f"-Wl,-rpath,{LLAMA}", "-o", str(executable)], check=True)
        for order in ["llama-first", "whisper-first"]:
            subprocess.run([str(executable), str(args.llama_model.resolve()),
                            str(args.whisper_model.resolve()), str(pcm), order], check=True)


if __name__ == "__main__":
    main()
