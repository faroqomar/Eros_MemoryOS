#!/usr/bin/env python3
"""Complete an authentic single-commit bare object closure via original HTTPS; no Git process."""
from pathlib import Path
import base64
import concurrent.futures
import hashlib
import json
import os
import requests
import tempfile
import threading
import time
import urllib.parse
import zlib

BASE = Path(__file__).resolve().parent
CACHE = Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation')
REPO = CACHE / 'wax-canonical-original-pin-cache/repositories/Wax-18aab7e9'
REV = 'e4587f8cebb76aa92ece008253f13c66b756e68b'
ROOT = '653dd20a0d02944ffdcdb6e35d37a54449a64f2e'
UPSTREAM = 'christopherkarani/Wax'
URL = 'https://github.com/' + UPSTREAM + '.git'
WORKERS = 4
OBJECTS = REPO / 'objects'
SOURCES = [CACHE / 'wax-supported-objects/Wax/objects', Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories/Wax-18aab7e9/objects')]
lock = threading.Lock()
local = threading.local()


def get(url):
    if not hasattr(local, 'session'):
        local.session = requests.Session()
    attempt = 0
    while True:
        attempt += 1
        try:
            r = local.session.get(url, timeout=(60, 120))
            if r.status_code == 403 and r.headers.get('X-RateLimit-Remaining') == '0':
                time.sleep(30)
                continue
            if r.status_code in [400, 401, 403, 404, 410]:
                raise RuntimeError('Permanent HTTP status ' + str(r.status_code) + ' ' + url)
            r.raise_for_status()
            return r.content
        except RuntimeError:
            raise
        except Exception as error:
            print(json.dumps(dict(retry=attempt, url=url, error=str(error))), flush=True)
            time.sleep(min(20, attempt * 2))


def object_path(objects, oid):
    return objects / oid[:2] / oid[2:]


def raw_object(kind, body):
    return kind.encode() + b' ' + str(len(body)).encode() + b'\0' + body


def store(oid, raw):
    if hashlib.sha1(raw).hexdigest() != oid:
        raise RuntimeError('Git object identity mismatch ' + oid)
    target = object_path(OBJECTS, oid)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if hashlib.sha1(zlib.decompress(target.read_bytes())).hexdigest() != oid:
            raise RuntimeError('Existing object corrupted ' + oid)
        return
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False, prefix='wax-verified-') as f:
        f.write(zlib.compress(raw))
        os.fchmod(f.fileno(), 0o444)
        temporary = Path(f.name)
    try:
        os.link(temporary, target)
    except FileExistsError:
        pass
    finally:
        temporary.unlink()



def get_blob(entry):
    """Persist partial bytes; resume only a matching original Git blob path."""
    if not hasattr(local, 'session'):
        local.session = requests.Session()
    parts = CACHE / 'wax-canonical-download-parts'
    parts.mkdir(exist_ok=True)
    partial = parts / (entry['sha'] + '.part')
    expected = entry['size']
    if expected == 0:
        return b''
    url = 'https://raw.githubusercontent.com/' + UPSTREAM + '/' + REV + '/' + urllib.parse.quote(entry['path'], safe='/')
    attempt = 0
    while not partial.exists() or partial.stat().st_size < expected:
        start = partial.stat().st_size if partial.exists() else 0
        end = min(expected - 1, start + 131072 - 1)
        attempt += 1
        try:
            response = local.session.get(url, headers={'Range': 'bytes=' + str(start) + '-' + str(end),
                                                       'Accept-Encoding': 'identity'},
                                         stream=True, timeout=(30, 90))
            with response:
                if response.status_code in [400, 401, 403, 404, 410, 416]:
                    raise RuntimeError('Permanent ranged HTTP ' + str(response.status_code) + ' ' + entry['path'])
                response.raise_for_status()
                if response.status_code == 206:
                    wanted = 'bytes ' + str(start) + '-'
                    if not response.headers.get('Content-Range', '').startswith(wanted):
                        raise RuntimeError('Wrong range offset for ' + entry['path'])
                elif response.status_code != 200 or start != 0:
                    raise RuntimeError('Origin did not honor resumed byte range for ' + entry['path'])
                with partial.open('ab') as out:
                    for chunk in response.iter_content(8192):
                        if out.tell() + len(chunk) > expected:
                            raise RuntimeError('Origin blob exceeded upstream Git size ' + entry['path'])
                        out.write(chunk)
                    out.flush()
                row = dict(path=entry['path'], sha1=entry['sha'], received=partial.stat().st_size, total=expected)
                with lock:
                    with (BASE / 'canonical-range-progress.jsonl').open('a') as out:
                        out.write(json.dumps(row) + '\n')
                    if row['received'] == expected or row['received'] // 1048576 != start // 1048576:
                        print(json.dumps(dict(range_download=row)), flush=True)
        except RuntimeError:
            raise
        except Exception as error:
            print(json.dumps(dict(range_retry=attempt, path=entry['path'],
                                  persisted=partial.stat().st_size if partial.exists() else 0, error=str(error))), flush=True)
            time.sleep(min(20, attempt * 2))
    if partial.stat().st_size != expected:
        raise RuntimeError('Persisted blob size mismatch ' + entry['path'])
    return partial.read_bytes()


