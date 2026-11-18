# Automatic local recall with Wax and Cactus

Owner authorization: 2026-11-18. Implement both local providers and repair the remaining memory interpretation failures.
Status: local recall implemented and connected Simulator checks passed; Step 2 quality gates remain blocked.
Automatic derived writes remain disabled. The earlier 1.7B retrieval fixture passed; the selected [4B configuration](2026-11-18-qwen4b-conversation.md) fails 10/12 with two extra-source cases. Semantic extraction remains unqualified.
This connects the narrow retrieval-before-answer path from group 8 to ordinary group 7 conversations.
It does not complete relationship advice, the full group 8 checklist or phone qualification. Connected Step 3 draft delivery is now authorized; the 4B task owns current delivery status.
The earlier [automatic-memory task](2026-11-18-automatic-personal-memory.md) retains its failed model trials and completed repairs.

## Intended behavior

- Look up relevant saved material before ordinary and temporary chat replies.
- Use current app-owned records with dates, types and stable source IDs; do not treat a retrieved quote as a confirmed fact.
- Answer general questions when no saved source matches. Explicit memory-only questions still require evidence.
- Preserve normal originals; temporary queries and answers create no durable history, extraction work or provider query log.
- Use Wax keyword search and Cactus local vector search through replaceable app-owned interfaces.
- Keep corrections, deletions and source ownership in MemoryOS. Rebuild indexes from current originals and entries.
- Check returned passages against a fresh canonical snapshot after provider work; reject stale or unknown evidence.
- Derive update permission from actual protection flags. A classifier cannot declare an ordinary entry protected.
- Interpret a linked clarification answer as the current statement, retaining the earlier quote and question as context.
- Require unchanged semantic gates before enabling automatic memory writes. Retrieval does not qualify extraction accuracy.

## Ownership and architecture

Main owns ChatCore orchestration, app composition, bundle preparation and this record.
The retrieval worker owns reusable provider contracts, upstream adapters and their focused tests.
The semantic worker owns PersonalMemoryExtraction and its tests, with one bounded consumed-case diagnostic.
A fresh independent verifier reviews the connected implementation and affected tests.
No prior inference or build worker was active at preflight. Physical phone tests remain paused.

`LocalRetrievalCore/RetrievalCore` defines source values, ID/score/passage hits and provider interfaces.
`LocalAIIntegrations/WaxMemoryRuntime` and `LocalCactusEvaluation/CactusMemoryRuntime` wrap pinned upstream code.
Lab adapter wrappers retain evaluation compatibility; production targets do not import evaluation fixtures.
`LocalMemoryRetrieval` owns chunk mapping, snapshot caching, provider choice and rank combination.
`LocalChatMemory` supplies app snapshots and validates current evidence after search.
`ChatUseCases` retrieves before generation and gives source-backed context to the existing chat model.
The ViewModel and Views continue to call injected use cases; no SDK or database call enters presentation.
The app bundles the existing verified Cactus embedding asset. Build and runtime make no model download.
Provider choice is injected as Wax, Cactus or hybrid; default hybrid requires both providers and the verified model.
Missing assets fail explicitly. No cloud fallback or silent lexical downgrade is enabled.

## Verification plan

Chat tests: ordinary recall, empty results, corrected context, private nonretention, source exclusion and failures.
Provider tests: actual SDK calls, paraphrases, English/Arabic, no-match queries, source mapping and snapshot rebuild.
Recovery tests: correction/deletion during search, stale IDs, duplicate text, malformed result, cancellation and missing assets.
Security checks: exact source passages, protected derived files, excluded backup, no query persistence and local-only runtime.
Semantic regressions: ordinary/confirmed/corrected/legacy update handling and exact linked-answer evidence.
Keep old consumed model cases and scorers unchanged; stop further full trials until the fixed regression set passes.
Build and analyze the final iOS Simulator source. Show actual dark changed flow or labeled host results.
Record host and Simulator evidence separately. Neither proves physical battery, heat or locked-phone behavior.

## Skills and sources

