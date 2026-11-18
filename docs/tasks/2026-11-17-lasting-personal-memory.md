# Group 7: lasting personal memory, profiles and projects

Status: Step 2 BLOCKED on remaining qualification. Independent repairs/tests and selected physical targets pass. Connected Step 3 draft delivery is now authorized; the [current task](2026-11-18-qwen4b-conversation.md) retains merge gates.
Checklist: group 7, all thirteen items in the owner's November 17 request.
Authority: current owner request; [personal context decisions](../decisions/personal-context-goal.md).
Outcome: normal chats preserve originals and support correctable profiles/project memory; temporary chats retain no new lasting content.
Existing unrelated documentation edits remain untouched except additive current-task links.

## Step 1 plan and acceptance

- Preserve normal user messages with stable chat/message source IDs before local generation.
- Ask immediately about unresolved meaning; retain originals without derived entries until resolution.
- Separate facts, preferences, goals, interpretations, tentative ideas, plans, workflows and commitments.
- Provide source/date inspection, categories, profile links, summaries, correction history and undo.
- Suggest identities from names/aliases without silent merges; require explicit merge and confirmed-fact change actions.
- Provide self/person/project profiles, source-backed communication interpretations and optional questions.
- Import bounded local images with supplied/imported/generated provenance; no image generator connection.
- Temporary chat may read existing memory; no new chat, draft, transcript or derived record reaches disk.
- Explicit end/process exit discards temporary content; background switching keeps in-memory content.
- Preserve the existing phone history, local operation, hidden navigation, dark mode and Arabic/English.
- Builder checks cover persistence/reopen/failure, ambiguity, corrections/undo, merge gates, image bounds and private writes.
- Capture new dark Simulator screens and record exact source identity. Phone performance remains unmeasured.

Architecture: existing app repository and local packages; no new upstream SDK/model.
`PersonalMemory*` in `LocalMemory/MemoryCore` owns domain values, validation and use cases.
`FilePersonalMemoryRepository` and its pooled-history storage codec in `MemorySQLite` own atomic protected storage behind an app-owned protocol.
`ChatMemoryRecording` in `ChatCore` receives normal user originals; the composition adapter calls personal use cases.
`PersonalMemoryViewModel` owns feature state and invokes injected use cases; SwiftUI views render and forward actions.
Views: `Features/PersonalMemory/{PersonalMemoryViews,PersonalProfilesView,PersonalEntryDetail}.swift` and `Chat/ChatView.swift`.
`Composition/PersonalMemoryComposition.swift` constructs the repository/actor; `ChatComposition.swift` injects recorder/retrieval.
Save/correct/resolve: View → `PersonalMemoryViewModel` → `PersonalMemoryUseCases` → `PersonalMemoryRepository` → protected file adapter.
Image import: View → ViewModel → `Domain/ImportPersonalImage.swift` → `PersonalImageReading` → `Composition/PersonalImageReader.swift`.
The app composition root injects one shared personal-memory actor into chat recording/retrieval and profile features.
Existing record SQLite and normal chat archives remain separate stores; identifiers retain provenance.
The personal graph has its own versioned archive and explicit recovery; no vendor index owns original data.

Skill search: installed catalog and project inventory for SwiftUI, concurrency, persistence/privacy, source-linked memory, navigation, empty states and tests. Selected entry points:
- `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md`: project-scoped historical recall.
- `/Users/eros/.codex/skills/mattpocock-implement/SKILL.md`: bounded implementation; project stage gates override commit advice.
- `.agents/skills/swiftui-expert-skill/SKILL.md` and `swiftui-ui-patterns/SKILL.md`: native views and state ownership.
- `.agents/skills/swift-concurrency/SKILL.md`: Swift 6 actor isolation, serialized writes and cancellation.
- `.agents/skills/swift-testing-expert/SKILL.md`: meaningful public-contract tests; XCTest for UI.
- `.agents/skills/axiom-security/SKILL.md`: protected personal storage and temporary-session leak prevention.
- `.agents/skills/axiom-accessibility/SKILL.md`: final native labels, semantic fonts, touch targets, Reduce Motion and large-text flow checks; extended accessibility qualification remains open.
- `.agents/skills/ux-navigation/SKILL.md`, `ux-empty-states/SKILL.md`, `ux-heuristics-audit/SKILL.md`: connected native flows and error/empty-state review.
No cloud, web, model or upstream-package adoption is in scope; package-selection work is N/A.
Model/runtime/assets are unchanged; graph timing is scoped below. Physical memory/energy and release qualification stay separate.

