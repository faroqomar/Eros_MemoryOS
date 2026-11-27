# Source-backed understanding and personal organization

Status: Step 2 continued on November 24. Source repairs and the six-case default search regression pass, but required relationship meaning remains failed. No Step 2 or model-quality pass. Original owner request: checklist groups 8 and 9, 2026-11-18.
Starting source: `e5735fa4e0bb98bab1762609724f8c270aa98be2` on `feat/personal-memory-local-recall`.
Owner continuation, 2026-11-19: repair in-scope blockers and complete Step 2 without questions. Skip physical-device checks and list them at handback. Step 3, publication and release remain outside this request.
Owner continuation, 2026-11-23: repair all active blockers and improve model accuracy and response speed. Reproduce the three Arabic failures, freeze fresh independent role/event/timeline cases, and measure response latency separately from correctness. Physical-device skip and Step 2 scope remain in force. The owner later requested continued app, codebase and flow improvements while the candidate downloads; this extends the same verified Step 2 work, not delivery scope.

## Scope and acceptance

- Search current app-owned sources with keyword, semantic and linked-record retrieval; compare known answers without treating substitute tests as model-quality proof.
- Inspect original text, dates, surrounding conversation and current corrections; distinguish originals, extracted reports, owner confirmation and AI hypotheses.
- Analyze selected discussions, agreements, disagreements, unresolved issues, commitments, repair attempts and change over time with exact source citations.
- Support partner, friend, family and colleague contexts from either participant's available history; describe missing/one-sided context.
- Keep emotional/communication interpretations revisable, with alternatives and counterevidence; do not diagnose or assert hidden motives.
- Ask for clarification before substantive advice when the owner's account conflicts with messages. Preserve both accounts.
- Offer evidenced options/tradeoffs and requested-only drafts; no sending capability. Surface relevant insights in-app.
- Project source-linked conversation, topic and period summaries from current originals. Reject stale analysis after correction/deletion.
- Navigate real BrainMap records and sources. Keep the connected understanding path offline with no cloud fallback.
- Persist birthdays with partial dates and corrections. Let the user choose per-person notification/calendar behavior, exact timezone/time/recurrence and explicit schedule approval.
- Retain exact approval across deliveries; require approval for changed scope. Handle denied permissions, retries and duplicates.
- Inspect, edit, test, disable and undo supported organization rules. Save named views over current records.
- Keep anniversaries and broader external actions outside this implementation.

## Architecture and skills

Main owns composition, relationship adapter/presentation, integration and builder evidence.
Scoped C33 agents own relationship core contracts, search/BrainMap and organization respectively.
No new engine/service is selected. The existing 4B, Wax and Cactus remain experimental. November 23 adds a pinned Qwen3.5 4B text-only candidate evaluation under the accuracy/speed repair request; the app default stays unchanged until qualification.
Automatic extraction writes remain disabled. Physical-phone testing remains paused under existing instructions.
Existing unrelated untracked evidence and `output/` stay untouched.

Selected paths and reasons:

- `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md`: project-only recall and reviewed Markdown delivery.
- `/Users/eros/.codex/skills/mattpocock-implement/SKILL.md`: authorized implementation; project stage limits override generic commit advice.
- `/Users/eros/.codex/skills/mattpocock-tdd/SKILL.md`: behavioral checks at public seams; avoid implementation-mirroring assertions.
- `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md`: builder boundary inspection; this is not independent Step 2 verification.
- `.agents/skills/swiftui-expert-skill/SKILL.md`: observable state, native controls and view composition.
- `.agents/skills/swift-testing-expert/SKILL.md`: public use-case, adapter and feature-state tests with fictional records.
- `.agents/skills/swift-concurrency/SKILL.md`: cancellation, actor isolation and stale-result rejection.
- `.agents/skills/swiftui-performance-audit/SKILL.md`: measured resident memory, request latency and interruption cleanup.
- `.agents/skills/ux-navigation/SKILL.md`: inspectable source links and hidden-sidebar navigation. `.agents/skills/ux-error-recovery/SKILL.md` and `.agents/skills/ux-empty-states/SKILL.md` cover missing/deleted records, model import, and retry without lost input.
- `.agents/skills/axiom-accessibility/SKILL.md`: labels, Dynamic Type and touch controls.
- `.agents/skills/swift-package-manager/SKILL.md`: justified app-owned organization target, no vendor adoption.
- `.agents/skills/axiom-security/SKILL.md`: protected storage and explicit calendar/notification actions.
- `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md`: bounded reproduction and falsifiable semantic/runtime hypotheses for the November 23 repair; keep existing failed evidence and source-preservation gates.

