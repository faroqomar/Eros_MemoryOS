# Complete feature register

2026-11-26. The native dark workspace connects Record, Brain, Calendar and Notes to the existing local features. Settings offers five persistent in-app Brain marks. Calendar shows app-owned birthdays. See the [native design task](tasks/2026-11-26-native-four-tab-design.md).

2026-11-17 follow-up: the owner reports the phone voice/chat checklist works. Fresh Step 2 review repairs microphone lifecycle, adapter composition, voice metrics and model-recovery copy; 14 selected UI tests and the affected package/native/build checks pass. The owner confirms normal phone header behavior; an intermittent Simulator capture/rendering observation remains unresolved. Accuracy/device qualification remains separate and accessibility is deferred. See the [current voice/chat record](tasks/2026-11-17-voice-chat.md).

2026-11-15, group 6 Step 2: independent review and recovery/RTL repairs are recorded; Step 2 remains blocked. Recording/import, both local adapters, timestamped corrections and association-preserving export remain implemented. Accessibility diagnostics, accuracy failures and physical iPhone checks block qualification. See the [voice task](tasks/2026-11-15-voice-transcription.md).

2026-11-15, C47/C48: group 5 local-chat Step 2 independent review and recovery repairs pass their local checks. C49 generation timing improves, while clean scrolling/frame-budget and unavailable device/OS checks block passage. Extended VoiceOver testing is withdrawn for this task; basic accessibility remains required. Experimental production-model quality remains open. See the [chat task](tasks/2026-11-15-local-ai-chat.md).

Recorded on 2026-11-06. This register covers current requests and assistant proposals. The [historical register](reference/historical-research.md) preserves the older feature groups and technical ideas. Source IDs refer to the [source register](reference/source-register.md).

Updated on 2026-11-07 with C09 owner direction: demo first, then feature-by-feature growth; ChatGPT first; birthdays as the initial action scope. See [demo and feature direction](decisions/demo-and-feature-direction.md).

C10 later selects Swift with SwiftUI. C11 selects a clickable first demo with sample data. These are stack and demo-type decisions, not implemented product features or measured performance.

C12 includes BrainMap in the first demo alongside Capture, People/person details, Projects, and Birthdays. Layouts and interactions remain open.

**Production feature completion remains open.** The native foundation and current sample-data task demonstrate selected interfaces, not real recording, imports, AI, or scheduling. Checklist group 3 adds durable local typed records. Its [Step 2 review](tasks/2026-11-14-local-storage-text-capture.md) closed two correctness defects and passed local functional checks. Physical iPhone/minimum-runtime and unresolved accessibility checks still block passage; broader product completion remains open. See the [complete interface demo task](tasks/2026-11-14-complete-interface-demo.md) for exact implementation/check status. Requested scope does not select a technical solution or delivery date.

## Owner-requested features

