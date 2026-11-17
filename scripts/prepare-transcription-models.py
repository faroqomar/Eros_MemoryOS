#!/usr/bin/env python3
"""Explicit preparation only. Download pinned public multilingual speech assets.

Runtime adapters never invoke this script or download missing files.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('destination', nargs='?', type=Path,
                    default=ROOT / 'native/verification/audio-step1/models')
parser.add_argument('--cpp-model', choices=['tiny', 'small-q5_1'], default='tiny')
ARGS = parser.parse_args()
DEST = ARGS.destination.expanduser().resolve()
CPP_FILENAME = f'ggml-{ARGS.cpp_model}.bin'
PINS = {
 'argmaxinc/whisperkit-coreml': '0f63a7800b00dd0226abd051b906c246e1907482',
 'openai/whisper-tiny': '169d4a4341b33bc18d8881c4b69c2e104e1cc0af',
 'ggerganov/whisper.cpp': '5359861c739e955e79d9a303bcbc70fb988958b1',
}

def fetch_repo(repo):
    revision = PINS[repo]
    sub = '/openai_whisper-tiny' if repo.startswith('argmax') else ''
    with urllib.request.urlopen(f'https://huggingface.co/api/models/{repo}/tree/{revision}{sub}?recursive=true', timeout=60) as response:
        listing=json.load(response)
    return [(repo,revision,row) for row in listing if row['type']=='file' and
            (sub or row['path'] in [CPP_FILENAME,'tokenizer.json','tokenizer_config.json'])]

def fetch(item):
    repo,revision,row=item
    suffix=row['path'].removeprefix('openai_whisper-tiny/')
    folder=('whisper.cpp' if ARGS.cpp_model=='tiny' else 'whisper-small-q5') if repo=='ggerganov/whisper.cpp' else 'whisperkit'
    out=DEST/folder/suffix
    out.parent.mkdir(parents=True,exist_ok=True)
    url=f"https://huggingface.co/{repo}/resolve/{revision}/{row['path']}"
    digest=row.get('lfs',{}).get('oid')
    if row['size'] > 4*1024*1024 and digest and not out.exists():
        subprocess.run([sys.executable,str(ROOT/'scripts/fetch-evaluation-asset.py'),
            '--url',url,'--output',str(out),'--bytes',str(row['size']),
            '--sha256',digest,'--workers','8','--chunk-mib','1'],check=True)
    else:
        if not out.exists():
            for attempt in range(4):
                try:
                    with urllib.request.urlopen(url,timeout=90) as response:
                        data=response.read()
                    break
                except (OSError,TimeoutError):
                    if attempt==3: raise
                    time.sleep(2**attempt)
            if len(data)!=row['size']: raise RuntimeError('Asset byte count mismatch')
            if digest and hashlib.sha256(data).hexdigest()!=digest: raise RuntimeError('Asset SHA256 mismatch')
            if not digest and hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=row['oid']:
                raise RuntimeError('Git blob hash mismatch')
            out.write_bytes(data)
    data=out.read_bytes()
    if len(data)!=row['size']: raise RuntimeError('Existing asset size mismatch')
    actual=hashlib.sha256(data).hexdigest()
    if digest and actual!=digest: raise RuntimeError('Existing asset hash mismatch')
    if not digest and hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=row['oid']:
        raise RuntimeError('Existing Git asset hash mismatch')
    return {'path':str(out.relative_to(DEST)), 'bytes':len(data),'sha256':actual,'repository':repo,'revision':revision}

if __name__=='__main__':
    items=[]
    for repo in PINS: items.extend(fetch_repo(repo))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        receipts=list(pool.map(fetch,items))
    (DEST/'models-receipt.json').write_text(json.dumps({'assets':receipts,'pins':PINS},indent=2)+'\n')
    print(json.dumps({'verifiedFiles':len(receipts),'bytes':sum(x['bytes'] for x in receipts),'directory':str(DEST)}))
