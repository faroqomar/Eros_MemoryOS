# Group 7 follow-up: automatic, source-backed personal memory

Status: pipeline implementation verified with explicit limits; automatic-write adoption blocked by failed model quality. The owner requested research and implementation on November 18.
Scope: improve checklist group 7; this supersedes its rule-based normal-chat organization path.
Previous results remain dated evidence in the [group 7 task](2026-11-17-lasting-personal-memory.md).
Connected Step 3 draft delivery is now authorized; see the [current task](2026-11-18-qwen4b-conversation.md). Failed qualification still blocks merge. No cloud connection, new import service or release starts.

## Outcome and authority

Normal conversation should create useful, inspectable memories without making the owner classify each message.
The owner rejected the current implementation as inauthentic and asked to study other projects and implement a better approach.
Preserve original messages, existing phone history, temporary-chat privacy and confirmation for protected changes.
[Personal-context decisions](../decisions/personal-context-goal.md) remain authoritative alongside this current request.

## Research and selected approach

[Primary-source research](../reference/2026-11-18-automatic-memory-patterns.md) examines pinned Mem0, Memobase and Hindsight source.
Use recent conversational context, source-grounded semantic proposals, duplicate checks and reversible temporal updates.
Profiles and dated source/event history remain distinct. Adopt no server, SDK, hosted API or copied upstream implementation.
Reuse the current experimental llama.cpp runtime; grammar constrains syntax, not semantic truth.
The 0.6B/1.7B candidates fail semantic extraction checks. The pinned official Qwen3 4B Q4_K_M follow-up is now evaluated and also fails; no model is adopted.
The owner reconfirmed local-only evaluation; the completed [larger-model worker](t3-thread://v2/f80f8a18-dac8-4f85-ab0b-525d4d497bbd/thread:delegated-task:command%3Amcp%3A0037f5fa-9ef9-49df-a4c2-a4fbdf8c70d5%3Adelegate-task%3A73f17f63-73e7-4b90-b9fe-0d1cdb2085da) owned only the resumable download and external evaluation results.
Source revision `bc640142c66e1fdd12af0bd68f40445458f3869b`, Apache-2.0, 2,497,280,256 bytes; SHA-256 `7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5`.
Only public weights are downloaded. No conversation leaves the device/host; quality and physical memory/performance gates still apply.
No keyword or greeting list may stand in for a semantic extractor when inference fails.
Only original user sources can support personal claims. Assistant suggestions are not adopted decisions.

## Skills and ownership

Follow-up skills: `/Users/eros/.agents/skills/docs-sync/SKILL.md` keeps this completed evaluation and failure status current.
Catalog search concerns: semantic extraction, Swift actor cancellation, source ownership, inference security, testing and native recovery.
Selected `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md` for scoped recall;
`mattpocock-research`, `mattpocock-implement` and `mattpocock-tdd` under the same skill root for research and implementation.
Project `.agents/skills/swift-concurrency/SKILL.md`, `swift-testing-expert/SKILL.md` and `swiftui-expert-skill/SKILL.md`
guide actor work, meaningful tests and native state. `axiom-security/SKILL.md` and its agentic-security reference guide untrusted input/output.
Research helper owns only the cited research note. Core helper owns MemoryCore/persistence contracts and tests.
Runtime helper owns structured generation, the shared inference lease and native view changes. Main owns worker/chat/composition integration and evidence.
A fresh verifier who did not implement the change will inspect final behavior, architecture, privacy and recovery.

## Acceptance criteria

- [x] Preserve ordinary user messages with exact bytes, dates and stable source IDs before analysis.
- [x] Keep streamed chat available; background organization must not replace ordinary replies with a generic meaning menu.
- [ ] Extract useful claims from realistic English, Arabic/Iraqi Arabic and mixed ordinary conversations using the actual local model.
- [x] Require exact user-source evidence, valid IDs/types and bounded output before any automatic derived write.
- [ ] Keep reported facts, preferences, goals, tentative material, events and interpretations distinct and correctable.
- [ ] Ask a specific, natural question for material ambiguity; accept an ordinary-language answer linked to its original.
- [x] Deduplicate retries and repeated claims without discarding supporting sources or collapsing distinct events.
- [x] Retain earlier states on updates; never silently overwrite confirmed/user-corrected information or merge people.
- [x] Give foreground chat/speech priority over extraction, sharing one resident local model/runtime.
- [x] Temporary chat creates no durable source, extraction job or derived memory; pause/restart behavior remains intact.
- [x] Malformed, cancelled, unsupported or incomplete analysis preserves originals and exposes retryable state.
- [x] Old archives, corrections, undo, readable export and source links survive the added metadata.

## Architecture and data flow

`LocalMemory/MemoryCore`: original/source values, analyzer protocol, typed proposals, validation and use cases.
`MemorySQLite`: existing protected atomic archive and pooled undo history; no SDK or UI dependency enters the domain.
`ChatCore/StructuredChatModel`: app-owned structured generation interface; runtime adapter implements it through the existing reviewed SDK.
`LlamaTextRuntime`: request-scoped grammar sampler beside unchanged ordinary chat; no second model copy or remote fallback.
`LocalInferenceCoordinator`: one inference lease, background cancellation before foreground chat/speech/unload.
`LocalMemory/PersonalMemoryExtraction`: bounded prompt/strict decoder adapter depending only on MemoryCore and ChatCore.
Native composition injects the shared inference coordinator and enforces the unqualified-model gate.
App-owned processing use case: persisted normal-source backlog, bounded retries and source/revision revalidation before commit.
View → ViewModel → injected use case → app-owned repository/analyzer; Views and ViewModels never call the runtime or database.
Normal source capture precedes generation. Extraction runs after the visible reply and resumes from durable normal originals.
Generated confidence is not a fact probability. Evidence checks establish provenance, not universal semantic accuracy.

## Verification and benchmark plan

Core tests: grounding, identity scope, contradictions, exact Unicode, idempotency, undo, stale results, legacy archives and failed writes.
Runtime tests: grammar/UTF-8/output caps, fresh sampler state, shared lease, foreground preemption and cancellation.
Integration tests: real recorder/worker boundaries with controlled analyzer outcomes; no private-source/job writes.
Actual-model cases: fictional social chatter, paraphrased preferences, people/project facts, pronouns, reported speech,
negation, role-play/venting, changed facts, repeated statements and Arabic/mixed names. Record failures and abstentions.
Safety gate: zero unsupported accepted personal claims in designated safety cases; finite tests do not prove general accuracy.
Use a held-out corpus and report extraction recall separately; target at least 85% expected supported items on the selected corpus.
Measure Release extraction latency, cancellation and interference with foreground work on the intended device when available.
Original preservation stays before analysis; require no wait for extraction in the visible chat completion path.
Existing physical lock/energy qualification remains open; the owner withdrew iOS 18 testing from the current group 7 gate.
The owner now skips further physical-phone tests. A test that had already started passed 100 sources but failed 1,000 sources at the retained-state budget; repair/recheck stays on host/Simulator.

## Results and delivery

Independent actual 1.7B validation fails: 8/18 cases, 3/11 complete claims, 5 accepted meaning/metadata/attribution mismatches; host p95 7.08 s.
The production qualification flag stays false. The gate calls no model and mutates no original, status or undo history; normal chat still preserves originals.
The verified 4B follow-up completed all 38 cases without runtime errors, but failed both quality suites. Independent: 9/18 cases, 3/11 complete claims, 1 accepted mismatch, host p95 23.64 s; development: 12/20 cases, 6/12 claims, 2 accepted mismatches, p95 19.22 s.
All 74 pre/post source/runtime/test hashes stayed unchanged. The host helper sampled RSS reached 4.410 GB; this is not an exact peak or phone result. The approximately 8.15-hour download recovered retained partials and passed full size/SHA verification.
Automatic writes remain disabled. The bounded diagnosis found routing restrictions; the isolated repair trial below retains the disabled gate. No further model download, phone work or cloud integration starts.
Independent final 85 core + 10 extraction functions pass. Core/archive checks cover provenance, repeat questions after 55 later changes, legacy loading, undo, invalid output and the 1,000-source/50-history regression.
The review repaired inactive-session resumption, lost clarification questions, non-destructive skip, unqualified global retry and repeated state budget charges.
Final source adds a per-call exact-value validation cache; changed classifications, profiles, ambiguity and links still receive graph-specific checks.
Final Simulator Release edits pass: 26.30 ms p95 at 100 sources and 239.37 ms at 1,000 sources, each with 50 retained revisions and 90 edits across 3 repetitions. Fresh-actor reopen medians are 33.00/318.27 ms. Host p95 varies 243–260 ms; no final phone recheck exists.
Native Release 18 unit functions pass, including fresh-pending and pre-existing-deferred gate regressions. Runtime adapter 16 + actual grammar 4 and LocalChat 57 checks pass.
Native UI checks pass normal original capture, temporary draft lifecycle, confirmed profile correction and Arabic large text.
The clarification UI scenario is skipped while model qualification is off; it is not a semantic-runtime pass.
The isolated saved-audio/private-continuity UI test remains failed: cancellation control stayed visible beyond 10 s. Its initial missing fixture was repaired; the later timeout remains unresolved.
No further phone tests run after the owner skip. The earlier 100-source phone attempt passed; 1,000 sources failed before the storage repair. Preserve both results.
See [compact current evidence](../evidence/automatic-memory-2026-11-18/results.json); captures and cleanup receipt follow here.

### Evidence and retained work

Preserve unique prior evidence, upstream source/assets, canonical builds, app-owned histories and unrelated dirty work.
Dark captures: [normal chat](../evidence/automatic-memory-2026-11-18/normal-chat.png), [specific question](../evidence/automatic-memory-2026-11-18/clarification-fixture.png), [answer provenance](../evidence/automatic-memory-2026-11-18/answer-provenance-fixture.png), [Arabic people](../evidence/automatic-memory-2026-11-18/people-ar-fixture.png).
Device: iPhone 18 Pro Simulator/iOS 27.2, Release, dark. Clarification/people use controlled fictional proposals, not a qualified model; normal Hi uses the actual 0.6B chat runtime.
Manual answer submission retained its question/parent link and both existing clear memories. Final capture fingerprints are in the compact evidence; rendered source screens did not change during the later Settings-copy-only repair.
Cleanup: task cache scope before 1,659,260,928 bytes, after 0; 10 directories removed (1,582.39MiB reported footprint), plus resolved profiling/diagnostic output. The model worker removed another 112.28 MiB of redundant scratch/logs and retained the verified public model. Retained exceptions are in the compact evidence.
Evidence guard, local links, formatting and isolated inference linkage pass. The compact evidence records the scoped project-memory delivery receipt. No Step 3 starts.

### Repair trials

Corpora differ; these scores do not establish a before/after quality or latency trend. Frozen source, fixtures, errors and failed-case outcomes are in the [compact receipt](../evidence/automatic-memory-2026-11-18/results.json). Prior trial sets become consumed when used for diagnosis.

| Trial | Cases | Complete claims | Accepted mistakes | Host p95 | Result |
| --- | --- | --- | --- | --- | --- |
| Routing repair, fresh12 | 8/12 | 7/8 | 2 | 17.12s | Fail |
| Acceptance review, fresh20 | 16/20 | 10/12 | 1 | 24.43s | Fail |
| Eligibility repair, fresh20 | 14/20 | 11/13 | 1 | 28.93s | Fail |
| Typed classification, third20 | No completed score | Not measured | Not measured | Not measured | Interrupted at startup, exit143 |
| Structural grammar, fourth20 | 10/20 | 7/13 | 0 | 31.00s | Fail; consumed regression data |

Three fictional probes proved exclusive routing forced clear claims out of clarify responses and forbade abstention from memory responses. Removing that pass repaired the structural limit without weakening extraction/domain checks; mixed-clause red/green tests passed. The fresh12 still accepted invented content and an uncertain clause, asked about a greeting and rejected a linked answer. All75 pre/post source/runtime/fixture hashes stayed unchanged. The [historical dark results capture](../evidence/automatic-memory-2026-11-18/routing-repair-results.png) labels that failed host trial.
The owner then requested repairs for memory and audio. A separate local keep/ask/discard review retained source guards and preserved clear candidates, but semantic review remained probabilistic. Consumed12 reproduction was8/12 cases,7/8 claims,2 mistakes; first review10/12,7/8,0 mistakes. Targeted greeting/linked-answer repairs passed before the fresh20 failed. Its126 pre/post hashes stayed unchanged; no runtime/domain errors explained the quality failure.
A four-case diagnostic found a general Arabic question translated into clarification, a project routine stored as self/plan, both Arabic clauses combined as interpretation, and repeated questioning after a venting answer. Split-clause/project examples and removing the proposed question improved extraction, but the second fresh20 still failed, including an accepted resolved-venting claim. It had one invalidOutput and127 unchanged pre/post hashes.
Skills: `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md` and `mattpocock-tdd/SKILL.md` for reproductions/public seams; `.agents/skills/swift-testing-expert/SKILL.md` for async tests; `axiom-security/SKILL.md` for untrusted source/output boundaries. SwiftUI/concurrency guidance supports the audio helper's state/lease audit; `/Users/eros/.agents/skills/docs-sync/SKILL.md` keeps these records current.

### Audio repair

The pending voice card now renders stopping, removes repeated Cancel and measures monotonic cancellation time. Processing and inference exclusion remain active until real native join. The original recording and paused private draft survive. The prior>10s root cause is unproven; the unchanged binary reproduction completed in about6.6s, so there is no demonstrated native-load preemption or comparative speed claim.
Final fresh-recording/private-flow UI passes within the unchanged10s total budget: acknowledgement1.437s, join6.542s from before tap; elapsed<=10 asserted immediately after join. [Stopping](../evidence/automatic-memory-2026-11-18/audio-stopping.png) and [interrupted/retry](../evidence/automatic-memory-2026-11-18/audio-interrupted.png) are actual dark MemoryOS Check captures on iPhone18Pro Simulator/iOS27.2. The receipt identifies the captured binary/audio source. Device session closed; phone history untouched.
An initial native test launch failed after combined analyze pruned test PlugIns; a separate build-for-testing restored them before native18 and UI passed. Later grammar work reuses the independently checked, unchanged audio/chat/native component evidence.

### Current typed classification and grammar

A second local call now independently labels opaque S0… source spans. It sees no extractor kind, owner, proposed question or M/Q role. Exact agreement on kind, owner/name, event and time retains the original proposal/evidence/update ID. Semantic disagreement defers the original through the existing worker. Excluded content creates no memory; uncertainty or protected-change consent can ask a specific question. Same-model errors can correlate; missing first-stage claims cannot be recovered by this check.
Release88 core+25 extraction+59 chat+18 native functions pass. New extraction regressions cover hidden metadata/roles, ordered complete IDs, real Booleans, metadata disagreement, protected consent, no Q promotion and actual worker deferral/retry with original bytes/dates. Final grammar work reruns25 extraction tests and iOS build/analyze/format/linkage; the verifier justifies reuse of unchanged core/chat/native component evidence.
The T3 restart interrupted consumed4 diagnostics after one completed case. Main and replacement verifier found no surviving inference process, verified128 unchanged hashes/model identity, retained the unknown-exit partial/log, and resumed only remaining10/12/20. Resumed diagnostics exited0 without context/token/runtime errors; Arabic mixed extraction/classification passed, while ordinary-question/project/venting cases remained rejected or mismatched.
A hold crossed an authorized third-suite launch. The verifier stopped only its own process (exit143), preserving startup logs and no completed score/result. That corpus remains interrupted, never relabeled fresh. A new20/13-claim suite froze before grammar edits. New sequencing requires diagnostic completion and a separate explicit fresh-trial signal.
Grammar now enforces the existing decoder's structural rules: exact ordered IDs; self/none owner pairs; nonempty named owners; false episode with empty time; special-kind empty metadata and valid question shape. Prompts, labels, decoder/domain guards,2048/512 limits and6000-byte input bound remain unchanged. The new fixture is `c97d545bf0464bf294daba8f747554f4ac4d6cd104ea17fd67703101b560c598`; final129-file source aggregate is `4d1fb42bf4fd6881f80c22bbce1f979760b72f1897e35429f23959014448928b`. The fourth trial finished:10/20 cases,7/13 complete claims,0 accepted mistakes,p95 31.00s,exit1. All129 pre/post source hashes stayed unchanged; no runtime/context/token/JSON errors explained the ten reproduced failures. This corpus is now consumed regression data; automatic writes stay off.

A direct code finding also repaired fallback confirmations: protected changes previously omitted their topic and both protected/identity prompts were always English. Pure EN/AR letter selection now ignores punctuation and quotes a bounded200-byte whole-Character excerpt; full evidence/protectedID/manual correction/no-merge policy remains. Three public-usecase regressions failed before the fix, then all88 core+25 extraction and18 native functions passed. A fresh verifier independently passed3functions/5scenarios, including Arabic identity, English with an Arabic name and1000combiningmarks. `ux-error-recovery/SKILL.md` guides specific, recoverable wording. No semantic keyword fallback or new model is introduced.

### Evidence and cleanup

Historical routing diagnosis/main/verifier cleanup removed99,741,988/120,381,440/118,448,128 allocated bytes. Current main/audio cleanup removed248,365,056/83,771,392 bytes. Retain verified model assets, canonical builds, original research, app histories, compact failed/unavailable evidence and active verifier work.
Root mistakenly removed two same-name verifier stdout/build logs during the first20 trial. The final structured results, observed exit1 and126 unchanged hashes remain; compile-only exit0/30.06s was observed, but its raw log is lost. Report this evidence limit. Cleanup now requires an exact worker-owned path list after completion, never a prefix assumption.
### Workflow reset and bounded fixes

The owner stopped the experiment loop. Two read-only audits found full trials launched after0/4 and1/4 diagnostics, stale pending status, whole-batch loss on one disagreement, inconsistent self-profile wire types and incomplete legacy protection flags. Main is the sole code writer; one reviewer checks code, the process reviewer checks the launch guard. No new corpus, model, inference layer or scoring change.
The partial-result repair keeps independently agreed original proposals and exact disputed spans. Domain validation prevents overlaps; an optional durable remainder marker survives answer/skip/reopen/export. Extra valid questions defer after the first. A linked answer keeps its exact question context, including legacy fallback. Explicit retry reviews the full source and deduplicates prior claims. Answering one question may leave another disagreement awaiting retry; no generic question is invented.
The input repair uses schema type `self` and the same protection rule as commit: confirmed, owner-corrected or legacy evidence missing. Captured-output and input regressions fail before each fix; deterministic green, independent review and at most three consumed model probes precede any further qualification decision.
`python3 scripts/run-memory-qualification.py --receipt /tmp/memoryos-reset-qualification-gate.json -- <reviewed command>` refuses holds, stale source/review, changed argv/environment/model, red/missing fixed10 regressions and duplicate ownership. It verifies model SHA, stops its owned child on TERM and leaves another owner's lock alone. Gate tests use dummy processes, never inference. Required85% cases/claims and zero mistakes remain unchanged.
Final Release package tests pass91 core+28 extraction functions; the independent process reviewer passes4 guard tests and finds no further scoped defect. Release iOS Simulator compilation and static analysis pass. Unchanged59 chat/18 native functions and the actual audio UI evidence above remain separately reused.
One bounded consumed11/15/19 probe completes1/3 cases/claims,0 accepted mistakes:11 now keeps its preference and asks a specific question;15 still requests consent for an unprotected update;19 still reopens an answered question. Times52.85/36.84/39.57s. Source/fixture/harness/model hashes stay unchanged. This does not isolate the model-input change from partial reconciliation; controlled replay proves the code fix. No further model runs. Both semantic failures remain blocked; no fresh corpus, scorer relaxation or third inference pass.
The [dark host code/results capture](../evidence/automatic-memory-2026-11-18/workflow-reset-results.png) labels the patched source and retained Simulator audio states. Independent cleanup recheck confirms33 exact owned generated paths removed:713,879,552 allocated bytes to0 for those paths; retained capture/result hashes match. Preserve the model, canonical builds, original trace harness, unresolved fictional traces, compact receipts, source/research and app histories. This measures selected allocation, not guaranteed volume free space. Scoped project-memory delivery is recorded in results.json after successful sync/check. No Step3, model adoption, phone test or release starts.

Later owner-authorized [Wax/Cactus integration](2026-11-18-local-recall-integration.md) connects recall to ordinary chat.
Its final tests supersede affected component counts above. The two model-input repairs now defer both consumed
semantic cases on type disagreement; they still do not qualify automatic writes. Earlier failed trials remain failed.