| ID | Feature | Intended behavior | Source |
| --- | --- | --- | --- |
| R01 | Voice capture | Open the app and record a thought with one clear button. | C01 |
| R02 | Text and chat capture | Dump thoughts into a text/chat field without organizing them first. | C01 |
| R03 | Idea collection | Save the owner's ideas and categorize them. | C01 |
| R04 | Conversation import | Import exported chats with other people. C09 names Telegram, Instagram, and WhatsApp among requested sources. Preserve discussion content; format support and order remain open. | C01; C09 |
| R05 | Person profiles | Connect imported information to the correct person and maintain a useful profile, including requested images and questions in R30/R31. Exact profile fields remain open. | C01; C09 |
| R06 | Discussion organization | Group what the owner and each person discussed by topic or context. | C01 |
| R07 | Audio transcription | Convert recorded or imported audio into text. The wording of the initial audio/export request needs format clarification. | C01 |
| R08 | Transcript export | Export a transcript and connect it to the relevant person's profile. Export formats remain open. | C01 |
| R09 | Project recognition | Identify which project a capture concerns. | C01 |
| R10 | Project updates | Add new information, plans, ideas, and future possibilities to that project. | C01 |
| R11 | Specific-chat understanding | Explain the context and meaning of a selected conversation. | C01 |
| R12 | Conflict understanding | Help examine disagreements in chats. Avoid treating a possible interpretation as an established fact. Detailed behavior remains open. | C01; supporting proposal C03 |
| R13 | Email reading | Read email from accounts the owner chooses to connect. | C01 |
| R14 | Calendar actions | Add relevant email or captured information to the owner's calendar under selected rules. C09 limits the initial action/reminder scope to birthdays; broader actions are later scope. | C01; C09 |
| R15 | Person-specific reminder choices | Let the owner choose what information about each person deserves a reminder. | C01 |
| R16 | Important dates | Start with birthdays only under C09. Anniversaries and other owner-selected dates remain later goals. Exact reminder behavior remains open. | C01; C09 |
| R17 | User-defined rules | Let the owner define how the app organizes information and acts on it. Rule format remains open. | C01 |
| R18 | Minimal interface | Keep everyday use simple and avoid complex capture flows. | C01; C04 |
| R19 | Hidden sidebar | Show the sidebar only when the owner opens it. | C01 |
| R20 | Tabs | Organize access through tabs or sections. Their initial set remains open. | C01 |
| R21 | Requested custom tabs | Create a tab when the owner asks. The implementation is not selected. | C01 |
| R22 | On-phone AI and memory | Keep everyday storage and processing on the iPhone where feasible. Test difficult work on the phone first. | C01; C02 |
| R23 | Local control and self-hosting | Minimize dependence on external hosting. Keep optional external connections separate from local operation. | C01; C02 |
| R24 | Optional external AI, starting with ChatGPT | C09 selects ChatGPT as the first external provider. Claude remains a later requested option. Supported authentication, model access, and allowed data transfers remain open. | C01; C09 |
| R25 | Obsidian vault connection | Integrate the app with an Obsidian vault. C09 also considers the vault as a storage option or a future app-owned store. No storage authority, access, export, or editing model is selected. | C01; C09 |
| R26 | PDF and Word reading | Import and understand these document types. Scanned PDFs and older Word formats need separate support decisions. | C01 |
| R27 | Multiple languages | Understand Arabic, English, and other selected languages. | C01 |
| R28 | Future device access | Extend useful capabilities to MacBook and possibly Android, alongside iPhone. Identical AI performance is not established. | C01 |
| R29 | Future sync backend | Consider Convex or Supabase for cross-device use. Neither is selected. | C01 |
| R30 | Person images | Support supplied photos, optional generated images, and reuse of an available supplied chat/profile image. Import availability, generation provider/location, and detailed behavior remain open. | C09 |
| R31 | Guided person questions | Ask questions about a person and learn from the owner's answers. Question selection, timing, storage, and how answers affect the profile remain open. | C09 |
| R32 | BrainMap in the first demo | Include a BrainMap screen with fictional sample connections in the clickable demo. Production graph architecture, automatic relationship extraction, and exact interactions remain open. | C12 |

The owner also confirmed the iPhone 15 Pro Max, requested simple conversation with ASD-STE100 as a reference, and authorized project documentation plus a separate Hindsight bank. These are [decisions and workflow instructions](decisions/decision-register.md), not app features.

## Supporting proposals from the conversation

These proposals support the requested product. They remain unapproved choices.

