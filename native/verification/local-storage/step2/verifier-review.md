<!-- hindsight:ignore -->
# Independent Step 2 review: local storage and text capture

Reviewer: fresh independent verifier `storage_step2_verifier`, 2026-11-14. The reviewer did not implement Step 1. Scope: checklist group 3. No app/test source edits, Git mutations, cleanup deletions, device interaction or new agents.

## Current result

**Blocked.** Initial review found two P2 correctness defects. Focused repaired-source review and independent host tests now close F1 and the feature-level F2 path. The actual provider retry also passes in the simulator. No open F1/F2 code finding remains. Required physical/runtime/accessibility checks still block passage. Physical iPhone 15 Pro Max lock/Data Protection and performance checks, iOS 18 runtime and affected accessibility acceptance remain blocked. Fresh simulator capture evidence now passes the narrow screenshot requirement. The reviewer cannot waive these checks.

Authority: current AGENTS, README, product overview, decision register, task record, development workflow and commercial rules. Current-turn project-scoped Hindsight recall succeeded through `./scripts/memory recall`; it confirmed C35 durable-storage authorization and the old demo-scope correction. Current repository source governs implementation claims.

Initial source: all paths in `../source-hashes.json` matched before repairs; baseline head `977334f857430313eb8d5145318cf90198e6b62a` with uncommitted implementation and unrelated pre-existing C34 policy changes. Main owns final-source identity after repairs.

## Findings

### F1, P2: canonical String equality loses exact text changes

Initial `MemoryCore/LocalMemory.swift`, `LocalRecordRules.correction`, uses `record.text != text` to detect a correction. Swift String equality considers composed `é` and decomposed `e` plus U+0301 equal, though their UTF-8 differs. The actual repository accepts this correction and stores no revision. Initial archive validation at line 131 also accepts a current text whose bytes differ from its last revision/original. Restore at `MemorySQLite/SQLiteRecordRepository.swift:97` accepts byte-different originals for the same UUID because synthesized record/revision equality uses String equality. The draft-clear comparison in the initial ViewModel at line 66 can clear newly typed equivalent text after an in-flight save.

Isolated actual-source reproduction in `verifier-reproductions.log`: requested correction bytes `[101,204,129]`; retained bytes `[195,169]`; revision count 0. A current/original-byte mismatch archive and a same-ID byte-different source restore both succeeded. This breaks exact-original/correction history and conflicting-source validation. Repair byte-sensitive comparisons and assert UTF-8 in regressions. Keep ordinary display equivalence where exact bytes are not required.

Status: **closed by focused review and tests**. `RecordRevision` and `LocalRecord` implement byte-sensitive text equality; archive validation, correction no-op and draft-clear checks use UTF-8 sequence equality. Three new package regressions and the in-flight-draft regression pass. The original isolated reproduction now retains requested bytes, records one revision, rejects the mismatched archive and rejects the same-ID source conflict. Evidence: `verifier-package-tests-final.log`, `verifier-feature-tests-final.log`, `verifier-reproductions-final.log`.

### F2, P2: initial storage failure cannot recover through Reload

Initial `Composition/LocalStoreComposition.swift:33-35` catches directory, protection, database-open or schema errors and constructs a ViewModel with nil use cases. The initial ViewModel stores immutable optional dependencies (`LocalRecordsViewModel.swift:9-10`). Reload calls `load`, which returns an error before attempting any open when that dependency is nil (`45-48`). An initial transient open/full/lock failure disables capture for the lifetime of that app process. Reopening a screen cannot retry storage; forcing termination risks the unsaved in-memory draft.

The existing recoverability test starts with an already-open injected repository and does not cover failed initial composition. The actual-source nil/Reload reproduction confirms repeated Reload keeps save disabled. Repair through an injected app-owned retryable open/session boundary, preserving the same feature state and draft. Add a failed-open, recovery, successful-save regression. The main agent selected this repair.

Status: **closed by focused review, host feature tests and actual-provider simulator test**. `MemoryCore/LocalMemorySession.swift` defines a Sendable app-owned session/provider boundary. `LocalStoreComposition` injects `LocalStoreProvider`; its actor performs filesystem/SQLite work off the UI actor and caches a session only after successful setup. The same ViewModel retries failed open through `load`, retaining the draft and guarding concurrent reload/mutation. Controlled failure/retry/save passes in independent host tests. `LocalStoreProviderTests.blockedDirectoryCanRecoverInSameFeatureInstance` also uses the actual provider, removes a regular-file directory blocker, retries the same feature/provider and checks saved IDs/text after reopen; `functional.log:3006-3009` records this actual provider test passing and all 17 app test functions in 5 suites passing.