MVVM mapping: new feature Views render injected ViewModels; ViewModels coordinate app-owned use cases.
`MemoryCore/Relationship*` owns interpretation rules and source validation. A composition adapter alone calls `StructuredChatModel`.
`Domain/MemorySearch*` owns current snapshot/search projections; composition owns existing retrieval adapters.
`LocalOrganization` owns versioned birthday/rule/view state, exact approvals and persistence contracts; native adapters own OS APIs.
Existing `PersonalMemoryUseCases` owns original sources, revisions and reversible metadata changes.
All domain targets remain independent of SwiftUI, provider SDKs and concrete persistence.

## Builder checks and targets

Test public seams already required by Step 1: source-validating understanding use case, current-snapshot search, schedule approval/recovery, rule apply/undo and ViewModel state transitions.
Run Release LocalMemory/LocalOrganization tests, native affected tests, Simulator compilation/static analysis and selected connected UI checks.
Use Swift 6 strict concurrency with current Xcode 27.2 / Swift 6.4.2; retain iOS 18 deployment target.
New APIs require current primary Apple/Swift documentation when their behavior is uncertain.
Use fictional English/Arabic cases; reject prompt instructions in source data and fabricated source IDs/quotes.
Bound selected-context analysis; refuse excess input rather than hide truncation. No full-history psychological-accuracy claim.
Target pure current-source projections at 1,000 short sources: p95 under 250 ms on host/Simulator, five runs after warmup.
Measure actual 4B finite-case quality and elapsed time separately; every asserted observation must cite an exact offered quote.
Physical latency, battery and sustained heat remain unmeasured and require later qualification.

## Builder repairs and API checks

- Repeated conversation sorting exceeded the unchanged 250 ms projection target (413 ms). Sorting each conversation once reduced the measured 1,000-source result to 3.7 ms.
- A stale-result feature check found an invalidation-order bug; preserve the old result before intersecting selected IDs. Affected feature tests now pass.
- The initial undo UI check tested existence before asynchronous removal. Use a removal expectation and named controls; preserve other saved applications. Repeated selector-only retries did not diagnose the persistent failure.
- Failure hierarchy then proved a real custom-tab bug: default List row button behavior opened the editor when opening a view. Apply borderless styles to isolate open/edit/delete actions. The regression asserts that opening neither edits nor deletes the tab. Those assertions pass after repair. Freeze the undo receipt ID before tapping: a live first-match query otherwise retargets the next older receipt. The final connected rerun passes through undo, BrainMap, search and saved-item navigation.
- Search kept its keyboard over result links after submission. Explicit focus dismissal and interactive scroll dismissal restore source access.
- Reject drafts without an evidenced finding. Exact quote validation remains independent of the grammar that constrains model quotations.
- Native schedules use Apple's [notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app), [calendar triggers](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) and [EventKit access](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui). Calendar integration accepts only writable on-device calendars; no silent synced-account fallback.
- Annual schedules fix Gregorian date, time and timezone. Feb 29 skips nonleap years. The OS owns delivery after exact approval; correction cancels old behavior before reapproval.
- Category rules require explicit test/apply. Durable receipts support retry and undo after failure. Named views filter current entries; they do not duplicate the original store.

