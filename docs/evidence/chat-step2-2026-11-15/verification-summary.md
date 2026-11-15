# Independent chat verification, 2026-11-15

Prior checkpoint: base HEAD `7e4297e165f03f3caf57de41f7fbec30135fe912`, uncommitted chat implementation, [56-file source manifest](final-source-sha256.json). Manifest SHA-256 `d9a54b72739dc02aa92fcc96382826946b01832c30adfc956d71e4e7bbaf0fd3`. C49 performance repair follows this checkpoint; these results do not certify subsequent edits.

Fresh architecture and behavior reviewers inspected source, traced actions, executed host checks and rechecked repairs. Their consolidated outcomes follow. [Final prior-checkpoint receipt](final-checks.json) identifies configuration, installed executable and retained result bundles. Device: iPhone 18 Pro Max, iOS 27.2 Simulator, Release arm64. No physical-device result is claimed.

## Architecture and data ownership

- Send: `ChatView` → `ChatViewModel` → `ChatUseCases` → `ChatModel`/`ChatRepository` protocols → injected llama/persistence adapters. Views render state and forward actions. ViewModels coordinate feature state through use cases.
- `ChatCore` imports Foundation only. SwiftUI/provider SDKs stay outside domain code; concrete SDK construction stays in adapters/composition. Model import checks the local asset through an app-owned preparation use case.
- Memory retrieval reads a fresh `LocalMemoryUseCases` snapshot. Corrections replace retrieved evidence; Trash excludes records. Missing evidence prevents generation in memory mode. Original records, stable IDs and source links remain app-owned. The model has no record-write interface.
- Chat archives and drafts remain separate from original-record storage and backup. Atomic versioned files recover interrupted generation as partial output. Lifecycle coordination flushes drafts and joins/unloads generation. A forced kill within the draft debounce can lose the latest unflushed keystrokes.
- Existing upstream llama.cpp stays external and replaceable. [Dependency receipt](architecture-dependency-check.json): revision `a956a852c9c8bc1fb07206364838ddef299178c0` / b12387; 531 source files and all three framework binaries matched. Qwen3-0.6B Q4_K_M: 396,705,472 bytes; SHA-256 `ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a`; Unsloth revision `50968a4468ef4233ed78cd7c3de230dd1d61a56b`. Existing MIT/Apache provenance remains in the support review.

## Findings and rechecks

| Finding | Repair and result |
| --- | --- |
| B1: save retry left a stale storage error | Successful persistence clears only `.storage`; unrelated model errors survive. Independent isolated pre-fix reproduction failed and repaired behavior passed. Permanent tests cover both paths. |
| B2: saved-chat failures were hidden | History shows action errors; failed open keeps history visible. Failed deletion/retry is covered. |
| B3: stopped text claimed a disk save | Wording now says the partial reply is retained. Persistence failure remains visible. |
| B4: assertions could count prompt text or empty output | Follow-up checks latest assistant text; stop waits for nonempty partial output; source/history Done controls have distinct identifiers. Obsolete alert test logic was removed. |
| Interruption during initial draft commit | Gated reproduction: zero native model calls, one unload, draft retained. No defect reproduced. |

| Check | Observed result |
| --- | --- |
| Core | 24 functions pass; retained compact count in [receipt](final-checks.json). |
| Real native runtime | 19 contracts pass normally (16.548 s) and under OS `deny network*` (18.844 s). The first nested SwiftPM sandbox attempt failed before tests; rerun disabled only the inner sandbox while OS network denial stayed active. This proves host adapter isolation, not disconnected full-app execution. |
| App and UI | 22 app functions and seven affected UI scenarios pass in the retained final result bundle. Two unchanged scroll scenarios pass in the retained initial result bundle. Initial source-flow failure was an ambiguous Done selector, fixed before rerun. Nine scenarios across runs does not mean the initial broad run passed fully. |
| Build/static checks | Release build, analysis, strict formatting and whitespace checks pass. Standalone build uses `ENABLE_TESTABILITY=NO`; [build receipt](final-checks.json). |
| Basic accessibility | Largest-text/keyboard flows, English/Arabic native semantic audits and Reduce Motion evidence pass within simulator scope. Basic spoken navigation reached the composer. |

The extended VoiceOver diagnostic never completed reliably. Attempts exposed activation API limits, stop timing, traversal bounds, asynchronous sheet dismissal and keyboard/focus failures. Some reached reply/history/source speech, which does not establish an end-to-end pass. The live UI test source was restored to its prior passing hash. C49 removes this extended test from the current task requirements; it is not reported as passed. Basic labels, text size, contrast and usable touch controls remain required. Obsolete retry bundles, copied test sources and repeated logs were deleted after retaining this outcome.

## Limits and cleanup

[Baseline performance review](performance-review.md) retains the observed timing failures and attribution limits. C49 renderer/probe repairs and affected checks are recorded in the [current compact result](c49-render-result.json). Physical iPhone, minimum supported iOS, OS pressure/protected-file checks, full-app disconnected execution and owner acceptance remain separate unavailable or pending checks. Experimental Arabic/Iraqi model quality failures remain open.

Earlier cleanup reclaimed 922,356 KiB (900.74 MiB), plus 23 Finder metadata files. Three Step 1 result bundles (3,102 files) and the baseline trace/two Step 2 bundles (2,106 files) were independently rehashed with zero mismatches before obsolete caches were removed. Those aggregate results are retained; large generated per-file preservation inventories are not useful permanent documentation. C49 removes repeated runtime logs/call trees and superseded attempts while retaining the active baseline trace, passing result bundles, compact source identity and selected dark captures. [Cleanup totals](cleanup-summary.json).