| ID | Proposal | Purpose and boundary | Source |
| --- | --- | --- | --- |
| P01 | Source-backed question answering | Search personal information and answer with the original source. State when evidence is missing. | C03; C05; L01 sections 3 and 8 |
| P02 | Four memory record types | Keep originals, extracted information, owner-confirmed facts, and AI interpretations distinct. | C03 |
| P03 | Traceable evidence | Link claims to message dates, speakers, audio timestamps, or document sections/pages. | C03; L01 sections 3.4 and 5.3 |
| P04 | Corrections and undo | Correct facts, classifications, links, and capture results. Do not silently replace source history. | C03; C05 |
| P05 | Identity matching | Match names, nicknames, Arabic/English spellings, and contact identifiers. Let the owner merge or split mistaken profiles. | C03; L01 section 5.3 |
| P06 | Time-aware history | Keep changed plans and conflicting statements with their dates. Distinguish tentative ideas from agreed commitments. | C03; L01 section 3.2 |
| P07 | Multi-record links | Link one capture to several people, projects, ideas, or dates without copying it. | C03, consolidated interpretation |
| P08 | Clear processing state | Save captures before AI work. Show processing results and allow correction. | C03; C05 |
| P09 | Transcript review | Preserve audio, create timestamped text, and allow edits. Show uncertain recognition where supported. | C03; L01 sections 6 and 8 |
| P10 | Speaker separation | Separate voices in multi-speaker audio. Ask the owner to identify a speaker when identity is uncertain. | C03 |
| P11 | Resumable import jobs | Process large archives in batches. Resume after interruption without duplicate records. | C03; C05 |
| P12 | Custom tabs as saved views | Store filters over existing records when the owner requests a new tab. Do not generate arbitrary executable code. | C03 |
| P13 | Rule enforcement | Convert chosen rules into visible, editable settings. Enforce cloud restrictions and action permissions outside model prompts. | C03 |
| P14 | Calendar preview and trusted automation | Show proposed event details and source first. Let the owner choose narrowly defined automatic cases later. | C03 |
| P15 | Local data protection | Use encryption, protected keys, backup/restore, export, and deletion. Exact designs remain open. | C03; C05; L01 section 7 |
| P16 | Obsidian import/export boundary | Keep structured app records and readable Markdown views. Define what happens when the same note changes in both places. | C03 |
| P17 | Two external-AI routes | Offer manual context handoff or an official API connection. Limit transferred context to owner-selected data. | C03 |
| P18 | Native AI components | Evaluate llama.cpp for text and WhisperKit or whisper.cpp for speech. Evaluate small multilingual models such as Qwen3-1.7B. No selection or benchmark exists. | C03; C05 |
| P19 | Local storage and search | Evaluate SQLite, keyword search, multilingual semantic search, and linked records. A graph server is not assumed. | C03; C05 |
| P20 | Historical app language and framework options | Resolved by D21/C10: Swift with SwiftUI is selected. The earlier Flutter proposal and Swift-versus-Objective-C comparison remain history. This row does not assert an implementation or efficiency result. | C03; C05; C09; C10 |
| P21 | Cross-device record protocol | Plan stable IDs, edit versions, attachment transfer, conflict resolution, and deletion propagation. Encryption and key recovery remain open. | C03 |
| P22 | Language and device evaluation | Test Iraqi Arabic, mixed languages, names, sarcasm, right-to-left text, long imports, heat, battery use, and interruption recovery. | C03; C05 |
| P23 | No silent network fallback | Keep a failed or difficult local task local unless the owner chooses external processing. Imported text must not override rules. | C03 |
| P24 | Capture interface details | Add an attachment button, compact result receipt, undo action, and a small reminder list. Initial sidebar sections were examples only. | C03 |
| P25 | Small offline proof of concept | Record, transcribe, classify, link, retrieve with a source, correct, and export on the actual phone. Test in airplane mode after model downloads. | C03; C05 |

## Older features

The [historical register](reference/historical-research.md) contains H01-H40. It includes timelines, sentiment/topic analytics, relationship graphs, persona style, digital legacy, broader capture tools, privacy controls, professional editions, sharing, and advanced search research.

The old research uses words such as "decision" and "will implement." Those words do not establish owner approval. New owner requests determine current direction. No feature has a committed delivery date.


## Relationship and life-context clarification