## Actual architecture and ownership inspection

- Capture Save: `CaptureView` button -> `LocalRecordsViewModel.saveCapture` -> injected `LocalMemoryUseCases.create` -> app-owned `RecordRepository.create` -> `SQLiteRecordRepository.create` -> parameter-bound SQL inside one transaction. The ViewModel clears the submitted draft only after the repository returns success and treats a later snapshot failure as a committed save, preventing duplicate create retries.
- Correction/Trash/link actions follow the same direction. `LocalRecordRules` owns correction eligibility, link eligibility and deletion timestamps. Views retain focus, navigation and sheet state. Input enablement and list filtering serve presentation.
- Files restore: picker forwards URL -> ViewModel `importArchive` -> `RestoreArchiveFromFile.execute` -> injected `ArchiveDataReader` -> `LocalArchiveFileReader`; restore then goes through use cases/repository. Views and ViewModels do not read files or import SQLite.
- `MemoryCore` imports Foundation; it has no dependency on SwiftUI/UIKit, MemorySQLite or provider SDKs. Separate MemoryCore/MemorySQLite targets compile within the one app-owned package. The system CSQLite target links the OS sqlite3 library. Swift 6 package mode and app strict concurrency complete apply. One storage actor serializes operations; no C pointer spans an await. Each operation closes its connection.
- The composition layer owns the concrete adapter, canonical Application Support path, complete file protection and backup exclusion. Files read in bounded chunks with security-scoped access and a 50 MiB cap. Physical inheritance/lock behavior still needs the required device check.
- The configured origin is the canonical `faroqomar/Eros_MemoryOS` repository. No remote package, model asset, copied upstream engine or new custom engine repository entered this task. No Package.resolved pin is needed for this app-owned local package/system-library integration. OS SQLite runtime version is OS-owned; the storage decision records that distinction and its public-domain license.
- No network client, AI provider or silent cloud fallback appears in these storage paths. Explicit readable export goes through the native Files flow and discloses that choosing a cloud destination transfers its content. Recording/transcription/retrieval/model replacement are unaffected and need no speculative interface here.

## Independent checks

| Check | Result | Evidence and limit |
| --- | --- | --- |
| Initial source identity | Pass | Every SHA-256 entry in baseline `../source-hashes.json` matched before repairs. |
| Independent plain core build | Pass | `verifier-core-build.log`, `swift build --configuration release --target MemoryCore`, independent scratch path. Host result only. |
| Existing storage contracts | Pass for initial candidate | `verifier-package-tests.log`: 18 Release Swift Testing tests in 3 suites. Independent scratch path `/tmp/memoryos-step2-verifier-build`. Checks exact bilingual/NUL binding, reopen/UUIDs, correction history, undirected links, Trash, archive round-trip/idempotent merge/conflict rollback, invalid/future schemas/archives, SQL-write failure rollback, concurrent writes and capacity preflight. F1 shows the original test suite lacked a byte-sensitive Unicode case. |
| Abrupt process interruption | Pass for one host case | `verifier-interruption.json`: actual repository restore worker received SIGKILL while journal held 29,240 bytes; repository reopen recovered exactly the one original row, zero incoming revisions, integrity_check `ok`. Actual source via isolated executable. This does not prove hardware power-loss, device lock, Files-provider interruption or physical iOS behavior. |
| Controlled ViewModel/file-reader tests | Pass for repaired feature | `verifier-feature-tests-final.log`: 10 Release tests in 2 suites pass, including connection retry and byte-sensitive pending draft.  The independent host run overlapped the main repair batch and saw the new ViewModel before SwiftPM discovered its new domain type; `verifier-feature-tests.log` is a changing-source diagnostic, not a final failure or pass claim. The initial inspected tests cover retained draft, duplicate rejection, continued typing, committed-create/reread failure and bounded file import. |
| Baseline app/UI evidence inspection | Pass for recorded baseline only | Inspected `../final-ui-summary.json`: 27 tests passed, 0 failures, iPhone 18 Pro iOS 27.2 simulator. Main records 14 app tests and 13 functional UI tests. This reviewer did not operate the device or independently rerun UI automation. Final repairs require affected rechecks. |

