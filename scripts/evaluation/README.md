# Published benchmark pilot preparation

This opt-in tooling uses public permitted data in an external evaluation cache. It never calls an inference or judge API. The native test harness owns actual app-pipeline execution. Frozen cases are engineering pilots, not complete benchmark scores or production acceptance.

## Pinned sources and rights

- RHELM data: `microsoft/RHELM` revision `d0e8e0cc7be6b7042819175ddef550d217c7c5a9`, [CC BY 4.0 dataset notice](https://huggingface.co/datasets/microsoft/RHELM/blob/d0e8e0cc7be6b7042819175ddef550d217c7c5a9/README.md). Attribute the RHELM authors/Microsoft; identify this app-specific import/retrieval and manual scoring as adaptations. [Upstream loader/evaluator](https://github.com/microsoft/RHELM/tree/5e170da7a2db96b4d222620a2aaaddb031cb8098/evaluation), MIT. Role/date prefixes, strict date cutoff and attachment-date association follow that loader; MemoryOS supplies its own chunking and retrieval.
- LongMemEval v1 cleaned S: revision `98d7416c24c778c2fee6e6f3006e7a073259d48f`, [MIT dataset notice](https://huggingface.co/datasets/xiaowu0162/longmemeval-cleaned/blob/98d7416c24c778c2fee6e6f3006e7a073259d48f/README.md). Full S asset: 277,383,467 bytes, SHA-256 `d6f21ea9d60a0d56f34a05b609c79c88a451d2ae03597821ea3d5a9678c3a442`. [Upstream notices and protocol](https://github.com/xiaowu0162/LongMemEval/tree/9e0b455f4ef0e2ab8f2e582289761153549043fc) remain applicable, including ShareGPT/UltraChat background provenance. No weights train on these records. This pilot uses S, not oracle evidence-only histories, M, or v2.
- PersonaMem v1 is an optional later axis, not part of this pilot: [MIT data card](https://huggingface.co/datasets/bowen-upenn/PersonaMem-v1/blob/a8076d5608c93ba2a28983cd78aa99b01a163ae7/README.md), [MIT code](https://github.com/bowen-upenn/PersonaMem/tree/d07e6ade22e85e0e5d562247323a9c3e07553226). Its choice accuracy and question-specific context end index require their own protocol. No PersonaMem history was fetched or scored here.

Restricted sets stay unavailable: [LoCoMo](https://github.com/snap-research/locomo/blob/3eb6f2c585f5e1699204e3c3bdf7adc5c28cb376/LICENSE.txt) is CC BY-NC 4.0; [LoCoMo-Plus](https://github.com/xjtuleeyf/Locomo-Plus/tree/059f4e3d38f7f1f96765e8e2cb7de3097551bffb) has no verified top-level reuse license and adapts that base. [PersonaMem-v3's data notice](https://github.com/bowen-upenn/PersonaMem-v3/blob/ad80a3b1b322129fb0585ead33b129a87bb4e387/LICENSE) excludes derived personas from its MIT code license and retains CC BY-NC 4.0. [RealCompanion](https://huggingface.co/datasets/Quislab/RealCompanion) requires reviewed individual access; agreement 4.4 bars product/service/commercial use, and 5.1 requires deleting evaluation indexes. No restricted corpus was fetched. Independently authored app cases are separate tests, not substitutes for those benchmarks.

## Frozen selection and isolation

Protocol `memoryos-published-pilot-2026-11-24-v1` selects seven RHELM items: lexicographically first question ID within each of its seven categories, using the first canonical persona, David_R._Ellis. This single-persona pilot cannot establish persona generalization. It imports every source strictly before each question date, including email and attachment sources. Same-day sources stay excluded, matching upstream. Question text and evidence labels remain unchanged.

LongMemEval selects the lexicographically first non-abstention ID within each of six categories, plus the first abstention ID. It preserves each released S history and dates in full; `has_answer` and `answer_session_ids` go only to the separate labels file. Each question's history is an independent persona instance. Never share indexes, chat state, or derived memory between cases. LongMemEval can repeat an upstream session ID at different released dates. Keep both occurrences and their exact text/date; qualify canonical UUIDs with the deterministic session-occurrence number while preserving original `sourceID`, `sessionID` and labels. `sourceOccurrence` records that mapping. Retrieval diagnostics group original upstream turn/session references; they do not claim occurrence-level precision for repeated references.

Input JSON contains `schemaVersion`, `protocolID`, and `cases`. Each case has `id`, `benchmark`, `category`, `personaID`, unchanged `question`, `questionDate`, and `records`. Records have stable UUID `id`, upstream `sourceID`, `sessionID`, original `date`, `speaker`, and source `text` with role/date framing. Expected answers and evidence selection never enter inference JSON. LongMemEval preserves its original date strings. App code must not silently substitute the current date.

The importer refuses empty or over-101,000-byte sources. The existing app retrieval adapter owns Unicode-safe passage splitting. Missing evidence mappings, context errors and unavailable categories remain visible. Do not replace them by easier questions or shortened/oracle histories.

## Execution and scoring

Run preparation with `python3 scripts/evaluation/prepare_published_pilot.py --cache EXTERNAL_PATH --benchmark rhelm --fetch-rhelm`, or `--benchmark longmemeval` after the pinned S asset finishes verification. Use `--benchmark combined` to reverify both corpora and write `combined-inputs.json`, `combined-labels.json` and `combined-manifest.json` with frozen alternating order and exact hashes. RHELM verifies each source against the pinned Git blob ID and byte count; LongMemEval verifies its full published LFS SHA-256. Generated inputs, labels, asset receipts and outputs stay outside Git and production resources. Retain required original notices with cached assets. The native harness must consume only the input file.

Freeze the exact model/hash, template, sampling, token limits, search mode and test-source digest before inference. Run serially through fixture import/indexing and the app-owned retrieval/filter/answer interfaces. The native harness injects frozen record snapshots through `LocalChatMemory.readRecords` and uses an isolated in-memory chat repository; this pilot does not verify persistent original-record ingestion or SQLite import. One separate synthetic smoke checks the pipeline before published-data runs; it contributes no published score.

The frozen resource budget is 1,800 seconds across all 14 published cases, with a 300-second maximum per case including ingestion/indexing, retrieval and generation. This engineering budget extends the earlier measured 10–33-second short-record retrieval allowance for full histories; it is not a published benchmark timing protocol. Before any published-data outputs, freeze combined order as R0,L0,R1,L1 through R6,L6 using the original prepared selections. RHELM retains its seven alphabetical category positions; LongMemEval retains its six alphabetical type positions followed by abstention. Combined preparation changes no question, source, identity or label. Alternating order avoids assigning the whole budget to one corpus first, although later strata can still remain unrun. Preserve all selected cases and histories; do not infer cross-benchmark accuracy or affordability from unequal completion.

Each request gets the smaller of 300 seconds and the shared remaining budget. Carry actual elapsed pilot execution, including cancellation/join and cleanup, between input files; downloads, builds and the separate smoke are outside this budget. Use a monotonic clock for elapsed time. When a deadline expires, cooperatively cancel and join the worker before cleanup or the next case. Record actual elapsed time and any cancellation overshoot; a cooperative timeout is not a hard real-time guarantee. A late or truncated response remains `budget-timeout`, incomplete and ineligible for answer scoring. Persist `budget-not-run` for cases never started. A timeout after a completed ranking/retrieval stage may retain that completed stage's diagnostics, with explicit completion flags; incomplete stages have no retrieval score.

Keep all 14 cases in the denominator and report attempted, completed, timed-out, failed and not-run counts by benchmark. A later expansion requires a stated new budget and separately labelled run, not selective retries or larger limits chosen from answer quality. A pipeline error may stop a run while preserving completed and missing rows.

`score_published_pilot.py` measures turn/file and session evidence retrieval. RHELM references a turn without distinguishing speaker, so either cited speaker satisfies that turn label; attachment labels are file-level here, not verified section coverage. Annotation precision does not prove unlabelled retrieved records irrelevant. No-positive-label cases require separate abstention review.

Published answer judges remain unrun. LongMemEval's script supports pinned GPT judges or a local 70B endpoint; neither is selected or authorized here. RHELM uses a hosted judge. Manual review must report its own protocol, reviewer, accuracy/omissions and unsupported assertions; it is not an official-equivalent score. Preserve LongMemEval category-specific semantics, including temporal off-by-one tolerance, usable preference evidence, updated-answer priority and explicit unanswerability. Keep citation support, attribution, stale facts and runtime latency separate. Translated/app-specific cases must have separate denominators.

## Native invocation

Use a final Release `build-for-testing` from the reviewed source, with strict analysis completed before that build. The current harness uses `.build/audio-app/Build/Products/MemoryOS_iphonesimulator27.2-arm64.xctestrun` and simulator `8843F67E-B2AF-4605-A3AE-25D168BD1B28`; verify those local identities before reusing them. Keep the reviewed Cactus assets in `MemoryOS.app/MemoryModels/Cactus`. Build once, then run the separate synthetic smoke before the published pilot. Do not run another model job concurrently.

After `--benchmark combined` produces and verifies the external inputs, the following preparation copies only the exact evaluation candidate into the test build and creates a sibling test-run configuration. Keeping the copy beside the original preserves Xcode's `__TESTROOT__` paths. It does not change project resources or the app's production model selection.

```sh
python3 - <<'PYCONFIG'
import hashlib, json, pathlib, plistlib, shutil
products = pathlib.Path('.build/audio-app/Build/Products')
cache = pathlib.Path('/Users/eros/Library/Caches/MemoryOS-AI-Evaluation')
prepared = cache / 'benchmarks/prepared'
inputs = prepared / 'combined-inputs.json'
manifest = json.loads((prepared / 'combined-manifest.json').read_text())
assert not (prepared / 'combined-native-results.json').exists(), 'Preserve prior results; choose a new output path'
assert hashlib.sha256(inputs.read_bytes()).hexdigest() == manifest['inputSHA256']
asset = cache / 'models/Qwen3.5-4B-Q4_K_M.gguf'
expected = '217002fa8008ef4fc6d548353a3aebef055a96e6ff8e0e2c0953ef8254a89c14'
with asset.open('rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == expected
assert asset.stat().st_size == 3032091584
model = products / 'Release-iphonesimulator/MemoryOS.app/MemoryModels' / asset.name
copy = model.with_suffix(model.suffix + '.verified-copy')
shutil.copy2(asset, copy)
copy.replace(model)
base = products / 'MemoryOS_iphonesimulator27.2-arm64.xctestrun'
config = plistlib.loads(base.read_bytes())
target = config['MemoryOSTests']
env = {k: v for k, v in target.get('EnvironmentVariables', {}).items()
       if not k.startswith('MEMORYOS_')}
env.update(MEMORYOS_TEST_LOCAL_MODEL='qwen35',
           MEMORYOS_PUBLISHED_INPUT=str(inputs),
           MEMORYOS_PUBLISHED_OUTPUT=str(prepared / 'combined-native-results.json'),
           MEMORYOS_PUBLISHED_SHA256=manifest['inputSHA256'],
           MEMORYOS_PUBLISHED_BUDGET_SECONDS='1800',
           MEMORYOS_PUBLISHED_CASE_SECONDS='300')
target['EnvironmentVariables'] = env
(products / 'MemoryOS-published-pilot.xctestrun').write_bytes(plistlib.dumps(config))
PYCONFIG
xcodebuild test-without-building \
  -xctestrun .build/audio-app/Build/Products/MemoryOS-published-pilot.xctestrun \
  -destination 'platform=iOS Simulator,id=8843F67E-B2AF-4605-A3AE-25D168BD1B28' \
  -parallel-testing-enabled NO \
  -only-testing:MemoryOSTests/PublishedMemoryBenchmarkTests \
  -resultBundlePath /tmp/memoryos-published-pilot.xcresult CODE_SIGNING_ALLOWED=NO
```

Use a new result-bundle/output path for a separately authorized run; preserve failed output instead of overwriting it. The synthetic smoke uses the same test with its separate input/hash/output and a 300-second total budget; it is outside the published denominator. To use the original Qwen3 baseline, omit `MEMORYOS_TEST_LOCAL_MODEL`; the literal value `qwen3` is intentionally invalid in this test selector. Do not substitute model paths or hashes through environment variables.

The native result uses a top-level `results` array. Its `candidateSourceIDs` describe initial app ranking, while `retrievedSourceIDs`/`retrievedUUIDs` describe the evidence retained for generation. `rankingCompleted` and `retrievalCompleted` distinguish finished empty stages from interrupted stages. `completed` means pipeline execution completed, not answer accuracy. `runtime-error`, `budget-timeout` and `budget-not-run` remain separate. The CLI checks the native input SHA-256 and input/label/result protocol IDs before scoring, and records the supplied label hash. Verify that label hash against the frozen manifest as part of the run receipt. Run the offline scorer with the matching frozen files:

```sh
python3 -B scripts/evaluation/score_published_pilot.py \
  --inputs /Users/eros/Library/Caches/MemoryOS-AI-Evaluation/benchmarks/prepared/combined-inputs.json \
  --labels /Users/eros/Library/Caches/MemoryOS-AI-Evaluation/benchmarks/prepared/combined-labels.json \
  --results /Users/eros/Library/Caches/MemoryOS-AI-Evaluation/benchmarks/prepared/combined-native-results.json \
  --output /Users/eros/Library/Caches/MemoryOS-AI-Evaluation/benchmarks/prepared/combined-retrieval-metrics.json
```

Offline preparation tests: `python3 -B -m unittest discover -s scripts/evaluation -p 'test_published_pilot.py'`. The commands above document the runner; they do not establish that a run passed or that manual review equals the published judge.

## Consumed slash-grammar regression

Execution status: **three separate consumed replays, none with a scoreable answer**. The consumed LongMemEval case `01493427` exposed a native grammar-transport error from slash-bearing date literals. A separately frozen external input, `slash-grammar-regression-inputs.json`, copies only that case from the original combined input, with all 487 records, the question/date and labels unchanged. Its protocol adds `-slash-grammar-regression`; its separate labels/manifest retain the original input hash and selection provenance.

Run this diagnostic only after the original frozen pilot finishes and the causal fix passes actual native grammar acceptance. Use the same candidate and native pipeline with **300 seconds total and 300 seconds per case**. Keep its output/score separate from the original 14-case run. This is a targeted replay of a consumed failure, not a new held-out case, full benchmark, easier history or pooled score.

Initial November 24 replay: the native grammar contract passes after the slash-encoding repair. The separate full-history regression finishes in 284.842 seconds with completed ranking and `memorySubjectUnclear`; it produces no answer. Original pilot and replay results remain separate in the [continuation receipt](../../docs/evidence/understanding-organization-2026-11-18/step2-astra-evaluation.json).

The later subject/cache repair uses the same frozen 487-record input and labels, unchanged candidate, and 300-second total/case budgets. That separate replay times out at 303.166 seconds: indexing/ranking takes 263.056 seconds and includes both annotated supports among eight candidates. Retrieval and answer remain incomplete; the offline scorer leaves the answer score null. A zero native harness exit means it recorded the timeout, not that accuracy passed. The original fourteen-case denominator remains unchanged. The receipt retains this result under `previousRepair.publishedReplay`; no official judge ran.

Eight independently frozen Arabic/English app cases also ran under identical source/inputs for both models. Independent grading gives default Qwen3 4 full, 0 partial and 4 failures; candidate Qwen3.5 4 full, 1 partial and 3 failures. Both retrieve the three completed source sets exactly and correctly clarify one identity ambiguity. Relationship meaning still fails (0/4 default, 1/4 candidate), including accepted unsupported default claims and empty answerable outputs. These app diagnostics have separate labels and denominators; they are not a published benchmark or model qualification.

The third repair preserves that exact full-history input, model and 300-second budget. It times out at 303.978 seconds after 266.584 seconds indexing/ranking. Both annotated supports reach eight candidates, but retrieval remains incomplete and no answer is scoreable. It ran on the recorded pre-rollback binary; all 29 retrieval/runtime/test source files remain byte-identical after the relationship-only rollback. The receipt keeps this executed-source boundary explicit under `latestRepair.publishedReplay`. Interrupted vector checkpoints improve recovery, not measured cold throughput. The original fourteen-case denominator and restricted-data reasons remain unchanged.
