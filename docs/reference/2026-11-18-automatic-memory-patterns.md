# Automatic personal memory from ordinary conversations

Research date: 2026-11-18. Status: recommendation for the lead agent; no implementation or runtime validation in this task.

## Recommendation

Use the existing experimental llama.cpp model to propose memories from a bounded window of ordinary conversation. Validate evidence in Swift before saving derived entries. Keep original messages, attributed claims, tentative plans and owner corrections distinct. Let the owner keep talking; request a short clarification only when an unresolved identity or contradiction affects the result. Do not require a classification menu for each message.

Combine Mem0's recent-context extraction and duplicate checks, Memobase's profile/event separation, and Hindsight's supporting-fact links and temporal consolidation. These are design patterns to implement through independent app-owned interfaces. This recommendation adds no Python backend, hosted API, database server, SDK, model download or service connection.

## Source snapshots and comparison

I inspected official repository source at Mem0 `f1791daa86d469249c9b002f62644d58a1eb96a0`, Memobase `358c16bbc6d687937d79bc2f984a11c3be8da901`, and Hindsight `9fb28dbd724dc1ce4da7cb4c49008e601db76c5f`. Links below pin these revisions. Prompt instructions describe intended behavior, not measured accuracy.

| Concern | Mem0 | Memobase | Hindsight |
| --- | --- | --- | --- |
| Ordinary multi-turn conversation | Default OSS add retrieves related memories and recent turns, then runs additive model extraction. Prior context helps resolve references; new messages supply new claims. [M1], [M2] | Summarizes timestamped chats into information, events and schedules, then extracts profile slots from the memo. This adds a lossy intermediate summary. [B1], [B2] | Chunks structured conversations while preserving turns where possible, then extracts significant facts and entities. [H1] |
| Source evidence and quoted spans | The output schema has text, attribution and related-memory IDs; it does not require message IDs or exact evidence spans. [M1] | The reviewed summary/profile output formats contain derived text and times, without required exact quoted spans. An event's profile delta is not an original quotation. [B1], [B2], [B4] | Can retain chunk text when the bank enables document-text storage; observations track supporting fact IDs. This supports a source chain, without span-level entailment validation. [H2], [H4] |
| Speaker attribution | Distinguishes user statements from assistant recommendations and excludes assistant echoes. Role attribution alone cannot identify people inside reported speech. [M1] | Input includes timestamp, alias and role; profile instructions warn against assigning another person's job to the user. [B1], [B2] | Separates world facts from assistant actions. Its world category includes user claims; it is not proof that a claim is objectively true. [H1] |
| Profile versus episode | Additive memories cover personal facts and events; the reviewed add path does not require separate durable-profile and episode records. [M1], [M2] | Explicit profile slots plus chronological events with summary, optional tags and profile delta. [B4], [B5] | Separates datable events from ongoing conversational states; derives consolidated observations from facts. [H1], [H3], [H4] |
| Time and updates | Prompt distinguishes conversation observation date from today's processing date. [M1] | Preserves mention time and event time; merge instructions preserve both old and new annotations. [B1], [B3] | Uses event date for relative expressions, supports coarse time ranges, and orders consolidation by statement time rather than ingestion order. [H1], [H3] |
| Conflict, consolidation and duplicates | Current default adds new memories, skips duplicates and links related or contradictory information. Legacy four-operation prompts remain in the file but are not the default add path. [M1], [M2] | Merge can append, update conflicting content, or abandon redundant/irrelevant content. Summary replacement can hide detail unless originals remain available. [B3] | Consolidation distinguishes repeats, changes, endings and new facets; retains earlier states and permits duplicate-observation deletion. [H3] |
| Ambiguity, uncertainty and corrections | Integrity instructions prohibit fabricated details and unsupported demographic inference. They do not prove calibrated uncertainty. [M1] | Extraction permits implied information; merging forbids invented content. This needs stricter safeguards for personal claims. [B2], [B3] | Consolidation can record a statement as wrong and retain corrected history. These prompts do not prove sarcasm, identity or intent accuracy. [H3] |

The distinction matters: automatic extraction can work without a user-facing taxonomy, while internal types still protect meaning. None of the inspected paths proves reliable extraction on MemoryOS's model, Iraqi Arabic, or personal relationship conversations.

## Proposed Swift integration

Research baseline: [PersonalChatRecorder](../../native/MemoryOS/Composition/PersonalMemoryComposition.swift) passed one user message to [PersonalMemoryUseCases](../../native/LocalMemory/Sources/MemoryCore/PersonalMemoryUseCases.swift) and could return a generic meaning question. The historical `PersonalMemoryConversation` phrase helper was removed during the authorized rework. The replacement uses [typed analysis](../../native/LocalMemory/Sources/MemoryCore/PersonalMemoryAnalysis.swift); implementation evidence belongs to the task record.

