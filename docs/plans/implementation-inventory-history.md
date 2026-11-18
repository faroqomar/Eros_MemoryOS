# Historical implementation inventory through C51

Preserved provenance only. C52 moves current roadmap ownership to implementation-checklist.md groups 15–18. Unchecked historical entries are not instructions to reopen groups 1–5. Original S/T/R/P/H IDs remain reference identifiers.


Current roadmap update: C51, 2026-11-15. The first milestone remains a clickable SwiftUI demo on an iPhone. Simulator completion, physical-device verification, owner acceptance and production adoption are separate. Groups 1–5 retain their existing identities; the owner-pasted older list omitted the current local-chat group 5. Its voice and subsequent stages therefore continue below as groups 6–13, followed by customization and final verification. Existing S/T/R/P/H IDs remain stable. See the [personal-context goal](../decisions/personal-context-goal.md).

The dated inventories below preserve historical checkpoints; current task records and the current roadmap additions govern conflicting status wording. Checked items in a pasted planning list do not establish missing physical-device or production evidence.

Recorded on 2026-11-12. This checklist inventories the current project tools, design references, and feature registers before native implementation.

Update, 2026-11-13, C20: the owner selected the newly supplied Capture/sidebar screenshots and requested the native foundation plus a device connection check. Native source now exists under `native/` and passes a simulator build. The earlier no-native checkpoint below is historical. See [setup and device readiness](../how-to/native-swiftui.md) and [verification](../verification/2026-11-13-swiftui-foundation.md). The full feature demo and physical iPhone launch remain incomplete.

## Current foundation step, C20

- [x] **Create the SwiftUI project:** Native project, shared scheme, Capture, sidebar routes, system fonts, and shared controls now exist. The simulator build passes. See the verification record for interaction results.
- [x] **Check the iPhone connection:** Confirmed the available iPhone simulator and installed Xcode/SDK. No physical iPhone appeared. Documented USB trust, Developer Mode, signing team, and installation steps. Physical-phone installation remains open under S11.

## Current instruction and completion rules

Owner update C24, 2026-11-14: execute authorized items through the [three-step development workflow](../how-to/development-workflow.md). Use the [task template](../templates/development-task.md) for one connected outcome at a time. This checklist remains the inventory; workflow adoption does not complete an item or authorize unresolved features, new layouts, dependencies, or a merge.

The owner requested Swift implementation and launch on an iPhone. The next owner message places this checklist first. That request authorizes work on the selected sample-data demo; it does not select unresolved runtime libraries or add historical features to the first build. Prepare this inventory before starting native implementation.

For application work below, an unchecked box means the Swift implementation and its relevant verification remain incomplete. It does not mean that the owner rejected the feature. Tool entries state whether they are selected, candidates, or research. Checked asset entries mean the file exists, not that the owner approved the design. No native Swift app, native build, or iPhone launch evidence exists in this workspace at this checkpoint. The existing HTML/CSS/JavaScript prototype is a separate reference.

Use the [feature register](../feature-register.md) for scope, the [decision register](../decisions/decision-register.md) for choices, and the [visual reference index](../design/visual-reference-index.md) for design status. This inventory preserves their existing IDs. Supporting and historical entries do not expand the selected first demo.

## Current complete-demo task

