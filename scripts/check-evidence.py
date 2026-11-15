#!/usr/bin/env python3
"""Bound new documentation evidence. Default: staged Git content, not old files."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT = {'.md', '.json', '.txt', '.log', '.csv', '.html', '.xml', '.swift'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', help='Working-tree files or directories; default checks staged additions/changes')
    args = parser.parse_args()
    staged = not args.paths
    errors, totals = [], {}
    if staged:
        raw = subprocess.check_output(['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z'], cwd=ROOT)
        paths = [ROOT / p.decode() for p in raw.split(b'\0') if p]
    else:
        paths = []
        for name in args.paths:
            path = Path(name).resolve()
            if not path.is_relative_to(ROOT):
                errors.append(f'{name}: explicit path must be inside the repository')
                continue
            if not path.exists():
                errors.append(f'{name}: explicit path does not exist')
                continue
            if not (path.is_file() or path.is_dir()):
                errors.append(f'{name}: explicit path must be a file or directory')
                continue
            paths.extend(path.rglob('*') if path.is_dir() else [path])
    checked = 0
    for path in sorted(set(paths)):
        try:
            relative = path.relative_to(ROOT)
        except ValueError:
            continue
        name = relative.as_posix()
        evidence = name.startswith('docs/evidence/')
        task = name.startswith('docs/tasks/')
        if not (evidence or task) or path.suffix not in TEXT:
            continue
        if not staged and not path.is_file():
            continue
        data = subprocess.check_output(['git', 'show', ':' + name], cwd=ROOT) if staged else path.read_bytes()
        checked += 1
        lines = len(data.splitlines())
        limit_lines, limit_bytes = (1000, 65536) if evidence else (200, 32768)
        if lines > limit_lines or len(data) > limit_bytes:
            errors.append(f'{name}: {lines} lines / {len(data)} bytes exceeds {limit_lines} lines / {limit_bytes} bytes')
        if evidence:
            if re.search(r'call[-_]?tree|preservation.*manifest|runtime.*dump', path.name, re.I):
                errors.append(f'{name}: keep raw diagnostic exports outside docs; retain a concise result')
            if len(re.findall(rb'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])', data)) > 100:
                errors.append(f'{name}: oversized per-file hash inventory; retain source identity and aggregate preservation result')
            folder = '/'.join(relative.parts[:3])
            total = totals.setdefault(folder, [0, 0])
            total[0] += lines
            total[1] += len(data)
    for folder, (lines, size) in totals.items():
        if lines > 3000 or size > 262144:
            errors.append(f'{folder}: changed text totals {lines} lines / {size} bytes exceeds 3000 / 262144; consolidate results')
    print(json.dumps({'checkedTextFiles': checked, 'scope': 'staged content' if staged else 'explicit working-tree paths', 'errors': errors}, indent=2))
    return bool(errors)


if __name__ == '__main__':
    sys.exit(main())
