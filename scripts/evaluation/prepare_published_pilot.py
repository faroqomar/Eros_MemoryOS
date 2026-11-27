#!/usr/bin/env python3
"""Prepare pinned public benchmark inputs outside Git; never invoke an inference API.

The output separates original source records/questions from answer/evidence labels.
RHELM source dates follow upstream strict-before-question filtering. LongMemEval
uses the entire released S history. These are app-pipeline pilots, not full scores.
"""
import argparse
import concurrent.futures
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.request
import uuid

RHELM_REV = 'd0e8e0cc7be6b7042819175ddef550d217c7c5a9'
LONGMEM_REV = '98d7416c24c778c2fee6e6f3006e7a073259d48f'
LONGMEM_SHA = 'd6f21ea9d60a0d56f34a05b609c79c88a451d2ae03597821ea3d5a9678c3a442'
PERSONA = 'David_R._Ellis'
PROTOCOL = 'memoryos-published-pilot-2026-11-24-v1'
NS = uuid.UUID('d94c7af9-ecb2-4bce-ae5e-9de1d94fc074')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def fetch(url, path):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(3):
        try:
            data = urllib.request.urlopen(url, timeout=40).read()
            tmp = path.with_suffix(path.suffix + '.tmp')
            tmp.write_bytes(data)
            tmp.replace(path)
            return
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


def record(benchmark, persona, source, session, date, speaker, text, occurrence=None):
    if not text or len(text.encode()) > 101000:
        raise ValueError(f'Unrepresentable source: {benchmark}/{source}')
    identity = f'{benchmark}/{persona}/{source}'
    if occurrence is not None:
        identity += f'/occurrence/{occurrence}'
    value = dict(id=str(uuid.uuid5(NS, identity)), sourceID=source, sessionID=session,
                 date=date, speaker=speaker, text=text)
    if occurrence is not None:
        value['sourceOccurrence'] = occurrence
    return value


def prepare_rhelm(root, download):
    metadata = root / 'rhelm-blob-metadata.json'
    if download:
        fetch(f'https://huggingface.co/api/datasets/microsoft/RHELM/revision/{RHELM_REV}?blobs=true', metadata)
    meta = json.loads(metadata.read_text())
    if meta['sha'] != RHELM_REV:
        raise ValueError('RHELM metadata revision mismatch')
    paths = sorted(x['rfilename'] for x in meta['siblings']
                   if f'/{PERSONA}/' in x['rfilename'] or
                   x['rfilename'] == f'QA_final/low_score_qa_{PERSONA}_all_validated.jsonl')
    data = root / 'rhelm'
    if download:
        def one(path):
            fetch(f'https://huggingface.co/datasets/microsoft/RHELM/resolve/{RHELM_REV}/{path}', data / path)
        with concurrent.futures.ThreadPoolExecutor(6) as pool:
            list(pool.map(one, paths))
    blobs = {x['rfilename']: x for x in meta['siblings']}
    for path in paths:
        raw = (data / path).read_bytes()
        expected = blobs[path]
        actual = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
        if len(raw) != expected['size'] or actual != expected['blobId']:
            raise ValueError(f'Pinned RHELM Git blob identity mismatch: {path}')
    assets = [dict(path=p, sha256=digest(data / p), bytes=(data / p).stat().st_size) for p in paths]
    qa = [json.loads(line) for line in (data / f'QA_final/low_score_qa_{PERSONA}_all_validated.jsonl').read_text().splitlines()]
    chosen = [min((x for x in qa if x['question_type'] == category), key=lambda x: x['id'])
              for category in sorted({x['question_type'] for x in qa})]
    records = []
    seq_dates = {}
    for path in paths:
        if path.startswith('emails/'):
            name = Path(path).name
            match = re.search(r'_(\d{4})_(\d{2})_(\d{2})', name)
            if not match:
                raise ValueError(f'No email date: {path}')
            date = '-'.join(match.groups())
            seq_dates[int(name.split('_')[0])] = date
            raw = (data / path).read_text()
            blocks = [b.strip() for b in re.split(r'\n=+\n', raw) if b.strip()]
            text = f'Date: {date}\n\n' + '\n\n---\n\n'.join(blocks)
            records.append(record('rhelm', PERSONA, name, name, date, 'email', text))
    for path in paths:
        file = data / path
        if path.startswith('conversations/'):
            obj = json.loads(file.read_text())
            for turn in obj['conversation']:
                for speaker in ['user', 'assistant']:
                    source = f"{obj['date']}:{turn['turn']}:{speaker}"
                    text = f"{speaker.title()} ({turn.get('timestamp', '')}): {turn.get(speaker, '')}"
                    records.append(record('rhelm', PERSONA, source, obj['date'], obj['date'], speaker, text))
        elif path.startswith('attachments/'):
            date = seq_dates[int(file.name.split('_')[0])]
            records.append(record('rhelm', PERSONA, file.name, file.name, date, 'attachment', file.read_text()))
    records.sort(key=lambda r: (r['date'], r['sourceID']))
    cases, labels = [], []
    for q in chosen:
        case_id = f"rhelm/{PERSONA}/{q['id']}"
        available = [r for r in records if r['date'] < q['question_date']]
        # Preserve upstream evidence labels, with both speakers eligible for a dated turn.
        evidence = []
        missing = []
        for e in q['supporting_evidence']:
            if re.match(r'^\d{4}-\d{2}-\d{2}:', e):
                matches = [r['sourceID'] for r in available if r['sourceID'].rsplit(':', 1)[0] == e]
            else:
                matches = [r['sourceID'] for r in available if r['sourceID'] == e.split(':', 1)[0]]
            evidence.extend(matches)
            if not matches:
                missing.append(e)
        cases.append(dict(id=case_id, benchmark='rhelm', category=q['question_type'], personaID=PERSONA,
                          question=q['question'], questionDate=q['question_date'], records=available))
        labels.append(dict(caseID=case_id, expectedAnswer=q['answer'], supportingSourceIDs=sorted(set(evidence)),
                           upstreamSupportingEvidence=q['supporting_evidence'], unmappedEvidence=missing,
                           abstention=q['question_type'] == 'hallucination', retrievalLabelGranularity='turn-both-speakers-or-file'))
    return cases, labels, assets


