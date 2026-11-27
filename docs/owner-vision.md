# MemoryOS: my ideas, thoughts, and choices

Compiled on 2026-11-19 from the available project records.

**Reading note:** The first-person sections reconstruct the owner's meaning in plain English. They are paraphrases, not verbatim quotations or a complete chat transcript. The source records contain sanitized summaries, and some earlier wording is unavailable. This document collects the distinct ideas found in those records. It does not invent missing thoughts, approve proposals, or certify working features.

**Status:** Requested and confirmed describe what the owner wants or chose. Proposed describes an assistant suggestion. Historical describes older research whose authorship and approval are not established. Superseded describes a choice replaced by a later instruction. Implementation and verification belong to the linked task records.

## 1. The app I want

I want a personal second brain that helps me manage my life in my own way. I want somewhere to put my thoughts, conversations, ideas, recordings, plans, and information about people. Later, I want to ask about them and recover the relevant context.

I want both everyday thought and project memory, and help understanding relationships. Both matter for the first useful product. I am not asking for a general ChatGPT replacement. I want an assistant that understands the personal context I choose to give it.

I first want it to help people like me who manage thoughts, projects, and relationships. I also want to sell it in the future. I have not settled the countries, business location, pricing, or launch date.

Sources: [product overview](product-overview.md), [personal-context goal and discovery Q1–Q5](decisions/personal-context-goal.md), [C22](reference/source-register.md).

## 2. Let me put information in without filing it first

I want to open the app and start typing or recording. I should not need to choose a folder, category, person, or project before I can express a thought. I want to dump information into a simple chat field or use one clear recording button.

Then I want the app to work out what the capture concerns: a person, a project, an idea, a date, or several related things. I want to find it later without remembering where I filed it. I should be able to correct the organization.

I want to capture everyday thoughts, new ideas, project information, workflow changes, current plans, future possibilities, and commitments. The app must preserve the difference between considering something and deciding to do it.

Sources: [R01–R03, R09–R10, R18](feature-register.md), [personal-context goal](decisions/personal-context-goal.md), [group 7 request](tasks/2026-11-17-lasting-personal-memory.md).

## 3. Normal chat should become useful lasting memory

I want normal conversations with the app to become lasting memory without a separate save-and-classify process for each message. I want it to recognize useful information and connect it to what it already knows.

I want real understanding of meaning. I rejected repeated generic menus that ask me to classify ordinary messages. If I am venting, role-playing, considering an uncertain plan, or saying something ambiguous, ask a specific question in the conversation when clarification matters.

Ask immediately before deriving a memory from unresolved ambiguity. If I do not answer, keep my original message and leave the ambiguous part unresolved. Do not turn a frustrated statement into a confirmed fact or a tentative thought into a commitment.

Sources: [discovery Q6, Q14, Q19](decisions/personal-context-goal.md), [group 7](tasks/2026-11-17-lasting-personal-memory.md), [automatic-memory rework](tasks/2026-11-18-automatic-personal-memory.md).

## 4. Keep what happened separate from what the AI thinks

I want the app to preserve original communications, audio, attachments, and my corrections. A summary or interpretation should link back to its source. It must not replace what someone said.

Keep original records, extracted statements, information I confirmed, and AI interpretations distinct. Keep dates and surrounding context so a later answer can distinguish a changed plan from a contradiction. Treat something reported by a person as their statement, rather than independent proof that it happened.

Let me inspect sources, correct mistakes, and undo organization changes. Ask before changing confirmed facts or merging people. If my interpretation conflicts with the messages, ask me to clarify before giving a substantive answer about the conflict. Preserve both accounts and the contrary evidence.

Sources: [discovery Q7, Q16, Q18](decisions/personal-context-goal.md), [commercial and engineering rules](how-to/commercial-engineering-rules.md), [group 8 scope](tasks/2026-11-18-understanding-organization.md).

## 5. Understand people and relationships from their history

I want to import extensive conversations with people, including available photos and voice messages. I want the app to understand the history and help me explore a particular discussion, argument, or change in the relationship.

This includes partners and romantic relationships, friends, family, and colleagues. It should work from either participant's available history. I want to ask what each person said, what they agreed on, what caused disagreement, what repair attempts they made, and what remains unresolved.