C28 authorized Step 1 of checklist group 2. C29 requested Step 2 for the same demo. The [task record](../tasks/2026-11-14-complete-interface-demo.md) owns source identity, repairs, and evidence for S02–S11. Independent review confirms the repaired interface and passing local functional scenarios, unit tests, and Release compilation. Step 2 remains blocked by unresolved native accessibility diagnostics, physical iPhone checks, and iOS 18 runtime validation. Owner visual acceptance remains open; retain unfinished review/device boxes. C32 cleanup passes, with 984.45 MiB reclaimed and preserved source/evidence hashes. C30/C31 start Step 3 review and private draft delivery in [PR #1](https://github.com/faroqomar/Eros_MemoryOS/pull/1); merge remains blocked. The dated foundation checks below are historical evidence for their identified source.

## Selected first build

- [x] **S01 · Swift + SwiftUI:** Created the native iPhone project and shared scheme. The simulator build passes. This does not complete the remaining demo screens or physical iPhone launch.
- [ ] **S02 · Capture:** Show the large recording control and text composer with fictional sample interactions. Clearly identify simulated recording and processing.
- [x] **S03 · Hidden sidebar:** Simulator checks pass for all seven routes, close/reopen, and return to Capture. The drawer stays hidden during capture. Physical iPhone and VoiceOver acceptance remain open.
- [ ] **S04 · People and person details:** Browse fictional profiles and their linked discussions, dates, and projects.
- [ ] **S05 · Projects:** Browse fictional projects, their captures, current plans, and tentative ideas.
- [ ] **S06 · Birthdays:** Demonstrate fictional birthday details and reminder choices. Real scheduling is later work.
- [ ] **S07 · BrainMap:** Show fictional person/project/capture connections and usable navigation. Exact node interactions remain to be defined.
- [ ] **S08 · Arabic and English:** Support RTL/LTR layouts and mixed-language sample text. Verify native text rendering.
- [x] **S09 · Demo boundaries:** Current foundation labels temporary text and recording/attachment previews. The recording-notice and process-reset tests pass. It has no live AI, imports, provider login, notifications, or production persistence.
- [ ] **S10 · Design review:** Compare the implemented screens with the retained references. Record owner review separately from successful builds.
- [ ] **S11 · iPhone launch:** Build, install, launch, and inspect the native interface. Record the exact device and whether it is physical or simulated. A simulator result does not prove launch on the owner's physical iPhone 15 Pro Max.

## Tools and repositories

These are components already named in project records, not a newly selected dependency list. External links identify the recorded sources; this checklist does not claim fresh upstream compatibility checks.

### Native app and local components

- [x] **T01 · Swift / SwiftUI (selected):** Xcode 27.2 and iOS 27.2 SDK verified. Native simulator build passes. Physical-phone signing and connection remain open.
- [ ] **T02 · [Wax](https://github.com/christopherkarani/Wax) (shortlisted):** Evaluate local memory storage and retrieval. Not selected for production or needed for the sample-data demo.
- [ ] **T03 · [Cactus](https://github.com/cactus-compute/cactus) (shortlisted):** Evaluate local model/retrieval components with app-owned memory rules. Verify the maintained iOS package and API before integration. The recorded [cactus-engine](https://pypi.org/project/cactus-engine/) link is research, not a selected Swift dependency.
- [ ] **T04 · [AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) (recording candidate):** Evaluate real microphone recording in a later feature step.
- [ ] **T05 · [WhisperKit / Argmax Swift](https://github.com/argmaxinc/argmax-oss-swift) (shortlisted):** Evaluate local Arabic/English transcription with multilingual models.
- [ ] **T06 · [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (shortlisted):** Compare local transcription using the same recordings. The recorded Swift integration option is [whisper.spm](https://github.com/ggml-org/whisper.spm).
- [ ] **T07 · [llama.cpp](https://github.com/ggml-org/llama.cpp) (candidate):** Evaluate local text-model execution; no runtime is selected.
- [ ] **T08 · [Qwen3-1.7B](https://huggingface.co/Qwen/Qwen3-1.7B) (example candidate):** Compare multilingual model quality and device cost. It is not a fixed shortlist or selected model.
- [ ] **T09 · [SQLite / FTS5](https://www.sqlite.org/fts5.html) (proposal):** Evaluate local records and keyword search. Database, schema, encryption, and semantic-search components remain open.
- [ ] **T10 · MemoryOS-owned adapters (proposal):** Keep source records, corrections, and stable IDs independent of provider indexes. Test provider switching and rollback before adopting it.

### Connections and later integrations

- [ ] **T11 · [Obsidian](https://help.obsidian.md/Files+and+folders/How+Obsidian+stores+data) (requested):** Decide vault import/export versus shared-vault access and storage authority.
- [ ] **T12 · ChatGPT (first external AI priority):** Select a supported connection and data-sharing policy before integration. Subscription access does not establish API entitlement.
- [ ] **T13 · Claude (later requested option):** Decide its connection and selected-data handoff after the first provider.
- [ ] **T14 · Telegram imports (requested):** Select and test an export format, including missing-media handling.
- [ ] **T15 · Instagram imports (requested):** Select and test an export format. No direct-account connector is selected.
- [ ] **T16 · WhatsApp imports (requested):** Select and test an export format and attachment handling.
- [ ] **T17 · Email, including [Gmail API research](https://developers.google.com/workspace/gmail/api/guides) (requested/provider open):** Select accounts, permissions, and supported retrieval behavior.
- [ ] **T18 · Calendar / birthday notifications (requested/mechanism open):** Select timing, recurrence, permissions, and notification versus calendar behavior.
- [ ] **T19 · [Supabase](https://supabase.com/docs/guides/self-hosting) (future sync candidate):** Evaluate only when sync work begins. Not selected.
- [ ] **T20 · [Convex](https://docs.convex.dev/self-hosting) (future sync candidate):** Alternative future sync option. Not selected.

### Existing development and design tools

- [x] **T21 · Hindsight development connection:** Existing project wrapper and documented isolated bank `project-memoryos`. This is coding-agent memory, not selected app memory. The current turn used project-scoped recall.
- [x] **T22 · Static prototype:** Existing [HTML entry](../../index.html), [app logic](../../src/app.js), [sample data](../../src/data.js), and [styles](../../src/style.css). Reference only for native work; no Swift delivery follows from these files.
- [x] **T23 · Taste prototype kit:** Existing [CSS](../../src/kit.css), [chart helper](../../src/charts.js), and [MIT license](../../src/KIT-LICENSE). [Upstream attribution](https://github.com/Leonxlnx/taste-skill). Availability does not require charts or analytics in the app.
- [x] **T24 · Local fonts:** Geist and Geist Mono files plus OFL licenses exist under `public/fonts/`. Native bundling, Arabic fallback, and rendering checks remain incomplete.
- [ ] **T25 · [Khoj](https://github.com/khoj-ai/khoj) / [Memvid](https://github.com/memvid/memvid) (research only):** Previous alternatives. Neither is selected for native integration.
- [ ] **T26 · Apple background processing / Instruments (research):** Verify supported background work and measure real workloads when relevant. No benchmark has passed.

Flutter and Objective-C are not the selected primary stack. Older cloud-stack libraries remain historical under H35-H36 below. See the [source register](../reference/source-register.md) and the [runtime](../decisions/runtime-memory-options.md) and [audio](../decisions/audio-recording-and-transcription.md) notes for provenance and unresolved choices.

## Design references and implementation checks

- [x] **V01 · Retained owner reference:** [Capture and sidebar image](../../designs/references/capture-sidebar-owner-reference-2026-11-07.png). Use its white surfaces, charcoal controls, minimal composer, and hidden sidebar as the recorded visual reference. Retention does not approve every detail.
- [x] **V02 · Generated Capture/Menu concept:** [Two-screen mockup](../../designs/2026-11-07-capture-sidebar/memoryos-capture-sidebar.png) and [prompt](../../designs/2026-11-07-capture-sidebar/prompt.md). Proposed concept, not final approval.
- [x] **V03 · Generated BrainMap concept:** [Map and selected-project state](../../designs/2026-11-07-brainmap/brainmap-concept.png), [prompt](../../designs/2026-11-07-brainmap/prompt.md), and [manifest](../../designs/2026-11-07-brainmap/manifest.json). Proposed and unapproved; fictional content.
- [x] **V04 · Achromatic Ledger prototype:** Existing [brand specification](../../.taste/brand.json), [prototype plan](../../.taste/page.json), [asset manifest](../../.taste/assets.json), and [recorded web checks](../../src/build-verification.json). Treat them as prototype evidence, not native-device acceptance or final owner approval.
- [x] **V05 · Rejected people-card history:** [Manifest and five variants](../../designs/2026-11-07-people-cards/manifest.json): Collector, Portrait, Dossier, Timeline, Connections. The owner rejected all five. Preserve them as history and do not adopt them as the default.
- [x] **V06 · Capture composition:** Implemented the microphone control, open space, bottom composer, attachment affordance, and send control in SwiftUI. Retained a simulator screenshot; owner acceptance remains separate.
- [x] **V07 · Sidebar composition:** Implemented overlay, scrim, close control, seven routes, and settings access. Kept the reference's Profiles label for the planned People section. Simulator route tests pass; owner acceptance remains separate.
- [ ] **V08 · BrainMap composition:** Select a direction through the [reference-led lab](../design/reference-lab.md), then implement and verify node selection, readable connections, details, and return navigation. C14 rejects the first layout study. Native work and design approval remain incomplete.
- [ ] **V09 · People / Projects / Birthdays:** Select layouts through the [reference-led lab](../design/reference-lab.md), then implement and verify their states. C14 rejects the first four-screen study. New variants remain proposals; visual approval and native verification remain incomplete.
- [ ] **V10 · Typography and controls:** Verify Arabic fallback, Dynamic Type, contrast, touch targets, safe areas, keyboard behavior, and reduced motion on the native app.
- [ ] **V11 · Native comparison and owner review:** Retain screenshots and record visual review. Keep build success, device checks, and owner approval separate.

Layout-definition update, 2026-11-12: the owner rejected the [first specification](../design/screen-layouts.md) and [interactive study](../../designs/2026-11-12-screen-layouts/screen-layouts.html). Preserve them as history. The current [reference-led localhost lab](../design/reference-lab.md) explores five directions with annotations. It does not complete V08/V09 native delivery or owner approval.

## All 32 owner-requested features

All items below remain unchecked for the native application. Only the interface subset above belongs to the first demo. Requested live capabilities need later implementation and their unresolved decisions.

- [ ] **R01 · Voice capture:** Open the app and record a thought with one clear button.
- [ ] **R02 · Text and chat capture:** Dump thoughts into a text/chat field without organizing them first.
- [ ] **R03 · Idea collection:** Save the owner's ideas and categorize them.
- [ ] **R04 · Conversation import:** Import exported chats with other people. C09 names Telegram, Instagram, and WhatsApp among requested sources. Preserve discussion content; format support and order remain open.
- [ ] **R05 · Person profiles:** Connect imported information to the correct person and maintain a useful profile, including requested images and questions in R30/R31. Exact profile fields remain open.
- [ ] **R06 · Discussion organization:** Group what the owner and each person discussed by topic or context.
- [ ] **R07 · Audio transcription:** Convert recorded or imported audio into text. The wording of the initial audio/export request needs format clarification.
- [ ] **R08 · Transcript export:** Export a transcript and connect it to the relevant person's profile. Export formats remain open.
- [ ] **R09 · Project recognition:** Identify which project a capture concerns.
- [ ] **R10 · Project updates:** Add new information, plans, ideas, and future possibilities to that project.
- [ ] **R11 · Specific-chat understanding:** Explain the context and meaning of a selected conversation.
- [ ] **R12 · Conflict understanding:** Help examine disagreements in chats. Avoid treating a possible interpretation as an established fact. Detailed behavior remains open.
- [ ] **R13 · Email reading:** Read email from accounts the owner chooses to connect.
- [ ] **R14 · Calendar actions:** Add relevant email or captured information to the owner's calendar under selected rules. C09 limits the initial action/reminder scope to birthdays; broader actions are later scope.
- [ ] **R15 · Person-specific reminder choices:** Let the owner choose what information about each person deserves a reminder.
- [ ] **R16 · Important dates:** Start with birthdays only under C09. Anniversaries and other owner-selected dates remain later goals. Exact reminder behavior remains open.
- [ ] **R17 · User-defined rules:** Let the owner define how the app organizes information and acts on it. Rule format remains open.
- [ ] **R18 · Minimal interface:** Keep everyday use simple and avoid complex capture flows.
- [ ] **R19 · Hidden sidebar:** Show the sidebar only when the owner opens it.
- [ ] **R20 · Tabs:** Organize access through tabs or sections. Their initial set remains open.
- [ ] **R21 · Requested custom tabs:** Create a tab when the owner asks. The implementation is not selected.
- [ ] **R22 · On-phone AI and memory:** Keep everyday storage and processing on the iPhone where feasible. Test difficult work on the phone first.
- [ ] **R23 · Local control and self-hosting:** Minimize dependence on external hosting. Keep optional external connections separate from local operation.
- [ ] **R24 · Optional external AI, starting with ChatGPT:** C09 selects ChatGPT as the first external provider. Claude remains a later requested option. Supported authentication, model access, and allowed data transfers remain open.
- [ ] **R25 · Obsidian vault connection:** Integrate the app with an Obsidian vault. C09 also considers the vault as a storage option or a future app-owned store. No storage authority, access, export, or editing model is selected.
- [ ] **R26 · PDF and Word reading:** Import and understand these document types. Scanned PDFs and older Word formats need separate support decisions.
- [ ] **R27 · Multiple languages:** Understand Arabic, English, and other selected languages.
- [ ] **R28 · Future device access:** Extend useful capabilities to MacBook and possibly Android, alongside iPhone. Identical AI performance is not established.
- [ ] **R29 · Future sync backend:** Consider Convex or Supabase for cross-device use. Neither is selected.
- [ ] **R30 · Person images:** Support supplied photos, optional generated images, and reuse of an available supplied chat/profile image. Import availability, generation provider/location, and detailed behavior remain open.
- [ ] **R31 · Guided person questions:** Ask questions about a person and learn from the owner's answers. Question selection, timing, storage, and how answers affect the profile remain open.
- [ ] **R32 · BrainMap in the first demo:** Include a BrainMap screen with fictional sample connections in the clickable demo. Production graph architecture, automatic relationship extraction, and exact interactions remain open.

## All 25 supporting proposals

These entries preserve the existing proposal register. They are not additional selected first-demo features. P20 records the resolved stack choice; its unchecked application status does not reopen SwiftUI selection.

- [ ] **P01 · Source-backed question answering:** Search personal information and answer with the original source. State when evidence is missing.
- [ ] **P02 · Four memory record types:** Keep originals, extracted information, owner-confirmed facts, and AI interpretations distinct.
- [ ] **P03 · Traceable evidence:** Link claims to message dates, speakers, audio timestamps, or document sections/pages.
- [ ] **P04 · Corrections and undo:** Correct facts, classifications, links, and capture results. Do not silently replace source history.
- [ ] **P05 · Identity matching:** Match names, nicknames, Arabic/English spellings, and contact identifiers. Let the owner merge or split mistaken profiles.
- [ ] **P06 · Time-aware history:** Keep changed plans and conflicting statements with their dates. Distinguish tentative ideas from agreed commitments.
- [ ] **P07 · Multi-record links:** Link one capture to several people, projects, ideas, or dates without copying it.
- [ ] **P08 · Clear processing state:** Save captures before AI work. Show processing results and allow correction.
- [ ] **P09 · Transcript review:** Preserve audio, create timestamped text, and allow edits. Show uncertain recognition where supported.
- [ ] **P10 · Speaker separation:** Separate voices in multi-speaker audio. Ask the owner to identify a speaker when identity is uncertain.
- [ ] **P11 · Resumable import jobs:** Process large archives in batches. Resume after interruption without duplicate records.
- [ ] **P12 · Custom tabs as saved views:** Store filters over existing records when the owner requests a new tab. Do not generate arbitrary executable code.
- [ ] **P13 · Rule enforcement:** Convert chosen rules into visible, editable settings. Enforce cloud restrictions and action permissions outside model prompts.
- [ ] **P14 · Calendar preview and trusted automation:** Show proposed event details and source first. Let the owner choose narrowly defined automatic cases later.
- [ ] **P15 · Local data protection:** Use encryption, protected keys, backup/restore, export, and deletion. Exact designs remain open.
- [ ] **P16 · Obsidian import/export boundary:** Keep structured app records and readable Markdown views. Define what happens when the same note changes in both places.
- [ ] **P17 · Two external-AI routes:** Offer manual context handoff or an official API connection. Limit transferred context to owner-selected data.
- [ ] **P18 · Native AI components:** Evaluate llama.cpp for text and WhisperKit or whisper.cpp for speech. Evaluate small multilingual models such as Qwen3-1.7B. Text-runtime/model Simulator experiments now exist under group 4; production selection and speech benchmarks remain open.
- [ ] **P19 · Local storage and search:** Evaluate SQLite, keyword search, multilingual semantic search, and linked records. A graph server is not assumed.
- [ ] **P20 · Historical app language and framework options:** Resolved by D21/C10: Swift with SwiftUI is selected. The earlier Flutter proposal and Swift-versus-Objective-C comparison remain history. This row does not assert an implementation or efficiency result.
- [ ] **P21 · Cross-device record protocol:** Plan stable IDs, edit versions, attachment transfer, conflict resolution, and deletion propagation. Encryption and key recovery remain open.
- [ ] **P22 · Language and device evaluation:** Test Iraqi Arabic, mixed languages, names, sarcasm, right-to-left text, long imports, heat, battery use, and interruption recovery.
- [ ] **P23 · No silent network fallback:** Keep a failed or difficult local task local unless the owner chooses external processing. Imported text must not override rules.
- [ ] **P24 · Capture interface details:** Add an attachment button, compact result receipt, undo action, and a small reminder list. Initial sidebar sections were examples only.
- [ ] **P25 · Small offline proof of concept:** Record, transcribe, classify, link, retrieve with a source, correct, and export on the actual phone. Test in airplane mode after model downloads.

## Historical inventory: H01-H40

These entries preserve research, including older tools and repositories. They are not the current implementation backlog unless a current request separately selects matching scope. H09 overlaps the selected fictional BrainMap demo, but does not select the historical production graph. Do not adopt the rejected cloud-first stack through this inventory.

- [ ] **H01 · Natural-language recall:** Ask about past events, decisions, people, topics, and relationships. Show the supporting records.
- [ ] **H02 · Life timelines:** Organize events by year, month, and day. Summarize milestones and changes.
- [ ] **H03 · Event extraction:** Identify who, what, when, and where. Connect explicit dates, invitations, milestones, trips, and related conversations.
- [ ] **H04 · Topic discovery:** Group discussions into themes. Map topics to people and periods. Consider BERTopic or other clustering.
- [ ] **H05 · Communication statistics:** Count messages and contacts. Show reply times, active periods, top contacts, and changes in communication. Counts do not prove closeness or cause.
- [ ] **H06 · Sentiment and emotion trends:** Explore tone over time and by relationship. Allow analysis to be disabled and errors corrected. Treat sarcasm, culture, and missing data as limitations.
- [ ] **H07 · Change detection:** Find shifts in message frequency, topics, or tone. Show hypotheses with supporting counts and time ranges.
- [ ] **H08 · Commitments and conflict history:** Extract promises, tentative plans, and disagreements. Track follow-ups where evidence supports them. Do not infer completion from silence.
- [ ] **H09 · Relationship graph:** Connect people, groups, organizations, projects, events, and places. Explore communities and relationship changes.
- [ ] **H10 · Evidence browser and feedback:** Open cited snippets, inspect raw records and data ranges, correct insights, and merge/split contacts. Include reasons for negative feedback.
- [ ] **H11 · Proactive reflection:** Offer daily/weekly summaries and "this day in history" prompts. Sensitivity and notification controls need review.
- [ ] **H12 · Broader imports:** Gmail/IMAP, chat exports, SMS backups, diary entries, screenshots, photos, and email archives. Named connector ideas include WhatsApp, Messenger, Outlook, Slack, Teams, Notion, and note apps.
- [ ] **H13 · Share capture:** iOS share extension and Android share targets for text, links, and images. Store source metadata.
- [ ] **H14 · Quick capture access:** Widgets, Siri/App Intents, home-screen shortcuts, Android intents, and possible assistant integrations.
- [ ] **H15 · Camera and screenshot handling:** Take or select images, read text, and consider screenshot import suggestions with permission. No continuous access or background monitoring has been approved.
- [ ] **H16 · OCR and speech review:** Prefer local recognition, review uncertain text, support corrections and a possible names dictionary. Cloud fallback was an option, not current permission.
- [ ] **H17 · Capture categories and browser:** Ideas, decisions, tasks, journal/reflection, quotations/references, milestones, and conflict notes. Browse by date or tag, then edit or delete. Classification should be skippable or correctable.
- [ ] **H18 · Offline queue and processing controls:** Capture while offline, show queued/processing/failed/completed states, retry safely, and allow manual transfer controls. Old mandatory upload behavior is superseded by the current local-use preference.
- [ ] **H19 · Temporary conversations:** Keep short-term conversational context separate from durable memory. Consider a configurable timeout, continue-later/pinned context, clear-session action, and private/incognito chat.
- [ ] **H20 · Multilingual behavior:** English, Arabic, and Turkish were named. Consider cross-language search, query translation, same-language replies, original/translated citations, and Arabic RTL. Current additional-language priorities remain open.
- [ ] **H21 · Owner data controls:** Consent by source/purpose, a consent ledger, connected-source pause/revoke controls, inspect/correct/delete/export, retention choices, and disabling selected analyses.
- [ ] **H22 · Privacy views and redaction:** Explain why an insight appears. Consider masking selected identifiers, custom sensitive terms/topics, selective import, restricted export, and sensitivity settings.
- [ ] **H23 · Portable exports:** Export raw data and derived records in formats such as JSON/CSV; export reports as PDF/HTML. Exact formats are historical suggestions.
- [ ] **H24 · Writing-style profile:** Analyze vocabulary, punctuation, sentence form, tone, greetings, emoji, and language mixing. Use a structured style guide and selected examples.
- [ ] **H25 · Persona style controls:** Neutral/light/strong style levels, user adjustments, and factual grounding separate from presentation. Sensitive-topic tone behavior remains a design choice.
- [ ] **H26 · Optional personal style training:** Consider per-user LoRA/adapters or feedback-driven tuning later. This is research, not permission to train on private data.
- [ ] **H27 · Digital legacy persona:** Preserve an explicitly labeled AI memory/style simulation. Explore consent or estate authority, an exportable read-only archive, identity disclosure, and limits. Current owner has not reconfirmed this product scope.
- [ ] **H28 · Clinician or coach use:** Consented client summaries, timelines, between-session reflection, and a limited pilot. No clinical validation or pilot authorization exists.
- [ ] **H29 · Enterprise memory:** Team knowledge, onboarding, expertise lookup, role continuity, workflow insights, and professional/industry editions. Shared access and consent would need a new design.
- [ ] **H30 · Collaboration:** Mutually shared memories or joint timelines. Private sharing and third-party data controls remain unresolved.
- [ ] **H31 · Additional personal sources:** Health/fitness logs, photo metadata, travel/location context, external contacts/social graphs, and possible cross-source patterns. No sensor or health-data integration is authorized.
- [ ] **H32 · External API and plugins:** Query personal memory through authenticated tools. Consider email/chat plugins, Siri/Alexa hooks, and exports to other note systems.
- [ ] **H33 · Three retrieval views:** Semantic vectors, keyword/full-text search, and linked entities/events share stable source IDs. Graph traversal and nearby-thread/time context can supplement retrieval.
- [ ] **H34 · Ranking and expansion experiments:** RRF rank fusion, MMR diversity, BM25, HNSW/IVF, optional MiniLM/MPNet cross-encoders or ColBERT, HyDE, pseudo-relevance feedback, synonyms, recency weighting, and possible learned ranking/session embeddings. None is a selected app algorithm.
- [ ] **H35 · Historical cloud stack:** Python/FastAPI, LangChain/custom orchestration or Haystack research; Postgres/pgvector; Neo4j/relational graph; Qdrant/Pinecone scale options; Elastic/OpenSearch; object storage; Docker/CI. Cloud-first launch is superseded for current planning.
- [ ] **H36 · Historical model/tool choices:** GPT-4/GPT-3.5, Claude, Llama 2/GPT-J, OpenAI embeddings, multilingual MPNet/LaBSE, spaCy/NER, date parsers, emotion lexicons, Presidio, Vision, ML Kit, and OS speech APIs. These names record past options, not current recommendations.
- [ ] **H37 · Security research:** Device/app unlock, encryption, protected keys, encrypted backups, deletion across derived stores, TLS, per-user isolation, 2FA/SSO, token controls, rate limits, safe logs, threat modeling, BYOK, KMS, confidential compute, and incident response. Designs need current review.
- [ ] **H38 · Evaluation research:** Known-answer data, citation support, contradiction tests, precision/recall/MRR, RAGAS, OCR/ASR error rates, identity accuracy, injection/privacy testing, feedback, performance/cost measurements, and regression tests. Historical targets were not measured results.
- [ ] **H39 · Business and deployment options:** Freemium/premium, one-time/lifetime or self-hosted editions, enterprise licenses, private/VPC/on-prem hosting, possible open-core code, pilots, partnerships, regional launches, and professional packs. No pricing, company launch, or deployment is selected.
- [ ] **H40 · Delivery and growth suggestions:** Prototype/MVP/v1/v2 stages, web dashboard, native mobile clients, TestFlight/beta plans, staffing, legal review, privacy documentation, support/community work, future research, cost monitoring, and optional capture gamification. No schedule, hiring, budget, or publication is approved.

## 3. Add reliable local storage and text capture

C35 authorizes Step 1, C36 starts Step 2 and C37 authorizes Step 3 review/private draft delivery, 2026-11-14. Independent review closed Unicode byte-preservation and initial storage-open retry defects. Local functional/storage tests, builds/analysis, cleanup and dark screenshots pass. Physical iPhone protection/performance, iOS 18 runtime and unresolved accessibility checks block Step 2. See the [connected task record](../tasks/2026-11-14-local-storage-text-capture.md). These boxes remain open until independent verification; implemented subsets do not complete broader R02/R03/R05/R10/R22/R23/R27. Earlier S09 temporary-capture wording describes the historical demo and no longer describes this task's durable typed captures.

- [ ] **Choose storage:** Evaluate SQLite and define where original records live.
- [ ] **Save typed thoughts:** Keep captures after closing and reopening the app.
- [ ] **Store linked records:** Give people, projects, ideas, and captures stable connections.
- [ ] **Edit and correct:** Let the owner fix information without losing its source.
- [ ] **Protect records:** Define deletion, export, backup, and restore behavior.
- [ ] **Keep local use independent:** Make capture work without an external service.


## 4. Test local AI tools on the phone

C38 authorizes Step 1; C39 requires completed downloads/repairs and C40 selects Simulator for this stage. Step 1 now completes actual SDK/model checks and repeated Simulator comparisons: 450 completed operations plus 15 explicit MLX unavailable cases, with separate real Mac MLX execution. Quality failures keep production adoption open. Physical battery/heat remains future phone-readiness work. See the [measured results](../evidence/local-ai-2026-11-14/resume-summary.md) and [task record](../tasks/2026-11-14-local-ai-phone-evaluation.md). C41 starts independent Step 2. C43 follow-up repairs close the clean-checkout package regression, Cactus source-verification gap and Dynamic Type findings. Independent repair checks and both unfiltered accessibility audits now pass for the C40 Simulator experiment. These broader outcome boxes remain open for applicable physical-phone evidence and production component selection; they do not mean the Simulator implementation/downloads are unfinished. C44 Step 3 merges the verified experiment in [PR #4](https://github.com/faroqomar/Eros_MemoryOS/pull/4), merge `7e20302`. The proposed group 5 chat checklist is not implemented by this evaluation.

- [ ] **Compare memory options:** Evaluate Wax and a supported Cactus-based configuration.
- [ ] **Compare text runtimes:** Evaluate llama.cpp and other suitable supported options.
- [ ] **Compare models:** Test Qwen3-1.7B and other candidates on the same examples.
- [ ] **Test your languages:** Check Arabic, Iraqi Arabic, English, names, and mixed text.
- [ ] **Measure phone cost:** Record speed, memory, storage, battery use, and heat.
- [ ] **Select components:** Choose from measured results and keep original records independent of those choices.


## 5. Connect local AI to chat and complete the chat experience

C47 authorizes Step 1 and C48 starts Step 2. [Implementation and independent evidence](../tasks/2026-11-15-local-ai-chat.md) include fresh architecture/behavior review, recovery repairs, actual Simulator flows, cleanup and dark captures. Checked boxes identify verified local outcomes. Open boxes retain performance and unavailable-device/OS gates; C49 removes extended VoiceOver testing from this task. Step 2 has not passed; Step 3 has not started.

- [x] Send a main-app message and receive a real local-model reply.
- [ ] Stream text while typing, scrolling and navigation stay responsive. Streaming and interaction flows pass. C49 generation timer maxima are 35–46 ms in four matched requests; clean scrolling latency and actual frame budget remain unestablished because automation snapshots distort retained scroll proxies.
- [x] Continue conversations and show context limits without silently dropping history.
- [x] Provide multiline input, keyboard handling, send/loading states and a distinct Save thought action.
- [x] Animate message arrival and control changes with Reduce Motion support.
- [x] Follow the bottom, preserve manual reading position and provide Latest.
- [x] Stop, preserve partial replies, retry and regenerate without duplicate messages.
- [x] Create, reopen, rename and delete chats; preserve chats and drafts across restart.
- [x] Render paragraphs, lists, emphasis and code; copy replies.
- [x] Retrieve relevant app-owned memories with current source links and missing-evidence states.
- [x] Keep AI interpretations separate; apply record corrections/deletions to retrieval.
- [x] Test Arabic, Iraqi Arabic, English, names, mixed text and RTL in real conversations.
- [ ] Recover from missing models, interruption, memory pressure, backgrounding and relaunch. Missing-model retry, stop/background partial retention and relaunch pass; actual OS memory-pressure injection remains unavailable.
- [ ] Work offline after model preparation; no silent cloud fallback. Local-file inference, visible missing-model failure and 19 native host contracts under OS network denial pass; full disconnected Simulator execution remains unverified.
- [x] Verify MVVM, injected interfaces and replaceable existing adapters.
- [x] Verify larger text, labels, Reduce Motion, contrast and usable touch targets in the requested Simulator scope. Maximum text and English/Arabic native semantic audits pass; Reduce Motion has actual captures. C49 withdraws extended VoiceOver testing from this task; it did not pass. Physical-device readiness remains separate.
- [x] Measure loading, first text, generation, scrolling, memory and cancellation; separate simulator/phone results.
- [ ] Complete fresh independent Step 2, repairs, dark evidence and owner simulator testing. Review, repairs and local evidence are complete; listed acceptance gates and owner testing remain open.
