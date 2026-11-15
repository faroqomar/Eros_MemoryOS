#!/usr/bin/env python3
"""Summarize saved evaluation reports without changing raw records or grading prose."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import statistics


def stats(values):
    values = sorted(value for value in values if value is not None)
    if not values:
        return None
    if any(not math.isfinite(value) or value < 0 for value in values):
        raise ValueError("Measurements must be finite and nonnegative")
    return {"count": len(values), "median": statistics.median(values),
            "p95NearestRank": values[math.ceil(len(values) * .95) - 1],
            "minimum": values[0], "maximum": values[-1]}


def summarize(paths, fixture_path=None):
    fixture = json.loads(fixture_path.read_bytes()) if fixture_path else None
    expected = {item['id']: set(item['expectedSourceIDs']) for item in fixture['cases']} if fixture else {}
    groups = defaultdict(list)
    seen = set()
    for path in paths:
        data = path.read_bytes()
        saved = json.loads(data)
        # Host collectors retain their extra measurement receipt around the same core report.
        report = saved.get("report", saved)
        if report.get("formatVersion") not in (1, 2):
            raise ValueError(f"Unsupported report format: {path}")
        context = report["context"]
        key = (report["configuration"]["id"], context["environment"],
               context["sourceIdentity"], context.get("batchID", str(path)))
        repetition = context.get("repetition", 0)
        if (key, repetition) in seen:
            raise ValueError("Duplicate batch repetition; preserve one canonical input per suite")
        seen.add((key, repetition))
        groups[key].append((path, hashlib.sha256(data).hexdigest(), report))
    output = []
    for key, entries in sorted(groups.items()):
        entries.sort(key=lambda entry: entry[2]["context"].get("repetition", 0))
        reports = [entry[2] for entry in entries]
        if fixture and any(report['suiteID'] != fixture['id'] or
                           [item['id'] for item in report['results']] != [item['id'] for item in fixture['cases']]
                           for report in reports):
            raise ValueError('Report cases differ from the exported canonical fixture')
        signatures = [(report["suiteID"], report["configuration"], report["settings"],
                       [result["id"] for result in report["results"]]) for report in reports]
        if any(signature != signatures[0] for signature in signatures):
            raise ValueError("A batch changed corpus, configuration, settings, or case order")
        all_cases = [result for report in reports for result in report["results"]]
        warm = [result for report in reports if report["context"].get("repetition", 0) > 0
                for result in report["results"]]
        cold = [result for result in all_cases if result.get("output", {}).get("wasColdLoad")]

        def measurements(cases):
            return {
                "retrievalSeconds": stats([item.get("searchSeconds") for item in cases]),
                "generationSeconds": stats([item.get("generationSeconds") for item in cases]),
                "requestToFirstTokenSeconds": stats([
                    item.get("output", {}).get("firstTokenSeconds") for item in cases]),
                "preparationSeconds": stats([
                    item.get("output", {}).get("preparationSeconds") for item in cases]),
                "endToEndOutputTokensPerSecond": stats([
                    item["output"]["generatedTokenCount"] / item["generationSeconds"]
                    for item in cases if item.get("output", {}).get("generatedTokenCount") is not None
                    and item.get("generationSeconds", 0) > 0]),
            }

        retrieval = [item for item in all_cases if item["retrievalStatus"] == "completed"]
        output.append({
            "candidateID": key[0], "environment": key[1], "sourceIdentity": key[2],
            "batchID": key[3], "context": reports[0]["context"],
            "configuration": reports[0]["configuration"], "settings": reports[0]["settings"],
            "recordedSuites": len(reports),
            "recordedRepetitions": [report["context"].get("repetition", 0) for report in reports],
            "inputs": [{"path": str(path), "sha256": digest} for path, digest, _ in entries],
            "retrievalStatuses": dict(Counter(item["retrievalStatus"] for item in all_cases)),
            "generationStatuses": dict(Counter(item["generationStatus"] for item in all_cases)),
            "outputsAtTokenCap": sum(item.get("output", {}).get("generatedTokenCount")
                                     == reports[0]["settings"]["maximumOutputTokens"]
                                     for item in all_cases),
            "exactSourceSetMatches": sum(item.get("exactSourceSetMatch") is True for item in retrieval),
            "completedRetrievalCases": len(retrieval),
            "evidencePresentRetrievalCases": sum(bool(expected[item['id']]) for item in retrieval) if fixture else None,
            "relevantSourceRankedFirst": sum(bool(expected[item['id']]) and bool(item['retrievedSourceIDs'])
                                            and item['retrievedSourceIDs'][0] in expected[item['id']]
                                            for item in retrieval) if fixture else None,
            "noEvidenceRetrievalCases": sum(not expected[item['id']] for item in retrieval) if fixture else None,
            "noEvidenceAbstentions": sum(not expected[item['id']] and not item['retrievedSourceIDs']
                                        for item in retrieval) if fixture else None,
            "meanSourceRecall": statistics.mean(item["sourceRecall"] for item in retrieval) if retrieval else None,
            "allCases": measurements(all_cases), "fiveWarmSuites": measurements(warm),
            "perCaseWarm": {case_id: measurements([item for item in warm if item['id'] == case_id])
                            for case_id in dict.fromkeys(item['id'] for item in warm)},
            "coldModelRequests": measurements(cold),
            "indexBuildSeconds": stats([report.get("indexBuildSeconds") for report in reports]),
            "coldIndexBuildSeconds": stats([report.get("indexBuildSeconds") for report in reports
                                            if report['context'].get('repetition', 0) == 0]),
            "warmIndexBuildSeconds": stats([report.get("indexBuildSeconds") for report in reports
                                            if report['context'].get('repetition', 0) > 0]),
            "reportedPeakMemoryBytes": stats([
                report["telemetry"].get("peakMemoryBytes") for report in reports]),
            "reportedStorageBytes": stats([
                report["telemetry"].get("storageBytes") for report in reports]),
            "measurementMethods": sorted({
                report["telemetry"].get("measurementMethod", "unrecorded")
                for report in reports}),
            "qualityReview": "No semantic pass is inferred. Review raw answers against the separate rubric.",
        })
    return {"formatVersion": 1,
            "fixture": {"path": str(fixture_path), "sha256": hashlib.sha256(fixture_path.read_bytes()).hexdigest()} if fixture_path else None,
            "method": "Nearest-rank p95; warm means suite repetitions 1-5. End-to-end output tokens/s includes prompt preparation and prefill. Cold means an explicit wasColdLoad=true. Read each group's measurementMethods: host RSS and simulator sampled phys_footprint are different measures. Groups keep environment, source identity and batch separate. Simulator results do not estimate phone battery or heat.",
            "groups": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--suite-fixture", type=Path)
    args = parser.parse_args()
    result = summarize(args.reports, args.suite_fixture)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"groups": len(result["groups"]), "output": str(args.output)}))


if __name__ == "__main__":
    main()