## Step 1 results and gates (historical)

Implemented: independent relationship contracts and exact-source validation; current-source search/BrainMap; native relationship ViewModel and local adapter; persisted birthday/schedule/rule/view use cases and OS adapters. Views forward actions to injected use cases. Provider SDKs remain in composition/integration targets.
Release packages: LocalMemory 115 tests pass; LocalOrganization 11 pass; retrieval 12 execute/pass, five optional checks skip. All 17 final affected native tests pass, including real OS notification trigger/timezone, stable-ID replacement and removal. Builder UI checks exposed inherited identifiers and the row-action defect above. Show the rule name on each undo receipt. Both connected UI flows pass: partial birthday correction/approval/disable/relaunch, and rule test/apply/custom view/undo/BrainMap/search. Final Release Simulator compilation, analysis and strict formatting of 45 Swift files pass. Existing upstream header/dSYM and test-host duplicate-class warnings remain; these runs do not qualify the upstream dependencies.
Actual local 4B trials fail: initial 1/4 passes (two runtime errors); repaired six-case trial 1/6 passes (three rejected outputs), 103.9 seconds total. Only Arabic uncertainty handling passes the repaired trial. Agreement/injection handling and conflict/draft/topic requests do not meet their frozen criteria. These are consumed builder inputs, not independent qualification. Every returned proposal used exact offered quotations; this does not establish interpretation accuracy. Keep the failed gate and experimental UI label.
Known-answer retrieval, eight records/six queries under host deny-network isolation: keyword 4/6 exact sets, semantic 1/6 (only the empty-result case), linked 4/6. Semantic finds none of five expected relevant records; no promotion follows. Keyword remains default. Linked mode follows saved edges and labels context. See [compact results](../evidence/understanding-organization-2026-11-18/results.json) and [search comparison](../evidence/understanding-organization-2026-11-18/search-comparison.json).
The source-backed workflow uses bundled local inference and rebuildable local indexes; network-isolated connected Simulator qualification remains open. Calendar OS delivery, notification firing time and physical performance remain unverified. Organization backup/export integration remains a production recovery gap.
Dark screenshots: eight [selected captures](../evidence/understanding-organization-2026-11-18/) from the actual iPhone 18 Pro Max / iOS 27.2 Simulator, November 19. Fictional data only. Source/binary identities are in compact results. Arabic RTL and accessibility-medium text remain readable in the captured state; restore English/large afterward. This is a basic builder check, not an accessibility audit. A live one-source analysis rejects unsupported output and saves no interpretation; the failure capture is retained.
Independent Step 2, owner visual acceptance, supported-device qualification and delivery remain separate.
Earlier 4B retrieval baseline remains failed at 10/12; this task must not relabel that result.
Evidence guard and relative-link checks pass. The final memory-delivery receipt is in the linked compact results.
Step 2 cleanup will inspect tracked, untracked and ignored files; no unrelated cleanup is authorized here.

Storage baseline: app source 1,316 KiB, LocalMemory source tree 348 KiB, task records 268 KiB (`du -sk`, 2026-11-18).

## Step 1 handback and retention (historical)

Explicit Keep preserves the owner's account as its own original and confirmed interpretation beside linked evidence. Generated reports remain rebuildable, revision-bound local artifacts. Source changes invalidate reports and ranking caches; a failed purge blocks the personal-memory mutation.
Selected context is bounded to 40 originals / 48 KB in the domain; the current 4B adapter further limits its encoded payload to 3,500 bytes and the existing 2,048-token runtime context. Oversize requests refuse without hidden truncation. These limits do not establish complete-history understanding.
Cleanup removed 16 resolved diagnostic artifacts totaling 347,433,059 bytes, plus the agent's 219,987,506-byte search harness. Compact failures and selected results remain. Final failed-model and passing connected-test bundles stay outside the repository as selected proof. Active shared build caches, unrelated concurrent documents, original research and app-owned history remain.
Post-build storage (`du -sk`): app 1,436 KiB; LocalMemory 266,088 KiB; LocalOrganization 178,860 KiB; task records 284 KiB. Package totals include retained active build caches; these are not source-size measurements. Compact results own final evidence usage and memory-delivery receipts.
No commit, push, merge, Step 2 qualification or release occurs in this Step 1 task. Model-quality findings, calendar delivery, production recovery and connected network isolation remain open.