I want help examining possible emotions, communication patterns, and changes over time. Explain the evidence, offer alternative explanations, and challenge my interpretation when the evidence warrants it. Support me emotionally while helping me think clearly.

Do not claim certainty about someone's inner motives or diagnose them. Missing messages, sarcasm, cultural context, and one-sided histories can change the interpretation. Make interpretations visible, revisable, and correctable.

Sources: [confirmed personal-context goal](decisions/personal-context-goal.md), [discovery Q3 and Q23](decisions/personal-context-goal.md), [groups 8–9 request](tasks/2026-11-18-understanding-organization.md).

## 6. Help me think about my next action

I want the app to explain options, recommend a next step, and show the evidence and tradeoffs. I make the decision.

When I ask, help me draft a respectful reply or plan a conversation. Do not send it automatically. Show relevant insights inside the app when they are useful. Notifications need topics and timing that I enable.

Ask before external actions. One approval can cover an exact recurring reminder schedule, including its agreed scope. That does not grant permission for other actions or a changed schedule.

Sources: [discovery Q4, Q8, Q10–Q11, Q15, Q23](decisions/personal-context-goal.md).

## 7. Build useful person profiles and a profile of me

I want each person to have a useful profile connected to their discussions, important information, dates, projects, and source material. The app should suggest identities across names, nicknames, languages, and imported sources, while asking before a merge.

For my own profile, include the preferences and goals I state. It may also include interpretations if it labels them clearly and lets me correct them. Do not present a guessed personality trait as a confirmed fact.

Ask optional questions about a person and learn from my answers. Keep the questions short enough that they do not turn capture into a long questionnaire.

I want options to supply a photo, reuse a photo that an import actually contains, or use a generated representation. Preserve the image's origin. A generated image is not a verified photograph; a missing export photo must remain missing.

Sources: [C09, R05, R30–R31](feature-register.md), [discovery Q12](decisions/personal-context-goal.md), [group 7](tasks/2026-11-17-lasting-personal-memory.md).

## 8. Organize my projects, ideas, and workflows

I want to tell the app about a project without opening a special form first. It should connect new information to the right project and help me recover its history.

Keep project facts, current plans, workflow updates, tentative ideas, future possibilities, and commitments distinct. Let me see related people, discussions, sources, and corrections. Organize categories, links, and summaries reversibly so I can repair mistakes.

I also want tabs or sections that I can request. I want to define rules for how the app organizes information and acts. The later requested scope includes inspecting, editing, testing, disabling, and undoing supported rules, and saving named views over current information.

Sources: [R03, R09–R10, R17, R20–R21](feature-register.md), [group 7](tasks/2026-11-17-lasting-personal-memory.md), [groups 8–9 scope](tasks/2026-11-18-understanding-organization.md).

## 9. Let me record and continue a conversation

I want to record new audio and import supported audio. I want pause, resume, save, a visible recording state, and clear permission handling. Preserve the recording and let me review and correct its transcript.

A recording from Home should open a conversation. Show my audio as a message with playback and duration, and let me reveal the transcript with a disclosure control. After transcription, the local AI should reply. My typed follow-ups should stay in that conversation.

Save audio before processing. If transcription or generation fails, show the problem and let me recover without losing the recording or creating duplicate messages. Give me a Recordings route to manage existing material. I also want transcript export and links to relevant people and sources.

Local Arabic, Iraqi Arabic, English, mixed speech, names, and difficult recordings matter. A completed recording flow does not establish transcription accuracy. Existing audio imports, new recordings, and multi-speaker handling have different support requirements.

Sources: [R01, R07–R08](feature-register.md), [audio candidates](decisions/audio-recording-and-transcription.md), [group 6](tasks/2026-11-15-voice-transcription.md), [voice-chat request](tasks/2026-11-17-voice-chat.md).

## 10. Give chat the behavior I expect

I want local replies that stream as the model writes. Preserve conversations and drafts so I can return to them. Keep follow-ups connected to the conversation and relevant memories.

I want stop, retry, regenerate, readable formatting, and copying. Handle context limits honestly instead of silently dropping information needed for the answer. Keep the composer, keyboard, scrolling, and motion usable during generation.

