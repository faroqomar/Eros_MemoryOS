# Step 2 provenance and measurement review

Date: 2026-11-15. Reviewer: fresh scoped provenance verifier. Scope: checklist group 4, C40 Simulator experiment. This review does not certify a phone, production model, distribution, or release.

**Result: PASS for the retained dependency and experiment evidence.** Main-agent fixes and the independent behavior review identify the final runtime source separately. The measured Step 1 source remains `b44661c8b96b5e54457dd3918a5eced91c856dcc90d03b08f1b0dfbf8c595e00`.

> 🧠 **From Hindsight memory (Local AI phone comparison — checklist group 4 Step 1)** — The recorded experiment completed on Simulator and keeps production adoption separate.

I used the project-scoped wrapper recall before examining files, then checked these historical claims against actual files and immutable raw bytes. No model, runtime, or provider was selected for production by this review.

## Findings and corrections

1. **Closed documentation finding:** the decision-register A03 row and llama adapter README described missing/unlinked integration and three tests after the real integration had run. The main agent corrected them. I read the resulting A03 row and README: they now identify actual CPU/Accelerate execution, five Step 1 contracts, the new Step 2 input-validation regression, and the distinction from phone evidence. The task's resumed header now says completed checkpoint. Historical failed attempts remain retained.
2. **Scope clarification:** iOS 18 runtime validation remains unperformed. The applicable experiment runs on the explicitly selected iOS 27.2 Simulator. The primary verifier/main agent must retain minimum-OS compatibility as a separate future gap, with no iOS 18 runtime claim. Neither compilation nor the present evidence establishes that compatibility.
3. **Cleanup preservation:** the old MLX derived build contains seven unique log/configuration files; the temporary Wax consumer has four configuration/copied-source files. Preserve their exact bytes before removing generated caches. Inspection alone does not complete cleanup. The main agent owns deletion and the primary verifier owns its focused recheck.

No unresolved dependency, raw-report integrity, summary-calculation, or attribution defect was found in this scope.

## Verification matrix

| Criterion | Result | Direct evidence |
| --- | --- | --- |
| Measured runtime identity | PASS | All 99 files in the retained source manifest matched at the initial independent audit. Recomputed compact sorted-map digest equals `b446…5e00`. [Integrity receipt](provenance-integrity.json). Later intentional Step 2 changes need their own final manifest; they do not rewrite old reports. |
| Raw input selection | PASS | All 31 selected file hashes, selected batch IDs, source identities, ordered case IDs and empty `manualReviews` match actual bytes. Total 465 rows: 450 completed operations and 15 explicit MLX-unavailable rows. The contaminated 1.7B timing batch is excluded; its original reports remain separate. |
| Metric calculations | PASS | Independently recomputed warm medians, nearest-rank p95, throughput, retrieval sets/rank/abstention and process/storage statistics match saved values. Full regeneration through the retained summarizer also produces identical JSON. [Integrity receipt](provenance-integrity.json); [summarizer](../../../scripts/summarize-local-ai.py). |
| Cold/warm and measurement interpretation | PASS | One cold plus five warm suites per supported candidate, fresh index/context, retained weights, 75 warm requests. `LabProcessMeasurement` samples `TASK_VM_INFO.phys_footprint` every 100 ms. A fresh measurement instance enters each suite. These are whole-process sampled peaks. Throughput includes preparation/prefill; logical files exclude shared bundle overhead. No cache flush, phone battery, temperature or incremental SDK memory claim. [Measured report](../../../docs/evidence/local-ai-2026-11-14/resume-summary.md). |
| Quality attribution and repetition | PASS | Raw review hashes match; separate builder-AI counts are 1/15 for llama 0.6B, 7/15 for llama 1.7B and 1/15 for Mac MLX 0.6B. All six outputs for each llama case match byte-for-byte. Repetition is not 90 independent quality examples. No human review was inserted into raw reports. |
| Canonical packages and pins | PASS | Five Wax and twelve MLX lockfile pins match recorded original URLs, revisions and genuine checkout Git HEADs. Lockfile hashes match final canonical receipts. MLX uses effective yyjson 0.13.0. [Dependency receipt](dependency-integrity.json). |
| SDK binaries and patches | PASS | Three llama binaries, twelve Cactus artifact files, three Wax binaries and recorded Wax resources match actual hashes. Both retained patches match receipts. The llama build uses exact upstream source and CPU/Accelerate, with no engine algorithm patch. [Dependency receipt](dependency-integrity.json). |
| Wax canonical/source equivalence | PASS | I compared 1,457 snapshot files with genuine canonical checkout bytes. Only the two retained desktop-guard files differ. No SDK manifest difference or extra source difference appears. [Source recheck](source-equivalence-recheck.json). |
| Ownership and composition | PASS | The Xcode project consumes actual local adapter packages/binary SDK products. Core/UI contain app-owned code; upstream implementation remains external source or generated ignored artifacts. The Wax binary excludes core objects and exposes app-owned values; its exact-source/compiler dependency remains explicit. Package manifests preserve original source URLs and reviewed pins. |
| Licenses and offline claims | PASS for personal experiment | Seven Wax notices and 24 canonical MLX dependency notice/license files match hashes; Cactus and llama license copies match binary/source receipts. Cactus retains its custom eligibility limits, separate from the model's Apache declaration. Actual host network-denied execution receipts remain separate from conservative raw `offlineConfirmed=false` and uninstrumented Simulator networking. No release clearance is claimed. |
| Screenshot provenance | PASS for retained Step 1 evidence | All eleven retained capture hashes match their manifest and measured source identity. These remain historical Step 1 screenshots. Main-agent fresh Step 2 captures are separate evidence. |
| Cleanup | Inspection complete; primary recheck pending | [Candidate inventory](provenance-cleanup-candidates.json) identifies generated files and exact unique bytes to preserve. Canonical Git metadata, current builds, models, original sources and retained evidence remain outside candidate deletion scope. |
| Physical device cost | Outside C40 experiment | No physical speed, memory, battery, heat, or deployment claim. Phone readiness remains separate. |

## Preservation notes

The old MLX derived folder holds 2,721,808,801 logical regular-file bytes. It contains generated products/modules/caches, seven log/workspace-state files, and no Git metadata. The old Wax verification folder holds 878,396,669 logical regular-file bytes, four non-build configuration/copied-source files, six generated build symlinks, and no Git metadata. The extra empty SwiftPM scratch directories contain only 219 and 223 bytes of markers/lock files. The inspected Python bytecode folder holds 38,873 bytes. These counts describe inspection time; the main cleanup receipt records actual removed bytes and retained exceptions.

No healthy download was stopped, source changed, file deleted, commit made, or benchmark run by this verifier. Hash and metadata checks reused unchanged measured evidence. The main agent retains model manifests and full runtime-verification receipts rather than adding a redundant two-gigabyte model read during UI work.