## Mandatory Step 2 matrix

| Requirement | Current result | Evidence or reason |
| --- | --- | --- |
| MVVM action path and injection | Pass for repaired structure | Concrete traces above plus inspected domain session/provider, initializer injection, off-main platform provider and ViewModel load retry. |
| Dependency direction and independent core | Pass for repaired core/feature | Separate core target/build, injected protocols, platform adapters outside core/UI. |
| Behavior, error and recovery tests | Pass for affected host and recorded simulator tests | Independent 21 storage tests plus 10 feature/file-reader tests pass after repairs. Actual provider retry passes in `functional.log:3006-3009`; 17 app test functions and 13 functional UI scenarios pass in `functional-summary.json`. |
| One canonical repository; engine ownership | Pass | Canonical origin; OS system SQLite; app-owned adapter, no copied upstream source or new engine repository. |
| Reviewed dependencies and assets | Pass for affected scope | Swift 6 local targets, system SQLite documented/license reviewed; no third-party package/model assets. SDK/runtime platform revision requires final environment evidence. |
| Real adapter contracts | Pass for inspected tested subset; remaining device checks blocked | Actual SQLite tests and host SIGKILL recovery. Files cancellation ignores user-cancel errors at picker/export completion; synchronous transactions finish atomically. No in-progress cancel control is offered. Hardware lock/interruption and Files-provider behavior remain separate. |
| Arabic/English and offline | Pass for affected host/functional simulator behavior; accessibility blocked separately | Exact mixed text/NUL bindings, final 13 functional UI scenarios, Arabic Unicode regression and fictional mixed-text retry/backup captures; no networking. Main owns device interaction. No model/default/asset checks apply because no inference enters scope. |
| Durable originals/IDs/history/links/Trash | Pass for repaired host contracts | Independent 21-test suite plus original reproduction recheck closes byte-sensitive corrections, source conflicts and archive invariant defects. |
| Export/import, upgrade and replacement recovery | Pass for repaired host normal/error subset | Version-0 empty DB -> schema 1 initialization; foreign/unversioned/newer refusal without reset; transactional JSON merge/rollback/idempotency; abrupt restore recovery. Future migrations have no supported predecessor beyond empty schema 0 and require new tests when introduced. Provider indexes/rebuild unaffected. |
| Physical-device benchmarks | Blocked | Required iPhone 15 Pro Max Release workload: 1,000 bilingual ~1 KiB records, 30 saves, 5 cold opens; p95 save <200 ms, snapshot <1 s, DB+journal <10 MiB. No device/runtime result available. Host timings cannot replace it. |
| Data Protection, unlock and passcode | Blocked | Policy/source inspected; physical protected-file inheritance/lock/recovery unavailable. No custom encryption claim. |
| iOS 18 runtime | Blocked | Available evidence uses iOS 27.2 simulator and iOS 18 deployment target compilation. Runtime behavior on minimum supported OS remains unverified. |
| Accessibility, Dynamic Type, RTL and dark UI | Blocked for complete acceptance | Native controls/system text styles and dark/RTL app environment inspected. Both targeted English/Arabic local-record audits fail contrast and Dynamic Type checks in `local-accessibility-summary.json` and `local-accessibility-run.log`. Rendered text/action evidence contradicts selected growth warnings but leaves contrast/unlocated findings and VoiceOver unresolved; no accessibility pass follows. |
| Cleanup and retained evidence | Pass for narrow final cleanup | `cleanup-receipt.json` and independent `verifier-cleanup-recheck.json`: 21 explicit external paths absent, 3 duplicate logs absent with canonical hashes intact, removed VM members have no product consumer, 36 source/7 capture hashes and original research/backup/Foundation links preserved. |
| Fresh Step 2 screenshots | Pass for capture evidence | Seven current dark Release iPhone 18 Pro / iOS 27.2 simulator captures with source/binary manifest identity. Reviewer inspected all seven saved images. This does not establish physical-device performance, accessibility or owner design acceptance. |
| Cloud isolation, sync, AI quality, model/recording energy/thermal | N/A | No cloud/AI/sync/account/recording/model capability enters this storage increment. This does not waive physical storage latency/capacity/Data Protection checks. |

## Open checks and evidence boundaries

