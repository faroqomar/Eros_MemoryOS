#!/usr/bin/env python3
"""Hydrate reviewed exact transitive Git objects. No rewritten URL, filter or promisor."""
import datetime
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import subprocess

BASE = Path(__file__).resolve().parent
CACHE = Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation')
OLD = Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories')
spec = importlib.util.spec_from_file_location('verified_objects', BASE / 'hydrate-complete-canonical-wax.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
ENV = os.environ.copy()
ENV.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin', GIT_NO_LAZY_FETCH='1', GIT_ALLOW_PROTOCOL='none',
           GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null', GIT_CONFIG_NOSYSTEM='1')


def exact_unsigned(metadata, kind):
    offsets = ['+0000'] + [('+' if i >= 0 else '-') + f'{abs(i)//60:02}{abs(i)%60:02}'
                          for i in range(-720, 841, 15) if i]
    if kind == 'tag':
        t = metadata['tagger']
        epoch = int(datetime.datetime.fromisoformat(t['date'].replace('Z', '+00:00')).timestamp())
        for offset in offsets:
            body = ('object ' + metadata['object']['sha'] + '\ntype ' + metadata['object']['type']
                    + '\ntag ' + metadata['tag'] + '\ntagger ' + t['name'] + ' <' + t['email']
                    + '> ' + str(epoch) + ' ' + offset + '\n\n' + metadata['message']).encode()
            raw = m.raw_object('tag', body)
            if hashlib.sha1(raw).hexdigest() == metadata['sha']:
                return raw
    else:
        prefix = 'tree ' + metadata['tree']['sha'] + '\n' + ''.join('parent ' + x['sha'] + '\n' for x in metadata['parents'])
        a, c = metadata['author'], metadata['committer']
        ae = int(datetime.datetime.fromisoformat(a['date'].replace('Z', '+00:00')).timestamp())
        ce = int(datetime.datetime.fromisoformat(c['date'].replace('Z', '+00:00')).timestamp())
        for ao, co, end in itertools.product(offsets, offsets, ['\n', '']):
            body = (prefix + 'author ' + a['name'] + ' <' + a['email'] + '> ' + str(ae) + ' ' + ao + '\n'
                    + 'committer ' + c['name'] + ' <' + c['email'] + '> ' + str(ce) + ' ' + co + '\n\n'
                    + metadata['message'] + end).encode()
            raw = m.raw_object('commit', body)
            if hashlib.sha1(raw).hexdigest() == metadata['sha']:
                return raw
    raise RuntimeError('Cannot recover exact upstream ' + kind + ' identity')


def main():
    stable = json.loads((BASE / 'stable-MetalANNS-provenance.json').read_text())
    packages = [
        ('MetalANNS', 'christopherkarani/MetalANNS', 'MetalANNS-3408e04a', '0.3.0', stable['commit']['sha'],
         exact_unsigned(stable['commit'], 'commit'), stable['tag_object']),
        ('GRDB', 'groue/GRDB.swift', 'GRDB.swift-dd0599db', 'v7.12.0', '92a554cd0d5e8d67cb18993c6054e73fe42c066c', (BASE / 'canonical-GRDB-commit.raw').read_bytes(), None),
        ('Crypto', 'apple/swift-crypto', 'swift-crypto-7e0614ea', '3.15.1', '95ba0316a9b733e92bb6b071255ff46263bbe7dc', (BASE / 'canonical-Crypto-commit.raw').read_bytes(), None),
        ('ASN1', 'apple/swift-asn1', 'swift-asn1-7065ad2c', '1.7.4', '917b472dbe53ba699cbb0495f9a95a084bc6364d', (BASE / 'canonical-ASN1-commit.raw').read_bytes(), None),
    ]
    for name, upstream, identity, tag, rev, raw, annotated in packages:
        if (BASE / 'transitive-cache' / name / 'tag-proof.json').exists():
            print(json.dumps(dict(reusing_completed_cache=name, revision=rev)), flush=True)
            continue
        if hashlib.sha1(raw).hexdigest() != rev:
            raise RuntimeError('Original commit identity mismatch')
        repo = CACHE / 'wax-canonical-original-pin-cache/repositories' / identity
        if not repo.exists():
            subprocess.run(['/usr/bin/git', 'init', '--bare', str(repo)], env=ENV, check=True)
            subprocess.run(['/usr/bin/git', '-C', str(repo), 'remote', 'add', 'origin', 'https://github.com/' + upstream + '.git'], env=ENV, check=True)
        subprocess.run(['/usr/bin/git', '-C', str(repo), 'config', 'remote.origin.fetch', '+refs/*:refs/*'], env=ENV, check=True)
        subprocess.run(['/usr/bin/git', '-C', str(repo), 'config', 'remote.origin.mirror', 'true'], env=ENV, check=True)
        m.BASE = BASE / 'transitive-cache' / name
        m.BASE.mkdir(parents=True, exist_ok=True)
        m.REPO, m.OBJECTS, m.REV = repo, repo / 'objects', rev
        m.UPSTREAM, m.URL = upstream, 'https://github.com/' + upstream + '.git'
        m.ROOT = raw.split(b'\0', 1)[1].splitlines()[0].decode().split()[1]
        m.WORKERS = 2
        m.SOURCES = [OLD / identity / 'objects', CACHE / 'wax-supported-objects/MetalANNS/objects'] if name == 'MetalANNS' else [OLD / identity / 'objects']
        m.store(rev, raw)
        print(json.dumps(dict(starting=name, revision=rev, root_tree=m.ROOT)), flush=True)
        m.main()
        target = rev
        if annotated:
            data = exact_unsigned(annotated, 'tag')
            m.store(annotated['sha'], data)
            target = annotated['sha']
        ref = repo / 'refs/tags' / tag
        ref.parent.mkdir(parents=True, exist_ok=True)
        ref.write_text(target + '\n')
        r = subprocess.run(['/usr/bin/git', '--no-lazy-fetch', '-C', str(repo), 'fsck', '--full', '--no-reflogs'], env=ENV, capture_output=True, text=True)
        (m.BASE / 'fsck.log').write_text(r.stdout + r.stderr)
        if r.returncode:
            raise RuntimeError('Complete cache fsck failed: ' + name)
        (m.BASE / 'tag-proof.json').write_text(json.dumps(dict(tag=tag, tag_object=target, resolved_commit=rev, original_url=m.URL, fsck_exit_code=r.returncode), indent=2) + '\n')
        print(json.dumps(dict(complete=name, revision=rev, fsck_exit_code=r.returncode)), flush=True)


if __name__ == '__main__':
    main()