Helpers: `lasting_core` owns core/package work; `chat_privacy` owns chat privacy. Main owns UI/composition/integration/evidence and merge decisions.

## Builder results

Source baseline: `d35fc55febc8e841ee2e3c0a81c074b8045ace1b`; changes remain uncommitted.
Final 38-file ordered Swift-source digest (paths, bytes and deletion markers): `ef1798f2e87aeba566858bf4f49a4e60876f5383e89d66dcbb618fb406427ddb`.
Release Simulator binary SHA256: `dd360dffde61cb26d87da0fb0d8f6efe2b156ec13a28cc35b2ffc5e784e1820d`.
The feature uses the real People/Projects routes and keeps original local records in the Saved records segment.
Normal messages enter the personal source archive before model preflight. Questions stay conversation-only;
clear preference/goal prefixes organize without a questionnaire. Unfamiliar/mixed statements ask for meaning.
Resolved entries gain kind categories and unique known-name/alias associations. Shared nicknames do not auto-link.
Bounded conversation summaries contain up to five resolved source excerpts; pending portions never enter them.
Corrections refresh automatic excerpts. Owner-edited summaries keep their supporting source IDs.
Sources, entry-specific prior text/dates, confirmed-change dialogs and reversible merge/organization remain inspectable.
Optional prompts carry typed meaning across languages. Images retain bytes and supplied/imported/generated provenance;
picker imports cap at 2 MiB and render through dimension checks and 720-pixel thumbnails.
Organized-memory export is readable JSON, separate from record/audio storage; restore refuses nonempty history.
Temporary chat uses typed messages, may retrieve existing memories, and bypasses lasting-memory recording and disk writes.
Background switching retains the private draft; inactive private screens have an opaque cover. Explicit end and restart discard it.
Home labels its normal capture behavior when a private session remains available. Private audio entry is blocked.

Builder review used `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md` with focused fresh standards/spec helpers.
This review belongs to Step 1, not the owner's independent Step 2. Repairs and regression coverage:
- Commit photo provenance and attachment together; failure/retry leaves neither partial sources nor duplicate imports.
- Show previous correction text/dates; compare UTF-8 bytes so canonical-equivalent corrections remain visible.
- Expose answered-source reclassification with confirmed-fact protection.
- Add reversible automatic categories/name links and source-excerpt summaries without deriving from unanswered captures.
- Pin edited-summary citations and separate organization overrides from text edits; test more than five later messages.
- Preserve real profile searches and navigation paths across section changes; retain sample exploration only in BrainMap.

Final builder checks: Release LocalMemory **41 test functions**, LocalChat **56**, native **68 in 14 suites** pass.
Native checks include adapter/composition, exact originals, failure recovery, optional prompt semantics and image validation.
Strict Swift formatting over all current changed source files and `git diff --check` pass.
Unsigned generic-iOS Release static analysis/compilation passes. Twelve distinct affected UI functions now pass across final/reused runs. Selected final captures use the free iPhone 18 Pro Simulator.
Initial build attempts exposed a profile-editor scope mistake and Release testability/architecture flags; repaired.
UI retries repaired obsolete selectors, navigation/input isolation and async assertions. A typed item sheet fixes optional-question meaning; the Arabic large-text goal test passes.
A full second model reply exceeded the earlier 45 s wait during concurrent Simulator work. Full-reply timing remains unqualified in group 16. The source-attribution regression now checks current citations and stop recovery, and passes in 162.594 s; it does not claim the old full-reply deadline passed. Prior failures remain recorded here; retries are not independent verification.
Builder commands: Release `xcodebuild test`, Simulator `8843F67E-B2AF-4605-A3AE-25D168BD1B28`, `ENABLE_TESTABILITY=YES ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`; Release `swift test` for LocalMemory and LocalChat.

Builder limits: the conservative organizer is not a qualified natural-language or psychological model.
Image generation, archive import pipelines and semantic matching remain outside this group; supplied/imported/generated files are labeled.
Undo retains 50 recent graph changes; immutable originals stay retained. Full-app backup/deletion policy remains open.
Step 2 benchmark targets: Release on iPhone 15 Pro Max, 100/1,000 fictional short sources, three cold/warm repetitions;
median reopen below 1 s and p95 edits below 250 ms, with storage/RSS growth recorded. These are targets, not measured phone results.
Physical protection, energy/thermal cost and owner visual acceptance remain unqualified; iOS 18 testing was withdrawn for this task by the owner on November 18, not passed.
Existing upstream SDK/model pins and licenses do not change. No upstream adapter implementation is copied.