Reuse [ChatModel](../../native/LocalChat/Sources/ChatCore/ChatModels.swift), the existing [LlamaChatModel adapter](../../native/LocalTextEvaluation/Sources/LlamaEvaluationAdapter/LlamaChatModel.swift), and the reviewed asset configured in [ChatComposition](../../native/MemoryOS/Composition/ChatComposition.swift). Keep its experimental status. Do not load a second model copy or let extraction contend with an active streamed reply.

Proposed responsibilities, without new repositories or custom inference engines:

- `MemoryCore`: app-owned `ConversationMemoryExtracting` protocol and typed candidate/evidence values; independent of SwiftUI and llama.cpp.
- Integration adapter: assemble bounded role-labeled turns, call the existing model, parse a strict JSON response, and return candidates. The current text-generation contract does not guarantee grammar-constrained output; malformed output must fail validation. Reuse runtime access through composition; do not expose a chat implementation to the memory domain.
- App-owned use case: gather persisted source messages, validate candidates, resolve duplicates/conflicts and commit a revision through `PersonalMemoryRepository`.
- Composition root: inject the extraction adapter, repository and shared generation coordinator. Views and ViewModels call use cases; they do not invoke the runtime or storage.

Suggested sequence:

1. Preserve a normal chat's original message with stable conversation/message IDs, role and timestamp before extraction. A temporary chat must create no durable extraction job, candidate or source copy.
2. After the current reply finishes, enqueue a bounded recent-turn window with overlap and a source cursor. Include assistant turns as context; accept personal claims only with user-message evidence. Keep assistant suggestions separate from adopted plans.
3. Provide a small relevant set of existing entries for reference resolution and duplicate comparison. Mark it as context, not fresh evidence. Require empty output when the conversation adds nothing memorable.
4. Ask for strict JSON candidates with `kind`, subject reference, proposition, assertion mode, evidence list, event-time expression, optional time interval, and related-entry IDs. Kinds can include profile claim, episode, tentative plan and correction. These are internal values, not menu choices.
5. Require each evidence item to contain message ID, exact quote and UTF-8 byte bounds in the unchanged original. Require multiple spans for cross-turn resolutions. Treat speaker, quoted speaker and claim subject as separate values; a reported claim about Ali must not become the owner's attribute.
6. Swift checks JSON/schema limits, source ownership, ID membership, complete UTF-8 boundaries, exact quote equality, time-range validity and evidence roles. Reject invented references, unsupported names/dates, assistant-only personal assertions and malformed candidates. Treat source text as untrusted data; give extraction no tools or action permissions. Exact matching proves provenance, not semantic truth; quotation can still fail to support the proposition.
7. Preserve uncertainty and attribution in the candidate. Do not infer intent, diagnosis, stable personality or commitment from venting, role-play, questions or hypotheticals. Keep unresolved candidates outside confirmed profiles; ask a natural question only when it helps. Model-generated confidence is not a probability of truth.
8. Anchor relative dates to the source message and its known timezone. Keep original expressions and date precision. Retain unknown dates as unknown; do not convert an approximate month or week into an invented exact day.
9. Use source-span identity for exact retries. Compare subject, predicate, value, assertion mode and event time before merging equivalent claims. Similar topic/entity alone is not a duplicate: two visits are two episodes. Add new evidence to equivalent entries without discarding its source.
10. Append a correction or superseding version with links to both sources. Separate an explicit correction from a later life change or conflicting report. Owner corrections outrank derived summaries; later imports must not undo them. Ambiguous conflicts remain visible until resolved.
11. Commit only after checking source existence, temporary/deletion state and graph revision again. Cancellation, truncation, failed validation or unavailable model preserves originals and leaves extraction pending/failed. Use bounded retries; avoid an empty-success result and avoid a regex fallback that fabricates semantic success.
12. Build profiles and retrieval summaries from accepted claims and episodes. Rebuild them after correction, removal or changed extraction policy. Show a compact saved-memory receipt with source and undo; keep normal chat available when extraction abstains.

This sequence is a proposed independent design. Small validation checks belong in Swift; model inference handles conversational meaning. Existing exact matching remains useful for evidence and retry safety.

## Quality gate and limitations

The existing model has no extraction-quality result from this research. JSON validity and exact quotations cannot filter all hallucinations: a model can attach a real quotation to a false claim. Validate semantic support, speaker attribution, negation, tentative language and corrections on the actual runtime before treating automatic profile updates as trustworthy. A second pass by the same small model is not independent proof.

Use held-out fictional English, Arabic, Iraqi Arabic and mixed-language conversations. Include pronouns across turns, two people with similar names, reported speech, assistant suggestions, sarcasm, negation, hypothetical plans, corrected birthdays, changing jobs, repeated events, late imports and unrelated chatter. Check false profile writes, unsupported-claim rate, extraction recall, abstention, evidence-span validity, correction precedence and retry idempotency. Set acceptance thresholds before evaluation; require zero unsupported accepted claims in the designated safety cases, while reporting the finite sample size.

Then measure extraction latency, peak memory, context consumption and interference with chat on the intended device. Check cancellation, no-network behavior, temporary sessions, deletion during extraction and recovery. These are required follow-up checks, not tests run here. Larger contexts, overlap and extra passes cost tokens, latency and energy; use measured bounds rather than copying server defaults.

