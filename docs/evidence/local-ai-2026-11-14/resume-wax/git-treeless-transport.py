#!/usr/bin/python3
import os,sys
args=sys.argv[1:]
if "clone" in args and "--mirror" in args:
    pos=args.index("clone")+1
    args[pos:pos]=["--filter=tree:0","--depth=1","--no-single-branch"]
os.execv("/usr/bin/git",["/usr/bin/git","-c","http.version=HTTP/1.1","-c","fetch.recurseSubmodules=false",*args])
