#!/usr/bin/env python3
"""Score retrieval labels offline; require explicit review for answer semantics.

This does not run, emulate or claim equivalence to the published LLM judges.
Annotation precision is not proof that unlabelled sources are irrelevant.
"""
import argparse
from collections import Counter
import json
import hashlib
from pathlib import Path
import re


def group_source(benchmark, source):
    if benchmark == 'rhelm' and re.match(r'^\d{4}-\d{2}-\d{2}:\d+:(user|assistant)$', source):
        return source.rsplit(':', 1)[0]
    return source


def metrics(expected, found):
    if not expected:
        return dict(expected=0, retrieved=len(found), recall=None, annotationPrecision=None,
                    note='No positive labels; answer abstention requires separate semantic review')
    correct = len(expected & found)
    return dict(expected=len(expected), retrieved=len(found), matched=correct,
                recall=correct / len(expected), annotationPrecision=correct / len(found) if found else 0)


def score(inputs, labels, results):
    truth = {x['caseID']: x for x in labels['labels']}
    rows = (results.get('results', results.get('rows')) if isinstance(results, dict) else results)
    if rows is None:
        raise ValueError('No native results array')
    outputs = {x['caseID']: x for x in rows}
    if len(outputs) != len(rows):
        raise ValueError('Duplicate result IDs')
    expected_cases = {c['id'] for c in inputs['cases']}
    if set(outputs) - expected_cases or set(truth) != expected_cases:
        raise ValueError('Case IDs do not match frozen inputs')
    scored = []
    for case in inputs['cases']:
        row = outputs.get(case['id'])
        label = truth[case['id']]
        if row is None:
            scored.append(dict(caseID=case['id'], status='not-run', answerAccuracy=None))
            continue
        if row['status'] in {'budget-not-run', 'not-run'}:
            scored.append(dict(caseID=case['id'], category=case['category'], status=row['status'],
                               retrieval=None, candidateRetrieval=None, answerAccuracy=None,
                               measurement='not-run'))
            continue
        if row['status'] not in {'completed', 'runtime-error', 'budget-timeout'}:
            raise ValueError('Unknown run status')
        uuid_map = {r['id'].lower(): r['sourceID'] for r in case['records']}
        sources = set(row.get('retrievedSourceIDs', []))
        for id_ in row.get('retrievedUUIDs', []):
            if id_.lower() not in uuid_map:
                raise ValueError('Returned source UUID is not in this isolated case')
            sources.add(uuid_map[id_.lower()])
        allowed = {r['sourceID'] for r in case['records']}
        if sources - allowed:
            raise ValueError('Returned source is not in this isolated case')
        expected = {group_source(case['benchmark'], x) for x in label['supportingSourceIDs']}
        found = {group_source(case['benchmark'], x) for x in sources}
        retrieval_measured = row.get('retrievalCompleted', row['status'] == 'completed' or bool(sources))
        candidates = set(row.get('candidateSourceIDs', []))
        if candidates - allowed:
            raise ValueError('Candidate source is not in this isolated case')
        candidate_measured = row.get('rankingCompleted', bool(candidates))
        score_row = dict(caseID=case['id'], category=case['category'], status=row['status'],
                         retrieval=metrics(expected, found) if retrieval_measured else None,
                         candidateRetrieval=metrics(expected, {group_source(case['benchmark'], x) for x in candidates}) if candidate_measured else None,
                         answerAccuracy=None,
                         answerReview=('required-manual-not-official-judge' if row['status'] == 'completed' else 'not-scoreable-incomplete-run'),
                         caseScoreEligible=row['status'] == 'completed',
                         measurement='complete-run' if row['status'] == 'completed' else 'completed-stage-diagnostics-only',
                         seconds=row.get('seconds'),
                         unmappedEvidence=label.get('unmappedEvidence', []))
        if 'supportingSessionIDs' in label and retrieval_measured:
            sessions = {r['sourceID']: r['sessionID'] for r in case['records']}
            score_row['sessionRetrieval'] = metrics(set(label['supportingSessionIDs']), {sessions[s] for s in sources})
        scored.append(score_row)
    benchmark_by_id = {c['id']: c['benchmark'] for c in inputs['cases']}
    summaries = {}
    for benchmark in sorted(set(benchmark_by_id.values())):
        subset = [r for r in scored if benchmark_by_id[r['caseID']] == benchmark]
        summaries[benchmark] = dict(denominator=len(subset), statusCounts=dict(Counter(r['status'] for r in subset)))
    return dict(protocolID=inputs['protocolID'], denominator=len(scored), benchmarkSummaries=summaries,
                statusCounts=dict(Counter(r['status'] for r in scored)), rows=scored,
                officialAnswerScore=None, officialJudgeStatus='not-run-no-authorized-hosted-inference',
                interpretation='Fixed subset app-pipeline retrieval diagnostics; not a full benchmark score')


def validate_run_identity(input_bytes, labels, results):
    inputs = json.loads(input_bytes)
    if not isinstance(results, dict):
        raise ValueError('Native result metadata is required')
    if results.get('inputSHA256') != hashlib.sha256(input_bytes).hexdigest():
        raise ValueError('Native result input SHA-256 does not match supplied inputs')
    protocol = inputs.get('protocolID')
    if not protocol or labels.get('protocolID') != protocol or results.get('protocolID') != protocol:
        raise ValueError('Input, label and native result protocols differ')
    return inputs


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ['inputs', 'labels', 'results', 'output']:
        p.add_argument('--' + key, type=Path, required=True)
    args = p.parse_args()
    input_bytes = args.inputs.read_bytes()
    label_bytes = args.labels.read_bytes()
    labels = json.loads(label_bytes)
    results = json.loads(args.results.read_text())
    inputs = validate_run_identity(input_bytes, labels, results)
    report = score(inputs, labels, results)
    report['inputSHA256'] = results['inputSHA256']
    report['labelSHA256'] = hashlib.sha256(label_bytes).hexdigest()
    report['modelSHA256'] = results.get('modelSHA256')
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f"Scored {report['denominator']} frozen cases; semantic answers need review")


if __name__ == '__main__':
    main()