## Step 2 continuation

Skills reassessed: the existing Swift/UI/security/test skills remain applicable; `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md` supplies bounded probes and repairs. `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md` supplies separate standards and requirements reviews. Current-turn project recall completed; a correction separates the stale group-7 initiative from this task.
Main coordinates source, builds, model runs and evidence. Scoped builders repair search and organization. Independent verifiers inspect actual source and results. The owner skips physical-device checks for this stage; no phone interaction occurs.

Engineering repairs:

- Keep exact quote-sized passages with full original input context. Use selected focus, account-conflict preflight, cited-only meaning audit and one bounded retry. Reject stale results after input/correction/deletion; restore saved-report controls. Model audit remains probabilistic.
- Search ranks local candidates, constrains literal subjects and app-owned identity membership, then checks topic relevance. A query-only resolver separates a name, a generic question and unresolved identity. Unresolved identity shows a recovery message; it does not become an empty result or another person's memory.
- Organization archives support empty-store restore after the referenced personal backup. Restored approvals retain history with delivery disabled. Format 2 migrates format 1 without replacing IDs or data; unsupported formats refuse without reset.
- Persist pending installation intent before OS writes. Inspect unknown outcomes before cleanup/retry. Preserve external conflicts as reviewRequired; old previews cannot overwrite them. A fresh revision-bound review or explicit disable supplies authorization. If rollback and its receipt both fail and actual behavior conflicts, require review rather than claim automatic cancellation.
- EventKit changed implicit February 29 recurrence to last-February-day behavior. Explicit month/day recurrence and post-save verification fix that defect. Validate every occurrence; refresh objects after each deletion so a removed master cannot leave stale detached exceptions. Require progress, valid permission and verified absence.
- Remove the failed source-reader, event-kind hardlock and bounded-reasoning experiments. The same 4B asset failed at 256/512/1,024 preparation tokens, including 4,096 context; useful runtime contract checks did not establish meaning. Keep only structural-token refusal in the ordinary 2,048-token runtime. No new model/provider/cloud connection.

Verification:

- LocalMemory Release: 115 functions pass; unchanged relevant source evidence reused. LocalOrganization Release: 22 functions pass, including migration, conflicts, failed outcome saves and reopen recovery.
- Final affected native run: 65 functions/7 suites pass in 84.212 s. Actual Calendar expansion produces 2028/2032 leap days, skips 2029–2031, rejects the later edited occurrence without overwriting it and cancels the series. An actual annual notification delivers; OS date delta is 0 s. These are Simulator results, not phone delivery guarantees.
- Projection of 1,000 originals: five post-warm runs, p95/max 5.004 ms against 250 ms target. Four unchanged ordinary-chat scenarios pass. Structural-token refusal passes five controlled functions and one actual existing-model SDK contract.
- Search: repaired consumed independent corpus 6/6 exact sets, 126.164 s. Same eight-record builder comparison: keyword 4/6, semantic 6/6, linked 4/6. Keyword/linked miss the two nonliteral queries; no false positives. Semantic median is 33.134 s versus keyword 1.35 ms. Keep keyword default and semantic explicit; this finite result does not qualify general retrieval.
- Connected host workflow passes four stages with kernel network denial in 92.564 s. Actual Simulator repositories/models pass search, report persistence/reopen, correction/deletion/rebuild under injected public-network API failures in 93.641 s; workflow counter stays 15→15. The Simulator kernel-policy attempt remains unavailable. Fault injection plus host proof does not close group 16 full-app disconnection/no-egress qualification.
- Relationship meaning remains failed: final ordinary Simulator trial is 2/3 automatic but 0/3 manual. It invents a client, calls an unanswered request a commitment and changes the offered action. Exact quotations and the model audit do not repair those errors. Preserve earlier twelve-case manual 6/12 and 8/12 results as historical; do not rerun the broad trial while the targeted regression fails.
- Final Release build, analysis, linkage and strict formatting pass. Both connected UI flows pass (205.759 s). Explicit English/Arabic month/day labels pass the targeted birthday rerun (75.427 s). Its first attempt exposed an offscreen fixture in the native picker; the test now scrolls to the unchanged identity before selecting it. Final dark captures use the actual final binary.