The owner requests extensive chat/media imports, source-preserving relationship and person understanding, and organization of ideas, workflows and projects. Fine-tuning and tools are discussion topics, not selected implementations. See the [confirmed goal and proposed approach](decisions/personal-context-goal.md).


## Group 7 implementation, 2026-11-17

The [group 7 task record](tasks/2026-11-17-lasting-personal-memory.md) now owns bounded source-preserving conversation memory, real self/person/project profiles, reversible organization, identity confirmation, image provenance and typed temporary chat. Step 2 independent checks and measured phone latency pass after repairs; locked-device and energy/sustained-thermal qualification block the overall stage. On November 18 the owner withdrew iOS 18 testing from this task's gate; it did not pass. Conservative classification and model quality limits remain explicit. Step 3 is not requested.

### Automatic organization follow-up, 2026-11-18

The owner rejected generic meaning menus and requested authentic automatic memory based on other projects. The [current follow-up](tasks/2026-11-18-automatic-personal-memory.md) adds a semantic extraction port, exact source evidence, temporal revisions, durable clarification question/answer provenance and foreground-priority scheduling. Independent quality testing failed for the tested local model; production composition therefore blocks automatic derived writes. Normal originals, manual information and corrections remain available. The owner selected further local-only evaluation, with physical tests skipped for now. This is not completed automatic-memory adoption.

Follow-up evaluation, November 18: the verified local 4B candidate completed 38 host cases but failed its semantic gate (independent 3/11 complete claims; 1 accepted mismatch). Automatic derived writes remain disabled. A fresh 12-case routing repair trial also failed: 7/8 complete claims, 2 accepted mismatches. The current task/evidence retains both results; no model, cloud or phone adoption follows.

Automatic-memory workflow reset, 2026-11-18: the completed fourth host trial failed10/20 cases and7/13 claims, with0 accepted mistakes; its inputs are now consumed regression data. Main owns bounded code repairs and independent review. Further full qualification requires current green regressions; automatic writes remain disabled. See [the current task](tasks/2026-11-18-automatic-personal-memory.md).

## Local recall integration, 2026-11-18

The owner authorizes Wax and Cactus integration for lookup before ordinary chat replies. The [current task](tasks/2026-11-18-local-recall-integration.md) preserves dated originals, current corrections and private-session nonretention through replaceable local providers. Connected Simulator verification passes, including recall, corrections and private-chat nonretention. Arabic retrieval and automatic extraction quality remain unqualified. This narrow integration does not complete relationship understanding or the rest of group8.

Owner-selected conversation model, November 18: the main app now uses the existing pinned Qwen3 4B for replies and relevance, with one bundled weight file and no smaller-model fallback. Follow-up context retains current cited answers; stale evidence remains withheld. Automatic extraction remains disabled. See the [conversation task](tasks/2026-11-18-qwen4b-conversation.md) for current quality checks and limits.

## Groups 8–9 implementation, 2026-11-18

The [current Step 2 task](tasks/2026-11-18-understanding-organization.md) owns current-source retrieval, bounded relationship analysis and layered reports, real BrainMap navigation, birthdays with exact annual approval, reversible category rules and saved custom views. It preserves original text, owner accounts and distinct AI hypotheses. Existing local models remain experimental; exact citations alone do not prove interpretation accuracy. Anniversaries and broader actions remain later scope. Builder evidence, independent qualification, owner acceptance and delivery are separate.

November 24 Step 2 repair: default search passes the six original cases, three named probes and three generic probes; the original profile-linked group answer now preserves both people and their restrictions without unsupported qualifications. Protected vector checkpoints retain completed work after cancellation. Final build/analysis and 196 native controls pass. All five consumed relationship cases still fail semantic acceptance; failed audit experiments were removed. Fresh paired diagnostics give default 1/12 and candidate 0/12 full passes and the full-history benchmark replay times out without a scoreable answer. These remain separate from earlier runs in the linked task. No semantic qualification, candidate adoption or automatic derived writes follows. Physical checks remain owner-skipped.