def longmem_records(q):
    if not len(q['haystack_session_ids']) == len(q['haystack_dates']) == len(q['haystack_sessions']):
        raise ValueError('LongMemEval session/date alignment mismatch')
    counts = Counter(q['haystack_session_ids'])
    seen = Counter()
    records, evidence = [], []
    for session, date, turns in zip(q['haystack_session_ids'], q['haystack_dates'], q['haystack_sessions']):
        occurrence = seen[session] if counts[session] > 1 else None
        seen[session] += 1
        for i, turn in enumerate(turns):
            source = f'{session}:{i}'
            text = f"{turn['role'].title()} ({date}): {turn['content']}"
            records.append(record('longmemeval-v1-s', q['question_id'], source, session, date,
                                  turn['role'], text, occurrence=occurrence))
            if turn.get('has_answer'):
                evidence.append(source)
    return records, evidence


def prepare_longmem(root):
    path = root / 'longmemeval_s_cleaned.json'
    if digest(path) != LONGMEM_SHA:
        raise ValueError('LongMemEval full asset SHA-256 mismatch')
    rows = json.loads(path.read_text())
    categories = sorted({r['question_type'] for r in rows})
    chosen = [min((r for r in rows if r['question_type'] == cat and not r['question_id'].endswith('_abs')),
                  key=lambda r: r['question_id']) for cat in categories]
    chosen.append(min((r for r in rows if r['question_id'].endswith('_abs')), key=lambda r: r['question_id']))
    cases, labels = [], []
    for q in chosen:
        case_id = 'longmemeval-v1-s/' + q['question_id']
        records, evidence = longmem_records(q)
        cases.append(dict(id=case_id, benchmark='longmemeval-v1-s', category='abstention' if q['question_id'].endswith('_abs') else q['question_type'],
                          personaID=q['question_id'], question=q['question'], questionDate=q['question_date'], records=records))
        labels.append(dict(caseID=case_id, expectedAnswer=q['answer'], supportingSourceIDs=evidence,
                           supportingSessionIDs=q['answer_session_ids'], abstention=q['question_id'].endswith('_abs'),
                           retrievalLabelGranularity='turn-and-session'))
    return cases, labels, [dict(path=path.name, bytes=path.stat().st_size, sha256=LONGMEM_SHA)]


