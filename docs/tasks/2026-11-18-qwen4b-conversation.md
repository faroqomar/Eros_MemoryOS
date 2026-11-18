# Qwen3 4B-only local conversation

Owner authorization: use the existing Qwen3 4B as the only conversational language model and improve replies.
Status: 4B configuration implemented; direct conversation checks pass; retrieval quality remains blocked. This selects the experimental app configuration; it does not qualify automatic memory writes or release.

## Scope and acceptance

- Generate chat replies and relevance decisions with the same pinned 4B asset; no smaller-model fallback.
- Bundle one verified weight file for offline first use. Optional Files import accepts only that exact model.
- Preserve ordinary follow-up context when its cited evidence remains current.
- Withhold earlier AI claims after cited source changes or disappearance, and in memory-only mode.
- Keep originals, temporary-chat nonretention, model cancellation and automatic-write gates.
- Check actual English instructions, follow-ups, Iraqi Arabic, source corrections and irrelevant retrieval.
- Build/test on Simulator; physical-phone performance remains paused and unmeasured.

## Architecture and skills

Existing MVVM and app-owned protocols remain. ChatComposition injects LlamaChatModel through ChatCore.
The bundled model supplies both conversation and relevance adapters; the inference coordinator unloads
chat before relevance and relevance unloads before answer generation. Cactus embeddings and speech
remain specialized independent adapters; “4B only” replaces conversational models, not these functions.
No SDK, runtime pin or network service changes. Existing 2048-token context and 256-token chat output cap remain.

Selected skills: `/Users/eros/.codex/skills/mattpocock-implement/SKILL.md` for bounded execution;
`.agents/skills/swift-testing-expert/SKILL.md` for regression/runtime assertions;
`.agents/skills/swift-concurrency/SKILL.md` for inference ownership;
`/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md` for independent standards/spec review.
Project stage authorization overrides generic skill commit advice. The owner now requests Step 3.

## Asset and compatibility

Model: Qwen3-4B-Q4_K_M.gguf, 2,497,280,256 bytes.
SHA-256: 7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5.
Existing official revision and Apache 2.0 provenance remain in the automatic-memory evidence.
Build copies from the verified existing cache; no download. Runtime verifies SHA before model load.
Old imported smaller models are ignored and preserved; no owner files or history are deleted.
Earlier failed extraction tests remain failed. Model selection does not change automaticMemoryQualified=false.

## Results

Release chat checks pass 69 functions, including unchanged-citation follow-ups and corrected-source redaction.
Three bundle integrity/repair/cleanup tests pass. Simulator build and static analysis pass.
Independent review found no blocking wiring defect. Four direct 4B conversation cases pass: instruction
following, assistant-context follow-up, Iraqi Arabic negation and latest-day correction. The connected
recall/correction/private-chat test passes. The initial retrieval run matches 10/12, finds 6/6 positives,
but accepts extra passages in 2 cases. Keep this failed baseline. One bounded relevance-prompt repair
explicitly required subject and information, but still failed both cases. It was rejected; the original
prompt is restored. The failed trial stopped after the first four completed cases, not a full-suite score.
The earlier 25-function native run therefore fails its retrieval quality assertions; do not label it green.
One bundled 4B weight file replaces the earlier 1.7B bundle; old imported 0.6B files remain ignored.
Completed host scratch cleanup removes 86,274,048 allocated bytes; compact outcomes and current builds remain.

Remaining limitations: conservative citation matching may still withhold a prior reply when passage ranking
changes. Context/output limits remain bounded; selecting 4B does not guarantee perfect Arabic or reasoning.
Signed iPhone build passes; restored-baseline Simulator and signed iPhone rebuilds pass. Final dark capture BLOCKED: two Device-tool install attempts fail with “Artifact transfer was interrupted.”
The prescribed debug retry completes tar creation but fails upload. Device actions stop; session released. No phone execution or performance claim.


Final source matches the baseline that passed the four direct conversation cases and connected
correction/private test. Its retrieval gate remains 10/12, with 6 positive hits and 2 extra-source cases.
No second full score is claimed for the rejected prompt. Final restoration retains the selected 4B model.
The signed app is at `.build/iphone/Build/Products/Release-iphoneos/MemoryOS.app`; install through Xcode Run.
No phone installation or benchmark was performed. Original phone history remains untouched.

See [compact results](../evidence/qwen4b-2026-11-18/results.json) for failed and passing checks.
Evidence guard, 103 local links and whitespace checks pass. Project memory delivery is checked separately.

## Step 3 review and draft delivery

The owner authorizes final review, cleanup and normal Git delivery. The connected personal-memory,
automatic-extraction and Wax/Cactus changes are uncommitted dependencies of this configuration;
the draft PR includes them and links their existing task/evidence records. Unrelated image-generation
outputs and separate earlier architecture/skill-policy task evidence stay outside the PR. The selected review and PR skills are
`/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md` and `mattpocock-pr/SKILL.md`.
The documentation-sync skill (`/Users/eros/.agents/skills/docs-sync/SKILL.md`) guides current status/link
corrections; `.agents/skills/swift-package-manager/SKILL.md` guides a manifest-only check, which passes.
Two fresh read-only reviewers checked standards and specification separately; both cleanup rechecks pass. Current production hashes
match the retained baseline; the only source edit in Step 3 clarifies a historical evaluation comment.
Behavior tests are reused for unchanged executable code. No new inference or phone run is claimed.

Cleanup consolidates stale rebuild/prompt-review statuses into the current result, preserves the failed
trial summary and removes one byte-identical completed test log after verifying the retained copy.
The duplicate used 6,295,552 allocated bytes and now uses zero. The compact receipt records retained
exceptions. Staged evidence guard and 367 local links pass. Owned whitespace checks pass; exact upstream
LICENSE/NOTICE copies retain their source whitespace. Earlier task records remain history.

Merge stays BLOCKED: the actual 4B retrieval suite requires 12/12 and zero extra-source cases but returns
10/12 with two extra-source cases. Final changed-screen capture remains unavailable after the prescribed
Device retry failed. Physical testing remains paused, automatic-write qualification remains failed, and
owner visual acceptance for the combined personal-memory UI remains open.
Draft delivery does not pass Step 2, enable automatic writes, or authorize release.