The reviewer inspected source/tests and ran host checks. Main owns source fixes, final tests, T3 device interaction, screenshot capture, task documentation and cleanup. Keep final source identity separate from the initial manifest. Source inspection does not establish owner visual approval or commercial/release readiness. A missing required physical/runtime/accessibility result leaves Step 2 blocked after local repairs.

## Focused repaired-source review

Independent final host checks: 21 package tests in 4 suites, 10 platform-independent feature/file-reader tests in 2 suites; both Release runs pass. The package run recompiles the repaired MemoryCore with its new session/provider type. The original source reproduction now confirms F1 rejection/preservation behavior. The fixed-dependency nil initializer still refuses saves as intended; production no longer constructs it on failed open. Production uses the retryable provider initializer.

The main agent removed the unread `saved` state and the ViewModel `restore(Data)` entry used only by a test. Capture uses the returned success value. Production imports use `importArchive(URL)`; the malformed-import test now injects a file reader and follows that route. No product consumer depends on the removed members. Independent tests compile and pass after those removals.

The SQLite adapter did not change during repairs. Retain its SIGKILL recovery evidence; the repaired core tightens equality/validation and does not change SQL transaction/recovery mechanics. Final cleanup inventory, hashes, actual-provider simulator execution and UI/accessibility evidence still need focused review.

## Final candidate and added main-agent evidence review

All entries in main `source-hashes.json` match current source. All core/feature entries overlap the independent recheck manifest exactly. Main Release simulator/device analysis logs end in success. Main `functional-summary.json` reports 30 logical tests passed and zero failures; parameterized execution totals differ. The reviewer checked the actual-provider failure/retry test in `functional.log`, not just the builder summary.

Main `retry-fixture.json` records a reversible simulator-only regular-file startup blocker and byte-identical restoration of the preserved store. Main screenshots show the retained draft/error and recovery; no production data reset follows. `native-backup.json` records actual native Files export on the Release iOS 27.2 simulator: 10 records, 2 revisions, 2 links and matching original UTF-8/IDs/dates against the live store. The reviewer inspected this receipt; the main agent performed device/file-flow interaction. Native import now passes in the updated receipt: the main agent observed Backup restored, retained all 10 records, and compared original/current/history/dates and all links/UUIDs after an idempotent import. Picker whole-cell press did not select the file; a visually grounded icon press selected it. Post-picker AX recovery remains a separate unresolved symptom.

The affected-screen English and Arabic accessibility runs both fail. The log locates contrast warnings on original/current source, dates and actions, as well as unresolved nodes; it also reports Dynamic Type warnings including native toolbar controls. `rendered-text-growth.json` shows sampled source cell height 4.84x, Correct/Trash rows 1.83x and footer 7.94x at the largest accessibility size, with actions hittable. The reviewer inspected the actual largest-action screenshot and sees enlarged text and reachable actions. The partly clipped Link row provides no growth measurement. These samples do not resolve contrast, unlocated warnings or VoiceOver. Keep acceptance blocked; no issue filter waives a finding.

### Post-Files accessibility tree symptom

The main agent observed a normal visible app screen after successful export but received a two-node fallback accessibility tree; process relaunch restored the tree. Cause remains unresolved. Source inspection finds no exporter completion mutation of menu state, accessibility modifiers or navigation. `LocalRecordsView.swift:176-185` clears `archiveData` after export completion and reports non-cancel errors. `RootView` hides content only from its own `menuIsOpen` state, which export never mutates.

Apple documents that SwiftUI sets the export binding false before calling completion, so clearing the in-memory archive afterward follows the documented lifecycle. Source: [Apple fileExporter documentation](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)). The installed iOS 27.2 SDK still exposes this iOS 14+ FileDocument overload; it uses a future soft-deprecation sentinel rather than a hard-deprecated API. User cancellation does not call completion for this overload, leaving archiveData until a later export or feature lifetime end; this does not explain hidden AX nodes.

No current evidence identifies an app-code cause, SDK cause or automation-bridge cause. Record the symptom and relaunch recovery without classifying it as a confirmed product bug or dismissing it as a tool problem. Post-Files accessibility/automation recovery remains unresolved. Do not add speculative production changes without a reproducible source/behavior link.

### Host diagnostic benchmark

