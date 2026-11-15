#!/usr/bin/env python3
"""Fetch the exact SDK source subset and verify its Git blob identities before writing."""
import argparse
import concurrent.futures
import hashlib
import http.client
import json
import socket
from pathlib import Path
import time
import urllib.error
import urllib.request

PIN = '40a7123b0788f5b38c5fe0daa0d909b4286fe773'
BASE = 'https://raw.githubusercontent.com/cactus-compute/engine/' + PIN + '/'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--tree', type=Path)
    parser.add_argument('--workers', type=int, default=8)
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    if (root / '.memoryos-upstream-source.json').exists():
        raise SystemExit('Source was already prepared. Preserve any patch/build and reuse it; choose a clean directory to re-fetch.')
    if args.tree:
        tree = json.loads(args.tree.read_text())
    else:
        with urllib.request.urlopen('https://api.github.com/repos/cactus-compute/engine/git/trees/' + PIN + '?recursive=1', timeout=120) as response:
            tree = json.load(response)
    if tree.get('sha') != PIN or tree.get('truncated'):
        raise SystemExit('Expected the complete exact-commit GitHub tree.')
    files = [item for item in tree['tree'] if item['type'] == 'blob'
             and (item['path'].startswith(('cactus/', 'libs/stb/', 'libs/audio/'))
                  or item['path'] in ['LICENSE', 'CACTUS_VERSION'])
             and not item['path'].startswith(('cactus-engine/libs/curl/', 'cactus-engine/tests/'))]

    def fetch(metadata):
        path = root / metadata['path']
        path.parent.mkdir(parents=True, exist_ok=True)
        failures = 0
        while True:
            try:
                if path.exists():
                    content = path.read_bytes()
                else:
                    url = BASE + metadata['path']
                    if failures >= 2:
                        url = 'https://cdn.jsdelivr.net/gh/cactus-compute/engine@' + PIN + '/' + metadata['path']
                    with urllib.request.urlopen(url, timeout=120) as response:
                        content = response.read()
                actual = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\x00' + content).hexdigest()
                if actual != metadata['sha']:
                    raise RuntimeError('Source identity mismatch; preserve the file and inspect it.')
                path.write_bytes(content)
                print(json.dumps({'file': metadata['path'], 'verified': True}), flush=True)
                return metadata['path'], hashlib.sha256(content).hexdigest()
            except (urllib.error.URLError, socket.timeout, http.client.HTTPException, TimeoutError, ConnectionError) as error:
                failures += 1
                print(json.dumps({'retry': metadata['path'], 'errorType': type(error).__name__, 'attempt': failures}), flush=True)
                time.sleep(3)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        hashes = dict(pool.map(fetch, files))
    receipt = {'revision': PIN, 'sourceURL': BASE,
               'verification': 'Required SDK files matched pinned GitHub tree Git blob identities before patching. Excludes unrelated tests, Android archives and disabled libcurl.',
               'files': hashes}
    (root / '.memoryos-upstream-source.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'verifiedFiles': len(hashes), 'revision': PIN}), flush=True)


if __name__ == '__main__':
    main()
