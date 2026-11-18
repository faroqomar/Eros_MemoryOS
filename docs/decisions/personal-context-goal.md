# Personal context and relationship memory goal

Owner clarification C50, 2026-11-15. This records product intent, not implementation authorization or verified capability.

## Confirmed goal

MemoryOS should provide personalized understanding of the user's life, people, relationships, ideas, workflows and projects. The owner is not seeking a general ChatGPT replacement.

Users should be able to import extensive conversation histories, including available photos and voice messages, from WhatsApp, Instagram, Facebook, Snapchat and previously requested sources. The goal includes romantic relationships from either participant's perspective and other personal relationships. Actual export availability, formats, size limits and completeness need verification; unlimited ingestion and complete understanding are not promised.

Preserve original communications and attachments unchanged. Build separate, source-linked summaries, timelines, person profiles and interpretations. Help users examine arguments, possible emotions, communication patterns and changes over time. Answer later questions using relevant original evidence and surrounding context. Treat psychological interpretations as revisable hypotheses, not diagnoses or proven motives. Allow corrections and distinguish reported facts from independently established facts. Missing/deleted messages and one-sided histories limit conclusions.

Support low-friction capture of ideas, workflow changes, project updates and everyday thoughts for later organization and retrieval. This is a product requirement, not a medical claim about the owner.

## Proposed technical direction

Use staged, resumable imports, attachment transcription/OCR/vision, source-linked extraction, topic/time summaries and retrieval of original passages. Keep processing coverage visible. Preserve app-owned originals; summaries and indexes remain rebuildable. Respect iOS background scheduling and device storage limits.

Start behavior customization with instructions and examples. Consider LoRA fine-tuning only against measured failures, using consented or synthetic reviewed examples and held-out Arabic/Iraqi/English tests. Keep private user archives in retrieval storage rather than training shared weights. Fine-tuning does not guarantee faster inference, factuality or psychological expertise.

Candidate tools include local memory search, source inspection, transcription, OCR, timeline comparison, project linking, optional web search and optional image generation. These remain proposals. External transfers require explicit permission and bounded payloads. Imported messages and web pages are data, never tool instructions. Writing, sharing, reminders and deletion remain controlled actions under existing scope.

No training, provider connection, import implementation or new app stage starts from this discussion.

## Recording

Selected guidance: /Users/eros/.codex/skills/t3-hindsight-required/SKILL.md for project-isolated recall and Markdown delivery; /Users/eros/.agents/skills/stop-slop/SKILL.md for concise documentation. Current source confirms experimental Qwen3-0.6B GGUF in native/MemoryOS/Composition/ChatComposition.swift. Existing group 4 records also compare Qwen3-1.7B; production adoption remains open.


## Discovery interview: confirmed round 1, 2026-11-15

The owner requested mattpocock-grill-me, mattpocock-grilling and mattpocock-grill-with-docs; their domain-modeling dependency also applies. Use multiple-choice question tools with free-text answers. Pause further feature work until the owner confirms shared understanding at the end of discovery. Groups 1–5 stay closed under C52.

- Q1: The first audience is people like the owner managing thoughts, projects and relationships.
- Q2: All three promises matter: capture/import then recall/connect/understand; relationship and communication understanding; life organization and help deciding next actions. No priority between them was selected.
- Q3: Support the user emotionally while challenging interpretations with evidence and alternatives.
- Q4: Proactively organize and suggest insights by default; ask before external actions. Exact allowed internal changes, notification behavior and external-action permission granularity remain open.
- Q5: The first complete product must demonstrate both relationship understanding and everyday thought/project memory.

Decision tree: audience/purpose → capture and conversation memory → organization/corrections → profiles/relationship reasoning → useful answers and advice; initiative → internal changes/insight delivery/external permissions; success → concrete scenarios/quality thresholds. Local/cloud tradeoffs, import priorities/limits, retention/deletion, models/tools, supported devices and commercial boundaries require later rounds where not already settled. Recommendations in unanswered questions are not decisions. No final product specification or implementation approval follows from round 1.

Skill paths: /Users/eros/.t3/harness/skills/mattpocock-grill-me/SKILL.md, /Users/eros/.t3/harness/skills/mattpocock-grilling/SKILL.md, /Users/eros/.t3/harness/skills/mattpocock-grill-with-docs/SKILL.md and /Users/eros/.t3/harness/skills/mattpocock-domain-modeling/SKILL.md. These guide the interview and durable terminology; current project rules govern recording.


## Discovery interview: round 2, 2026-11-15

