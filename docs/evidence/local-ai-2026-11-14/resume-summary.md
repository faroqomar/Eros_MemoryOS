# Local AI evaluation — resumed Step 1 results

Date: 2026-11-15. Scope: owner-selected Simulator under C39–C40. Historical builder checkpoint; independent Step 2 had not started at this capture. Current [task status](../../tasks/2026-11-14-local-ai-phone-evaluation.md) records the later review, repairs and unresolved Dynamic Type gate.

All requested model and SDK artifact downloads finished and passed their complete hashes. Wax, Cactus, llama.cpp and MLX now execute real SDK code. Required canonical dependency checks and the affected model tests pass. Earlier stopped downloads, format errors, setup corrections and provisional results remain recorded.

## Shared experiment

- iPhone 18 Pro Simulator, iOS 27.2, on Apple M1 Pro, 16 GiB, macOS 27.2.1. Release source identity `b44661c8b96b5e54457dd3918a5eced91c856dcc90d03b08f1b0dfbf8c595e00`.
- Fourteen fictional originals and fifteen cases: Arabic, Iraqi Arabic, English, names, mixed text, corrections, uncertainty, no evidence and imported instructions. Original Capture/SQLite data is untouched.
- Control, Wax, Cactus, Qwen3-0.6B and Qwen3-1.7B each complete six suites: 90 case operations per configuration. MLX records fifteen explicit unavailable cases on Simulator. Total selected results: 465 in 31 immutable reports.
- One fresh app/model session plus five warm suites. Each index is rebuilt; text contexts reset while weights stay loaded. Warm summary uses 75 requests. Per-case five-repeat medians, nearest-rank p95 and ranges remain in the JSON.
- The same full source corpus goes to every text model. Ground-truth IDs and review guidance do not enter its prompt. Retrieval and generation are separate arms; no combined production RAG flow is certified.
- CPU settings: four llama decode/batch threads and four Cactus workers. Accelerate/OS scheduling can differ. Text context 2048, greedy temperature 0, cap 256, nonthinking template; greedy sampling does not use the recorded seed.
- Cold means a fresh app/model session including verification and load. OS file caches were not flushed; staging and checksum reads can warm them.
- Memory is whole-process TASK_VM_INFO phys_footprint sampled every 100 ms, not incremental SDK RAM or host RSS. Model/index bytes exclude the shared lab app/SDK bundle. Battery and physical heat remain absent. The installed lab bundle with all linked experimental SDKs is 24.9 MiB; it is shared overhead, not a per-provider estimate. [Storage inventory](../../../native/verification/local-ai-step1/resume/storage-inventory.json).

The [input selection](../../../native/verification/local-ai-step1/resume/comparison-inputs.json), [raw reports](../../../native/verification/local-ai-step1/resume/simulator-reports), [summary](../../../native/verification/local-ai-step1/resume/simulator-summary.json), [exported fixture](../../../native/verification/local-ai-step1/resume/fictional-suite.json) and [source manifest](../../../native/verification/local-ai-step1/resume/source-hashes.json) preserve the evidence. One earlier 1.7B batch is excluded from timing because a dependency build overlapped it; its answers remain unchanged. The real cancel-and-rerun flow passes. [Incident receipt](../../../native/verification/local-ai-step1/resume/benchmark-interference.json).

## Retrieval on Simulator

| Configuration | Warm median / p95 | Sampled process peak | Model/index files | Exact expected sets per suite | Relevant first / evidence cases | No-evidence abstention |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Keyword control | 0.058 / 0.093 ms | 40.5 MiB | 0.0 MiB | 13/15 | 84/84 | 6/6 |
| Wax lexical | 1.816 / 2.786 ms | 55.0 MiB | 8.1 MiB | 10/15 | 84/84 | 0/6 |
| Cactus last-token | 80.102 / 104.325 ms | 113.8 MiB | 408.7 MiB | 0/15 | 84/84 | 0/6 |

All fourteen evidence-present questions rank a relevant source first in every repetition for all three configurations. The control is an in-memory lexical baseline, not a production engine. Wax returns fewer extras than Cactus in this small corpus. Both provider configurations return unrelated sources for the passport question. This corpus does not establish a semantic-retrieval advantage over lexical matching.

| Preparation | First index build, including cold setup | Five warm rebuilds: median / p95 |
| --- | ---: | ---: |
| Control | 0.0045 s | 0.0002 / 0.0002 s |
| Wax | 0.1395 s | 0.0244 / 0.0307 s |
| Cactus | 2.0419 s | 1.0408 / 1.0909 s |

Cactus cold preparation includes full file verification, model loading and embedding/indexing; its load cost is not isolated from that first rebuild. The v1.14 native mean-pooling default was incorrect for Qwen3 Embedding. The retained corrected export selects the last unpadded native hidden-state row and applies L2 normalization. The threshold stays 0.35 and top-k stays 3. Earlier mean-pooling results are preserved. [Configuration and contracts](cactus-resume/summary.md).

## Text on Simulator