Use current app-owned memory and respect corrections and deleted information. Let me inspect the sources used in a reply. Keep original records safe when I regenerate or edit a chat.

Sources: [C47 and local-chat task](tasks/2026-11-15-local-ai-chat.md), [current recall request](tasks/2026-11-18-local-recall-integration.md), [4B conversation request](tasks/2026-11-18-qwen4b-conversation.md).

## 11. Give me a temporary/private conversation mode

Sometimes I want a conversation that uses what the app already knows but adds nothing new to lasting memory.

Temporary chat may read existing memory for context. It must save no new lasting conversation or derived memory. End it when I explicitly finish or when the process terminates. Keep it available during brief app switching.

This is a requested privacy behavior. Its implementation limits and tests belong to the task records; the idea alone does not prove that every input type or failure path meets it.

Sources: [discovery Q13 and Q20](decisions/personal-context-goal.md), [group 7 privacy scope and evidence](tasks/2026-11-17-lasting-personal-memory.md).

## 12. Import the history I choose to provide

I have requested Telegram, Instagram, WhatsApp, Facebook, and Snapchat conversation imports. Keep the available messages and media, their speakers, dates, order, and context. I have not chosen a single first source.

I want extensive histories, including available photos and voice messages. Actual export contents and platform limits determine what the app can recover. Do not promise unlimited imports or reconstruct content that an export does not contain.

Finish processing an entire archive before allowing AI answers about that archive. This does not mean unrelated capture or chat must stop. The exact treatment of corrupt files, unavailable media, and completion needs a decision.

I also want PDF and Word reading, Obsidian notes, and email from accounts I choose to connect. Formats, scanned pages, tables, attachments, access permissions, and the first providers remain separate choices.

Sources: [R04, R13, R25–R26](feature-register.md), [personal-context goal and Q21–Q22](decisions/personal-context-goal.md), [checklist groups 10–11](plans/implementation-checklist.md).

## 13. Find what matters and show me where it came from

I want to ask natural questions about my past information and get useful answers from the relevant records. Show original passages, dates, surrounding conversation, and corrections so I can inspect the evidence.

I want conversation, topic, and time-period summaries, while retaining access to the originals. A correction or deletion should affect later search, summaries, profiles, and indexes. Warn me about incomplete or stale processing.

I included BrainMap in the demo because I want to explore connections between people, projects, and memories. The later scope asks for real records and source navigation. That does not approve a particular graph layout or make visual proximity proof of a relationship.

Sources: [R32](feature-register.md), [groups 8–9](tasks/2026-11-18-understanding-organization.md), [local recall](tasks/2026-11-18-local-recall-integration.md).

## 14. Remember important dates under my rules

I want to choose what deserves a reminder about each person. Start with birthdays. Anniversaries and broader actions can follow later.

Let me choose notifications versus calendar events, the time and timezone, and recurrence. Keep partial dates and corrections visible. Show what I am approving, preserve the exact approved schedule, and ask again if the scope changes.

I also want relevant email or captured information to become calendar items under chosen rules in a later stage. Permission denial, retries, and duplicate prevention need clear behavior.

Sources: [R14–R17](feature-register.md), [discovery Q15](decisions/personal-context-goal.md), [groups 8–9 request](tasks/2026-11-18-understanding-organization.md).

## 15. Keep the interface simple and native

I want a large microphone, a text/chat field, and a sidebar that stays hidden until I open it. Keep the app simple enough that the interface does not interrupt the thought I am trying to capture.

The supplied Capture and sidebar screenshots are the active layout reference. I chose Apple design and SwiftUI. Keep the central recording control, bottom composer, spacing, and hidden navigation. Use dark mode for the app by default and for completed previews and visual checks.

I requested native Liquid Glass controls where supported and removal of the marked composer warning/Done footer. Keep an appropriate fallback on older supported iOS versions. Preserve Arabic/English, readable text, usable controls, and right-to-left behavior.

Capture, People and person details, Projects, Birthdays, and BrainMap belong to the selected demo set. Inclusion does not mean I approved every screen's final layout.

Sources: [C19–C21 and active references](reference/source-register.md), [demo direction](decisions/demo-and-feature-direction.md), [voice-chat interface request](tasks/2026-11-17-voice-chat.md).

## 16. Keep everyday use on my iPhone