The compact [Step 2 receipt](../evidence/understanding-organization-2026-11-18/step2-results.json) retains failures and source identities. Step 3, merge, owner visual acceptance and release remain separate. Physical iPhone latency, heat/battery, protected-file behavior and actual phone reminder delivery are skipped, not passed; remind the owner at handback.

## Step 2 handback and retention

Four [final dark captures](../evidence/understanding-organization-2026-11-18/step2-source-search.png) show source layers/dates, experimental analysis controls, exact annual approval and organization recovery. Capture filenames and final native/source/binary identities are in the compact receipt; all use fictional data on iPhone 18 Pro Max / iOS 27.2 Simulator. No screenshot implies model-quality or owner visual acceptance.
Cleanup removed five reproducible cache/intermediate directories and 130 resolved external diagnostic entries/files, totaling 2,077,011,459 logical bytes. Selected cache usage fell from 999,992 KiB to zero; resolved external directories occupied 1,122,580 KiB before removal. Preserve final app Products, pinned SDK/model inputs, original research, ten unchanged Step 1 evidence files, Simulator history, unrelated active work and the unresolved fidelity bundle/selected proof logs. The earlier temporary native prototype test is removed; its unmeasured size is excluded.
Evidence/relative-link and source-preservation checks govern handback. Memory sync/check and useful recall status are recorded in the compact receipt after the final Markdown delivery; zero pending/failed operations is required before claiming delivery. No commit, push, merge, publication or release occurs in Step 2.

## Earlier November 23–24 repair checkpoints

The canonical receipts retain these historical results and source identities; they are not current qualification. Repairs addressed source passage IDs, actor/context boundaries, report concurrency, organization provenance, birthday approval, protected model import and original-only projections. Core127, organization34 and native159 checks passed at intermediate states. The disabled identity-hint comparison scored baseline10/12 versus hints11/12; both missed a multi-person query. Host source projection preserved IDs/dates/UTF8 across100 alternating pairs (0.133ms median versus6.419ms full graph). Physical performance remains unmeasured.

The Qwen3.5 download resumed from existing parts, passed exact bytes/SHA and three native runtime contracts, but remained unqualified. Initial native191 controls passed while default search scored4/6. Fourteen then-fresh app cases gave5full/7failed/1partial/1limited storage pass; relationship3/8 despite12/12exact quotes. The later repair passed192native controls and restored6/6original search plus3named probes. Eight paired diagnostic cases scored default4full/4failed and candidate4full/1partial/3failed; relationship0/4and1/4. Neither qualified. Compact original results, import timings, source hashes, captures and cleanup remain in [step2-results](../evidence/understanding-organization-2026-11-18/step2-results.json) and the [Astra receipt](../evidence/understanding-organization-2026-11-18/step2-astra-evaluation.json).