`verifier-host-benchmark.json` and its manifest preserve an independent Release host run against actual Core/SQLite and a symlink to the actual ViewModel. The harness seeds 1,000 bilingual 1,024-byte originals, then measures 30 full saveCapture/create/full-snapshot/refresh operations and 5 fresh repository+ViewModel load operations. The final store contains 1,030 records. Save median 14.05 ms, nearest-rank p95 44.04 ms, range 13.42-139.56 ms; API reopen range 13.11-13.70 ms; final database plus journal 1,507,328 bytes. All samples, variance, high shared-host load, toolchain, exact hashes and workload limits remain in the receipt. API reopen keeps OS caches warm and excludes app launch/rendering/Data Protection. This supplies a reusable HOST baseline only, with no baseline-versus-candidate or phone-speed claim. Physical thresholds remain blocked.

## Final focused input and Files recheck

The package test input now also covers Arabic U+0623 (`أ`) canonical decomposition. Independent `verifier-exact-text-final.log` records all 3 ExactTextTests functions passing, including both Arabic and café arguments. Only this package test file changed since the prior independent core/feature check; product source hashes match. `verifier-final-source-check.json` records the reviewed final manifest hash and zero current-source mismatches. No repeat host benchmark or SQL interruption test is needed for a test-data-only change.

The updated native backup receipt records successful native idempotent import and preserved original/current/history/date/link/UUID values. The main agent observed the two-node AX-tree symptom again after acknowledging the restored alert; relaunch restored the tree. Keep this recurrence unresolved.

`rendered-contrast-samples.json` records foreground RGB 245/245/245 and background 37/37/40 for sampled Correct text and Move to Trash controls, ratio 14.02:1. This sample contradicts low-contrast interpretation for these sampled text/control pixels only. It does not resolve the remaining labels, toolbar controls, unresolved nodes, VoiceOver or the failing audits.

The reviewer found no unique unretained result in the enumerated external build/harness/fictional-database/recall scratch paths. Main may remove those reproducible caches after retaining the source, manifests, raw samples, test logs and receipts in this evidence directory. Final cleanup-removal/storage receipt review now passes within the narrow reviewed scope, as recorded below.

## Final cleanup and capture disposition

**Cleanup: pass for reviewed removals and preservation. Overall Step 2: blocked.** The independent `verifier-cleanup-recheck.json` confirms all 21 enumerated external scratch paths are absent and all 3 duplicate log paths are absent. Retained canonical log hashes match. The main receipt accounts for 718,536 KiB (701.695 MiB) of allocated external scratch storage and 292,904 bytes of duplicate logs. Project/native size stays 1,188,544/818,532 KiB across the final external-cache removal; the larger initial-to-final project size includes retained unique new verification evidence. Do not equate those separate scopes or infer free-space changes from a shared active host.

The independent check verifies all 36 current source hashes, all 7 screenshot hashes and the screenshot manifest's source identity; original research hashes; retained fictional backup bytes; and both Foundation result symlink targets. The reviewer had already checked duplicate consumers and byte identity before removal. The two removed ViewModel members had no product consumer; affected final source tests passed before cache deletion. Main records app-database preservation. No broad test rerun is necessary for removal of reproducible external caches and byte-identical unused logs when source hashes remain unchanged.

The reviewer inspected seven actual dark saved captures: startup error with retained mixed-language draft; same draft after Reload recovery; regular and largest-text record source/actions; native local backup picker; and Backup restored alert. Captures use the Release iPhone 18 Pro simulator on iOS 27.2, with source/binary identity in the capture manifest. They satisfy capture evidence only. Physical-device performance/lock/passcode, iOS 18 runtime, affected accessibility findings and post-Files AX-tree recovery remain blocked or unresolved. Owner visual acceptance remains separate.

The final cleanup review created two small duplicate recall/skill scratch files for its required current-turn preflight; the reviewer reported those exact paths to main for removal. They contain no unique result; this review receipt and Markdown contain the retained outcome.

## Documentation consistency review

The final task Step 2 matrix, README and storage decision agree with the source review, repaired F1/F2 results, native import/export receipts, host-only performance limits and cleanup/capture evidence. They preserve blocked physical-device/minimum-runtime/accessibility checks, unresolved post-Files recovery, uncommitted source and unrequested Step 3. Main received one wording refinement for `docs/how-to/native-swiftui.md`: qualify passing local tests as functional/storage tests so the summary does not imply that the failing accessibility methods passed. Main also received the two supplemental scratch paths for final receipt accounting. Neither item changes app behavior or permits Step 2 passage.