My first target is my iPhone 15 Pro Max. I prefer storage and processing on the phone, including difficult work where feasible. Everyday use must not depend on a Mac or server.

I want local control and offline use. Arabic and English are required, including Iraqi Arabic and mixed-language use. I want other languages too, but I have not settled the list. Turkish appears in the older research.

A Mac can help with development and experiments. That does not make it a required part of the finished daily workflow. Measure the actual phone's speed, memory, storage, battery use, and heat before making performance claims.

Sources: [C01–C02 and D02–D05](decisions/decision-register.md), [language goal](product-overview.md).

## 17. Optional connections can come later

I want optional help from ChatGPT and later Claude, email access, an Obsidian connection, and future sync. My later discovery choice disables cloud AI and web search for the first useful version. ChatGPT-first is the priority for a future external-AI stage.

Choose supported authentication and decide what information may leave the phone before connecting. Do not assume that my ChatGPT subscription supplies an app integration or API entitlement. Never use a silent cloud fallback.

I want future MacBook access and possibly Android. Supabase and Convex are options to compare for sync, not selected services. Keep optional encrypted sync separate from permission to send readable context to cloud AI. Define conflicts, deletion propagation, backup, and key recovery before relying on sync.

Sources: [R23–R29](feature-register.md), [discovery Q17](decisions/personal-context-goal.md), [commercial rules](how-to/commercial-engineering-rules.md).

## 18. Experiment with components and keep them replaceable

I want to compare models through testing and analysis and choose based on results. I asked to consider Wax and Cactus, experiment with them, and be able to switch configurations without losing my information. Later, I requested their local recall integration.

I asked to document AVAudioRecorder for recording and WhisperKit and whisper.cpp for local transcription. Recording, speech recognition, retrieval, and language generation should remain independently replaceable.

I chose Swift with SwiftUI. Keep one canonical app repository. When I asked for separate engine repositories, I meant upstream libraries such as Wax, not new custom memory and speech products. Use small app-owned interfaces, thin adapters, and reviewed pinned versions.

I later selected the downloaded Qwen3 4B as the only conversational/relevance language model for the current experiment. This supersedes the smaller conversation-model composition. It does not prove production quality, qualify the phone, or enable automatic extraction after failed quality checks.

Sources: [C07–C10](reference/source-register.md), [corrected library decision](decisions/independent-engine-packages.md), [local recall](tasks/2026-11-18-local-recall-integration.md), [4B choice](tasks/2026-11-18-qwen4b-conversation.md).

## 19. Explore customization, tools, and background work

I asked how the app could become better suited to my context, including fine-tuning and tools. That discussion did not select a training method or authorize training on private conversations.

The recorded proposals include instructions and examples, source-backed retrieval, local search and source inspection, transcription, OCR, timeline comparison, project linking, optional web search, and optional image generation. Model tuning remains an experiment to justify against measured failures.

Large imports and processing need visible progress, recovery, and bounded storage. The proposed approach uses resumable work for transcription, extraction, summaries, and indexing within iOS limits. It must not promise unlimited recording, unlimited archives, or uninterrupted background execution.

Sources: [personal-context discussion and proposed direction](decisions/personal-context-goal.md), [checklist groups 10–13](plans/implementation-checklist.md), [thinking-aloud proposal](reference/2026-11-18-ui-inspiration.md).

## 20. Build it in stages and keep the evidence honest

I chose a clickable sample-data demo first, followed by feature-by-feature growth. I later authorized the native foundation and individual implementation tasks. A documentation or brainstorming request alone does not start another feature.

Use the three-step workflow: understand, plan, implement and test; independently verify and repair; then review, clean documentation, push, open the PR, and merge when the required gates pass. A requested Step 3 supplies normal delivery authorization. Publication and release remain separate.

Use MVVM: views display state, ViewModels manage feature state through use cases, and adapters isolate databases and providers. Check actual dependencies and behavior rather than relying on folder names. Use relevant skills and scoped helpers when useful, with fresh independent app verification.

Clean confirmed dead code, duplicate evidence, and temporary files while preserving original research, unique evidence, active work, and my phone history. Keep documentation compact. Show actual changed states in dark mode for development steps. Preserve failed, unavailable, deferred, and withdrawn checks as those states.

