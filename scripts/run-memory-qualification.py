#!/usr/bin/env python3
"""Run a full memory evaluation only after the fixed regressions pass on reviewed source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {f'grammar-{n:02}' for n in (2, 3, 9, 10, 11, 15, 16, 17, 19, 20)}
MODEL_SHA = '7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5'
CONFIG = {'context': 2048, 'output': 512, 'cloud': False}


def source_identity(root=ROOT):
    digest = hashlib.sha256()
    paths = subprocess.check_output(
        ['git', 'ls-files', '-co', '--exclude-standard', '-z', '--', 'native', 'scripts'], cwd=root)
    for name in sorted(set(paths.split(b'\0')) - {b''}):
        path = root / os.fsdecode(name)
        if path.is_file():
            digest.update(name + b'\0' + hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def preflight(receipt, identity):
    if receipt.get('hold') is not False:
        raise ValueError('qualification hold is active')
    if receipt.get('source_identity') != identity or receipt.get('reviewed_source_identity') != identity:
        raise ValueError('source differs from the regression run or independent review')
    if receipt.get('configuration') != CONFIG or receipt.get('model_sha256') != MODEL_SHA:
        raise ValueError('model/configuration differs from the reviewed evaluation')
    rows = receipt.get('regressions', {})
    if set(rows) != REQUIRED or any(
        row.get('passed') is not True or row.get('source_identity') != identity
        or type(row.get('accepted_mistakes')) is not int or row['accepted_mistakes'] != 0
        for row in rows.values()
    ):
        raise ValueError('required regressions are missing, red, stale, or accepted a mistake')


def launch_environment(receipt, command):
    if command != receipt.get('command'):
        raise ValueError('command differs from the reviewed invocation')
    reviewed = receipt.get('environment')
    if not isinstance(reviewed, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        and (key.startswith('MEMORYOS_') or key in {'DYLD_LIBRARY_PATH', 'DYLD_FRAMEWORK_PATH'})
        for key, value in reviewed.items()
    ):
        raise ValueError('missing or invalid reviewed evaluation environment')
    models = [value for key, value in reviewed.items() if key.endswith('_MODEL')]
    if not models or any(value != receipt.get('model_path') for value in models):
        raise ValueError('evaluation environment uses a different model')
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(('MEMORYOS_', 'DYLD_'))}
    environment.update(reviewed)
    return environment


def interrupted(signum, frame):
    raise KeyboardInterrupt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--print-source-identity', action='store_true')
    parser.add_argument('--lock', type=Path, default=Path('/tmp/memoryos-full-evaluation.lock'))
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    identity = source_identity()
    if args.print_source_identity:
        print(identity)
        return 0
    if args.receipt is None:
        parser.error('--receipt is required')
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    try:
        receipt = json.loads(args.receipt.read_text())
        preflight(receipt, identity)
        if not command:
            raise ValueError('no evaluation command supplied')
        environment = launch_environment(receipt, command)
        # An interrupted owner must reconcile a stale lock; never remove somebody else's lock.
        descriptor = os.open(args.lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except (ValueError, OSError, TypeError, KeyError) as error:
        print(f'BLOCKED: {error}', file=sys.stderr)
        return 2
    child = None
    previous_term = signal.signal(signal.SIGTERM, interrupted)
    try:
        with os.fdopen(descriptor, 'w') as lock:
            lock.write(json.dumps({'pid': os.getpid(), 'source_identity': identity}))
        preflight(json.loads(args.receipt.read_text()), source_identity())
        model = Path(receipt['model_path'])
        digest = hashlib.sha256()
        with model.open('rb') as stream:
            for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != MODEL_SHA:
            raise ValueError('model hash mismatch')
        preflight(json.loads(args.receipt.read_text()), source_identity())
        current_receipt = json.loads(args.receipt.read_text())
        if launch_environment(current_receipt, command) != environment:
            raise ValueError('reviewed environment changed before launch')
        child = subprocess.Popen(command, cwd=ROOT, env=environment, start_new_session=True)
        return child.wait()
    finally:
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        args.lock.unlink()
        signal.signal(signal.SIGTERM, previous_term)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('INTERRUPTED: owned evaluation stopped', file=sys.stderr)
        sys.exit(130)
    except (ValueError, OSError, TypeError, KeyError) as error:
        print(f'BLOCKED: {error}', file=sys.stderr)
        sys.exit(2)
