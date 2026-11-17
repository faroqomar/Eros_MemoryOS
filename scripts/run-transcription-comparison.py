#!/usr/bin/env python3
"""Run both local engines against identical, hash-verified fictional recordings."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unicodedata

ROOT=Path(__file__).resolve().parents[1]
if len(sys.argv)!=4:
 raise SystemExit('Usage: run-transcription-comparison.py MODEL_ROOT FIXTURE_ROOT OUTPUT_ROOT')
models,fixtures,output=map(lambda x:Path(x).resolve(),sys.argv[1:])
output.mkdir(parents=True,exist_ok=True)
manifest=json.loads((fixtures/'manifest.json').read_text())
subprocess.run(['swift','build','--package-path',str(ROOT/'native/LocalTranscription'),'-c','release'],check=True)
bin_directory=subprocess.check_output(['swift','build','--package-path',str(ROOT/'native/LocalTranscription'),'-c','release','--show-bin-path'],text=True).strip()
binary=Path(bin_directory)/'transcription-comparison'

def words(text):
 return re.findall(r'\w+',unicodedata.normalize('NFKC',text).casefold())
def distance(reference,hypothesis):
 previous=list(range(len(hypothesis)+1))
 for i,left in enumerate(reference,1):
  row=[i]
  for j,right in enumerate(hypothesis,1):
   row.append(min(row[-1]+1,previous[j]+1,previous[j-1]+(left!=right)))
  previous=row
 return previous[-1]
rows=[]
for case in manifest['recordings']:
 audio=fixtures/case['file']
 if hashlib.sha256(audio.read_bytes()).hexdigest()!=case['sha256']:
  raise SystemExit('Fixture hash mismatch')
 for provider in ['whisperkit','whisper.cpp']:
  for repetition in [1,2,3]:
   report=output/f"{case['id']}-{provider}-{repetition}.json"
   invocation=subprocess.run(['/usr/bin/sandbox-exec','-p','(version 1)(allow default)(deny network*)',str(binary),provider,str(models/provider),str(audio),str(report)],
     capture_output=True,text=True)
   if invocation.returncode:
    rows.append({'case':case['id'],'provider':provider,'repetition':repetition,
      'status':'failed','exitCode':invocation.returncode})
    (output/f"{case['id']}-{provider}-{repetition}.stderr.txt").write_text(invocation.stderr)
    continue
   data=json.loads(report.read_text())
   hypothesis=' '.join(x['text'] for x in data['passages'])
   expected=words(case['expected']);predicted=words(hypothesis)
   rows.append({'case':case['id'],'provider':provider,'repetition':repetition,
     'status':'completed','wordErrorRate':distance(expected,predicted)/max(1,len(expected)),
     'hypothesis':hypothesis,**{k:data[k] for k in ['elapsedSeconds','audioSeconds','realTimeFactor',
       'audioSHA256','processPeakResidentBytes','modelID','language','operatingSystem']}})
summary={'schemaVersion':1,'platform':'macOS host, not iPhone or Simulator',
 'network':'macOS sandbox denies network operations for every inference process',
 'measurement':'Fresh process per case; elapsed includes model loading, PCM decoding and inference. OS/CoreML caches may persist.',
 'normalization':'NFKC, Unicode word tokens, casefold; no Arabic dialect/diacritic normalization',
 'limitations':manifest['limitations']+['No natural human Iraqi dialect, battery, heat, physical phone, or production acceptance measurement.'],
 'results':rows}
(output/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'completed':sum(x['status']=='completed' for x in rows),'failed':sum(x['status']=='failed' for x in rows),'summary':str(output/'summary.json')}))
