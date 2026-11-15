#!/usr/bin/python3
"""Recover authentic pinned SDK Git objects after smart-HTTP truncation. No source edits."""
import pathlib,subprocess,os,urllib.request,urllib.parse,hashlib,time,json,concurrent.futures,threading,requests
repo=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories/Wax-18aab7e9')
revision='67da356544e145a02f97fcf9cf6be39a199ced74'
base='https://raw.githubusercontent.com/christopherkarani/Wax/'+revision+'/'
logpath=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax/blob-hydration.jsonl')
excluded=['Sources/WaxRerankerMiniLM/Resources/','Sources/WaxVectorSearchArctic/Resources/','Sources/WaxVectorSearchE5/Resources/','Sources/WaxVectorSearchMiniLM/Resources/']
tree=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'ls-tree','-r','-z',revision])
files=[]
for entry in tree.split(b'\0'):
 if not entry:continue
 metadata,path=entry.split(b'\t',1);mode,kind,oid=metadata.decode().split();path=path.decode()
 if kind!='blob':continue
 if not (path.startswith('Sources/') or path=='Package.swift' or path.startswith(('LICENSE','NOTICE'))):continue
 if any(path.startswith(prefix) for prefix in excluded):continue
 files.append((oid,path))
env=dict(os.environ,GIT_NO_LAZY_FETCH='1')
existing=subprocess.run(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'cat-file','--batch-check'],input=''.join(oid+'\n' for oid,path in files).encode(),capture_output=True,env=env,check=True).stdout.decode().splitlines()
missing=[item for item,result in zip(files,existing) if result.endswith(' missing')]
print(json.dumps({'source_revision':revision,'selected_files':len(files),'missing_files':len(missing)}),flush=True)
lock=threading.Lock();completed=0;totalbytes=0;local=threading.local()

def hydrate(item):
 global completed,totalbytes
 oid,path=item;attempt=0
 while True:
  attempt+=1
  try:
   if not hasattr(local,'session'):
    local.session=requests.Session()
    local.session.headers.update({'User-Agent':'MemoryOS-SDK-evaluation'})
   with local.session.get(base+urllib.parse.quote(path,safe='/'),timeout=(60,120)) as response:
    if response.status_code in [400,401,403,404,410]:raise RuntimeError('Permanent upstream HTTP '+str(response.status_code)+' for '+path)
    response.raise_for_status();data=response.content
   digest=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
   if digest!=oid:raise RuntimeError('Pinned Git blob hash mismatch for '+path)
   actual=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'hash-object','-w','--stdin'],input=data).decode().strip()
   if actual!=oid:raise RuntimeError('Git object store returned a different object ID')
   with lock:
    completed+=1;totalbytes+=len(data)
    with logpath.open('a') as log:log.write(json.dumps({'path':path,'git_blob_sha1':oid,'bytes':len(data),'attempt':attempt})+'\n')
    if completed%25==0 or completed==len(missing):print(json.dumps({'completed':completed,'total':len(missing),'verified_bytes':totalbytes}),flush=True)
   return
  except RuntimeError:raise
  except Exception as error:
   with lock:
    with logpath.open('a') as log:log.write(json.dumps({'path':path,'attempt':attempt,'transport_error':str(error)})+'\n')
   time.sleep(min(2*attempt,20))
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:list(executor.map(hydrate,missing))
print(json.dumps({'complete':True,'verified_source_files':len(files),'newly_fetched_bytes':totalbytes}),flush=True)
