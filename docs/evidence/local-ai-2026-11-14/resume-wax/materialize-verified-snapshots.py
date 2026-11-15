#!/usr/bin/python3
"""Materialize exact SDK source bytes from cached Git objects, with lazy fetch disabled."""
import pathlib,subprocess,zlib,hashlib,json,os
repos=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/repositories')
output=pathlib.Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/wax-verified-snapshots')
evidence=pathlib.Path('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax')
packages=[
 ('Wax','Wax-18aab7e9','https://github.com/christopherkarani/Wax.git','67da356544e145a02f97fcf9cf6be39a199ced74',['Sources']),
 ('swift-asn1','swift-asn1-7065ad2c','https://github.com/apple/swift-asn1.git','917b472dbe53ba699cbb0495f9a95a084bc6364d',['Sources']),
 ('MetalANNS','MetalANNS-3408e04a','https://github.com/christopherkarani/MetalANNS.git','1a8344c543eda41e3f4bb9826b1fe2f3dc03eb1f',['Sources']),
 ('GRDB.swift','GRDB.swift-dd0599db','https://github.com/groue/GRDB.swift.git','92a554cd0d5e8d67cb18993c6054e73fe42c066c',['GRDB','Sources']),
 ('swift-crypto','swift-crypto-7e0614ea','https://github.com/apple/swift-crypto.git','95ba0316a9b733e92bb6b071255ff46263bbe7dc',['Sources']),
]
excluded=['Sources/WaxRerankerMiniLM/Resources/','Sources/WaxVectorSearchArctic/Resources/','Sources/WaxVectorSearchE5/Resources/','Sources/WaxVectorSearchMiniLM/Resources/']
report=[]
for name,cache,url,revision,scopes in packages:
 repo=repos/cache
 process=subprocess.Popen(['/usr/bin/git','--no-lazy-fetch','-C',str(repo),'cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=dict(os.environ,GIT_NO_LAZY_FETCH='1'))
 def read(oid):
  loose=repo/'objects'/oid[:2]/oid[2:]
  if loose.is_file():
   raw=zlib.decompress(loose.read_bytes());header,body=raw.split(b'\0',1);kind,size=header.split()
   if int(size)!=len(body) or hashlib.sha1(raw).hexdigest()!=oid:raise RuntimeError('Invalid cached loose object '+oid)
   return kind.decode(),body
  process.stdin.write((oid+'\n').encode());process.stdin.flush();header=process.stdout.readline().decode().strip().split()
  if len(header)!=3:return None,None
  actual,kind,size=header;body=process.stdout.read(int(size));trailer=process.stdout.read(1)
  if actual!=oid or trailer!=b'\n' or hashlib.sha1((kind+' '+str(len(body))).encode()+b'\0'+body).hexdigest()!=oid:raise RuntimeError('Invalid packed object response '+oid)
  return kind,body
 try:
  kind,commit=read(revision)
  if kind!='commit':raise RuntimeError('Pinned commit unavailable: '+name)
  root=next(line.split()[1].decode() for line in commit.splitlines() if line.startswith(b'tree '))
  files=[];missing=[]
  def walk(path,oid):
   kind,body=read(oid)
   if kind!='tree':missing.append({'path':path,'oid':oid,'kind':'tree'});return
   at=0
   while at<len(body):
    boundary=body.index(b'\0',at);mode,leaf=body[at:boundary].split(b' ',1);child=body[boundary+1:boundary+21].hex();at=boundary+21
    full=path+'/'+leaf.decode() if path else leaf.decode()
    if mode in [b'40000',b'040000']:
     if any(full==scope or scope.startswith(full+'/') or full.startswith(scope+'/') for scope in scopes):
      if name!='Wax' or not any((full+'/').startswith(prefix) for prefix in excluded):walk(full,child)
    elif full=='Package.swift' or full.startswith(('LICENSE','NOTICE','COPYING')) or any(full.startswith(scope+'/') for scope in scopes):
     if name=='Wax' and any(full.startswith(prefix) for prefix in excluded):continue
     files.append((full,child,mode.decode()))
  walk('',root)
  destination=output/name;destination.mkdir(parents=True,exist_ok=True)
  manifest=[]
  for path,oid,mode in files:
   kind,data=read(oid)
   if kind!='blob':missing.append({'path':path,'oid':oid,'kind':'blob'});continue
   target=destination/path;target.parent.mkdir(parents=True,exist_ok=True)
   if mode=='120000':
    link=data.decode()
    if not (target.parent/link).resolve().is_relative_to(destination.resolve()):raise RuntimeError('Snapshot symlink leaves SDK root')
    if target.exists() or target.is_symlink():target.unlink()
    target.symlink_to(link)
   else:
    if target.exists():
     if target.read_bytes()!=data:raise RuntimeError('Snapshot source drift: '+str(target))
    else:target.write_bytes(data)
    target.chmod(0o555 if mode=='100755' else 0o444)
   manifest.append({'path':path,'git_blob_sha1':oid,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'mode':mode})
  item={'package':name,'original_url':url,'revision':revision,'root_tree':root,'snapshot':str(destination),'selected_scope':scopes,'complete':not missing,'files':manifest,'missing':missing}
  report.append(item);print(json.dumps({'package':name,'complete':not missing,'materialized_files':len(manifest),'missing_objects':len(missing)}),flush=True)
 finally:
  process.stdin.close();process.wait()
(evidence/'snapshot-source-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
