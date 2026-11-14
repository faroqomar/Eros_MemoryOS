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

Historical visual direction, C15 (2026-11-12): the owner rejected Atlas, Almanac, Circles, Cabinet, and Focus and directed the assistant to the already-decided Capture home screen. The [home-screen style](../design/home-style.md) governed that exploration. C17 supersedes its visual constraints for the current redesign.

Design tooling, C16 (2026-11-13): the owner requested using Astryx to design the app. The [isolated browser prototype](../design/astryx-prototype.md) uses Astryx components and fictional data. SwiftUI remains the selected native stack. The browser design does not establish visual approval, production behavior, or iPhone verification.

Historical visual direction, C17: the owner requested a complete wild redesign with prior visual rules released. The [resulting proposal](../design/wild-redesign.md) was rejected under C18. The old home image remains historical rather than a renewed pixel constraint.

Historical visual reference, C19: after rejecting the wild result, the owner selected Apple design. The [Apple-inspired proposal](../design/apple-inspired.md) remains a browser study.

Current visual reference, C20: the owner returned to the supplied [Capture](../../designs/references/2026-11-13-native-foundation/capture.png) and [sidebar](../../designs/references/2026-11-13-native-foundation/sidebar.png) screenshots. Preserve their central microphone, bottom composer, spacing, and hidden sidebar. C21 supersedes the light palette with dark mode for current delivery and final checks. Keep other screen layouts open. Native verification and owner acceptance of the implementation remain separate.

R01-R32 in the [feature register](../feature-register.md) are owner requests. They remain requirements to refine, rather than completed features.

## Proposed choices that have not been approved

| ID | Choice | Current status |
| --- | --- | --- |
| A02 | SQLite for local records | Proposed baseline. No database package, encryption option, or schema is selected. |
| A03 | llama.cpp for local text inference | Candidate runtime. No build, model compatibility test, or device result exists. |
| A04 | WhisperKit or whisper.cpp for transcription | D14 records the shortlist. Evaluate multilingual models for Arabic and English. No final speech model or benchmark exists. See [audio options](audio-recording-and-transcription.md). |
| A05 | Multiple local model candidates, including earlier multilingual suggestions | D16 requires selection through testing and analysis. Qwen3-1.7B is an earlier example, not a chosen model or fixed shortlist. No quality, speed, memory, or battery result exists. |
| A06 | Custom memory behavior over existing components | Assistant recommendation. D13 records Wax and Cactus as candidate foundations; exact reuse and custom scope remain open. See [runtime memory options](runtime-memory-options.md). |
| A08 | Saved filters for generated tabs | Proposed implementation of R21. No design approval exists. |
| A09 | Concrete app-owned storage and Obsidian integration | D27/C23 requires MemoryOS-owned durable records. Database/package selection and Obsidian access/two-way editing remain open. App database plus Markdown views is still an implementation proposal. Encryption, backup, and recovery need detailed design and verification under the standing rules. |
| A10 | One complete offline capture-to-answer prototype first | Proposed validation path. No execution approval, budget, or dates exist. |
| A11 | Reminder previews followed by selected automatic rules | Proposed action policy. D19 limits initial scope to birthdays; the owner has not selected approval thresholds or exact behavior. |
| A12 | Optional official authentication/API connection or manual handoff for external AI | D18 selects ChatGPT first. Exact supported iPhone connection, entitlements, models, and data-transfer permissions remain unverified in MemoryOS. |
| A13 | Evaluate Wax first, then retain it only if the phone experiment meets requirements | Assistant recommendation for the D13 shortlist. Evaluation order and production adoption are not final selections. |
| A15 | AVAudioRecorder for microphone capture, with separate interchangeable transcription adapters | D14 records the recording candidate. The adapter design, WhisperKit-first evaluation order, job queue, and versioned transcripts remain assistant proposals. No integration or device result exists. |

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
