#!/usr/bin/python3
"""Fetch stock releases over HTTPS, verify Git trees/blobs, reuse immutable cached objects. No Git process."""
import pathlib,json,requests,hashlib,zlib,tempfile,os,threading,concurrent.futures,time,urllib.parse
base=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax')
cache=pathlib.Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/wax-supported-objects')
output=pathlib.Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/wax-supported-snapshots')
old=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories')
packages=[('Wax','Wax-18aab7e9',['Sources']),('MetalANNS','MetalANNS-3408e04a',['Sources'])]
excluded=['Sources/WaxRerankerMiniLM/Resources/','Sources/WaxVectorSearchArctic/Resources/','Sources/WaxVectorSearchE5/Resources/','Sources/WaxVectorSearchMiniLM/Resources/']
lock=threading.Lock();local=threading.local();session=requests.Session();report=[]
def get(s,url):
 attempt=0
 while True:
  attempt+=1
  try:
   r=s.get(url,timeout=(60,120))
   if r.status_code==403 and r.headers.get('X-RateLimit-Remaining')=='0':print('Waiting for public metadata rate reset',flush=True);time.sleep(30);continue
   if r.status_code in [400,401,403,404,410]:raise RuntimeError('Permanent HTTP '+str(r.status_code)+' '+url)
   r.raise_for_status();return r.content
  except RuntimeError:raise
  except Exception as e:print(json.dumps({'transport_retry':attempt,'error':str(e),'url':url}),flush=True);time.sleep(min(attempt*2,20))
def store(objects,kind,body,oid):
 raw=(kind+' '+str(len(body))).encode()+b'\0'+body
 if hashlib.sha1(raw).hexdigest()!=oid:raise RuntimeError('Pinned '+kind+' hash mismatch '+oid)
 p=objects/oid[:2]/oid[2:];p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists():
  if hashlib.sha1(zlib.decompress(p.read_bytes())).hexdigest()!=oid:raise RuntimeError('Cached hash mismatch')
  return
 with tempfile.NamedTemporaryFile(dir=p.parent,delete=False,prefix='memoryos-')as f:f.write(zlib.compress(raw));os.fchmod(f.fileno(),0o444);temporary=pathlib.Path(f.name)
 try:os.link(temporary,p)
 except FileExistsError:pass
 finally:temporary.unlink()
for name,oldcache,scopes in packages:
 provenance=json.loads((base/('stable-'+name+'-provenance.json')).read_text());repo=provenance['repo'];revision=provenance['commit']['sha'];root=provenance['commit']['tree']['sha'];objects=cache/name/'objects'
 payload=json.loads(get(session,'https://api.github.com/repos/'+repo+'/git/trees/'+root+'?recursive=1'))
 if payload.get('sha')!=root or payload.get('truncated'):raise RuntimeError('Invalid complete tree response')
 entries=payload['tree'];expected={'':root};children={'':[]};files=[]
 for entry in entries:
  if entry['type']=='tree':expected[entry['path']]=entry['sha'];children[entry['path']]=[]
 for entry in entries:
  parent,sep,leaf=entry['path'].rpartition('/');children[parent].append(dict(entry,path=leaf if sep else entry['path']))
  path=entry['path']
  if entry['type']=='blob'and(path=='Package.swift'or path.startswith(('LICENSE','NOTICE','COPYING'))or any(path.startswith(scope+'/')for scope in scopes)):
   if not(name=='Wax'and any(path.startswith(prefix)for prefix in excluded)):files.append(entry)
 for directory in sorted(children,key=lambda x:(x.count('/'),len(x)),reverse=True):
  contents=b''
  for entry in sorted(children[directory],key=lambda e:e['path'].encode()+(b'/'if e['type']=='tree'else b'')):
   contents+=entry['mode'].lstrip('0').encode()+b' '+entry['path'].encode()+b'\0'+bytes.fromhex(entry['sha'])
  store(objects,'tree',contents,expected[directory])
 count=[0,0,0]
 def hydrate(entry):
  path,oid=entry['path'],entry['sha'];p=objects/oid[:2]/oid[2:];prior=old/oldcache/'objects'/oid[:2]/oid[2:]
  reused=False
  if p.exists():raw=zlib.decompress(p.read_bytes());kind,body=raw.split(b'\0',1);reused=True
  elif prior.exists():raw=zlib.decompress(prior.read_bytes());kind,body=raw.split(b'\0',1);reused=True
  else:
   if not hasattr(local,'session'):local.session=requests.Session()
   body=get(local.session,'https://raw.githubusercontent.com/'+repo+'/'+revision+'/'+urllib.parse.quote(path,safe='/'))
  store(objects,'blob',body,oid)
  destination=output/name/path;destination.parent.mkdir(parents=True,exist_ok=True)
  if destination.exists():
   if destination.read_bytes()!=body:raise RuntimeError('Snapshot drift')
  else:destination.write_bytes(body)
  destination.chmod(0o555 if entry['mode']=='100755' else 0o444)
  record={'package':name,'revision':revision,'path':path,'git_blob_sha1':oid,'sha256':hashlib.sha256(body).hexdigest(),'bytes':len(body),'reused':reused}
  with lock:
   count[0]+=1;count[1]+=len(body);count[2]+=int(reused)
   with(base/'supported-snapshot-blobs.jsonl').open('a')as f:f.write(json.dumps(record)+'\n')
   if count[0]%25==0 or count[0]==len(files):print(json.dumps({'package':name,'completed':count[0],'total':len(files),'reused':count[2],'bytes':count[1]}),flush=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=4)as pool:list(pool.map(hydrate,files))
 item={'name':name,'tag':provenance['tag'],'revision':revision,'root_tree':root,'original_url':'https://github.com/'+repo+'.git','snapshot':str(output/name),'complete':True,'files':len(files),'bytes':count[1],'reused':count[2]};report.append(item)
 print(json.dumps(item),flush=True)
(base/'supported-snapshot-summary.json').write_text(json.dumps(report,indent=2)+'\n')
