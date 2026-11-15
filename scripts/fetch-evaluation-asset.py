#!/usr/bin/env python3
"""Fetch a pinned public evaluation asset with resumable ranges and a required hash.

Weights stay outside Git. Healthy slow transfers have no elapsed-time cutoff.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import threading
import time
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--bytes", required=True, type=int)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--chunk-mib", type=int, choices=[1, 2, 4, 8], default=8)
    args = parser.parse_args()
    if not args.url.startswith("https://") or args.bytes <= 0:
        parser.error("Use HTTPS and a positive declared byte count.")
    if len(args.sha256) != 64 or any(c not in "0123456789abcdef" for c in args.sha256.lower()):
        parser.error("A declared SHA-256 is required.")
    if not 1 <= args.workers <= 32:
        parser.error("Use 1–32 workers.")
    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    parts = output.with_name(output.name + ".parts")
    parts.mkdir(exist_ok=True)
    state = parts / "asset.json"
    identity = {"url": args.url, "bytes": args.bytes, "sha256": args.sha256.lower()}
    if args.chunk_mib != 8:
        identity["chunkBytes"] = args.chunk_mib * 1024 * 1024
    if state.exists() and json.loads(state.read_text()) != identity:
        raise SystemExit("Existing partial data belongs to another asset. Preserve it and choose another output.")
    state.write_text(json.dumps(identity, indent=2) + "\n")
    chunk = args.chunk_mib * 1024 * 1024
    ranges = [(i, start, min(args.bytes - 1, start + chunk - 1))
              for i, start in enumerate(range(0, args.bytes, chunk))]
    stop = threading.Event()
    started = time.monotonic()
    resumed_bytes = sum(p.stat().st_size for p in parts.glob("*.part"))
    print(json.dumps({"event": "started", "resumedBytes": resumed_bytes,
                      "totalBytes": args.bytes, "workers": args.workers}), flush=True)

    def fetch(item):
        index, start, end = item
        part = parts / f"{index:05d}.part"
        failures = 0
        while not stop.is_set():
            have = part.stat().st_size if part.exists() else 0
            required = end - start + 1
            if have == required:
                return
            if have > required:
                raise RuntimeError("Partial range is larger than its declared size.")
            request = urllib.request.Request(
                args.url + ("&" if "?" in args.url else "?") + f"download=true&range_request={start+have}&request_nonce={time.time_ns()}",
                headers={"Range": f"bytes={start+have}-{end}", "User-Agent": "MemoryOS-Evaluation/1"})
            try:
                with urllib.request.urlopen(request, timeout=90) as response:
                    expected = f"bytes {start+have}-{end}/{args.bytes}"
                    if response.status != 206 or response.headers.get("Content-Range") != expected:
                        raise RuntimeError("Server did not honor the exact requested byte range.")
                    with part.open("ab") as destination:
                        while not stop.is_set():
                            data = response.read(min(65536, required - have))
                            if not data:
                                break
                            destination.write(data)
                            destination.flush()
                            have += len(data)
                            if have == required:
                                return
                failures += 1
            except Exception as error:
                failures += 1
                # Omit signed redirects, credentials and local error payloads from progress.
                print(json.dumps({"event": "retry", "range": index,
                                  "errorType": type(error).__name__,
                                  "httpStatus": getattr(error, "code", None),
                                  "attempt": failures}), flush=True)
            stop.wait(min(30, 2 ** min(failures, 5)))

    def progress():
        while not stop.wait(15):
            received = sum(p.stat().st_size for p in parts.glob("*.part"))
            print(json.dumps({"event": "progress", "receivedBytes": received,
                              "totalBytes": args.bytes,
                              "averageBytesPerSecond": round((received - resumed_bytes) / max(1, time.monotonic()-started))}), flush=True)

    def verify(path):
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(block)
        return path.stat().st_size == args.bytes and digest.hexdigest() == args.sha256.lower()

    if output.exists():
        if not verify(output):
            raise SystemExit("Existing final asset failed verification. It was preserved.")
        print(json.dumps({"event": "verified-existing", **identity}), flush=True)
        return
    reporter = threading.Thread(target=progress, daemon=True)
    reporter.start()
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            list(pool.map(fetch, ranges))
        assembled = output.with_name(output.name + ".assembling")
        with assembled.open("wb") as destination:
            for index, _, _ in ranges:
                with (parts / f"{index:05d}.part").open("rb") as source:
                    for block in iter(lambda: source.read(1024 * 1024), b""):
                        destination.write(block)
        if not verify(assembled):
            raise SystemExit("Downloaded bytes failed SHA-256. All parts were preserved for diagnosis.")
        os.replace(assembled, output)
        receipt = {**identity, "verified": True, "elapsedSeconds": round(time.monotonic()-started, 2)}
        output.with_name(output.name + ".receipt.json").write_text(json.dumps(receipt, indent=2)+"\n")
        for index, _, _ in ranges:
            (parts / f"{index:05d}.part").unlink()
        state.unlink()
        parts.rmdir()
        print(json.dumps({"event": "verified", **receipt}), flush=True)
    finally:
        stop.set()
        reporter.join(timeout=1)


if __name__ == "__main__":
    main()