The published pilot preserves all14 selected cases:2timeouts,1grammar failure,1interrupted,10not started,0scoreable answers. A repaired grammar replay stopped at false clarification; another timed out303.166s including263.056s indexing/ranking. Supports reached candidates, but retrieval/answer stayed incomplete. The [evaluation guide](../../scripts/evaluation/README.md) retains full histories, frozen selections, separate labels and300sdeadline. No official judge ran. LoCoMo/PersonaMem-v3 are noncommercial; LoCoMo-Plus extension rights remain unverified with restricted base; RealCompanion bars this product use. None was fetched. PersonaMemv1 remains optional/unrun. Corrected-date, speed and group replays remain consumed diagnostics. The second repair removed227,637,780logical bytes and completed independent review/memory delivery; current blockers below remain open.

## Renewed November 24 repair: required blockers remain

The main agent coordinated focused index/relationship builders and a fresh independent verifier in the existing root checkout. Skills: `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md`, project `swift-testing-expert`, `swift-concurrency`, `axiom-security`, `swiftui-expert-skill` and `ux-error-recovery` entry points. Required project recall succeeded; current source supersedes the stale groups 8–9 memory page. The canonical receipt separates historical runs and final source/binary identities.

Retained repairs address generic subject extraction, faithful dated chat wording, protected 32-vector checkpoints, bounded malformed-proposal recovery, validated citation deduplication, explicit processing errors and question scope/legacy reopening. Default search passes 6/6 original cases, 3/3 named probes and 3/3 generic probes. The original group question now passes all people/day restrictions with exact two sources in 43.919 seconds. Cache tests retain 32 of 64 completed vectors after cancellation and embed only the remaining 32 on resume; unchanged reopen embeds zero, a correction one. Worker-count and Wax measurements do not justify a throughput change. Failed structured-reading, claim-audit and direct-intent experiments were removed; their failed outcomes and unique source snapshots remain available.

Final Release build, analysis, inference linkage, formatting and whitespace checks pass. Final controlled checks: 196 native functions/26 suites, 68 ChatCore functions, 13 cache functions and 10 evaluation-tooling tests. These verify contracts, not semantic quality. The final consumed relationship set has 0 full/5 failed: four processing rejections and one partly useful response with unsupported change-over-time classification. The only later source change before fresh evaluation was neutral English/Arabic error copy.

The independently frozen twelve-case Arabic/English app set ran once per model against final source: default Qwen3 1 full/1 partial/10 failed; candidate Qwen3.5 0 full/2 partial/10 failed. Both have 0/8 full relationship passes. Wrong-person retrieval, missed identity clarification, accepted unsupported meaning and false rejection remain required blockers. Original bytes and zero derived writes pass 12/12 per model; returned quote bytes match, which does not prove meaning. No tuning followed these results. The third unchanged full-history published replay times out at 303.978 seconds, including 266.584 seconds indexing/ranking; retrieval remains incomplete and no answer score exists. Its 29 relevant runtime/retrieval/test files match final source; it is not a whole-final-binary run. Keep the original fourteen-case denominator and restricted-dataset reasons above.

Final dark captures show [analysis progress](../evidence/understanding-organization-2026-11-18/repair3-understand-dark.png), [verification error and retry](../evidence/understanding-organization-2026-11-18/repair3-recovery-dark.png) and [keyword source recovery](../evidence/understanding-organization-2026-11-18/repair3-search-dark.png), using fictional data on iPhone 18 Pro / iOS 27.2 Simulator with the final binary. The live error preserves the question and permits retry; no report was saved. This UI smoke is separate from semantic scoring.

Simulator cleanup incident: after opening the fictional source's delete confirmation, `agent-device alert dismiss` reported dismissal, but the source disappeared and the Simulator's undo events became empty. No explicit delete-confirm command was issued. The existing forget path clears global undo events; the exact automation cause is not established. No validated pre-operation undo backup was found and no recovery is claimed. Remaining counts are 16 sources, 15 entries, 4 profiles, 0 links and 0 undo events; without a pre-operation baseline, remaining records are not claimed byte-unchanged. The physical phone and its history were untouched. No blanket reset/restore occurred. This incident is separate from the frozen-case preservation checks and requires follow-up before further destructive UI checks.

