# Cactus local evaluation

This package implements `AIEvaluationCore.MemoryIndexAdapter` with real Cactus embeddings and vector search. MemoryOS owns the source records, stable IDs and corrections. Cactus owns a disposable derived index. This experiment does not open the Capture app's production store.

All 11 Release contracts pass with the verified Qwen3 Embedding 0.6B INT4 asset, including actual Arabic/mixed-text retrieval, correction, deletion, rebuild, cancellation, missing assets, manifest tampering and native vector persistence. The same contracts pass with host networking denied. The shared 15-case host run completes, but retrieval quality does not justify product adoption. See the [evidence index](../../docs/evidence/local-ai-2026-11-14/cactus-resume/summary.md) for raw results and limits.

## Compatible SDK and model

The evaluated SDK is official engine **v1.14**, commit `40a7123b0788f5b38c5fe0daa0d909b4286fe773`, with the retained `Support/upstream-v114-local-only.patch`. The official Qwen3 embedding ZIP uses flat `.weights` files. Engine v2.2.2 requires serialized graph bundles with `components/manifest.json`; it cannot load this archive. The official model repository has no such bundle, and current upstream documentation says local graph-bundle conversion is unavailable during its rewrite. We selected the official v1.14 flat-weight loader and tested it against the actual asset. The earlier v2.2.2 build/header repair remains historical evidence. We did not fabricate a graph manifest or change the model tensors.

The model is `Cactus-Compute/Qwen3-Embedding-0.6B`, revision `0df64898a34c75c209b9882110cd6f9aeb7115cd`, asset `weights/qwen3-embedding-0.6b-int4.zip`. Its SHA-256 is `22ff768a984fe931ac463b02cedce2ebd65172c6877d210bd5dc6d058fffbd7b`, size 376,277,536 bytes. Extraction produces 317 files at the model root, including `config.txt`, tokenizer files and `.weights` files. The config specifies 1024 embedding dimensions and INT4 quantization. The app-owned manifest SHA-256 is `229ba9eb5d361209c7f01d34cac0db77a623a33bb845c2eb90050ccc831c60af`. The adapter requires that exact manifest and rehashes each listed file before loading.

Cactus's retained license permits this personal/research evaluation. Future commercial eligibility needs a separate review. The model declares Apache-2.0. The package retains both license notices. This evaluation does not select a production provider or authorize publication.

## Boundaries and local-only patch

`AIEvaluationCore` contains provider-free contracts. The actor adapter imports that contract, Foundation/CryptoKit and the Cactus C module. The binary target contains compiled upstream code. Upstream source stays outside app source. The package supports arm64 macOS 14, iOS 18 device and iOS 18 simulator. Intel architectures are outside this experiment.

The v1.14 patch adds an explicit local-evaluation build option. It replaces telemetry with no-op implementations, excludes curl transport, and forces CPU after reading the model configuration. It removes forced global I8MM instructions because the M1 Pro host reports that feature unavailable; the existing specialized I8MM object retains upstream runtime feature detection. The patch backports the reviewed v2.2.2 `CACTUS_NUM_THREADS` control and exports a worker-count check. Actual contracts confirm four workers when launched with that setting. An explicit evaluation C export uses the native unpooled hidden states, selects the final token and normalizes that row to match the official Qwen model instructions. The original Cactus mean-pooling API stays unchanged; the preprocessing review retains the first mean-pooling baseline and the reason for this repair. The adapter checks the linked local-only guard before loading a model. It downloads nothing and has no cloud fallback.

Source verification uses the pinned Git tree's blob identities. The fetch recipe includes the three required bundled audio/image headers and excludes curl binaries. The builder accepts either that verified receipt-backed subset or a Git checkout at the exact pinned revision. A Git checkout does not need the subset receipt: the builder compares the actual `cactus/`, `libs/`, license and version bytes with the pinned Git tree. Both paths verify a temporary copy before applying the local-only patch or starting a build. An already patched source tree must differ only by the approved patch. Staged or unstaged source edits, deleted sources, unexpected compiled files (including ignored files), and symlinked source or patch paths fail verification. Keep build output outside the source directories. Build receipts retain the source revision, patch digest and framework file hashes. Actual denied-network model runs supplement the source/symbol audit.

