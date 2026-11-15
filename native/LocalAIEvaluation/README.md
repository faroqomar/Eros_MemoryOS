# Local AI evaluation support

This app-owned Swift package supports the isolated MemoryOS AI lab. It has no external dependencies, network client, model weights, production-record access, Wax implementation or Cactus implementation. The keyword index is a lexical control. It cannot establish semantic retrieval or model quality.

`AIEvaluationCore` owns the fictional corpus, retrieval/text adapter contracts, sequential runner, batch use case and version 2 JSON report. The decoder also accepts version 1 reports. `AIEvaluationPresentation` owns observable view state and calls an injected `EvaluationRunning` use case. The composition root supplies actual adapters. Keep SDK imports in separate integration targets when adding a reviewed SDK.

The corpus contains 14 fictional sources and 15 cases. It covers English, Arabic, Iraqi Arabic, mixed names/text, dates, corrections, negation, tentative plans, uncertain sarcasm, missing evidence and untrusted instructions. Expected source IDs and review guidance remain in the evaluator. Each text runtime receives the same full fictional corpus and the same question. It does not receive the answer key. Retrieval and generation measurements are separate.

Run the host control smoke:

```sh
swift test --package-path native/LocalAIEvaluation -c release
swift run --package-path native/LocalAIEvaluation -c release ai-evaluation \
  --source-identity <commit-or-source-manifest> > control-smoke.json
```

The CLI emits an envelope containing `report` and `selectionBlockers`. It labels the environment as `host` and purpose as `smoke`. The caller must record the actual toolchain and build command alongside the output. Missing runtime adapters produce blocked generation results. Missing telemetry stays absent rather than becoming zero. The JSON report does not assign a component winner.

`EvaluationReport.selectionBlockers` lists evidence gaps. An empty list would not establish acceptance. Final component selection still requires repeated controlled physical-iPhone comparisons, the task's numeric limits, human answer review and owner acceptance. Retrieval source recall measures evidence coverage, not answer truth. Inspect language, uncertainty, dates, source citations and behavior before entering a human quality review.

`CandidateConfiguration.scope` separates retrieval, text and combined experiments. Unrequested work is `notApplicable`; a missing required adapter is `blocked`. Text-only experiments still receive the complete shared corpus, so retrieval quality cannot change their input.

`RunEvaluationComparison` injects adapter factories, measurements and a report writer through core-owned protocols. It retains the same adapter for one cold suite and five warm suites. Every suite rebuilds its derived index; text requests reuse loaded weights with a fresh context. Each completed suite is saved before the next starts. Reports carry batch/repetition metadata and index build time. The use case releases adapters on completion, failure or cancellation. It stops after one wholly unavailable suite rather than saving six identical failures.

The runner propagates cancellation, rejects unknown/duplicate/excess source IDs and invalid token/timing measurements, rebuilds indexes from app-owned source values and retains generated text for review. The ViewModel permits one active run and reports completed cases. After cancellation, it waits for the use case to return and rejects late results before allowing a rerun.

`scripts/summarize-local-ai.py` reads saved reports or CLI report envelopes and writes a separate summary. It keeps environments, source identities and batches separate, rejects duplicate suite repetitions, records each raw input hash and uses nearest-rank p95. Warm statistics use repetitions 1–5. Token throughput includes the full request duration. It does not grade generated prose or change original reports. Simulator battery and physical heat remain absent.

The resumed comparison passes `--suite-fixture` to the summary tool with the actual JSONEncoder export of `EvaluationSuite.fictional()`. It verifies case order and records fixture hashes, top-1 evidence coverage, no-evidence abstention, cold/warm rebuild timings and per-case warm statistics. Memory fields retain each collector method; host RSS is not relabeled as Simulator phys_footprint. See `native/verification/local-ai-step1/resume/comparison-inputs.json` for included batches and the preserved timing exclusion.

## Native Simulator lab

Open `native/MemoryOSAILab.xcodeproj` for the experiment. It owns the lab and its UI-test scheme. The main `native/MemoryOS.xcodeproj` uses only `LocalMemory`; opening or building the Capture app does not require experimental SDK artifacts.

Prepare the generated Cactus, llama and Wax XCFrameworks and Wax resource receipt first. Follow the [Cactus](../LocalCactusEvaluation/README.md), [llama](../LocalTextEvaluation/README.md) and [Wax binary](../LocalAIIntegrations/BinaryIntegration/README.md) instructions. The reviewed binaries contain arm64 slices only. Pass the architecture for the entire package graph; a target-level setting does not constrain Xcode's generated SwiftPM targets.

```sh
xcodebuild -project native/MemoryOSAILab.xcodeproj -scheme MemoryOSAILab \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build analyze
```

Use a recorded `LAB_SOURCE_IDENTITY` build setting for evaluation runs. The default `unrecorded` identity is suitable only for setup checks. Install the local model files into the lab's separate `Documents/EvaluationModels` directory before model evaluation. The lab does not download them at launch.
