#!/usr/bin/python3
"""Hydrate original, hash-checked Git SDK objects; never change source or resolver versions."""
import pathlib,subprocess,os,urllib.parse,hashlib,time,json,concurrent.futures,threading,requests
base=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories')
evidence=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax')
packages=[
 ('swift-asn1','swift-asn1-7065ad2c','apple/swift-asn1','917b472dbe53ba699cbb0495f9a95a084bc6364d',['Sources']),
 ('MetalANNS','MetalANNS-3408e04a','christopherkarani/MetalANNS','9874645afb86f687f06a3e0b0fd8a310c3305ff1',['Sources']),
 ('GRDB.swift','GRDB.swift-dd0599db','groue/GRDB.swift','92a554cd0d5e8d67cb18993c6054e73fe42c066c',['GRDB','Sources']),
 ('swift-crypto','swift-crypto-7e0614ea','apple/swift-crypto','95ba0316a9b733e92bb6b071255ff46263bbe7dc',['Sources']),
]
lock=threading.Lock();local=threading.local();api=requests.Session()

def get(session,url):
 attempt=0
 while True:
  attempt+=1
  try:
   response=session.get(url,timeout=(60,120))
   if response.status_code==403 and response.headers.get('X-RateLimit-Remaining')=='0':
    print(json.dumps({'waiting_for_public_api_rate_limit':True}),flush=True);time.sleep(30);continue
   if response.status_code in [400,401,403,404,410]:raise RuntimeError('Permanent upstream HTTP '+str(response.status_code)+' for '+url)
   response.raise_for_status();return response.content
  except RuntimeError:raise
  except Exception as error:
   print(json.dumps({'transport_retry':attempt,'error':str(error),'url':url}),flush=True);time.sleep(min(2*attempt,20))

for name,cache,upstream,revision,scopes in packages:
 repo=base/cache
 revision=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'rev-parse',revision+'^{commit}']).decode().strip()
 commit=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'cat-file','-p',revision]).decode()
 root=next(line.split()[1] for line in commit.splitlines() if line.startswith('tree '))
 trees={};files={}
 def store_tree(oid):
  if oid in trees:return trees[oid]
  payload=json.loads(get(api,'https://api.github.com/repos/'+upstream+'/git/trees/'+oid))
  if payload.get('truncated') or payload.get('sha')!=oid:raise RuntimeError('Invalid upstream tree response')
  entries=payload['tree']
  body=b''.join((entry['mode']+' '+entry['type']+' '+entry['sha']+'\t').encode()+entry['path'].encode()+b'\0' for entry in entries)
  actual=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'mktree','--missing','-z'],input=body).decode().strip()
  if actual!=oid:raise RuntimeError('Pinned tree hash mismatch')
  trees[oid]=entries;return entries
 def subtree(path):
  oid=root
  for part in path.split('/'):
   entry=next((entry for entry in store_tree(oid) if entry['path']==part),None)
   if entry is None or entry['type']!='tree':return None
   oid=entry['sha']
  return oid
 def visit(path,oid):
  payload=json.loads(get(api,'https://api.github.com/repos/'+upstream+'/git/trees/'+oid+'?recursive=1'))
  if payload.get('truncated') or payload.get('sha')!=oid:raise RuntimeError('Invalid recursive upstream tree response')
  entries=payload['tree'];expected={'':oid};children={'':[]}
  for entry in entries:
   if entry['type']=='tree':expected[entry['path']]=entry['sha'];children[entry['path']]=[]
  for entry in entries:
   parent,separator,leaf=entry['path'].rpartition('/')
   record=dict(entry,path=leaf if separator else entry['path'])
   children[parent].append(record)
   if entry['type']=='blob':files[path+'/'+entry['path']]=entry['sha']
  for directory in sorted(children,key=lambda key:(key.count('/'),len(key)),reverse=True):
   body=b''.join((entry['mode']+' '+entry['type']+' '+entry['sha']+'\t').encode()+entry['path'].encode()+b'\0' for entry in children[directory])
   actual=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'mktree','--missing','-z'],input=body).decode().strip()
   if actual!=expected[directory]:raise RuntimeError('Pinned recursive tree hash mismatch')
   trees[actual]=children[directory]

 root_entries=store_tree(root)
 for entry in root_entries:
  path=entry['path']
  if entry['type']=='blob' and (path=='Package.swift' or path.startswith(('LICENSE','NOTICE','COPYING'))):files[path]=entry['sha']
 for scope in scopes:
  oid=subtree(scope)
  if oid:visit(scope,oid)
 missing=[]
 env=dict(os.environ,GIT_NO_LAZY_FETCH='1')
 items=list(files.items())
 states=subprocess.run(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'cat-file','--batch-check'],input=''.join(oid+'\n' for path,oid in items).encode(),capture_output=True,env=env,check=True).stdout.decode().splitlines()
 for item,state in zip(items,states):
  if state.endswith(' missing'):missing.append(item)
 print(json.dumps({'package':name,'revision':revision,'selected_files':len(items),'missing_files':len(missing),'verified_tree_objects':len(trees)}),flush=True)
 count=[0,0]
 def hydrate(item):
  path,oid=item
  if not hasattr(local,'session'):local.session=requests.Session()
  data=get(local.session,'https://raw.githubusercontent.com/'+upstream+'/'+revision+'/'+urllib.parse.quote(path,safe='/'))
  actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
  if actual!=oid:raise RuntimeError('Pinned blob hash mismatch: '+name+'/'+path)
  actual=subprocess.check_output(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'hash-object','-w','--stdin'],input=data).decode().strip()
  if actual!=oid:raise RuntimeError('Object store hash mismatch')
  with lock:
   count[0]+=1;count[1]+=len(data)
   with (evidence/'dependency-blob-hydration.jsonl').open('a') as log:log.write(json.dumps({'package':name,'revision':revision,'path':path,'git_blob_sha1':oid,'bytes':len(data)})+'\n')
   if count[0]%25==0 or count[0]==len(missing):print(json.dumps({'package':name,'completed':count[0],'total':len(missing),'verified_bytes':count[1]}),flush=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:list(executor.map(hydrate,missing))
 print(json.dumps({'package':name,'complete':True,'verified_source_files':len(items),'verified_trees':len(trees),'new_bytes':count[1]}),flush=True)