- Q6 confirmed: Automatically organize all normal chats into lasting memory; provide a temporary/private mode. Exact temporary-mode retention and access to existing memory remain unresolved.
- Q7 confirmed: Create reversible categories, links and summaries without asking. Ask before merging people or changing confirmed facts. Preserve originals.
- Q8 confirmed: Show proactive insights inside the app when relevant. Notifications require user-enabled topics and timing.
- Q9 unresolved: The owner answered all options, which included both self-profiling and no self-profile. Do not infer approval or rejection of inferred self-profiling; clarify in round 3.
- Q10 confirmed: Recommend a next step, explain evidence and tradeoffs, and leave the decision to the user.
- Q11 confirmed: Ask before each external action; no standing permissions. The boundary for recurring reminders, web search and multi-call cloud requests needs clarification rather than an inferred exception.

Next frontier: resolve Q9; define temporary-mode behavior, treatment of venting/hypotheticals in automatic memory, what counts as one approved external action, and how user-confirmed information interacts with conflicting source evidence. Feature implementation remains paused pending final shared-understanding confirmation.


## Discovery interview: round 3, 2026-11-15

- Q12 resolves Q9: Include stated preferences/goals and clearly labeled, correctable interpretations in the user's self-profile.
- Q13: Temporary/private chat can use existing memory for personalization but saves nothing new. The question's no-lasting-conversation/session-end removal boundary is selected; exact end-of-session and failure/relaunch behavior remains open.
- Q14: Ask what ambiguous venting means before creating derived memory. Normal chat preservation remains selected; clarification timing and unanswered-item handling remain open.
- Q15: One approval creates an exact recurring reminder schedule; each scheduled delivery needs no new approval. This defines one bounded approved action, not general standing permissions.
- Q16: Preserve conflicting original messages and the user's confirmed interpretation, prioritizing the interpretation in future answers. Reconcile this with Q3 evidence-based challenge before specifying answer behavior; do not infer permission to suppress contrary evidence or state false source claims.
- Q17: Disable cloud AI and web search for the first useful version. These remain future options, not rejected permanently. Future external-request approval granularity remains unresolved and deferred until that scope.

Next frontier: concrete conflict-answer behavior; clarification workflow; temporary-session end; initial import priority; long-import experience; scope of relationship advice. Keep recommendations distinct from owner decisions.


## Discovery interview: round 4 and owner stop, 2026-11-15

- Q18: Ask the user to clarify their meaning before answering a conflict between a confirmed interpretation and original evidence. This resolves the immediate response choice left open by Q16; preserve both records and do not silently treat either as a replacement for the other.
- Q19: Ask immediately in chat when venting or an uncertain plan needs clarification. Preserve the original even if the user does not answer; create no derived memory from the unresolved ambiguous part under Q14.
- Q20: End temporary/private chat on explicit user end or process termination. Brief backgrounding keeps it available. It may read existing memory but creates no lasting history or derived memory. This is intended behavior, not verified implementation.
- Q21: The owner answered all of them to the WhatsApp/Instagram/Telegram first-source question. Retain all three in the requested import scope; no single-source priority was chosen. Previously requested Facebook and Snapchat remain goals. Exact first-version source coverage/order is unresolved.
- Q22: Complete processing of an entire archive before enabling AI answers about that archive. Do not infer that unrelated app workflows must block. Missing/corrupt media and completion criteria remain unresolved.
- Q23: Explain relationship patterns, recommend next steps and draft respectful replies or conversation plans when asked; never send automatically.
- The owner ended the interview with “thats it”. Stop further questions now. Record the settled answers without interpreting the stop as approval to implement or proof that every design branch is resolved.

## Current synthesis and remaining limits

The intended first useful version combines everyday thought/project memory and relationship understanding. Normal chats automatically enter lasting memory; ambiguous venting requires immediate clarification before derivation. Users can inspect and correct self/person interpretations. The app proactively organizes reversibly and suggests relevant insights in-app. Ask before identity merges, confirmed-fact changes and external actions. An exact approved recurring reminder schedule can execute without approval for each occurrence. Cloud AI and web search stay disabled for the first useful version; earlier ChatGPT-first direction now applies only to a later external-AI stage.

Open choices include exact first-version import coverage, failed-media completion rules, deletion/retention and backup/key recovery, identity matching, quantitative quality/device targets, detailed reminder timing, and commercial scope. No further interview or implementation begins without a new owner request. These decisions refine future groups; groups 1–5 remain closed.