No licensed source or prompt implementation is proposed for copying. This note recommends independent behavior and app-owned interfaces, so it makes no license-clearance claim. Any later code, prompt, SDK or model adoption needs its own pinned-source and rights review. No general compliance, commercial readiness or phone-readiness conclusion follows from this research.

## Primary sources

Each reference points to the exact inspected file and revision; line anchors identify the relevant region.

[M1]: https://github.com/mem0ai/mem0/blob/f1791daa86d469249c9b002f62644d58a1eb96a0/mem0/configs/prompts.py#L468-L944
[M2]: https://github.com/mem0ai/mem0/blob/f1791daa86d469249c9b002f62644d58a1eb96a0/mem0/memory/main.py#L881-L1096
[B1]: https://github.com/memodb-io/memobase/blob/358c16bbc6d687937d79bc2f984a11c3be8da901/src/server/api/memobase_server/prompts/summary_entry_chats.py#L6-L67
[B2]: https://github.com/memodb-io/memobase/blob/358c16bbc6d687937d79bc2f984a11c3be8da901/src/server/api/memobase_server/prompts/extract_profile.py#L45-L106
[B3]: https://github.com/memodb-io/memobase/blob/358c16bbc6d687937d79bc2f984a11c3be8da901/src/server/api/memobase_server/prompts/merge_profile.py#L9-L71
[B4]: https://github.com/memodb-io/memobase/blob/358c16bbc6d687937d79bc2f984a11c3be8da901/docs/site/features/event/event.mdx#L5-L34
[B5]: https://github.com/memodb-io/memobase/blob/358c16bbc6d687937d79bc2f984a11c3be8da901/docs/site/features/profile/profile.mdx#L5-L54
[H1]: https://github.com/vectorize-io/hindsight/blob/9fb28dbd724dc1ce4da7cb4c49008e601db76c5f/hindsight-api-slim/hindsight_api/engine/retain/fact_extraction.py#L852-L1143
[H2]: https://github.com/vectorize-io/hindsight/blob/9fb28dbd724dc1ce4da7cb4c49008e601db76c5f/hindsight-api-slim/hindsight_api/engine/retain/chunk_storage.py#L106-L166
[H3]: https://github.com/vectorize-io/hindsight/blob/9fb28dbd724dc1ce4da7cb4c49008e601db76c5f/hindsight-api-slim/hindsight_api/engine/consolidation/prompts.py#L105-L148
[H4]: https://github.com/vectorize-io/hindsight/blob/9fb28dbd724dc1ce4da7cb4c49008e601db76c5f/hindsight-api-slim/hindsight_api/engine/consolidation/consolidator.py#L1-L10

## Research scope and handoff

Read project authority, current source boundaries, `/Users/eros/.t3/harness/instructions.md`, `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md`, and `/Users/eros/.codex/skills/mattpocock-research/SKILL.md`. Selected the research skill for external primary-source checks. Did not delegate. Ran project-scoped CLI recall and searched/read Hindsight pages; the group-7 page lacks current implementation detail, so current files govern this note. No recalled claim establishes extraction quality.

Only this research note was written. No app code, tests, builds, devices, Git mutation, dependency installation or personal-data transfer formed part of this task. The lead should review this draft before the normal sanitized Markdown memory sync; no memory-delivery claim is made here.

## Follow-up candidate limits

The tested 0.6B/1.7B local candidates did not qualify semantic extraction. The independent 1.7B run matched 8/18 cases and 3/11 complete claims, with 5 accepted meaning/metadata/attribution mismatches. Exact source spans alone cannot establish correct meaning.
The owner chose isolated evaluation of [official Qwen3 4B Q4_K_M](https://huggingface.co/Qwen/Qwen3-4B-GGUF/blob/bc640142c66e1fdd12af0bd68f40445458f3869b/Qwen3-4B-Q4_K_M.gguf); the task records its pinned hash, size and Apache-2.0 metadata. The verified follow-up failed: independent 3/11 complete claims and 1 accepted mismatch, p95 23.64 s; development 6/12 claims and 2 accepted mismatches, p95 19.22 s. All 38 cases completed; the gate stays off. The task links the compact evidence.
A host-only check found Apple Foundation Models available but `supportsLocale(ar)` false; no adapter or fallback was added. Apple requires [checking locale support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models.md). This is not a phone result.

A subsequent bounded repair removed exclusive chat/memory/clarify routing without changing extraction instructions/schema or domain checks. A fresh independent 12-case 4B trial still failed (7/8 complete claims, 2 accepted mismatches). The current task distinguishes repaired structural limits from unqualified semantic behavior; all automatic writes remain off.

Automatic-memory workflow reset, 2026-11-18: the completed fourth host trial failed10/20 cases and7/13 claims, with0 accepted mistakes; its inputs are now consumed regression data. Main owns bounded code repairs and independent review. Further full qualification requires current green regressions; automatic writes remain disabled. See [the current task](../tasks/2026-11-18-automatic-personal-memory.md).
