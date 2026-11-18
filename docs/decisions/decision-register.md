# Decision register

Recorded on 2026-11-06. Updated on 2026-11-07 for runtime memory, audio candidates, and demo/feature direction. Source IDs refer to the [source register](../reference/source-register.md). Current owner instructions take precedence over old research and assistant proposals.

## Confirmed direction and instructions

| ID | Decision or instruction | Evidence and effect |
| --- | --- | --- |
| D01 | Build the product concept around a personal second brain. | C01 asks for a system to manage the owner's life in their own way. The immediate scope is personal use. |
| D02 | Target the owner's iPhone 15 Pro Max first. | C02 gives the device model. It is the first evaluation device, not proof of performance. |
| D03 | Prefer everyday processing on the iPhone. | C02 selects phone-only use over help from a Mac. C01 also requests maximum local control. |
| D04 | Keep capture and navigation simple. | C01 requests a record button, chat input, hidden sidebar, and requested tabs. Exact visual design remains open. |
| D05 | Support Arabic and English, with additional languages later or as selected. | C01 states the language goal. Exact language coverage and accuracy are not verified. |
| D06 | Let the owner define rules and person-specific reminders. | C01 makes these product requirements. The action and permission model remains open. |
| D07 | Keep optional external AI and future sync in the vision. | C01 requests ChatGPT/Claude and future Convex/Supabase options. This does not select a provider or allow silent upload. |
| D08 | Evaluate alternatives to Hindsight for product memory. | C01 asks for a better-fit system, or a custom system if needed. The owner has not selected Hindsight or a replacement as app runtime. |
| D09 | Keep this task at documentation and memory setup. | C04 says not to build anything. C05 asks how it could be built. C06 authorizes documentation and a separate Hindsight project. No app build is authorized by these records. |
| D10 | Use short, simple conversation. | C04 asks for minimal conversation using ASD-STE100 as a reference. Do not claim certified compliance. |
| D11 | Preserve old and new ideas with their status. | C06 asks to document all new information and list old/new features and decisions. Keep originals and distinguish changes in direction. |
| D12 | Use a separate Hindsight development project. | C06 explicitly authorizes a project-isolated connection. Project ID is `memoryos`; bank is `project-memoryos`. This is development tooling. |
| D13 | Keep Wax and Cactus as runtime memory candidates and plan for switching between experimental configurations. | C07 authorizes recording this shortlist and goal. Neither is a final selection or verified iPhone integration. See [runtime memory options](runtime-memory-options.md). This documentation does not authorize implementation. |
| D14 | Document WhisperKit and whisper.cpp for local transcription, and AVAudioRecorder for new recordings. | C08 authorizes documenting these candidates. See [audio recording and transcription](audio-recording-and-transcription.md). No final engine/model selection, implementation approval, or phone verification follows. |
| D15 | Start with an app demo, then add and improve features one at a time. | C09 selects the delivery direction. Demo scope and acceptance criteria remain open; this documentation task does not start implementation. See [demo and feature direction](demo-and-feature-direction.md). |
| D16 | Compare multiple local AI models and choose through tests and analysis. | C09 selects the evaluation approach, not particular models, runtimes, thresholds, or a verified winner. |
| D17 | Include Telegram, Instagram, and WhatsApp in the requested conversation sources. | C09 names these sources. Export formats, order, media availability, and access methods remain open. |
| D18 | Start external-AI integration with ChatGPT. | C09 selects provider priority. Authentication, entitlement, selected model, and allowed data transfers remain open. |
| D19 | Limit the initial actions/reminders feature to birthdays. | C09 narrows the starting scope. Approval rules, recurrence, timing, and calendar versus notification behavior remain open. Other date/action types are later scope. |
| D20 | Add person photos/images and guided questions to person profiles. | C09 requests supplied photos, optional generated images, available supplied chat/profile images, and questions that help learn about the person. Technical choices and detailed behavior remain open. |
| D21 | Use Swift with SwiftUI for the iPhone app. | C10 explicitly accepts this stack. This resolves A01 and supersedes the earlier C09 undecided status. It does not select a database/model, establish efficiency results, or authorize implementation in this documentation task. |
| D22 | Make the first demo a clickable interface with sample data. | C11 explicitly chooses this demo type. Exact screens and review criteria remain open; live AI, real imports, provider connections, and production persistence belong to later feature work. |
| D23 | Include BrainMap in the first demo alongside Capture, People/person details, Projects, and Birthdays. | C12 confirms BrainMap inclusion in the proposed screen set. Use fictional sample data under D22. Layouts, interactions, review criteria, and production graph behavior remain open. |
| D24 | Create the SwiftUI foundation and check device readiness. Use the supplied Capture and sidebar screenshots. | C20, 2026-11-13, authorizes native project setup, navigation, fonts, shared controls, and connection checks. This supersedes D09's no-build boundary for this step only. It does not authorize live recording, AI, imports, production storage, publication, or release. |
| D25 | Use dark mode for completed work, final previews, screenshots, and visual checks. | C21, 2026-11-13, sets a standing owner preference. The native app uses dark mode by default. Keep the C20 composition and navigation; supersede its light palette for current delivery. |
| D26 | Plan for future commercial sales in several markets with optional cloud AI/sync. | C22, 2026-11-13, confirms the goal. Exact countries, business location, pricing, providers, and launch date remain open. It does not authorize service connections or release. |
| D27 | Apply the commercial, privacy, architecture, and maintenance requirements as project rules. | C23, 2026-11-13, adopts the [commercial and engineering rules](../how-to/commercial-engineering-rules.md). Use modular boundaries, app-owned records, replaceable providers, explicit cloud permissions, encrypted sync design, safe upgrades, relevant checks, and market-specific launch assessment. This is policy adoption, not implementation or compliance verification. |
| D28 | Use the three-step development workflow with a main builder/coordinator and an independent verifier for app changes. | C24, 2026-11-14, adopts (1) understanding/planning/implementation, (2) verification including architecture, tests, and relevant benchmarks, and (3) review/push/merge. The owner asks to organize the discussed workflow. See the [workflow and role boundaries](../how-to/development-workflow.md). Architecture and pass criteria start in step 1. C32 adds mandatory dead-code/junk cleanup during step 2. C33 adds useful subagents in all steps, temporary-file cleanup, screenshot handbacks, and standing Step 3 push/PR/merge authorization after required gates pass. C24 alone did not start an app task; feature scope, required verification, product/design acceptance, task-specific holds, and release boundaries remain. |
| D29 | Superseded interpretation: create custom memory and speech package repositories. | The assistant interpreted C25 as new custom engines. C26 clarifies that the owner meant upstream repositories such as Wax and wants less complexity. D30 supersedes this plan. The proposed custom repositories were not created. See the [corrected decision and historical note](independent-engine-packages.md). |
| D30 | Use selected upstream libraries behind small replaceable adapters in one app repository. | C26, 2026-11-14, clarifies C25 and asks to simplify. Keep app-owned interfaces/data, reviewed pinned package versions, separate upstream checkouts for library work, explicit integration testing, and justified forks only when a required patch warrants one. Add modules only for concrete needs. Preserve safe replacement and relevant contract, data-recovery, and device-performance checks. The [corrected architecture decision](independent-engine-packages.md) selects no provider or integration and supersedes D29's custom-repository interpretation. |
| D31 | Adopt the source-researched architecture refinements as standing rules and enforce their implementation during step 2. | C27, 2026-11-14, asks to write the rules, follow them consistently, and ensure implementation in step 2. The [mandatory rules](independent-engine-packages.md#mandatory-architecture-and-adoption-rules) and [step 2 checks](../how-to/development-workflow.md#mandatory-step-2-architecture-and-upstream-checks) require staged real module boundaries, reviewed SDK/model versions, portable app-owned data, contract/multilingual/offline/recovery checks, and relevant physical-device benchmarks. Step 1 plans/builds; step 2 verifies and requires missing in-scope implementation and repairs before passing. This is policy adoption, not a provider selection, benchmark result, new app task, or merge/release authorization. |
| D32 | Use a private canonical GitHub repository for MemoryOS. | C31, 2026-11-14, authorizes creating [https://github.com/faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS), connecting this workspace as `origin`, and treating it as the main/original project repository. It is not a fork or a new runtime-engine repository. Step 3 still requires verification and any required owner product/design acceptance. C33 supplies normal merge authorization when Step 3 is requested; task-specific holds still apply. |
| D33 | Allow useful subagents in all steps; clean dead/useless/temporary files in Step 2; show screenshots each step; complete Step 3 through merge after required gates pass. | C33, 2026-11-14, replaces the fixed two-agent cap and separate routine per-PR merge confirmation. The main agent coordinates scoped helpers and dependency order; app verification remains independent. A Step 3 request authorizes normal review/push/PR/merge for the task. Required checks/reviews, needed product/design acceptance, and explicit holds still govern passage. Capture actual dark changed/new UI states, or labeled code/document/results evidence for nonvisual work. |
| D34 | Require explicit MVVM and concrete app/upstream engine ownership checks. | C34, 2026-11-14, asks to name MVVM with the repository/engine rules so agents do not guess. Apply the [mandatory responsibilities](../how-to/commercial-engineering-rules.md#mandatory-mvvm-repository-and-engine-rules): View → ViewModel → use case → app-owned protocol → adapter. Keep one app Git repository and separate upstream library checkouts/pins under D30/D31. Step 1 maps files and dependencies; Step 2 inspects source, action traces, imports/injection, relevant tests, and ownership with pass/fail/blocked/N/A evidence; Step 3 confirms evidence matches the reviewed head. Required violations block passage. This records policy, not existing-demo compliance, provider selection, or authorization for another app task. |
| D35 | Search and select installed skills for each task and development step. | C45/C46, 2026-11-15, requests useful skills for Steps 1, 2, and 3 and requires a fresh task-specific catalog search, including skills beyond the starting map. Add, replace, or skip skills to match the actual work; record search concerns and selection reasons. Use the [step skill map](../how-to/agent-skills.md#skills-for-the-three-development-steps), read applicable entry points, and retain selected paths in the task record. Combine shared workflow skills with relevant project-local Swift/UX guidance. Preserve MVVM, stage authorization, independent app verification, cleanup, screenshots, final-source checks, and existing acceptance/merge gates. This documentation update does not start or complete an app stage. |

Historical visual direction, C15 (2026-11-12): the owner rejected Atlas, Almanac, Circles, Cabinet, and Focus and directed the assistant to the already-decided Capture home screen. The [home-screen style](../design/home-style.md) governed that exploration. C17 supersedes its visual constraints for the current redesign.

Design tooling, C16 (2026-11-13): the owner requested using Astryx to design the app. The [isolated browser prototype](../design/astryx-prototype.md) uses Astryx components and fictional data. SwiftUI remains the selected native stack. The browser design does not establish visual approval, production behavior, or iPhone verification.

Historical visual direction, C17: the owner requested a complete wild redesign with prior visual rules released. The [resulting proposal](../design/wild-redesign.md) was rejected under C18. The old home image remains historical rather than a renewed pixel constraint.

Historical visual reference, C19: after rejecting the wild result, the owner selected Apple design. The [Apple-inspired proposal](../design/apple-inspired.md) remains a browser study.

Current visual reference, C20: the owner returned to the supplied [Capture](../../designs/references/2026-11-13-native-foundation/capture.png) and [sidebar](../../designs/references/2026-11-13-native-foundation/sidebar.png) screenshots. Preserve their central microphone, bottom composer, spacing, and hidden sidebar. C21 supersedes the light palette with dark mode for current delivery and final checks. Keep other screen layouts open. Native verification and owner acceptance of the implementation remain separate.

R01-R32 in the [feature register](../feature-register.md) are owner requests. They remain requirements to refine, rather than completed features.

## Proposed choices that have not been approved

| ID | Choice | Current status |
| --- | --- | --- |
| A02 | SQLite for local records | Resolved for checklist group 3 Step 1 by the implementation selection below. This is not a production-readiness claim. |
| A03 | llama.cpp for local text inference | Experimental Simulator baseline under C40. Real CPU/Accelerate SDK builds and Qwen3-0.6B/1.7B comparisons run; quality prevents production adoption. Physical-device results remain open. See the [measured report](../evidence/local-ai-2026-11-14/resume-summary.md). |
| A04 | WhisperKit or whisper.cpp for transcription | D14 records the shortlist. Evaluate multilingual models for Arabic and English. No final speech model is selected. Group 6 has host/Simulator comparison evidence; physical iPhone and natural Iraqi qualification remain open. See [audio options](audio-recording-and-transcription.md). |
| A05 | Multiple local model candidates, including earlier multilingual suggestions | D16 requires selection through testing and analysis. Qwen3-1.7B is an earlier example, not a chosen model or fixed shortlist. Group 4 now records Simulator speed/memory/storage and builder quality review. Physical battery/heat and production adoption remain open. |
| A06 | Custom memory behavior over existing components | Assistant recommendation. D13 records Wax and Cactus as candidate foundations; exact reuse and custom scope remain open. See [runtime memory options](runtime-memory-options.md). |
| A08 | Saved filters for generated tabs | Proposed implementation of R21. No design approval exists. |
| A09 | Concrete app-owned storage and Obsidian integration | D27/C23 requires MemoryOS-owned durable records. Database/package selection and Obsidian access/two-way editing remain open. App database plus Markdown views is still an implementation proposal. Encryption, backup, and recovery need detailed design and verification under the standing rules. |
| A10 | One complete offline capture-to-answer prototype first | Proposed validation path. No execution approval, budget, or dates exist. |
| A11 | Reminder previews followed by selected automatic rules | Proposed action policy. D19 limits initial scope to birthdays; the owner has not selected approval thresholds or exact behavior. |
| A12 | Optional official authentication/API connection or manual handoff for external AI | D18 selects ChatGPT first. Exact supported iPhone connection, entitlements, models, and data-transfer permissions remain unverified in MemoryOS. |
| A13 | Evaluate Wax first, then retain it only if the phone experiment meets requirements | Assistant recommendation for the D13 shortlist. Evaluation order and production adoption are not final selections. |
| A15 | AVAudioRecorder for microphone capture, with separate interchangeable transcription adapters | Group 6 implements Apple capture and both local transcription adapters with app-owned recordings, versioned passages and recovery. The owner reports working phone capture/chat; measured language/device qualification remains open. See the [current voice/chat record](../tasks/2026-11-17-voice-chat.md). This is experimental integration, not production adoption. |

## Resolved earlier proposals

| ID | Earlier proposal | Resolution |
| --- | --- | --- |
| A01 | App language and interface framework | D21/C10 selects Swift with SwiftUI. Earlier Flutter and Objective-C primary-stack options are superseded for current planning. |
| A07 | Source/extraction/confirmation/interpretation separation | D27/C23 adopts this as an engineering requirement. Exact schemas and behavior remain to design and verify. |
| A14 | Common memory interface, separate provider indexes, and app-owned source records | D27/C23 adopts app-owned sources, replaceable adapters, and rebuildable provider indexes as requirements. Exact APIs, dependencies, migration, and integration remain open and unverified. |

## Changes from the old research

| Old direction | Current treatment | Reason |
| --- | --- | --- |
| Cloud generation and indexing are required for normal use. | Superseded as the current default. | D03 prioritizes iPhone processing without a daily Mac/server dependency. |
| Postgres + pgvector, Python/FastAPI, AWS/KMS, and a server-side graph form the launch stack. | Historical architecture; not a selected current stack. | No owner approval establishes these choices for the current phone-first product. |
| Local models are a later optional edition. | Superseded sequencing. | Local AI is central to the current request. |
| Digital legacy persona and self-insight are the two central launch products. | Historical broader vision. | The current request emphasizes daily capture, people, projects, and reminders. Advanced analytics and legacy scope need reconfirmation. |
| Calendar integration is excluded from the initial vision. | Superseded as a blanket product exclusion; delivery order remains open. | C01 explicitly requests calendar actions. |
| Native Swift plus Kotlin and a web dashboard are assumed. | Swift with SwiftUI is now selected for the iPhone; Kotlin and a web dashboard remain unselected. | D21/C10 selects the iPhone stack without selecting a stack for future platforms. |
| A 90-day rollout, cloud budgets, pricing, and hiring plan are commitments. | Historical estimates only. | C04/C06 authorize discussion, documentation, and memory setup, not a funded implementation or launch. |
| The research's legal, market, accuracy, and cost claims remain current. | Unverified historical claims. | No current validation has been performed for those claims in this task. |

## Open questions

1. Which iOS version, available storage, and app memory budget must the prototype support?
2. Which local models perform well on the owner's Arabic and English examples?
3. With Swift and SwiftUI selected under D21 and app-owned records required under D27, which concrete storage design fits the local app and future devices?
4. Which memory component can be reused, and which behavior needs custom code?
5. Which supported export format comes first among the requested Telegram, Instagram, and WhatsApp sources? Which other sources should follow?
6. Does the audio request include existing voice-note exports, live recording, multi-speaker recordings, or all three?
7. Which transcript formats are required: plain text, Markdown, subtitles, or another format?
8. Which email providers and calendar accounts should connect first?
9. For the initial birthday-only feature, which actions can run automatically, and which need review? What timing, recurrence, and notification/calendar behavior should apply?
10. Which profile fields and questions should the owner control? How should supplied, imported, and generated images work? Which important-date types follow birthdays?
11. What should a natural-language rule do, and how can the owner inspect its effect?
12. Which Obsidian vault access mode is feasible on iOS? How should two-way edits work?
13. Which PDF/Word formats, scanned pages, tables, images, and size limits are required?
14. Which other languages should join Arabic and English? Is Turkish still a priority from the older research?
15. Which data may leave the device for optional AI or sync? What must remain local?
16. Which supported ChatGPT authentication route, model access, and data permissions fit this app? How will later providers connect?
17. Should future sync use Supabase, Convex, another option, or no server? How will encryption keys and conflicts work?
18. Which historical features, especially analytics, persona, digital legacy, and sharing, does the owner still want?
19. What are acceptable accuracy, latency, battery, heat, and storage limits on the actual phone?
20. What backup, restore, deletion, source retention, and key-recovery behavior should the owner select?
21. Which layouts should the remaining native demo sections use? C20 restores the supplied Capture/sidebar reference. Preserve earlier browser proposals as history and distinguish reference selection from acceptance of the native implementation.

These questions are a record for future work. They do not require the owner to answer everything before reviewing the product idea.

## Checklist group 3 storage implementation, 2026-11-14

C35 authorizes Step 1 of reliable local storage and text capture. The [storage decision](local-record-storage.md) selects the OS SQLite library behind an app-owned protocol, schema/archive version 1, app-owned immutable originals and correction history, stable links, reversible Trash, and explicit readable JSON export/transactional merge restore. This resolves A02 for this implementation. It does not select an AI/search provider or settle permanent deletion, automatic cloud backup, custom encryption/key recovery or sync. The [task record](../tasks/2026-11-14-local-storage-text-capture.md) distinguishes implementation, local checks, independent verification and physical-device gaps.


## Checklist group 4 evaluation, C38, 2026-11-14

C38 authorizes Step 1 implementation and builder checks for local AI comparisons. It does not select Wax, Cactus, llama.cpp, MLX or a model for production. C39 requires completed downloads/repairs and C40 selects Simulator. The [task record](../tasks/2026-11-14-local-ai-phone-evaluation.md) and [measured summary](../evidence/local-ai-2026-11-14/resume-summary.md) now record completed SDK/model comparisons, explicit unsupported-platform results and measured quality failures. Builder recommendations select llama.cpp and Wax lexical as experimental baselines only. Neither tested text model meets the Arabic/Iraqi bar; no production provider/model is adopted. C41 separately starts independent Step 2. C43 repairs subsequently pass its C40 Simulator checks, including unfiltered accessibility audits; this does not change failed model-quality results or start Step 3. Physical cost remains separate.

## Checklist group 5 chat, C47, 2026-11-15

C47 starts Step 1 of main-app local chat. Reuse the reviewed llama.cpp CPU adapter and Qwen3-0.6B asset as an experimental integration baseline. This does not reverse group 4 quality failures or select a production model. Keep separate app-owned chat archives and original records; provide explicit memory retrieval and source controls, full-context refusals, recovery and offline operation. The [chat task](../tasks/2026-11-15-local-ai-chat.md) owns current implementation, tests, the requested iPhone 18 Pro Max simulator evidence, and remaining blockers. Independent Step 2 and Step 3 remain separate.


## C50: personal-context product goal

The owner requests extensive chat/media imports, source-preserving relationship and person understanding, and organization of ideas, workflows and projects. Fine-tuning and tools are discussion topics, not selected implementations. See the [confirmed goal and proposed approach](personal-context-goal.md).


## C51: expanded checklist and memory delivery, 2026-11-15

The owner requests updating Hindsight with C50 personal-context goals and expanding the implementation checklist to cover relationship/media imports, person understanding, life/project capture, fine-tuning evaluation and tools. The current checklist preserves existing IDs and chat group 5; later stages now cover the full goal. This is documentation authorization, not a new implementation stage or evidence that the pasted physical-device/production checkmarks passed.


## C52: forward-only milestone numbering, 2026-11-15

The owner requires closing checklist groups 1–5 around completed work and moving unfinished obligations into new numbered groups without returning to earlier milestones. Groups 15–18 own physical/OS/accessibility qualification, chat performance/recovery/offline checks, model quality/production selection, and acceptance/data-policy/delivery closure. Existing evidence and merge/release gates remain valid. This instruction reorganizes the roadmap; it does not claim missing checks passed or start new implementation.

## C53: mandatory Step 3 documentation cleanup, 2026-11-15

The owner starts Step 3 for local chat and requires updating this standing rule before delivery work: every Step 3 must clean documentation and remove confirmed unnecessary material. The [workflow](../how-to/development-workflow.md#step-3-documentation-cleanup) requires consolidation, link/evidence checks and compact cleanup totals while preserving originals, provenance, active work and required evidence. This adds a delivery duty; existing verification and merge gates remain unchanged.


## Group 7 implementation boundary, 2026-11-17

Owner clarification, 2026-11-18: iOS 18 runtime testing is withdrawn from this task's Step 2 gate. Record it as withdrawn, not passed. The deployment target and broader supported-OS/release qualification remain unchanged. Locked-device enforcement and energy/sustained-thermal checks remain open.

The owner requests Step 1 for lasting personal memory, profiles and project organization. The [task](../tasks/2026-11-17-lasting-personal-memory.md) owns the thirteen requested behaviors and builder evidence. Keep ordinary chat originals, confirmed claims, tentative project information and revisable interpretations distinct. Temporary sessions read existing memory but retain no new history; explicit end or process exit discards them while app switching retains in-memory state.

This implementation adds an app-owned version-1 personal graph archive beside the existing SQLite records and chat archive. Small protocols keep it replaceable. Atomic protected writes, bounded image/source data, original-preserving undo and explicit readable export/empty-store restore support recovery. The archive does not select a vendor index or new AI provider. Existing record/audio exports remain separate; full-app backup and production data-policy qualification remain open. The conservative organizer holds unfamiliar English/Arabic statements for clarification; it does not establish semantic or psychological accuracy. No new upstream library/model, cloud service, image generator or import-source connection is selected.


Graph-storage tradeoff: a separate bounded JSON archive avoids changing the existing SQLite schema and record archive contract during group 7. Step 2 measured 415 ms edit p95 at 1,000 sources with 50 undo revisions, above the 250 ms target. The adapter now stores repeated history values once in a versioned JSON envelope and reconstructs the same graphs. It reads legacy plain snapshots without rewriting them; the next successful edit atomically writes the compact form. Public exports remain full readable JSON. The file path, original IDs, protection and recovery rules remain unchanged; no provider or database dependency is added. The same physical candidate workload passes: edit p95 94 ms and median reopen 115 ms at 1,000 sources with 50 undo revisions. See the task record for methods, variability and remaining qualification gaps. Version 1 bounds the archive to 64 MiB, 10,000 sources/entries, 2,000 profiles and 50 undo revisions. The image picker accepts up to 2 MiB; the domain archive permits 5 MiB per photo. Rendering validates dimensions and downsamples to 720 pixels. Restore refuses a nonempty graph. This is a bounded implementation choice, not a scale or device-performance claim.

## Automatic-memory follow-up, 2026-11-18

The owner requested semantic automatic-memory rework after rejecting generic per-message meaning menus. The current [task](../tasks/2026-11-18-automatic-personal-memory.md) replaces that path with a model-independent analyzer contract, bounded local structured proposals and domain-owned source validation, clarification and reversible revisions. The tested 1.7B model fails independent accuracy, so this source candidate blocks automatic derived writes. The owner explicitly chose local-only evaluation of the larger pinned candidate and skips further phone tests. This authorizes evaluation, not production adoption or cloud integration; earlier physical lock/energy gates remain open.

Follow-up evaluation, November 18: the verified local 4B candidate completed 38 host cases but failed its semantic gate (independent 3/11 complete claims; 1 accepted mismatch). Automatic derived writes remain disabled. A fresh 12-case routing repair trial also failed: 7/8 complete claims, 2 accepted mismatches. The current task/evidence retains both results; no model, cloud or phone adoption follows.

Automatic-memory workflow reset, 2026-11-18: the completed fourth host trial failed10/20 cases and7/13 claims, with0 accepted mistakes; its inputs are now consumed regression data. Main owns bounded code repairs and independent review. Further full qualification requires current green regressions; automatic writes remain disabled. See [the current task](../tasks/2026-11-18-automatic-personal-memory.md).

## Automatic local recall integration, 2026-11-18

The owner requests repair and implementation of Wax and Cactus in the main app, with online primary-source research permitted. The [task](../tasks/2026-11-18-local-recall-integration.md) implements retrieval before ordinary replies and preserves app-owned originals, provider replacement, local-only execution and private-session nonretention. Existing physical-phone pause and semantic qualification gates remain; no Step3 or release begins.

Quality repair follow-up: the same task adds a bounded local relevance verifier after candidate search.
It reuses the previously downloaded, SHA-pinned Qwen3-1.7B community conversion through the existing
llama.cpp adapter; no model download or cloud fallback is added. The app bundles this 1,107,409,472-byte
asset for experimental host/Simulator verification. Cactus tokenizer fixes align byte mapping, valid
hash merges, NFC, pretokenization and EOS with the verified embedding asset. Automatic extraction
remains a separate failed qualification gate. Physical testing stays paused; this is not release adoption.


## Owner-selected 4B conversation, 2026-11-18

The owner selects the downloaded Qwen3 4B as the only conversational/relevance language model.
The [4B conversation task](../tasks/2026-11-18-qwen4b-conversation.md) replaces the smaller main-app
models and verifies follow-up context. This selection supersedes the earlier experimental 0.6B/1.7B
composition. The app bundles one pinned 4B file for offline use. Cactus embeddings and speech remain
specialized adapters. Automatic memory writes stay disabled after failed extraction qualification.
Physical-phone tests remain paused; model selection does not certify device performance or release.