Cleanup removed 30,138,545 logical bytes across this repair. The final selected batch fell from 8,834,970 logical bytes (24,416,256 allocated) to zero; 30 retained critical hashes match before/after. Retained exceptions include pinned assets, original research/source, unrelated work, shared caches, unique failed trials and source snapshots, frozen inputs/labels and final verification evidence. Evidence and 93 relative links pass. The canonical receipt owns the final independent review and Markdown memory delivery status; delivery remains pending until sync/check and useful recall complete. Step 2 remains blocked; candidate adoption, automatic derived writes, Step 3 and release remain unauthorized. Physical checks remain owner-skipped, not passed.


## November 24 cross-thread diagnosis and safety repair

Owner request: investigate the recovery thread and implement feasible Step 2 repairs. Keep the same app, model selection, local-only boundary and paused physical checks; no Step 3. Main owns the alert/UI and integration; focused agents own retrieval and sampler diagnosis; a fresh verifier checks final source and evidence. The diagnosis, Swift testing/concurrency and SwiftUI skills listed above apply. Acceptance requires explicit safe cancellation, unchanged stored history after cancellation, source-preserving owner filtering, faithful semantic answers and the unchanged cold-history deadline.

The device runner has a concrete unsafe fallback: `RunnerAlertButtonChoice.buttonIndex` can select the last popup action when dismiss finds no recognized Cancel label. This explains a possible failure mechanism, not the exact historical trigger. Replace the source deletion confirmation with a native alert and explicit Cancel/Forget identifiers. Warn in English and Arabic that permanent forgetting clears **all** personal-memory undo history, including unrelated changes. The existing permanent-erasure policy remains; no recovery of the earlier lost Simulator history is claimed.

A single-variable ownership-instruction experiment still retrieved the unrelated person in the exact consumed full-app key-location case (62.319 s); eleven other frozen rows remain explicitly not run. Remove that unsuccessful paragraph and redundant transport tests. The gated trace regression remains to expose the failure. A raw-source baseline also exposes a different failure before relevance: extracted names are empty but the resolver answers `complete`. Keep that failure separate from the exact consumed full-app wrong-owner replay.

The runtime adds explicitly injected, seeded Qwen3/Qwen3.5 non-thinking sampling profiles for local evaluation. App defaults and fixed-setting evaluation stay greedy. Model-card recommendations justify comparison, not a claim that greedy violates the current non-thinking contract. No prompt, grammar, taxonomy or seed tuning accompanies the relationship comparison. Both sampled consumed cases still end in `invalidEvidence`; the exact paired Thursday case remains incorrect. Contract success does not change the failed semantic gate.

A current-source benchmark audit confirms that 736 independent Cactus embeddings dominate cold import: indexing/ranking takes 266.584 of 300 seconds. Native inference accounts for 99.79% of measured embedding-plus-tokenization time. The reviewed API exposes no independent masked batch; concatenating histories changes vectors. Existing worker/Wax probes give no throughput remedy. Keep the deadline, full histories, failed denominator and rights holds unchanged. A different local model, proven upstream acceleration or a separately approved ingestion/evaluation change requires a new bounded plan.

Final analysis/build/linkage/formatting and 200 native controls pass. Cancellation UI passes in 44.942 s; the entire 18,437-byte Simulator store has the same SHA before Cancel, after Cancel and after relaunch. The [English](../evidence/understanding-organization-2026-11-18/diagnosis-cancel-dark.png) and [Arabic](../evidence/understanding-organization-2026-11-18/diagnosis-cancel-ar-dark.png) dark alert captures uses unchanged final UI source; its binary boundary is explicit. Exact source identities, independent verdict, cleanup and delivery are recorded in `currentDiagnosis` in the [canonical receipt](../evidence/understanding-organization-2026-11-18/step2-astra-evaluation.json). Required semantic and benchmark blockers remain open; physical checks remain skipped, not passed.
