# Cactus resumed integration evidence

The real Cactus configuration now runs the pinned Qwen3 Embedding 0.6B INT4 model. All 11 Release contracts pass, including the model-dependent contracts, with four verified CPU workers. The same contracts pass with networking denied. The shared 15-case retrieval run completes and retains its quality failures. The parent task owns simulator interaction, screenshots, final comparison and memory delivery.

## Current configuration and receipts

- SDK: official v1.14, commit `40a7123b0788f5b38c5fe0daa0d909b4286fe773`; [original source hashes](v114-source-provenance.json), [patched source hashes](v114-patched-source-manifest.json), [native compilation](last-token-runtime-build.log), [final build/source recheck](final-runtime-source-check.log), [patch roundtrip](patch-roundtrip-verification.json), and [binary receipt](v114-build-receipt.json).
- Local patch: `native/LocalCactusEvaluation/Support/upstream-v114-local-only.patch`. It excludes telemetry/curl, forces CPU, removes forced global I8MM on the measured M1 Pro host, and backports the v2.2.2 thread-count environment control. The linked worker-count contract verifies four workers. The explicit last-token embedding export corrects the model setup described in the [preprocessing review](preprocessing-review.md); it preserves the original mean-pooling API. The XCFramework contains actual arm64 macOS 14, iOS 18 device and iOS 18 simulator static libraries.
- Model: revision `0df64898a34c75c209b9882110cd6f9aeb7115cd`, [provenance](model-provenance.json), [full download verification](asset-download-receipt.json), [extraction receipt](asset-preparation.json), and [317-file manifest](asset-manifest.json). The adapter pins the manifest digest and rehashes each file before loading.
- Contracts: [current real-model run](last-token-contracts.log) and [current denied-network run](last-token-contracts-network-denied.log). Eleven tests execute; none skips. They cover actual Arabic/mixed top-1 retrieval, correction/delete/rebuild, cancellation, missing assets, counterfeit manifests, canonical data preservation, native vector ranking/delete/compact/reopen persistence, and a native 1024-dimensional last-token normalization check distinct from mean pooling.
- Local-only evidence: [current undefined-symbol audit](v114-network-symbol-audit.json) and its [raw symbols](v114-sdk-undefined-symbols.log). No listed curl/socket/connect/CFHTTP or URL-session reference appears. The actual denied-network model tests establish the operational offline check; the symbol audit alone is not a packet trace.
- Host report: [raw final retrieval results](cactus-host-last-token-retrieval-final.json), [summary](final-host-retrieval-summary.json), [sandbox invocation log](final-host-retrieval-network-denied.log), [source manifest](host-source-manifest.json), and [toolchain](host-toolchain.txt). This identity covers the Cactus/core source set and compiled SDK receipt for the host run, separate from the parent's simulator identity.

## Compatibility repair

The first reviewed engine v2.2.2 compiled after its public-header, local-only and object-format repairs, but its loader requires `components/manifest.json`. The official Qwen3 embedding archive contains legacy flat `.weights` files. The official model repository publishes no graph bundle for it, and upstream documents that local graph generation is unavailable during the rewrite. The compatible v1.14 release includes the native Qwen flat-weight loader and the embedding/vector C API. We rebuilt that release and verified the actual model; no tensor conversion or fabricated graph manifest occurred.

The source subset contains 90 original files after including the three bundled audio/image headers. Those header bytes came from the earlier verified cache only when their v1.14 Git blob identities matched. The [resumed fetch log](v114-source-download-resume.log) shows retry progress; the corrected fetch recipe includes these headers for a fresh preparation.

Cactus's retained license permits this personal/research evaluation. Future commercial eligibility remains a separate decision. The model declares Apache-2.0. No production provider selection, publication or release starts here.

## Host retrieval findings

The corrected last-token configuration keeps threshold 0.35/top-3 unchanged. It retrieves all expected sources for 14 of 15 cases. All 14 evidence-present queries rank a relevant source first, including Arabic birthday, nickname and digits. All 15 sets contain extras, so exact-set accuracy remains 0/15. The missing-evidence question returns three unrelated sources. We retained the scores and did not tune the threshold to the fixture.

The final host run builds the index in 1.649 seconds and has median search latency 78.0 ms, range 60.0–101.2 ms. The earlier corrected run remains in `cactus-host-last-token-retrieval.json`, with its original source identity in `last-token-first-host-source-manifest.json`; its median was 84.2 ms. Repeated host timings vary with host conditions and cache state. These numbers include this SDK/model/query configuration on the Mac host. They do not establish phone performance, generative answer quality or a product winner. The simulator's asset root is `Documents/EvaluationModels/cactus-qwen3-embedding-0.6b`, with the 317 files and `.memoryos-asset-manifest.json` directly inside it.

The earlier [mean-pooling raw report](cactus-host-retrieval.json), [summary](host-retrieval-summary.json) and [source identity](mean-pooling-host-source-manifest.json) remain unchanged. That setup recalled the full expected sources for 11/15 cases. Its Arabic misses cannot stand in for the corrected configuration.

## Historical and failed attempts

Preserve the following receipts as history. Do not cite them as current passing model checks:

- `runtime-build-final.log`, `v222-build-receipt.json`, `v222-prepare-runtime.txt`, `v222-upstream-local-only.patch`, and `source-provenance.json`: earlier v2.2.2 build/source repairs. That build cannot load this flat embedding archive.
- `real-model-contracts.log`, `real-model-contracts-network-denied.log`, `mean-pooling-final-contracts.log`, `v114-runtime-build.log`, `v114-mean-pooling-local-only.patch`, and `v114-mean-pooling-build-receipt.json`: complete earlier ten-test mean-pooling checks/build, superseded by the explicit last-token configuration.
- `failed-last-token-prototype-order.log`: the added C declaration preceded its type alias; moving the declaration after the alias resolved the compile error.
- `sdk-contract-tests-local-frameworks.log` and `xctest-network-denied.log`: earlier seven-pass/two-skipped model-independent checks, superseded by the complete current model runs.
- `failed-sdk-contract-compile.log`: first Swift Testing macro compile failure, fixed before later runs.
- `failed-nested-swiftpm-sandbox.log`: SwiftPM's nested sandbox failed under the outer sandbox.
- `failed-direct-bundle-invocation.log`: direct test-bundle execution failed; later checks use Xcode's `xctest` loader.
- `runtime-build.log`: initial v2.2.2 LLVM-only archive packaging failure; the subsequent build used ordinary optimized objects.
- `failed-v114-missing-bundled-headers.log`: the first compatible build exposed omitted bundled headers; the corrected fetch recipe and verified cache reuse resolved it.
- `v114-source-download.log`: a Python 3.9 socket timeout escaped the initial retry set. The corrected helper retries that exception and HTTP incomplete reads while preserving verified files.

The [rename receipt](failed-attempt-provenance.json) preserves original paths and hashes for the renamed failed logs. Network retries and [redundant transfer cleanup](redundant-transfer-cleanup.json) remain separate from the successful full model download. No healthy required download stopped because of elapsed time.

## Scoped storage cleanup

The [cleanup receipt](storage-cleanup.json) records 42,019,410 logical bytes removed: the redundant contiguous prefix after full archive verification, the unused replacement CMake environment and generated Python bytecode. The verified archive/model, external source/build checkouts, compiled framework and unique evidence remain active evaluation assets. Wider project/simulator cleanup belongs to the parent task.
