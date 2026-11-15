#!/usr/bin/python3
"""Fetch genuine Apple Crypto target bytes and write verified loose objects without Git processes."""
import pathlib,json,requests,threading,concurrent.futures,hashlib,zlib,tempfile,os,time,urllib.parse
base=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax')
package=next(x for x in json.loads((base/'snapshot-source-manifest.json').read_text()) if x['package']=='swift-crypto')
repo=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories/swift-crypto-7e0614ea')
files=[x for x in package['missing'] if x['kind']=='blob' and x['path'].startswith('Sources/Crypto/')]
local=threading.local();lock=threading.Lock();count=[0,0]
def fetch(item):
 path,oid=item['path'],item['oid'];destination=repo/'objects'/oid[:2]/oid[2:]
 if destination.exists():
  if hashlib.sha1(zlib.decompress(destination.read_bytes())).hexdigest()!=oid:raise RuntimeError('Existing object hash mismatch')
  return
 if not hasattr(local,'session'):local.session=requests.Session()
 attempt=0
 while True:
  attempt+=1
  try:
   url='https://raw.githubusercontent.com/apple/swift-crypto/'+package['revision']+'/'+urllib.parse.quote(path,safe='/')
   response=local.session.get(url,timeout=(60,120))
   if response.status_code in [400,401,403,404,410]:raise RuntimeError('Permanent HTTP '+str(response.status_code)+' '+path)
   response.raise_for_status();data=response.content;raw=b'blob '+str(len(data)).encode()+b'\0'+data
   if hashlib.sha1(raw).hexdigest()!=oid:raise RuntimeError('Pinned source hash mismatch '+path)
   destination.parent.mkdir(parents=True,exist_ok=True)
   with tempfile.NamedTemporaryFile(dir=destination.parent,delete=False,prefix='memoryos-verified-') as temporary:
    temporary.write(zlib.compress(raw));temporary.flush();os.fchmod(temporary.fileno(),0o444);temporary_path=pathlib.Path(temporary.name)
   try:os.link(temporary_path,destination)
   except FileExistsError:pass
   finally:temporary_path.unlink()
   with lock:
    count[0]+=1;count[1]+=len(data)
    with (base/'apple-crypto-priority.jsonl').open('a') as log:log.write(json.dumps({'path':path,'git_blob_sha1':oid,'bytes':len(data),'attempt':attempt})+'\n')
    if count[0]%10==0:print(json.dumps({'completed_new_files':count[0],'verified_bytes':count[1]}),flush=True)
   return
  except RuntimeError:raise
  except Exception as error:
   print(json.dumps({'transport_retry':attempt,'path':path,'error':str(error)}),flush=True);time.sleep(min(2*attempt,20))
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:list(executor.map(fetch,files))
print(json.dumps({'complete':True,'new_files':count[0],'verified_bytes':count[1]}),flush=True)