Keep durable project decisions in English Markdown and synchronize sanitized records to this project's separate development-memory bank. Do not retain raw personal chats or copy my screen recordings into project evidence. Product memory and coding-agent memory have different purposes.

Sources: [AGENTS.md](../AGENTS.md), [workflow](how-to/development-workflow.md), [architecture rules](how-to/commercial-engineering-rules.md), [development memory](how-to/hindsight.md).

## 21. Prepare for a maintainable commercial product

I want to be able to sell the app in several markets later. Plan data ownership, privacy, security, accessibility, maintenance, and safe upgrades from the start.

Keep my originals, stable IDs, links, corrections, and confirmed facts under MemoryOS ownership. Provider indexes must be rebuildable. Make backup, restore, migration, deletion, and provider switching verifiable. Keep secrets and private content out of logs.

Review the obligations that apply to the chosen markets and data flows before launch. Exact markets, business structure, pricing, providers, production data policies, and release readiness remain open. A build, test run, or merged PR does not establish commercial readiness.

Sources: [C22–C23](reference/source-register.md), [commercial and engineering rules](how-to/commercial-engineering-rules.md).

## 22. My design changes and reference history

These are recorded changes in direction, not one combined approved design.

- I requested several distinct People-card options and rejected those examples.
- I included BrainMap, then requested layouts for People, Projects, Birthdays, and BrainMap. I rejected the first layout proposal.
- I requested deeper reference research, distinct variants, and one local app where I could annotate regions I liked or disliked.
- I rejected Atlas, Almanac, Circles, Cabinet, and Focus, and asked for a simpler result based on the existing home screen.
- I asked to use Astryx, rejected that restrained result, requested a wild redesign, and rejected that result too.
- I chose Apple design, then supplied Capture/sidebar screenshots and asked to stick with them. My later dark-mode preference replaces the earlier light palette for current delivery.
- I later supplied memory controls, voice-note, person-page, relationship-graph, and timeline references. Their proposed adaptations still need review.

Attribution and details: [visual reference index](design/visual-reference-index.md), [source chronology](reference/source-register.md), [reference lab](design/reference-lab.md), [November 18 inspiration review](reference/2026-11-18-ui-inspiration.md). These retain the distinction between a reference I supplied and an implementation I accepted.

## 23. Supporting suggestions, kept separate from my decisions

The assistant proposed the approaches below. Some later became adopted rules or authorized implementation scope; the later source controls. Their inclusion here does not convert the remaining proposals into my choices.

| Register IDs | Suggested approach | Later status or remaining choice |
| --- | --- | --- |
| P01–P04 | Answer from sources; separate originals, extracted information, confirmed facts and interpretations; preserve provenance and undo. | Later rules and groups 7–8 adopt these principles. Detailed qualification remains task-specific. |
| P05–P07 | Match identities, retain time-aware history, and link one record to multiple people/projects. | Identity confirmation and correction safeguards were requested later. Exact automatic matching quality remains open. |
| P08–P10 | Save before processing; show state; review timestamped transcripts; distinguish speakers. | Save/recovery and transcript work entered later scope. General multi-speaker support remains unresolved. |
| P11–P14 | Resume imports; implement custom tabs as saved filters; expose rule enforcement; preview calendar actions. | Imports remain future work. Named views and bounded birthday approval entered groups 8–9. |
| P15–P17 | Protect local data; define Obsidian ownership; offer manual external-AI handoff or official APIs. | Protection rules are adopted. Full backup/key recovery, Obsidian mode and AI connection remain open. |
| P18–P20 | Compare native inference/speech, SQLite/search and app frameworks. | SwiftUI is selected; SQLite supports current typed records; model and adapter experiments have separate evidence. |
| P21–P23 | Version cross-device records; evaluate languages and device cost; prevent silent network fallback. | Ownership and no-fallback rules are adopted. Sync choices and production qualification remain open. |
| P24–P25 | Add capture attachments, a compact receipt/undo/reminder area, then prove a small offline capture-to-answer loop. | Individual interface details need review; task checks do not establish the full product. |

