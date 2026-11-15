#!/usr/bin/env python3
"""Verify the official Cactus embedding archive, then extract its app-owned manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

EXPECTED = '22ff768a984fe931ac463b02cedce2ebd65172c6877d210bd5dc6d058fffbd7b'
REPOSITORY = 'Cactus-Compute/Qwen3-Embedding-0.6B'
REVISION = '0df64898a34c75c209b9882110cd6f9aeb7115cd'


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        while data := stream.read(1024 * 1024):
            result.update(data)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if digest(args.archive) != EXPECTED:
        raise SystemExit('Archive SHA-256 mismatch. No model extraction or use permitted.')
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Choose an empty extraction directory; preserve existing prepared assets.')
    output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive) as archive:
        for member in archive.infolist():
            dest = (output / member.filename).resolve()
            if output not in dest.parents and dest != output:
                raise SystemExit('Unsafe archive member path.')
        archive.extractall(output)
    configs = list(output.rglob('config.txt'))
    if not configs:
        configs = list(output.rglob('config.json'))
    if not configs:
        raise SystemExit('No Cactus model configuration found in archive.')
    model = configs[0].parent
    files = {str(p.relative_to(model)): digest(p) for p in sorted(model.rglob('*')) if p.is_file() and p.name != '.memoryos-asset-manifest.json'}
    manifest = {'repository': REPOSITORY, 'revision': REVISION, 'archiveSHA256': EXPECTED, 'files': files}
    (model / '.memoryos-asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'modelDirectory': str(model), 'files': len(files), 'archiveSHA256': EXPECTED, 'manifestSHA256': digest(model / '.memoryos-asset-manifest.json')}))


if __name__ == '__main__':
    main()
