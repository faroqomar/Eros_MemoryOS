#!/usr/bin/env python3
"""Prepare a pinned whisper.cpp dynamic framework.

Uses the official binary without copying engine source. Generated output stays
ignored. Official dynamic slices must use Mach-O two-level namespaces, but may
export GGML internals. Other engines must isolate their own internals; static
llama linkage is unsafe. A static upstream slice gets a narrow-export wrapper.
"""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]
CACHE=Path.home()/'Dev/Tools/MemoryOS-Evaluation-Upstream'
ZIP=CACHE/'whisper-b5454-xcframework.zip'
SHA='e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b'
URL='https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip'
OUT=ROOT/'native/LocalTranscription/Artifacts/whisper.xcframework'

if not ZIP.exists():
 subprocess.run([sys.executable,str(ROOT/'scripts/fetch-evaluation-asset.py'),'--url',URL,
  '--output',str(ZIP),'--bytes','65816082','--sha256',SHA,'--workers','12','--chunk-mib','1'],check=True)
if hashlib.sha256(ZIP.read_bytes()).hexdigest()!=SHA: raise SystemExit('Official archive hash mismatch')
if OUT.exists():
 receipt_path=OUT.parent/'whisper-build-receipt.json'
 if not receipt_path.exists(): raise SystemExit('Existing artifact has no receipt; preserved for inspection.')
 previous=json.loads(receipt_path.read_text())
 info=plistlib.loads((OUT/'Info.plist').read_bytes())
 expected={(x['platform'],x['variant']):x['binarySHA256'] for x in previous['slices']}
 for library in info['AvailableLibraries']:
  binary=OUT/library['LibraryIdentifier']/library['LibraryPath']/'whisper'
  if hashlib.sha256(binary.read_bytes()).hexdigest()!=expected.get((library['SupportedPlatform'],library.get('SupportedPlatformVariant'))):
   raise SystemExit('Existing framework hash mismatch; preserved for inspection.')
 print(json.dumps({'verifiedExisting':str(OUT),'slices':len(expected)}))
 raise SystemExit(0)
OUT.parent.mkdir(parents=True,exist_ok=True)
receipt={'upstreamRevision':'d1be6fde11ac6e0407606b4e42fe72d34add8037','archiveSHA256':SHA,
 'toolchain':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),'slices':[]}
with tempfile.TemporaryDirectory(prefix='memoryos-whisper-build-') as temporary:
 scratch=Path(temporary)
 with zipfile.ZipFile(ZIP) as archive:
  for member in archive.infolist():
   if member.filename.startswith('/') or '..' in Path(member.filename).parts:
    raise SystemExit('Unsafe archive path')
  subprocess.run(['ditto','-xk',str(ZIP),str(scratch/'official')],check=True)
 xc=next((scratch/'official').rglob('whisper.xcframework'))
 info=plistlib.loads((xc/'Info.plist').read_bytes())
 frameworks=[]
 for library in info['AvailableLibraries']:
  platform=library['SupportedPlatform']; variant=library.get('SupportedPlatformVariant')
  if platform not in ['ios','macos'] or variant not in [None,'simulator']: continue
  if 'arm64' not in library['SupportedArchitectures']: continue
  source=xc/library['LibraryIdentifier']/library['LibraryPath']
  framework=scratch/library['LibraryIdentifier']/'whisper.framework'
  shutil.copytree(source,framework,symlinks=True)
  original=framework/'whisper'
  archive_path=scratch/(library['LibraryIdentifier']+'.a')
  archs=subprocess.check_output(['lipo','-archs',str(original)],text=True).split()
  if archs==['arm64']: shutil.copyfile(original,archive_path)
  else: subprocess.run(['lipo',str(original),'-thin','arm64','-output',str(archive_path)],check=True)
  kind=subprocess.check_output(['file',str(archive_path)],text=True)
  if 'dynamically linked shared library' in kind:
   header=subprocess.check_output(['otool','-hv',str(archive_path)],text=True)
   if 'TWOLEVEL' not in header: raise SystemExit('Dynamic dependency lacks two-level namespace isolation')
   receipt['slices'].append({'platform':platform,'variant':variant,
    'binarySHA256':hashlib.sha256(original.read_bytes()).hexdigest(),
    'linkage':'official dynamic, TWOLEVEL namespace; no repacking'})
   frameworks.extend(['-framework',str(framework)])
   continue
  if 'ar archive' not in kind: raise SystemExit('Unexpected upstream Mach-O type')
  symbols=subprocess.check_output(['nm','-gUj',str(archive_path)],text=True).splitlines()
  exports=sorted(set(x for x in symbols if x.startswith('_whisper_')))
  if not exports: raise SystemExit('No whisper exports')
  export_file=scratch/(library['LibraryIdentifier']+'.exports')
  export_file.write_text('\n'.join(exports)+'\n')
  sdk='macosx' if platform=='macos' else ('iphonesimulator' if variant=='simulator' else 'iphoneos')
  target='arm64-apple-macos14.0' if platform=='macos' else ('arm64-apple-ios18.0-simulator' if variant=='simulator' else 'arm64-apple-ios18.0')
  sdk_path=subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip()
  # Remove stale signatures when replacing the static archive with a dylib.
  signature=framework/'_CodeSignature'
  if signature.exists(): shutil.rmtree(signature)
  if original.is_symlink():
   binary=original.resolve()
  else: binary=original
  subprocess.run(['xcrun','clang++','-dynamiclib','-target',target,'-isysroot',sdk_path,
   '-Wl,-all_load',str(archive_path),'-Wl,-exported_symbols_list,'+str(export_file),
   '-Wl,-install_name,@rpath/whisper.framework/whisper','-framework','Accelerate',
   '-framework','Foundation','-framework','Metal','-framework','MetalKit','-framework','CoreML',
   '-o',str(binary)],check=True)
  actual=subprocess.check_output(['nm','-gUj',str(binary)],text=True).splitlines()
  if any(x.startswith('_ggml_') for x in actual): raise SystemExit('ggml symbol leaked from generated wrapper')
  receipt['slices'].append({'platform':platform,'variant':variant,'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'exportCount':len(actual)})
  frameworks.extend(['-framework',str(framework)])
 subprocess.run(['xcodebuild','-create-xcframework',*frameworks,'-output',str(OUT)],check=True)
(OUT.parent/'whisper-build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'artifact':str(OUT),'slices':len(receipt['slices'])}))
