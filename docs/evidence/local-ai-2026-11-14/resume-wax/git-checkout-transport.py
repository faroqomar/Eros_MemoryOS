#!/usr/bin/python3
import os,sys,subprocess,pathlib,json
args=sys.argv[1:]
real=['/usr/bin/git','-c','http.version=HTTP/1.1','-c','fetch.recurseSubmodules=false']
workspace='/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIIntegrations/.build/'
if 'clone' in args:
    with open('/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/docs/evidence/local-ai-2026-11-14/resume-wax/clone-commands.jsonl','a') as log:
        log.write(json.dumps(args)+'\n')
    if len(args)>=3 and args[-2].startswith(workspace+'repositories/') and args[-1].startswith(workspace+'checkouts/'):
        source,destination=args[-2:]
        original=subprocess.check_output(real+['-C',source,'config','--get','remote.origin.url']).decode().strip()
        assert original.startswith('https://github.com/'),original
        subprocess.check_call(real+['-C',source,'config','uploadpack.allowFilter','true'])
        args=[a for a in args if a not in ['--shared','--local','-l','--no-checkout']]
        args[args.index('clone')+1:args.index('clone')+1]=['--filter=tree:0','--no-local','--no-checkout']
        result=subprocess.run(real+args)
        if result.returncode:sys.exit(result.returncode)
        subprocess.check_call(real+['-C',destination,'remote','set-url','origin',original])
        subprocess.check_call(real+['-C',destination,'config','remote.origin.promisor','true'])
        subprocess.check_call(real+['-C',destination,'config','remote.origin.partialclonefilter','tree:0'])
        alternate=pathlib.Path(destination)/'.git/objects/info/alternates'
        alternate.parent.mkdir(parents=True,exist_ok=True)
        alternate.write_text(str(pathlib.Path(source).resolve()/'objects')+'\n')
        if original.rstrip('/').endswith('/Wax.git'):
            subprocess.check_call(real+['-C',destination,'config','core.sparseCheckout','true'])
            info=pathlib.Path(destination)/'.git/info/sparse-checkout'
            info.parent.mkdir(parents=True,exist_ok=True)
            info.write_text('/Package.swift\n/LICENSE*\n/NOTICE*\n/Sources/\n!/Sources/WaxRerankerMiniLM/Resources/\n!/Sources/WaxVectorSearchArctic/Resources/\n!/Sources/WaxVectorSearchE5/Resources/\n!/Sources/WaxVectorSearchMiniLM/Resources/\n')
        sys.exit(0)
    if '--mirror' in args:
        pos=args.index('clone')+1
        args[pos:pos]=['--filter=tree:0','--depth=1','--no-single-branch']
os.execv('/usr/bin/git',real+args)