def main():
    tree_file = BASE / 'canonical-complete-tree.json'
    if tree_file.exists():
        tree = json.loads(tree_file.read_text())
    else:
        tree = json.loads(get('https://api.github.com/repos/' + UPSTREAM + '/git/trees/' + ROOT + '?recursive=1'))
        tree_file.write_text(json.dumps(tree, indent=2) + '\n')
    if tree.get('sha') != ROOT or tree.get('truncated'):
        raise RuntimeError('Incomplete upstream tree')
    entries = tree['tree']
    expected = {'': ROOT}
    children = {'': []}
    for e in entries:
        if e['type'] == 'tree':
            expected[e['path']] = e['sha']
            children[e['path']] = []
        elif e['type'] not in ['blob', 'commit']:
            raise RuntimeError('Unexpected Git entry type ' + e['type'])
    for e in entries:
        parent, _, leaf = e['path'].rpartition('/')
        children[parent].append(dict(e, path=leaf))
    for directory in sorted(children, key=lambda p: (p.count('/'), len(p)), reverse=True):
        body = b''
        for e in sorted(children[directory], key=lambda e: e['path'].encode() + (b'/' if e['type'] == 'tree' else b'')):
            body += e['mode'].lstrip('0').encode() + b' ' + e['path'].encode() + b'\0' + bytes.fromhex(e['sha'])
        store(expected[directory], raw_object('tree', body))
    blobs = [e for e in entries if e['type'] == 'blob']
    missing = [e for e in blobs if not any(object_path(o, e['sha']).exists() for o in [OBJECTS] + SOURCES)]
    print(json.dumps(dict(total_blobs=len(blobs), total_blob_bytes=sum(e.get('size', 0) for e in blobs),
                          missing_blobs=len(missing), missing_bytes=sum(e.get('size', 0) for e in missing))), flush=True)
    counters = [0, 0, 0]
    def hydrate(e):
        oid = e['sha']
        raw = None
        reused = False
        for objects in [OBJECTS] + SOURCES:
            f = object_path(objects, oid)
            if f.exists():
                raw = zlib.decompress(f.read_bytes())
                reused = True
                break
        if raw is None:
            # GitHub may smudge LFS pointers at raw URLs. Tiny binary/model entries
            # use the Git blob API so the actual Git pointer bytes stay intact.
            if e.get('size', 0) < 4096 and any(x in e['path'].lower() for x in ['.mlpackage/', '.mlmodelc/', '.safetensors', '.onnx']):
                d = json.loads(get('https://api.github.com/repos/' + UPSTREAM + '/git/blobs/' + oid))
                body = base64.b64decode(d['content'])
            else:
                body = get_blob(e)
            raw = raw_object('blob', body)
            if hashlib.sha1(raw).hexdigest() != oid:
                d = json.loads(get('https://api.github.com/repos/' + UPSTREAM + '/git/blobs/' + oid))
                raw = raw_object('blob', base64.b64decode(d['content']))
        store(oid, raw)
        partial = CACHE / 'wax-canonical-download-parts' / (oid + '.part')
        if partial.exists():
            partial.unlink()  # Exact Git object has been verified and retained.
        with lock:
            counters[0] += 1
            counters[1] += len(raw.split(b'\0', 1)[1])
            counters[2] += int(reused)
            row = dict(path=e['path'], sha1=oid, reused=reused, bytes=e.get('size'))
            with (BASE / 'canonical-complete-objects.jsonl').open('a') as out:
                out.write(json.dumps(row) + '\n')
            if counters[0] % 25 == 0 or counters[0] == len(blobs):
                print(json.dumps(dict(completed=counters[0], total=len(blobs), bytes=counters[1], reused=counters[2])), flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(hydrate, blobs))
    # A shallow boundary is ordinary Git metadata, not a promisor configuration.
    # All blobs and trees reachable from this commit are now present and verified.
    commit = zlib.decompress(object_path(OBJECTS, REV).read_bytes())
    if hashlib.sha1(commit).hexdigest() != REV:
        raise RuntimeError('Commit object mismatch')
    (REPO / 'shallow').write_text(REV + '\n')
    ref = REPO / 'refs/heads/memoryos-reviewed'
    ref.parent.mkdir(parents=True, exist_ok=True)
    ref.write_text(REV + '\n')
    (REPO / 'HEAD').write_text('ref: refs/heads/memoryos-reviewed\n')
    result = dict(complete=True, revision=REV, root_tree=ROOT, original_url=URL, cache=str(REPO),
                  verified_blobs=len(blobs), verified_trees=len(children), blob_bytes=counters[1],
                  promisor=False, git_filter=None, local_server=False, transport_wrapper=False)
    (BASE / 'canonical-complete-cache.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