Source: [P01–P25 register](feature-register.md). Other proposals include staged multimodal imports, OCR/vision, layered summaries, retrieval before fine-tuning, a contextual graph with a list alternative, editable memory controls, and a filtered timeline. See [personal-context proposals](decisions/personal-context-goal.md) and [UI adaptations](reference/2026-11-18-ui-inspiration.md).

## 24. Older ideas I want kept in the record

**Historical research, not reconstructed first-person approval.** The original files describe a wider product. The records do not establish that the owner authored or adopted each item. Retain these ideas as history unless a current request separately selects them.

| IDs | Older idea | Details preserved |
| --- | --- | --- |
| H01 | Natural-language recall | Ask about past events, decisions, people, topics and relationships, with supporting records. |
| H02–H04 | Timelines, events and themes | Year/month/day views, milestones, who/what/when/where, trips/invitations, topic clusters and links to people/time periods. |
| H05–H07 | Communication and tone trends | Counts, response times, active periods, topic/tone changes and sentiment. Counts do not prove closeness or cause. |
| H08 | Commitments and conflicts | Promises, tentative plans, disagreements and follow-ups; silence does not prove completion. |
| H09–H10 | Relationship graph and evidence browser | Connect people, groups, organizations, projects, events and places; inspect sources; correct insights; merge/split mistakes. |
| H11 | Proactive reflection | Daily/weekly summaries and this-day-in-history prompts, with sensitivity and notification choices. |
| H12 | More import sources | Gmail/IMAP, SMS backups, diaries, screenshots, photos, email archives, Messenger, Outlook, Slack, Teams, Notion and other note apps. |
| H13–H15 | Faster capture routes | Share extensions/targets, widgets, Siri/App Intents, shortcuts, camera/OCR and permission-based screenshot suggestions. No continuous monitoring approval. |
| H16–H18 | Recognition and capture management | Local speech/OCR, uncertain text review, a names dictionary, editable categories, capture browser, offline queues and retry states. |
| H19–H20 | Session and language options | Timeouts, pinned context, clear-session/private chat; Arabic/English/Turkish, cross-language search, translated citations and RTL. Current temporary-chat choices supersede older defaults. |
| H21–H23 | Personal data controls | Consent ledger, source pause/revoke, retention, correction/delete/export, sensitive-topic controls, redaction, JSON/CSV and PDF/HTML reports. |
| H24–H26 | Writing-style customization | Vocabulary, punctuation, tone, greetings, emoji, mixed languages, adjustable style intensity and optional personal adapters. No private-data training approval. |
| H27 | Digital legacy persona | An explicitly disclosed AI memory/style simulation, prior consent or estate authority, read-only archive and identity limits. Not reconfirmed current product scope. |
| H28 | Clinician/coach edition | Consented summaries, timelines and between-session reflection. No clinical validation or pilot authorization. |
| H29–H30 | Enterprise and collaboration | Team memory, onboarding, expertise and role continuity, shared memories and joint timelines. Access/consent design unresolved. |
| H31–H32 | Additional personal context and plugins | Health/fitness, photo metadata, location/travel, social/contact context, authenticated memory APIs and assistant/email/chat plugins. No sensor or health integration approval. |
| H33 | Combined retrieval | Semantic search, keyword search, linked entities/events, graph traversal, nearby-thread and time context with shared source IDs. |
| H34 | Ranking research | BM25, RRF, MMR, HNSW/IVF, rerankers, HyDE, relevance feedback, synonyms, recency and learned/session ranking. No blanket algorithm selection. |
| H35–H36 | Historical cloud stack and models | Python/FastAPI, LangChain/Haystack, Postgres/pgvector, Neo4j, Qdrant/Pinecone, Elastic/OpenSearch, object storage, Docker/CI; older GPT/Claude/Llama, embeddings, NER, date parsing, Presidio, Vision/ML Kit and speech APIs. |
| H37–H38 | Security and evaluation research | Unlock, protected keys/backups, deletion across stores, isolation, 2FA/SSO, quotas, safe logs, threat models, BYOK/KMS, incident response; known-answer, citation, contradiction, recognition, identity, injection and performance tests. |
| H39 | Business options | Freemium/premium, one-time/lifetime, self-hosted, enterprise/private/VPC/on-prem, open-core, regional launches, pilots and professional packs. No selected pricing or deployment. |
| H40 | Growth and delivery options | Prototype/MVP/v1/v2, web dashboard, Android, TestFlight/betas, staffing, support/community, legal review, partnerships, cost monitoring and optional capture gamification. No current schedule or budget. |