## Dark builder captures

Actual iPhone 18 Pro / iOS 27.2 **Simulator**, fictional data, final Release binary above; not physical-device or owner approval.
Another thread owned Pro Max; the bounded wait failed and its session stayed untouched. Free Pro supplied captures through this thread's device command using native modal refs/screenshot coordinates after direct AX reported circuit-disabled; no accessibility pass follows.

- [Immediate clarification and held original](../evidence/personal-memory-2026-11-17/clarification.png).
- [Real project and typed plan](../evidence/personal-memory-2026-11-17/project.png).
- [Source text, date and project link](../evidence/personal-memory-2026-11-17/source.png).
- [Temporary session and explicit End](../evidence/personal-memory-2026-11-17/temporary.png).
- [Arabic self-profile, optional questions and image controls](../evidence/personal-memory-2026-11-17/profile-ar.png).

## Cleanup and evidence checks

Removed the confirmed unconsumed 3,440-byte `CatalogListView.swift`; BrainMap retains the fictional reference flow.
Task scratch cleanup: **1,389,412 → 778,912 KiB**, reclaiming **610,500 KiB (596.19 MiB)** across 4,416 generated files.
Removed duplicate device products/resolved logs/retries/failure exports after compacting outcomes; retained canonical Simulator build, research/references/upstream assets, Git metadata, app histories, selected captures and unrelated documentation edits.

## Step 2 verification

Owner requested Step 2 on November 17; checks continue through November 18. Project-scoped recall succeeded.
Selected additional skills: `mattpocock-code-review` for independent spec/standards checks, `swiftui-performance-audit`
and `mattpocock-diagnosing-bugs` for measured serialization diagnosis. Current source corrected the stale group 7 memory page.
No Step 3, commit, push, merge, publication or release is authorized.

Fresh reviewers: `s2_core_verifier` owns core/privacy and package evidence; `s2_ui_spec_verifier` owns independent UI/spec/MVVM inspection.
`s2_benchmark` owns only the isolated physical benchmark. Main owns production repairs, native runtime and cleanup.
Six confirmed findings were repaired and received focused independent source/regression rechecks:
- Edited summaries now derive automatic profile links from retained cited entries; explicit overrides remain intact.
- Generated excerpts keep whole graphemes within 512 characters and 2,048 UTF-8 bytes each, so valid originals cannot overflow generated summaries.
- Home/library voice actions explicitly select a normal conversation while retaining private sessions; direct private voice remains blocked.
- Source screens show personal-store failures/reload before presenting cached citation data.
- Export/picker failures reach visible state; cancellation stays neutral and failed export data remains available for retry.
- The physical edit benchmark exposed repeated-history encoding cost. A compact JSON envelope shares history values; legacy reads, exact Unicode versions, undo, corrupt references and failed writes receive independent regression coverage.
The UI reviewer corrected an inaccurate subfinding: Home already showed `chat.error`; the voice target-selection defect was valid.

Final independent Release packages: LocalMemory **50 functions / 6 suites**, LocalChat **57 functions**, pass.
Five new core probes cover cited-profile propagation/manual overrides, corruption preservation and two Unicode bounds cases.
The Home voice test initially inspected the public history list, which intentionally excludes private sessions; corrected to inspect in-memory state.
Native Release: **69 Swift Testing functions / 14 suites plus one fictional audio XCTest**, pass.
File callback tests cover retained export data, neutral cancellation, failure feedback and unchanged source history.
Initial UI: four connected flows pass after scrolling the native Settings form to reach its offscreen language picker at large text.
Final compact-archive run passes all **69 native functions, the audio fixture XCTest and four UI flows**. A fifth bundled-audio/private transition passes; the recording opens a normal voice chat and the separate private draft resumes exactly.
The extra UI test initially resumed during transcription and then assumed reused audio must still be pending. It now cancels the active phase and accepts the expected idempotent completed conversation. A stricter nested accessibility-ID query was not exposed by the native hierarchy; the existing voice message/control query replaces it. These were test errors; no product repair followed.
Strict Swift formatting across all 40 existing changed Swift files and `git diff --check` pass.
Palette calculation: secondary text/canvas **8.85:1**, secondary/panel **8.40:1**; this does not qualify material/native-control contrast.
No new SDK, model, provider, license or remote data flow. Cloud/account isolation is N/A for unchanged local scope.