def combine(rhelm, longmem):
    """Freeze R0,L0,R1,L1 order without changing original cases or labels."""
    rc, rl, ra = rhelm
    lc, ll, la = longmem
    if len(rc) != 7 or len(lc) != 7 or len(rl) != 7 or len(ll) != 7:
        raise ValueError('Combined frozen pilot requires exactly seven cases per benchmark')
    cases = [case for pair in zip(rc, lc) for case in pair]
    labels = [label for pair in zip(rl, ll) for label in pair]
    assets = [dict(benchmark='rhelm', **a) for a in ra] + [dict(benchmark='longmemeval-v1-s', **a) for a in la]
    return cases, labels, assets


def validate_cases(cases):
    if len({c['id'] for c in cases}) != len(cases):
        raise ValueError('Duplicate case identity')
    for case in cases:
        records = case['records']
        if len(records) > 30000:
            raise ValueError(f"History exceeds app record bound: {case['id']}")
        if len({r['id'] for r in records}) != len(records):
            raise ValueError(f"Duplicate canonical record IDs: {case['id']}")
        references = defaultdict(list)
        for row in records:
            references[row['sourceID']].append(row)
        for source, occurrences in references.items():
            if len(occurrences) <= 1:
                continue
            keys = [r.get('sourceOccurrence') for r in occurrences]
            if None in keys or len(set(keys)) != len(keys) or len({r['sessionID'] for r in occurrences}) != 1:
                raise ValueError(f"Unqualified repeated upstream source mapping: {case['id']}/{source}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cache', required=True, type=Path)
    p.add_argument('--benchmark', choices=['rhelm', 'longmemeval', 'combined'], required=True)
    p.add_argument('--fetch-rhelm', action='store_true')
    args = p.parse_args()
    root = args.cache.expanduser().resolve()
    repo = Path(__file__).resolve().parents[2]
    if root == repo or repo in root.parents:
        p.error('Dataset and generated inputs must stay outside the repository')
    root.mkdir(parents=True, exist_ok=True)
    if args.benchmark == 'combined':
        cases, labels, assets = combine(prepare_rhelm(root, args.fetch_rhelm), prepare_longmem(root))
    elif args.benchmark == 'rhelm':
        cases, labels, assets = prepare_rhelm(root, args.fetch_rhelm)
    else:
        cases, labels, assets = prepare_longmem(root)
    validate_cases(cases)
    out = root / 'prepared'
    out.mkdir(exist_ok=True)
    for kind, value in [('inputs', dict(schemaVersion=1, protocolID=PROTOCOL, cases=cases)),
                        ('labels', dict(schemaVersion=1, protocolID=PROTOCOL, labels=labels))]:
        (out / f'{args.benchmark}-{kind}.json').write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    manifest = dict(protocolID=PROTOCOL, benchmark=args.benchmark, sourceRevision=({'rhelm': RHELM_REV, 'longmemeval-v1-s': LONGMEM_REV} if args.benchmark == 'combined' else RHELM_REV if args.benchmark == 'rhelm' else LONGMEM_REV),
                    selection='lexicographically first question ID per category; RHELM first canonical persona; LongMemEval adds first abstention; combined alternates R0,L0,R1,L1 without changing cases',
                    license=({'rhelm': 'CC-BY-4.0', 'longmemeval-v1-s': 'MIT'} if args.benchmark == 'combined' else 'CC-BY-4.0' if args.benchmark == 'rhelm' else 'MIT'),
                    status='prepared-not-run', officialJudge='unavailable-no-authorized-hosted-inference',
                    inputSHA256=digest(out / f'{args.benchmark}-inputs.json'), labelSHA256=digest(out / f'{args.benchmark}-labels.json'),
                    cases=[dict(id=c['id'], category=c['category'], records=len(c['records']), inputBytes=sum(len(r['text'].encode()) for r in c['records'])) for c in cases], assets=assets)
    (out / f'{args.benchmark}-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k:v for k,v in manifest.items() if k != 'assets'}))


if __name__ == '__main__':
    main()