Skills under `.agents/skills/`, each read through `SKILL.md`: `swift-package-manager` for provider packaging,
`swift-concurrency` for actors/cancellation, `swift-testing-expert` for contracts, `axiom-security` for local files,
and `swiftui-expert-skill` for the source viewer and citation controls.
The semantic worker also uses `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md` for bounded diagnosis.
T3 Hindsight preflight and `/Users/eros/.agents/skills/stop-slop/SKILL.md` govern memory use and communication.
Current upstream references: [Wax](https://github.com/christopherkarani/Wax), [Cactus](https://github.com/cactus-compute/cactus).
Retain existing pinned revisions and local-only runtime patch; upstream marketing is not app benchmark evidence.

## Earlier integration results

Four new chat behavior tests reproduced ten failed assertions before the repair. Final Release checks pass
64 chat, 91 memory-core and 31 extraction functions. The independent verifier reran all 64 chat functions.
Two asset-bundling and seven artifact-guard tests pass; the verifier also checked all three platform artifacts.
Final binary-backed host contracts execute nine passing tests with five optional model/diagnostic tests skipped.
The same nine pass under an OS network-denial policy. This run does not qualify Cactus model inference offline.
Separate actual-model tests exercise Cactus and hybrid retrieval, cache reuse, corrections and deletion.

The final Simulator build and static analysis pass. All 22 selected native tests pass, including actual 0.6B
generation with hybrid recall, a corrected value in a new conversation, and temporary-chat nonretention.
These native tests use fictional repositories; the manual app flow additionally uses the real local stores.
In that flow, a new chat recalls an earlier fictional detail and opens the original message with its date.
The source screen distinguishes original statements, current entries and historical corrections.
Deleting chat history explicitly explains that separately saved originals and organized memories remain.

Actual dark captures: [ordinary recall](../evidence/local-recall-2026-11-18/ordinary-recall.png) and
[original source](../evidence/local-recall-2026-11-18/original-source.png).
Device: iPhone 18 Pro Simulator, iOS 27.2; isolated MemoryOS Check bundle. The Device session was released.
The [compact receipt](../evidence/local-recall-2026-11-18/results.json) records source, artifact and capture identities.
No compiled app/runtime source changed after the final build; later guard/docs changes passed separate checks.
Known build warnings remain: existing llama umbrella headers, existing unnecessary await, and Wax debug-symbol lookup.

## Earlier quality failures

Before the current repair, the frozen independent retrieval check had four cases. Hybrid retrieval with production annotations passes 3/4,
finds 1/2 positive sources, and rejects both unrelated queries. Iraqi Arabic paraphrase still misses.
A consumed score diagnostic puts its Arabic positive below a wrong-topic negative; lowering the 0.65 threshold
would admit that negative. That diagnostic remains failed. The current repair uses a separate relevance check before accepting candidates.
The document-vector cache avoids re-embedding unchanged records within a process; relaunch rebuilds it.
A 100-source first pass took 4.64 seconds and a one-source append 0.48 seconds on the host under build contention.
These are not phone measurements or large-archive qualification.

The semantic contract repair removes model-invented protection consent and passes the exact linked answer
to the second classifier. Deterministic tests cover ordinary, confirmed, corrected and legacy protections.
The bounded actual 4B diagnostic still matches 0/2 cases: a fact becomes a preference, a commitment an episode.
Both results are rejected, with zero accepted mistakes. The code repairs do not establish model quality.
Keep `automaticMemoryQualified=false`. These earlier results did not qualify extraction.

The current follow-up below separates candidate ranking from relevance and extraction typing.
Automatic writes still require at least 85% case accuracy and complete-claim recall with zero accepted mistakes.
Physical qualification remains paused. The full group 8 checklist, Step 3 and release remain outside this result.

## Cleanup and recording

Completed generated builds and duplicate assets are removed only through exact worker-owned path lists.
Nine owned generated directories went from 4,035,379,200 allocated bytes to zero (about 3.76 GiB).
This measures selected allocations, not guaranteed volume free space. Canonical artifacts remain intact.
The independent cleanup review confirms all nine paths absent and retained artifact, capture and log hashes intact.
Retain failed fictional diagnostics, reviewed model assets/upstream sources, final native build, selected captures,
original research and app histories. No user source, Git metadata or unrelated work is removed.
Strict formatting, scoped evidence checks and 169 local links pass. The compact receipt records final
project-memory delivery status; queued documents do not count as completed delivery.

## Quality repair follow-up

The owner requests fixes for both failures. Main coordinates one model test process at a time.
Tokenizer repair: byte 173 mapping and valid hash merges were wrong; native tokenization also omitted
model-defined NFC/pretokenization/EOS. The adapter now follows the verified model metadata and passes
25 recipe checks, 257 native mapping values, four pure Swift functions and seven actual native sequences.
Host, Simulator and device slices build; the final artifact receipt and patch match the retained sources.
The earlier reference omitted NFC; the final parity checks correct that diagnostic limitation.

Corrected embeddings alone still rank the consumed Arabic positive below a wrong-topic negative.
The app therefore verifies up to eight hybrid candidates with the existing local 1.7B model, using one
fixed question/passage relevance prompt. It accepts only selected IDs from unchanged app-owned sources.
The old cosine threshold is no longer the acceptance rule in this composition. Metadata, similarity or
shared names alone cannot qualify a source. The final output remains at most three source-backed passages.
This adds 1.03 GiB of bundled model data; missing/hash-invalid assets fail without a cloud fallback.
Chat, speech and relevance share a cancellation lease. Cactus candidate embedding runs outside that lease.

Historical 1.7B component check: 12/12 cases, six relevant passages accepted, zero of 90 off-topic passages
accepted. Full connected Simulator retrieval also passes 12/12 with six positive hits and zero false positives.
The fixture has eight records and is now consumed; it does not qualify large-archive recall or phone latency.
All 35 selected native tests pass. Full retrieval median is 8.80 s and p95 12.27 s on Simulator.

Removing unrelated classifier demonstrations repairs the consumed 4B fact case. The decision/event case
still disagrees. Stronger event wording and field reordering failed and were rejected. The unchanged
classifier on 1.7B failed both cases through type/subject errors. No agreement guard or scorer was weakened.
Release unit checks pass 91 core, 32 extraction and 68 chat functions. Automatic writes remain disabled.

The [quality receipt](../evidence/local-recall-2026-11-18/quality-repair.json) retains the earlier 1.7B results
separately from the earlier integration receipt. A fresh verifier checked the production filter, source
revalidation, pinned bundling and tokenizer artifacts. Final build and static analysis pass. The manual cross-chat Arabic lookup finds its original dated source.
The first host scratch run lacked Wax bundles; the verified resource-copy step repaired that harness.
A fresh native package cache could not clone incomplete cached repositories; exact pinned existing local
checkouts repaired the build setup without changing package revisions. Phone testing remains paused.

Follow-up cleanup removes 908,685,312 allocated bytes across eleven generated scratch directories.
Compact diagnostics, historical artifact receipts, canonical models/runtime and the final native build remain.

Actual dark Simulator captures: [Arabic recall](../evidence/local-recall-2026-11-18/arabic-recall-repaired.png) and
[original source](../evidence/local-recall-2026-11-18/arabic-original-source.png). Same iPhone 18 Pro/iOS 27.2,
MemoryOS Check bundle. Final independent review confirms unchanged sources, results and cleanup.