Physical baseline/candidate: paired **iPhone 15 Pro Max, iOS 27.0.1**, Xcode 27.2 / Swift 6.4.2, Release arm64.
The isolated `com.eros.memoryos.group7verification` app uses temporary fictional storage; canonical app/history stay intact.
Each dataset has 100/1,000 short sources, source-backed entries, one conversation excerpt and 50 full undo graphs.
Three fixture repetitions produce 90 timed edits; each also measures fresh-actor and warm-new-actor file reopen.
Filesystem caches are not flushed; these are archive reopen timings, not process launch or power-on cold reads.

| Sources | Baseline edit p95 | Candidate edit p95 | Candidate reopen median fresh / warm | Candidate archive |
| --- | --- | --- | --- | --- |
| 100 | 40.46 ms | 10.68 ms | 10.89 / 11.01 ms | ~119 KB |
| 1,000 | 414.86 ms (**FAIL**) | 94.19 ms (**PASS**) | 115.33 / 116.86 ms | ~1.02 MB |

Targets remain edit p95 <250 ms and median reopen <1 s. All candidate thresholds and source/reopen integrity assertions pass.
At 1,000 sources the baseline archive was ~16.87 MB; candidate endpoints RSS growth was 25.33 / 0.57 / 0.64 MB.
RSS includes XCTest and retained test snapshots, not isolated graph allocation, peak memory or proof of no leaks.
Candidate thermal endpoints were fair before/after all repetitions. Baseline thermal state was not recorded; no energy/causality claim.
Complete file/directory protection attributes and backup exclusion pass on the phone; locked-device access remains unqualified.
Host diagnosis isolated JSON encoding (~382 ms) from atomic writes (~9 ms); binary plist was slower and rejected.
A physical Time Profiler attachment rejected both verified PID and process name; no trace or stack shares were produced.
Independent codec checks cover legacy no-rewrite load, migration/reopen/export/undo, exact Unicode history, ten tamper cases and failed writes.
Unsigned generic-iOS Release analysis passes on the final production source; no Swift-source warnings.

## Step 2 verdict and retention

| Applicable check | Verdict and evidence |
| --- | --- |
| Requirements 1–3: originals / meaning / unresolved captures | PASS: exact bytes, IDs, idempotency, clarification and no-derivation tests; runtime capture/relaunch. |
| Requirement 4: reversible organization | PASS: repaired profile provenance and Unicode bounds; categories, summaries, history and undo probes. |
| Requirements 5–11: identities / confirmation / profiles / projects / images / questions | PASS within tested scope: independent core and native/UI checks. Conservative rule quality stays explicit. |
| Requirements 12–13: private lifecycle | PASS within tested scope: no-write projection, draft retention, background/restart/end and normal-audio target tests. |
| MVVM / dependency direction / app-owned adapters | PASS: independent action traces, package builds, injected interfaces and actual codec inspection. |
| Upstream ownership / assets / licensing | PASS unchanged pins; new adoption and cloud/account checks N/A because no dependency or remote flow changed. |
| Arabic / English / offline / recovery | PASS tested local cases; legacy upgrade, readable backup, full history, failed writes and corrupt-file refusal. No model-quality claim. |
| Selected physical latency / storage | PASS above; metadata protection/backup flags pass. |
| iOS 18 / locked-device access | iOS 18 testing WITHDRAWN by owner on November 18 for this task, not passed; deployment target unchanged. Locked-device enforcement remains BLOCKED pending owner run of the isolated probe below. |
| Energy / sustained thermal qualification | BLOCKED: energy unmeasured; endpoint thermal observations have no agreed sustained threshold. |
| Owner visual acceptance | Separate, not supplied by screenshots or tests. |