| Model and runtime | Warm first token: median / p95 | Warm total: median / p95 | Median end-to-end output tokens/s | Sampled process peak | Model file |
| --- | ---: | ---: | ---: | ---: | ---: |
| llama.cpp · Qwen3-0.6B Q4_K_M | 1.063 / 1.380 s | 1.476 / 2.438 s | 20.81 | 700.7 MiB | 378.3 MiB |
| llama.cpp · Qwen3-1.7B Q4_K_M | 2.597 / 2.900 s | 4.330 / 8.001 s | 17.93 | 1404.8 MiB | 1056.1 MiB |

Token throughput includes prompt preparation/prefill and output generation. It is not a decode-only kernel rate. All 90 answers per model complete, and each model produces byte-identical text for each case across its six suites. These are repeatability observations, not independent quality samples.

| Model | One cold preparation | One cold first token | One cold total request |
| --- | ---: | ---: | ---: |
| Qwen3-0.6B | 0.985 s | 2.691 s | 2.841 s |
| Qwen3-1.7B | 2.396 s | 5.807 s | 6.347 s |

## Builder quality review

| Configuration | Facts/meaning | Question language | Overall, including citations |
| --- | ---: | ---: | ---: |
| llama.cpp · Qwen3-0.6B | 7/15 | 10/15 | 1/15 |
| llama.cpp · Qwen3-1.7B | 8/15 | 9/15 | 7/15 |
| MLX · Qwen3-0.6B 4-bit, Mac only | See linked review | See linked review | 1/15 |

These are builder-AI judgments, not human review or owner acceptance. Raw reports keep empty manualReviews. Arabic/Iraqi questions require an Arabic answer; MSA is acceptable. Facts must preserve names, numbers, corrections and uncertainty. Citations must identify the expected evidence without unrelated IDs. The no-evidence answer does not need a citation.

The 1.7B model cites sources more reliably and preserves the complete mixed Unicode artist name. It still fails all three Iraqi Arabic examples. Failures include treating `گال` as a name, confusing tentative plans, contradictory reservation cancellation, overstated sarcasm and uncertainty about whether imported text can change permissions. The Arabic birthday answer substitutes the wrong surname. Neither tested text model meets the current quality bar.

Reviews and repeatability: [0.6B review](../../../native/verification/local-ai-step1/resume/llama-qwen06-host-builder-review.json), [0.6B equivalence](../../../native/verification/local-ai-step1/resume/qwen06-output-equivalence.json), [1.7B review](../../../native/verification/local-ai-step1/resume/llama-qwen17-simulator-builder-review.json), [1.7B equivalence](../../../native/verification/local-ai-step1/resume/qwen17-output-equivalence.json), [canonical MLX review](../../../native/verification/local-ai-step1/resume/mlx-host-canonical-builder-review.json).

MLX cannot evaluate this model on iOS Simulator under the pinned upstream platform requirements. Its native availability path records that limitation before any model/GPU work. Actual Mac GPU execution and OS-network-denied output remain separate; MLX host GPU timing is not compared with Simulator CPU timing. The corrected canonical graph uses yyjson 0.13.0 selected by the effective Swift 6.1 manifest. [Final MLX checks](../../../native/verification/local-ai-step1/resume/mlx-final-verification.json).

## Experimental component decision

- Use llama.cpp CPU/Accelerate for the current Simulator text-runtime baseline. MLX remains a separately tested Mac/supported-device candidate.
- Use Wax lexical as the low-cost provider baseline for the next experiment. Keep corrected Cactus replaceable for semantic experiments; the present fixture shows no retrieval-quality advantage and more extra results. This is a builder experiment recommendation, not main-app adoption.
- Keep Qwen3-1.7B as the stronger citation/reference model among these tested variants. Do not adopt either text model for personal memory use: Arabic/Iraqi accuracy, names and permission interpretation still fail.
- Keep canonical originals, stable IDs, corrections and source links under the existing app-owned store. Provider indexes remain rebuildable derivatives. No main Capture source or store schema changed.
- Production component selection remains open because the measured quality requirements fail. Physical iPhone cost, human review and independent Step 2 remain separate future evidence; they do not turn this completed Simulator experiment into an unfinished download task.

## Validation and captures

- Core/presentation: 32 test functions; real llama.cpp asset/native/settings contracts: 5; Wax canonical and real-binary consumer contracts: 5 unchanged definitions in each configuration; Cactus real-model contracts: 11 normal and OS-network-denied; MLX canonical contracts: 7 including real GPU/cancel/rerun; Simulator availability: one 15-case contract.
- Native lab Release build/static analysis, copied-resource hash enforcement and actual source-identified run/cancel/results pass. Original Capture app Release build/analysis passes with unchanged app/store sources.
- Canonical original-URL locks are retained for Wax and MLX. Full source/patch/binary provenance and effective-manifest checks are in [Wax handoff](resume-wax/SUPPORTED-CONFIGURATION.md), [Cactus handoff](cactus-resume/summary.md) and the MLX index above.
- Dark English/Arabic captures show actual Simulator states. A fresh inner-switch reference with a 200 ms hold enables Arabic and mirrored RTL. Earlier presses did not land; the failed English capture is labeled as such. [Capture manifest](../../../native/verification/local-ai-step1/resume/screenshots/manifest.json).

No independent Step 2 pass, merge or release is claimed. These measurements describe this Simulator session.