## Reproduce preparation and checks

Keep the upstream checkout, model archive and unpacked model outside Git. The existing download helper resumes exact byte ranges and verifies the complete archive:

```sh
python3 scripts/fetch-evaluation-asset.py \
  --url https://huggingface.co/Cactus-Compute/Qwen3-Embedding-0.6B/resolve/0df64898a34c75c209b9882110cd6f9aeb7115cd/weights/qwen3-embedding-0.6b-int4.zip \
  --output /path/to/cache/model-int4.zip --bytes 376277536 \
  --sha256 22ff768a984fe931ac463b02cedce2ebd65172c6877d210bd5dc6d058fffbd7b --workers 4
python3 native/LocalCactusEvaluation/Support/prepare_asset.py \
  /path/to/cache/model-int4.zip /path/to/empty/model
python3 native/LocalCactusEvaluation/Support/fetch_upstream.py \
  --output /Users/eros/Dev/Tools/MemoryOS-Evaluation-Upstream/CactusEngine/v1.14-compatible
python3 native/LocalCactusEvaluation/Support/prepare_runtime.py \
  --upstream /Users/eros/Dev/Tools/MemoryOS-Evaluation-Upstream/CactusEngine/v1.14-compatible \
  --cmake /Users/eros/Library/Android/sdk/cmake/3.22.1/bin/cmake \
  --ninja /Users/eros/Library/Android/sdk/cmake/3.22.1/bin/ninja
CACTUS_NUM_THREADS=4 CACTUS_EVAL_MODEL_DIR=/path/to/verified/model \
  swift test --package-path native/LocalCactusEvaluation -c release
```

`Artifacts/cactus.xcframework` and the build cache remain ignored. No remote Swift package resolution is needed: the package uses the local core package and local compiled binary target.

Run the source-gate regression tests without compiling an SDK or loading a model:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s native/LocalCactusEvaluation/Support/tests -p test_prepare_runtime.py -v
```

These tests use temporary Git fixtures and actual `git apply` calls. They cover clean and approved-patch trees, rejected changes, symlinks, and refusal before patching or building.

For a denied-network check, build first, then launch the test bundle with Xcode's loader. Sandboxing SwiftPM itself conflicts with its nested manifest sandbox:

```sh
CACTUS_NUM_THREADS=4 CACTUS_EVAL_MODEL_DIR=/path/to/verified/model \
  sandbox-exec -p '(version 1) (allow default) (deny network*)' \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xctest \
  native/LocalCactusEvaluation/.build/out/Products/Release/CactusEvaluationAdapterTests.xctest
```

Run the built `cactus-evaluation` executable with `--model-directory`, `--source-identity`, and `--output`. Its optional `--network-denied` flag records the operator's assertion; use it only with the retained sandbox invocation. The CLI runs the shared fictional suite with retrieval scope and retains raw source IDs/scores.

## Behavior and measurement limits

The adapter normalizes embeddings, adds Qwen3's query instruction, and uses explicit last-token pooling and Cactus's native index ranking with provisional threshold 0.35 and the suite's top-3 limit. It checks cancellation between synchronous native calls. A running native embedding call can delay cancellation until it returns.

Rebuild publishes a replacement index only after all sources succeed. Invalid or cancelled rebuilds preserve the prior snapshot. Empty rebuild clears the derived index. Closing removes only the adapter's generated index directory. Canonical IDs map to local numeric Cactus IDs; their identity does not depend on content hashes. The adapter rejects embedded NUL text before the C boundary.

The host result is a Release integration/retrieval smoke test. All 15 retrieval calls complete; 14 cases have full expected-source recall, and none matches the exact expected source set. All 14 evidence-present queries rank a relevant source first. The fixed threshold returns unrelated sources for the missing-evidence question. Keep these failures when comparing candidates. This arm does not run generation or establish physical iPhone battery, heat, or a production winner. The parent task owns simulator interaction and cross-provider comparison.
