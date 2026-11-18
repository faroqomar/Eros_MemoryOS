# MemoryOS UI inspiration review

Research date: 2026-11-18. Status: inspiration and proposed adaptations only.
This note grants no design approval, implementation stage, provider choice, import, or service connection.

## Project grounding and method

Read `AGENTS.md`, `README.md`, the product overview, decision register, feature register, and relevant source-register entries. Current [D24/D25 and product boundaries](../decisions/decision-register.md) retain the Capture composition, hidden sidebar, dark appearance, iPhone-first operation, and explicit external-data permissions.
Completed focused `project-memoryos` recall; current repository records govern over historical memory.
Selected `/Users/eros/.codex/skills/mattpocock-research/SKILL.md` for primary-source research and one cited note; `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md` for project-scoped recall; `/Users/eros/.t3/harness/instructions.md` for task boundaries. The research sub-agent did the work without further delegation.
Reviewed public page text and selected first-party SecondBrain images. No account login, purchase, kit download, app execution, or private-data upload occurred.

## Observed sources

All URLs below were accessed on 2026-11-18. Product descriptions remain publisher claims unless a visual observation is stated.

### 1. Editable memory controls

[VP0: AI Memory Management Settings UI in iOS](https://vp0.com/blogs/ai-memory-management-settings-ui-ios), Lawrence Arya; published May 31, updated June 18, 2026.
The author describes a readable memory list, per-item editing/deletion, an on/off switch, confirmed bulk deletion, and an explanation of storage and use. This is design guidance, not evidence of a working memory manager or MemoryOS privacy compliance.
Access: article text available. No specific settings-screen interaction was tested.

### 2. Voice capture and rediscovery

[Anna/asol_design: AI Voice Notes concept](https://dribbble.com/shots/27676321-Mobile-App-Design-AI-Voice-Notes-App-Smart-Notes-AI-App).
The designer describes quick recording, transcription, clear recording states, recurring themes, contextual resurfacing, and post-capture actions. She describes a dark recording state with lighter archive screens.
Access: creator's description available; the main artwork was not inspected at usable resolution in this subtask. The creator calls it a concept and labels numerical outcomes as future targets. They are not measured results. Continuous long-session behavior is unverified.

### 3. Personal relationship context

[SaaSUI: Clay collection](https://www.saasui.design/application/clay).
The gallery lists 23 screens and describes dark onboarding cards, separate email/calendar permission choices, a command menu, profiles, search, and settings. These are curator descriptions; a profile-image request failed in this review.
[Clay's official URL](https://clay.earth/) redirects to [Mesh](https://me.sh/). Both the web reader and direct HTTP retrieval confirmed this redirect. The destination advertises relationship search, contact organization, reconnect prompts, reminders, and life updates. Treat SaaSUI's Clay captures and the current destination as different dated evidence; this review does not establish the product's rebranding history.
Access: public official landing text available; no signed-in profile flow or integration was tested. SaaSUI alone does not substantiate product capabilities.

### 4. People, objects, and contextual links

[Capacities: Second Brain](https://capacities.io/second-brain).
The publisher illustrates a daily capture inbox, typed person/project/book objects, properties, and backlinks that bring related notes onto a person page. It offers search, tags, queries, and a graph as alternative routes to the same information.
The same page describes Capacities as a cloud app with offline access and export, with server encryption rather than end-to-end encryption. Its hosting and AI connections do not establish a suitable MemoryOS data flow.
Access: public text and inline examples available; no running graph, mobile accessibility, or offline behavior was tested.

### 5. Capture home and graph

[SecondBrain](https://secondbrainmemory.com/) presents voice capture, automatic organization, a connected-note graph, and exports. Its brain-dump example states a two-minute limit; this does not demonstrate uninterrupted long-form thinking aloud.
Visual inspection of its [first-party record image](https://secondbrainmemory.com/assets/shot-record-720.webp) shows a large central recording control, spare space, keyboard/attachment controls, and a visible bottom tab bar. The [first-party graph image](https://secondbrainmemory.com/assets/shot-brain-720.webp) shows many nodes and faint connections, with few readable labels in that static capture.
Provenance: the parent reviewer reports a visual match between the supplied home attachment and that first-party record image. This sub-agent inspected the official image but did not independently compare the supplied attachment. Do not extend that attribution to the supplied person or relationship-graph images.
Access: page text and these two public images inspected. Initial image retrieval returned HTTP 403; a request with browser headers succeeded. No live recording, graph interaction, local-only processing, or model accuracy was verified.

### 6. Chronological memory browsing

[Digcy: AI Memory Timeline App UI on UI8](https://ui8.net/digcy/products/ai-memory-timeline-app-ui).
Listing-derived: the indexed primary UI8 listing advertises 50 unique screens in light/dark variants, 100 total, with a timeline, photos/voice, memory details, search/filters, calendar, and maps. Counts describe the seller's kit inventory, not inspected files or implemented behavior.
Access: the parent reported HTTP 403. This subtask's direct open returned an unpopulated template; search exposed the listing text. Visuals remain uninspected. No purchase or kit download occurred.

## Proposed MemoryOS fit, subject to owner review

1. **Capture home:** retain the existing composition in dark mode, a dominant microphone, text entry, and hidden sidebar. Borrow the spare hierarchy from SecondBrain; its persistent tabs do not replace MemoryOS navigation.
2. **Thinking aloud:** propose one user-ended session with pause/resume and explicit save/recovery states. Let the owner finish recording before optional organization prompts. Ask a specific question about ambiguous meaning before creating derived memory; preserve unanswered originals without deriving claims from the ambiguous part. Keep a text alternative. Duration, interruptions, battery cost, and Arabic/English transcription need separate requirements and tests; promise no unlimited recording.
3. **Person profiles:** combine relationship context with Capacities-style backlinks. Show relevant discussions and projects beside dated source links. Keep original statements, owner confirmations, tentative claims, and interpretations distinct; ask before uncertain identity merges or relationship assertions.
4. **Contextual graph:** start from a selected person, project, or capture. Label each link, expose its evidence and uncertainty, and offer the same connections as a readable list. Do not infer relationship strength, intent, or psychological certainty from visual proximity.
5. **Memory controls:** propose plain-language entries with sources, correction/history, removal controls, and an explanation of what memory use or retention switches affect. Distinguish stopping new learning, excluding a derived claim, and deleting originals. Keep bulk actions deliberate; exact deletion and backup effects need a separate decision.
6. **Reversible organization:** let the owner inspect proposed links, merge/split errors, and undo changes while preserving original records and provenance. Avoid a mandatory per-message meaning menu. These references provide no evidence that a local model can classify MemoryOS data correctly.
7. **Timeline:** use UI8's chronology as inspiration for a sidebar destination with dated media and person/project filters. Open each item to its original source and correction history. Person/project filters are this proposal, not a verified kit feature. Keep Capture as home; maps, location collection, and automatic calendar actions need separate scope decisions.

## Boundaries and handoff

Preserve Arabic/English, RTL, accessible controls, source ownership, uncertainty, and explicit user confirmation. Keep everyday capture and memory local-first. Neither cloud products nor import controls in a reference authorize uploads, account connections, silent cloud fallback, or new imports.
Preserve existing originals and reference history. External artwork remains attributed inspiration; this note does not select assets for reuse or establish a reuse license.
The parent reviewed source attribution and proposals, linked this note from the source register, and checked relative links and whitespace. No app change, build, runtime test, PR, or development stage forms part of this research. The evidence guard does not count reference notes; its result is a scope check, not content certification.