Source: [H01–H40 historical register](reference/historical-research.md). The old schedules, budgets, formulas, numerical targets, legal claims, and bibliography remain in the unchanged [full research](../Project_Idea.md), [summary](../Project_Idea_Summary.md), and [expanded summary](../Project_Idea_Expanded_Summary.md). They are historical estimates and claims, not current commitments or verified facts. The report's contents mention fifteen novel concepts, but no corresponding numbered body section was found; this document does not invent it.

## 25. Choices that changed

| Earlier record | Later direction |
| --- | --- |
| Cloud-first architecture; local models as a later option | Prefer iPhone-local daily processing. Cloud AI and web search are disabled for the first useful version. |
| Digital legacy and professional use as central products | Current focus: everyday thought/project memory and personal relationship understanding. Wider editions remain historical. |
| Flutter proposal or undecided Swift/Objective-C | Swift with SwiftUI is selected. |
| Documentation-only/no-build checkpoint | Later task-specific requests authorized the native foundation and individual features. This writing task adds no app scope. |
| Obsidian or future storage undecided | App-owned durable records are required; SQLite supports typed records and a separate versioned archive supports personal graph data. Obsidian's integration mode remains open. |
| ChatGPT first | Still first for a future external connection; later discovery excludes cloud AI/web search from the first useful version. |
| Several experimental conversation models | Current experiment selects Qwen3 4B only for conversation/relevance. Production qualification remains separate. |
| Generic per-message meaning menus | Rejected in favor of semantic organization and specific clarification where needed. Failed extraction quality still blocks automatic writes. |
| Separate custom memory/speech repositories | Corrected to one app repository with replaceable upstream library integrations. |
| Light home, five visual variants, restrained/wild prototypes | Current layout uses supplied Capture/sidebar references, native Apple direction, and dark appearance. Rejected variants remain history. |
| Broad reminders and calendar actions | Birthdays first; later expansion needs its own scope. Exact approved recurrence can run without repeated approval for each delivery. |

Sources: [decision register](decisions/decision-register.md), [discovery](decisions/personal-context-goal.md), [source chronology](reference/source-register.md), [current model task](tasks/2026-11-18-qwen4b-conversation.md).

## 26. Things I have not settled

These are gaps in the available decisions, not questions that must interrupt this document.

- First import source and exact first-version coverage; supported export/audio/document formats; archive size and corrupt/missing-media completion rules.
- Exact identity-matching policy, profile fields/questions, image-generation approach, and final layouts beyond the accepted references.
- Final production model/provider choices and acceptable Arabic/Iraqi/English understanding, retrieval and transcription quality.
- Quantitative supported-device limits for latency, context, memory, storage, battery and sustained heat.
- Permanent deletion, retention, complete backup/restore, custom encryption/key recovery, and future sync conflicts.
- Email/calendar providers, Obsidian access/two-way editing, supported ChatGPT authentication, and future external-request permissions.
- Additional languages, Android scope, exact markets, business location, pricing, business model, and release date.
- Which remaining historical ideas should become current requirements.

Some old open-question lists predate later decisions. The dated discovery answers and current task records take precedence, including the settled temporary-session lifecycle and bounded recurring-reminder approval.

## Sources, coverage, and limits

This compilation covers the distinct ideas in R01–R32, the supporting P01–P25, historical H01–H40, discovery Q1–Q23, the source chronology, and the later linked chat/voice/personal-memory/recall/understanding requests. It groups repetition rather than treating repeated summaries as new approvals. Technical evidence stays in its canonical tasks.

The [source register](reference/source-register.md) records provenance and original hashes. The [feature register](feature-register.md), [decision register](decisions/decision-register.md), and [personal-context decisions](decisions/personal-context-goal.md) remain the authority for scope and decisions. The [implementation checklist](plans/implementation-checklist.md) retains the development order and qualification work.

This document preserves the recorded vision, including rejected and future ideas. It cannot certify that every thought from every past chat is available. It contains no raw personal conversation archive. See the [compilation record](tasks/2026-11-19-owner-vision.md) for document checks and memory-delivery status.