Final ordered 41-Swift-file source digest (same Step 1 algorithm): `b853db8bfbfab8bdbcb75b0f2e4325a7bedf1e20939b37fd6b786bb84d99436a`.
Final Release Simulator binary SHA256: `92f9fd529065513c7101dfe107f432424740aae294c236b6e4cd1f99acfec215`.
Selected [benchmark metrics](../evidence/personal-memory-step2-2026-11-18/benchmarks.json) preserve both the failed baseline and passing candidate.
New dark iPhone 18 Pro / iOS 27.2 **Simulator** captures use fictional data and the final Release app:
[clarification](../evidence/personal-memory-step2-2026-11-18/clarification.png), [source](../evidence/personal-memory-step2-2026-11-18/source.png),
[temporary](../evidence/personal-memory-step2-2026-11-18/temporary.png), [Arabic profile](../evidence/personal-memory-step2-2026-11-18/profile-ar.png).
Native accessibility refs exposed named controls; one stale ref required the advised fresh snapshot. This is not a VoiceOver announcement audit.

Step 2 cleanup targets: **1,147,576 → 0 KiB**, **13,252 generated files** removed; retained canonical Simulator build **781,040 KiB**.
Removed two package caches, resolved scoped recall/build/test/profiler diagnostics, the isolated physical-project copy and retry bundles.
Retained all source/tests, original research, app histories, prior unique evidence, four new captures and compact metrics; **363** unchanged tracked documentation/resource hashes and all five selected-evidence hashes match.
Lock-test follow-up, November 18: [isolated harness](../../native/MemoryOSLockTest/LockTestApp.swift) installed as **MemoryOS Lock Test** (`com.eros.memoryos.locktest`); production writer creates fictional data in its own sandbox. Two independent review findings repaired/rechecked: reject Simulator qualification; end background allowance on expiration and check cancellation after probe hops. Signed phone and Simulator Release builds/strict format pass; no Swift warnings. [Dark Simulator guard capture](../evidence/personal-memory-step2-2026-11-18/lock-test-simulator.png) is UI evidence only. Fresh POSIX deny/control and unlocked hash/repository checks await the owner. Production app/package source and prior benchmark binary unchanged. Skills: existing SwiftUI/concurrency/testing paths plus `.agents/skills/axiom-security/SKILL.md`. Step 2 stays BLOCKED; Step 3 not started.

## Greeting clarification repair, November 18

Owner's fictional greeting exposed the classifier treating unknown conversational text as unresolved memory intent; the receipt replaced generation. The diagnosis skill added a red regression: 14/16 initial cases failed, including English/Arabic greetings.
The domain now recognizes bounded social/request forms, retains originals without derived entries, preserves mixed tentative clauses, and uses computed `effectiveKind` for old unanswered greetings without a disk rewrite or overriding explicit owner meanings.
Independent reviewer closed sentence-boundary, capture-word and normalized Arabic/conjunction findings. Release LocalMemory: **53 functions / 6 suites PASS**; native: **70 functions / 14 suites plus one audio fixture XCTest PASS**. Real recorder → chat → model-spy cases prove greeting/request generation.
Runtime: **two UI flows PASS** on iPhone 18 Pro / iOS 27.2 Simulator: greeting/original/meaning (35.212 s) and ambiguity/resolution/relaunch (44.650 s). [New dark source capture](../evidence/personal-memory-step2-2026-11-18/greeting-source.png). UI retries repaired offscreen/merged row selectors and startup navigation; preliminary runs were cancelled for source-review repairs. Prior benchmarks retain their dated source identity; no new generation/phone latency claim.
Identity: final 44-file Swift digest including lock harness/deletion `5776016c0afa5c511d5370dd87ac22ba6e05f70eb5426584e8b42fcfa4186ae1`; Simulator binary `fced908cb03b9a5970b2b36248dc08f0d403cff41417378547ce3645c1481fdb`; phone binary `7f1d7efdfb649f1899a6038b04af3fffe246554fb249678734dfd72b18df2eab`. Signed Release installed over `com.eros.memoryos.demo` without uninstalling; Release generic-iOS analysis passes. Existing unrelated unnecessary-await warning in `ChatResponsivenessProbe.swift` remains.
Cleanup: scratch targets **738,704 → 0 KiB**, **6,271 generated files removed**; relocated/retained signed phone app **211,076 KiB** at `/tmp/memoryos-group7/phone/MemoryOS.app`, canonical Simulator build, active lock-probe builds, app histories, source and selected evidence. Resolved logs/retries were compacted above before removal. Lock enforcement and energy/sustained thermal qualification stay open; iOS 18 testing stays withdrawn. No Step 3 starts.
