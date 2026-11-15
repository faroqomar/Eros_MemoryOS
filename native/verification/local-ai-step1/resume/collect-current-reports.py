#!/usr/bin/env python3
"""Copy immutable, source-matched lab reports from the known simulator sandbox."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

IDENTITY = 'b44661c8b96b5e54457dd3918a5eced91c856dcc90d03b08f1b0dfbf8c595e00'
DEVICE = '452C5AF6-8A30-4F73-9C34-AADF3D6CF96C'
container = Path(subprocess.check_output(['xcrun','simctl','get_app_container',DEVICE,'com.eros.memoryos.ailab','data'],text=True).strip())
source = container/'Documents/EvaluationReports'
output = Path(__file__).resolve().parent/'simulator-reports';output.mkdir(exist_ok=True)
groups = {}
for path in sorted(source.glob('*.json')):
    raw = path.read_bytes();report=json.loads(raw)
    if report['context']['sourceIdentity'] != IDENTITY:continue
    target=output/path.name
    if target.exists() and target.read_bytes()!=raw:raise RuntimeError('Preserve conflicting saved report')
    if not target.exists():shutil.copy2(path,target)
    key=(report['configuration']['id'],report['context']['batchID'])
    row=groups.setdefault(key,{'candidateID':key[0],'batchID':key[1],'repetitions':[],'reports':[],'cases':0,'retrievalCompleted':0,'generationCompleted':0})
    row['repetitions'].append(report['context']['repetition'])
    row['reports'].append({'path':str(target),'sha256':hashlib.sha256(raw).hexdigest()})
    row['cases']+=len(report['results'])
    row['retrievalCompleted']+=sum(r['retrievalStatus']=='completed' for r in report['results'])
    row['generationCompleted']+=sum(r['generationStatus']=='completed' for r in report['results'])
for row in groups.values():row['repetitions'].sort()
receipt={'sourceIdentity':IDENTITY,'deviceID':DEVICE,'method':'Filesystem-only report retrieval from isolated Lab bundle; no UI interaction via simctl','groups':list(groups.values())}
(output.parent/'simulator-report-collection.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps([{k:v for k,v in row.items() if k!='reports'} for row in groups.values()]))
