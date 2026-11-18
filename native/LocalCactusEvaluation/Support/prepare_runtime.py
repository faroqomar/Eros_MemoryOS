#!/usr/bin/env python3
"""Build the reviewed local-only Cactus XCFramework outside app source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PIN = '40a7123b0788f5b38c5fe0daa0d909b4286fe773'
ROOT = Path(__file__).resolve().parents[1]


def run(args, cwd=None):
    subprocess.run([str(x) for x in args], cwd=cwd, check=True)

def relative_source_path(value):
    path = Path(value)
    if not value or path.is_absolute() or '..' in path.parts or '.git' in path.parts:
        raise SystemExit('Invalid source verification path: ' + repr(value))
    return path


def reject_symlink(path, root):
    current = path
    while current != root:
        if current.is_symlink():
            raise SystemExit('Symlinked source or patch paths are not supported: ' + str(path))
        if current.parent == current:
            raise SystemExit('Source path escaped its verification root: ' + str(path))
        current = current.parent


def source_expectations(upstream):
    if (upstream / '.git').exists():
        actual = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=upstream, text=True).strip()
        if actual != PIN:
            raise SystemExit(f'Refusing unexpected upstream revision: {actual}')
        entries = subprocess.check_output(
            ['git', 'ls-tree', '-r', '-z', '--full-tree', PIN], cwd=upstream)
        expected = {}
        for entry in entries.split(b'\0'):
            if not entry:
                continue
            metadata, name = entry.split(b'\t', 1)
            mode, kind, digest = metadata.decode().split()
            relative = os.fsdecode(name)
            if not (relative.startswith(('cactus/', 'libs/'))
                    or relative in ['LICENSE', 'CACTUS_VERSION']):
                continue
            relative_source_path(relative)
            if kind != 'blob' or mode not in ['100644', '100755']:
                raise SystemExit('Unsupported Git build-source entry: ' + relative)
            expected[relative] = ('git', digest)
        if not expected:
            raise SystemExit('Pinned Git tree contains no Cactus build sources.')
        return expected
    source_receipt = upstream / '.memoryos-upstream-source.json'
    reject_symlink(source_receipt, upstream)
    if not source_receipt.is_file():
        raise SystemExit('A pinned Git checkout or verified source receipt is required.')
    receipt = json.loads(source_receipt.read_text())
    if receipt.get('revision') != PIN or not receipt.get('files'):
        raise SystemExit('Source receipt does not identify the expected upstream revision.')
    for relative in receipt['files']:
        relative_source_path(relative)
    return {relative: ('sha256', digest) for relative, digest in receipt['files'].items()}


def verify_source_subset(upstream, patch, already_patched):
    reject_symlink(patch, patch.parent.parent)
    expected = source_expectations(upstream)
    patch_paths = {line[6:] for line in patch.read_text().splitlines() if line.startswith('+++ b/')}
    for relative in patch_paths:
        relative_source_path(relative)
    allowed = set(expected) | patch_paths
    unexpected = []
    compiled_suffixes = {'.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.hxx',
                         '.m', '.mm', '.s', '.S', '.cmake'}
    for folder in ['cactus', 'libs']:
        source_root = upstream / folder
        reject_symlink(source_root, upstream)
        for directory, directories, filenames in os.walk(source_root, followlinks=False):
            for name in directories + filenames:
                path = Path(directory) / name
                reject_symlink(path, upstream)
                relative = str(path.relative_to(upstream))
                if (path.is_file() and (path.suffix in compiled_suffixes
                                       or path.name == 'CMakeLists.txt')
                        and relative not in allowed):
                    unexpected.append(relative)
    if unexpected:
        raise SystemExit('Unexpected source files outside the reviewed subset: ' + repr(unexpected))
    with tempfile.TemporaryDirectory(prefix='memoryos-cactus-source-check-') as directory:
        original = Path(directory)
        for relative in allowed:
            source = upstream / relative
            reject_symlink(source, upstream)
            if source.is_file():
                target = original / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        if already_patched:
            try:
                run(['git', 'apply', '--reverse', patch], cwd=original)
            except subprocess.CalledProcessError as error:
                raise SystemExit('Source differs from the approved local-only patch.') from error
        mismatches = []
        for relative, (kind, digest) in expected.items():
            path = original / relative
            if not path.is_file():
                mismatches.append(relative)
                continue
            data = path.read_bytes()
            actual = (hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                      if kind == 'git' else hashlib.sha256(data).hexdigest())
            if actual != digest:
                mismatches.append(relative)
        # The retained unified patch adds files with an empty old hunk rather
        # than /dev/null headers. Reversing it leaves a zero-byte preimage.
        for relative in patch_paths - set(expected):
            path = original / relative
            if path.exists() and (not already_patched or not path.is_file() or path.read_bytes()):
                mismatches.append(relative)
        if mismatches:
            raise SystemExit('Pinned original source identity mismatch: ' + repr(mismatches))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--upstream', type=Path, required=True)
    parser.add_argument('--cmake', default='cmake')
    parser.add_argument('--ninja', default='ninja')
    parser.add_argument('--jobs', default='4')
    parser.add_argument('--output', type=Path, help='New artifact directory; existing artifacts are never replaced')
    parser.add_argument('--build-root', type=Path, help='Separate task-owned compiler output directory')
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    artifacts = (args.output or ROOT / 'Artifacts').resolve()
    if artifacts.exists():
        raise SystemExit('Refusing to replace existing artifacts; use --output with a new directory.')
    patch = ROOT / 'Support' / 'upstream-v114-local-only.patch'
    checked = subprocess.run(['git', 'apply', '--check', str(patch)], cwd=upstream, capture_output=True)
    if checked.returncode == 0:
        verify_source_subset(upstream, patch, already_patched=False)
        run(['git', 'apply', str(patch)], cwd=upstream)
    else:
        run(['git', 'apply', '--reverse', '--check', str(patch)], cwd=upstream)
        verify_source_subset(upstream, patch, already_patched=True)
    build_base = (args.build_root or upstream / '.memoryos-evaluation-build').resolve()
    artifacts.mkdir(parents=True)
    libraries = []
    for name, sdk, target in [('macos', 'macosx', 'Darwin'), ('simulator', 'iphonesimulator', 'iOS'), ('device', 'iphoneos', 'iOS')]:
        sdk_path = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
        build = build_base / name
        run([
            args.cmake, '-S', upstream / 'cactus', '-B', build, '-G', 'Ninja',
            '-DCMAKE_MAKE_PROGRAM=' + args.ninja,
            '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_OSX_ARCHITECTURES=arm64',
            '-DCMAKE_OSX_SYSROOT=' + sdk_path, '-DCMAKE_SYSTEM_NAME=' + target,
            '-DCMAKE_OSX_DEPLOYMENT_TARGET=' + ('14.0' if name == 'macos' else '18.0'),
            '-DCACTUS_LOCAL_EVALUATION_ONLY=ON',
            '-DCACTUS_CURL_ROOT=' + str(build_base / 'network-excluded'),
        ])
        run([args.cmake, '--build', build, '--target', 'cactus', '--parallel', args.jobs])
        headers = build / 'public-headers'
        headers.mkdir(exist_ok=True)
        shutil.copy2(upstream / 'cactus' / 'ffi' / 'cactus_ffi.h', headers / 'cactus_engine.h')
        (headers / 'module.modulemap').write_text('module cactus {\n  header "cactus_engine.h"\n  export *\n}\n')
        libraries += ['-library', build / 'libcactus.a', '-headers', headers]
    output = artifacts / 'cactus.xcframework'
    run(['xcodebuild', '-create-xcframework', *libraries, '-output', output])
    shutil.copy2(upstream / 'LICENSE', output / 'LICENSE')
    files = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.rglob('*')) if p.is_file()}
    receipt = {
        'upstreamURL': 'https://github.com/cactus-compute/engine', 'upstreamRevision': PIN,
        'patchSHA256': hashlib.sha256(patch.read_bytes()).hexdigest(),
        'configuration': 'Release, arm64 macOS14 / iOS18 device / iOS18 simulator, CPU enforced by the reviewed local-evaluation source patch',
        'network': 'Telemetry implementation excluded; curl transport compile definitions disabled; no cloud credentials or downloader',
        'artifactFiles': files,
    }
    (artifacts / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'files': len(files)}))


if __name__ == '__main__':
    main()
