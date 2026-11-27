# SwiftUI implementation checklist

C52, 2026-11-15: groups 1–5 are closed as completed implementation milestones. Continue forward; do not reopen them. Outstanding verification, quality, device and delivery work moves to groups 15–18 with its original evidence and dependencies. Closing these milestones does not turn unavailable or failed checks into passes or waive merge/release gates. Groups 6–14 keep their numbers. Group numbers are stable identifiers, not permission to delay a prerequisite until after dependent work.

The [historical inventory](implementation-inventory-history.md) preserves original S/T/R/P/H IDs and dated status. The [personal-context goal](../decisions/personal-context-goal.md) defines the product direction.

## 1. Prepare the design and project — complete

- [x] Retain design references and prototype provenance.
- [x] Create the SwiftUI project, navigation, typography, shared controls and dark appearance.
- [x] Check available devices and document physical iPhone setup requirements.

Physical installation and owner acceptance now belong to groups 15 and 18.

## 2. Build the complete interface demo — complete

- [x] Implement fictional Capture, hidden sidebar, People/details, Projects, Birthdays and BrainMap.
- [x] Implement Arabic/English layouts and mixed-language content.
- [x] Run the recorded simulator interface and functional checks.

Evidence: [demo task](../tasks/2026-11-14-complete-interface-demo.md). Remaining accessibility, device and owner acceptance now belong to groups 15 and 18.

## 3. Add local storage and text capture — complete

- [x] Implement app-owned SQLite records and durable typed captures.
- [x] Store stable identities/links and preserve original records with correction history.
- [x] Implement the current Trash, export and restore behavior.
- [x] Verify the recorded local functional and recovery cases.

Evidence: [storage task](../tasks/2026-11-14-local-storage-text-capture.md). Remaining device, accessibility, production protection and delivery work now belongs to groups 15 and 18.

## 4. Evaluate local AI components — complete

- [x] Complete the recorded Wax/Cactus, text-runtime and model experiments.
- [x] Evaluate Qwen3 0.6B/1.7B and Arabic/Iraqi/English source quality.
- [x] Record simulator costs and explicit unsupported-platform outcomes.
- [x] Establish experimental baselines while preserving app-owned originals.

Evidence: [evaluation task](../tasks/2026-11-14-local-ai-phone-evaluation.md). The experiment completed even where quality failed. Physical benchmarks and production selection now belong to groups 15 and 17.

## 5. Connect local AI to chat — complete

- [x] Implement real local replies, streaming, durable chats/drafts and context-limit handling.
- [x] Implement stop, partial retention, retry/regenerate, formatting and copy.
- [x] Retrieve current app-owned sources and respect corrections/deletions.
- [x] Implement and exercise Arabic/English, basic accessibility and Reduce Motion.
- [x] Complete the recorded independent review, repairs and local checks.

Evidence: [chat task](../tasks/2026-11-15-local-ai-chat.md). Remaining performance, OS/offline recovery, owner acceptance and delivery now belong to groups 15, 16 and 18. This milestone closure does not claim the earlier full Step 2 acceptance passed.

## Discovery decisions governing future work

The [recorded discovery rounds](../decisions/personal-context-goal.md#discovery-interview-confirmed-round-1-2026-11-15) govern future groups. Normal chats enter memory automatically, with clarification before deriving from ambiguous venting. Temporary chat uses existing memory but saves nothing and ends explicitly or on process termination. Proactive reversible organization and in-app insights are selected; external actions need approval, with one approval covering an exact recurring schedule. Disable cloud AI/web search for the first useful version. Require complete archive processing before AI answers about that archive. Ask before answering source/interpretation conflicts; relationship reply drafting is allowed on request, never automatic sending. All named import sources remain requested, with no single first source selected. The owner ended discovery; unresolved decisions remain open and implementation is not authorized by the interview.

## 6. Add real voice recording and transcription

Step 2 remains blocked after independent review and repairs: [implementation and verification evidence](../tasks/2026-11-15-voice-transcription.md). Owner update, November 17: leave accessibility work aside for now; retain failed diagnostics as deferred, not passed. The owner reports the later phone checklist works; the [November 17 voice/chat rerun](../tasks/2026-11-17-voice-chat.md) records functional acceptance and fresh review. Iraqi/mixed quality misses the measured target, and numerical phone cost, OS recovery and supported-runtime qualification remain open. The phone is currently disconnected. Checkboxes retain qualification status.

- [ ] Evaluate AVAudioRecorder; record, pause, resume and save with microphone permissions and visible recording state.
- [ ] Import supported audio formats; report unsupported, corrupt or missing files.
- [ ] Compare WhisperKit and whisper.cpp on the same Arabic, Iraqi Arabic, English and mixed recordings; measure transcription accuracy and physical-device cost.
- [ ] Review and correct transcripts with timestamps and links to unchanged original audio; preserve versions and uncertain words/speakers.
- [ ] Export transcripts with person, recording and source links.
- [ ] Recover from calls, interruptions, backgrounding, low storage and termination without losing saved material.

## 7. Build lasting personal memory, profiles, and project organization

The [group 7 task](../tasks/2026-11-17-lasting-personal-memory.md) records implemented behavior, passing independent tests and phone latency repairs. Step 2 remains blocked on locked-device access and energy/sustained-thermal qualification. The owner withdrew iOS 18 testing from this task's gate on November 18; it is not a pass or a deployment-target change. Later stages remain separate.

- [ ] **Remember normal chats:** Automatically preserve and organize ordinary conversations into lasting memory.
- [ ] **Clarify ambiguity:** Ask immediately when a statement could be venting, role-play, a tentative idea, or a real decision.
- [ ] **Preserve unanswered captures:** Keep the original without creating derived memories from unresolved ambiguous parts.
- [ ] **Organize reversibly:** Create categories, links, and summaries with visible corrections and undo.
- [ ] **Recognize people:** Suggest identities across names, nicknames, and imported sources.
- [ ] **Confirm sensitive changes:** Ask before merging people or changing confirmed facts.
- [ ] **Build your self-profile:** Include stated preferences and goals alongside clearly labeled, correctable interpretations.
- [ ] **Build person profiles:** Connect source-backed information, discussions, dates, and communication patterns.
- [ ] **Organize projects:** Separate current plans, workflow updates, facts, tentative ideas, and commitments.
- [ ] **Add person images:** Support supplied and imported photos; keep generated images distinct.
- [ ] **Ask optional profile questions:** Improve understanding without requiring lengthy forms.
- [ ] **Add temporary/private chat:** Use existing memory for personalization but save no new lasting conversation or derived memory.
- [ ] **End temporary sessions:** Discard them on explicit end or process termination; preserve them during brief app switching.

## 8. Add memory search and relationship understanding

[Groups 8–9 Step 2](../tasks/2026-11-18-understanding-organization.md) remains blocked on November 24. All six original search cases, three named probes, three generic probes and the original full group answer pass. Final build/analysis, 196 native controls and vector-checkpoint recovery pass. Relationship meaning still fails all five consumed cases; fresh paired diagnostics give default 1/12 and candidate 0/12 full passes. The permitted full-history replay times out without an answer score. Preserve separate denominators and rights/data-flow holds. Physical checks remain owner-skipped, not passed; no Step 3 or model adoption follows.

- [ ] Compare keyword, semantic and linked-record retrieval using known-answer examples; select only measured improvements.
- [ ] Answer with inspectable original passages, timestamps and surrounding context; abstain when evidence is insufficient.
- [ ] Preserve distinct originals, extracted statements, user-confirmed information and AI interpretations; retain corrections without rewriting originals.
- [ ] Explain selected conversations and arguments, agreements, repair attempts and changes over time.
- [ ] Present possible emotions, motives and communication/personality patterns as revisable interpretations; include alternative explanations and counterevidence, not diagnoses or certainty about inner states.
- [ ] Account for one-sided histories, sarcasm, missing messages, cultural context and conflicting statements; distinguish changed plans from contradictions.
- [ ] Maintain source-linked summaries at conversation, topic and time-period levels; retrieve originals rather than relying only on summaries.
- [ ] Propagate corrections and deletions through retrieval, summaries, profiles and indexes; show stale or incomplete processing.
- [ ] Connect BrainMap to real saved records and useful source navigation.
- [ ] Verify the connected workflow offline; keep indexes rebuildable from app-owned originals.

## 9. Add birthdays, rules and custom tabs

The same [Step 2 record](../tasks/2026-11-18-understanding-organization.md) owns approved annual birthday schedules, supported organization rules and named views.

- [ ] Save birthdays, partial dates and corrections; choose reminders per person.
- [ ] Select notifications versus calendar events; verify timing, timezone, recurrence, permission denial and duplicate prevention.
- [ ] Let users inspect, edit, disable and test organization/action rules; provide undo where applicable.
- [ ] Create named custom views over selected information.
- [ ] Expand to anniversaries and broader actions only after birthdays work and the later scope starts.

## 10. Add imports one source at a time

Source order remains open. Support depends on actual export formats and available content; no unlimited-size or complete-history promise.

- [ ] Telegram: select and verify an export format with available media.
- [ ] Instagram: verify conversation exports, identity and attachment availability.
- [ ] WhatsApp: verify text, timestamps, participants and available photos/voice messages.
- [ ] Facebook: verify supported message exports and available media.
- [ ] Snapchat: verify what an export contains and clearly report unavailable or expired content.
- [ ] PDF and Word: define supported formats, scanned documents, tables and source locations.
- [ ] Obsidian: select import/export versus vault access and define ownership.
- [ ] Preserve original export bytes, stable source IDs, participant attribution, timestamps/timezones, ordering, reply links and attachments when available.
- [ ] Process large archives in resumable batches with progress, coverage, cancellation, deduplication, retry and storage-budget checks.
- [ ] Transcribe audio and evaluate OCR/image understanding through replaceable adapters; link derived text to original media and mark uncertainty.
- [ ] Validate archive paths and file types; treat imported instructions as content, not executable actions.
- [ ] Define retention, export and deletion controls for third-party communications; review permission and market obligations before affected release.

## 11. Add optional connections and tools

Candidate tools remain proposals until their individual scope, provider and data flows are selected.

- [ ] ChatGPT first: choose a supported connection, authentication and per-request data-sharing controls.
- [ ] Claude later: add after the first external connection works.
- [ ] Email: authorize selected accounts and bounded retrieval.
- [ ] Broader calendar actions: apply selected rules and confirmation requirements.
- [ ] Local tools: bounded memory search, original-source inspection, timeline comparison, transcription, OCR and project/person linking.
- [ ] Optional web search: show external citations and separate public research from private relationship evidence; minimize outgoing queries.
- [ ] Optional image generation: define its project/person-image use, local versus cloud execution, cost, labeling and explicit data permission.
- [ ] Use typed tool schemas, argument validation, permission checks, timeouts, cancellation and bounded execution; handle unsupported tool calls safely.
- [ ] Resist instructions embedded in chats, attachments and web results; prevent unapproved sending, sharing, deletion or external transfers.
- [ ] Inspect, pause and disconnect services; revoke credentials and show what information leaves the phone. Preserve offline use and no silent cloud fallback.

## 12. Add other devices and synchronization

- [ ] Define record/media versions, edits, conflict handling, duplicates and deletion propagation.
- [ ] Compare Supabase and Convex only after sync requirements are clear; neither is selected.
- [ ] Design end-to-end encryption and key recovery separately from optional cloud AI.
- [ ] Add MacBook access; evaluate Android scope separately.
- [ ] Test offline changes, reconnection, backup/restore, account isolation, migrations and provider switching without data loss.

## 13. Customize behavior and background processing

- [ ] Define desired persona, response style, evidence handling and Arabic/Iraqi/English examples; let user preferences remain editable.
- [ ] Establish held-out tests for factual support, retrieval, relationship interpretations, tool choice, privacy and refusal when evidence is missing.
- [ ] Compare instructions/examples and retrieval improvements before choosing fine-tuning.
- [ ] If justified, select a licensed compatible base model and LoRA/QLoRA workflow; use reviewed synthetic or explicitly authorized examples and keep train/test people and conversations separate.
- [ ] Keep private user histories in source-backed memory; do not train shared weights on them by default.
- [ ] Compare tuned and original models on unseen cases, including regressions and unsupported psychological claims; document provenance, versions and rollback.
- [ ] Validate adapter/export/quantization compatibility and deployment on the actual iPhone; measure quality, latency, memory, battery and heat. Fine-tuning alone does not establish a speed gain.
- [ ] Implement resumable queues for import, transcription, extraction, summarization and indexing under iOS scheduling limits; expose progress and incomplete coverage.
- [ ] Define charging/battery/storage policies, cancellation, retries and recovery; do not imply continuous background execution.

## 14. Verify completed workflows and release readiness

Checks occur within every stage and again across connected workflows. Existing three-step authorization and independent verification gates remain applicable.

- [ ] Capture to recall: save, find, inspect source, correct and retrieve again.
- [ ] Audio to memory: record/import, transcribe, review, link and search.
- [ ] Import to profile: use a fictional multimodal relationship archive; verify identities, chronology, evidence, missing content and alternative interpretations.
- [ ] Life/project workflow: capture unstructured thoughts, update plans, distinguish tentative ideas and retrieve later without manual filing.
- [ ] Large archives: verify bounded storage, restart/resume, deduplication, processing coverage and retrieval of older evidence.
- [ ] Tools: verify permissions, hostile imported instructions, invalid calls, failures, offline paths and no unintended actions/transfers.
- [ ] Birthday reminder: verify actual alert/calendar behavior on a physical phone.
- [ ] Backup/restore and migrations: verify original bytes, links, corrections, attachments and derived-store rebuilding; test deletion propagation.
- [ ] Final physical iPhone review: dark UI, Arabic/English/RTL, accessibility, minimum supported OS, responsiveness, memory pressure, battery and heat.
- [ ] Complete required MVVM/domain/adapter checks, compilation/concurrency/static checks, relevant tests and dependency/license review.
- [ ] Review applicable commercial/privacy/recording/accessibility obligations and security baseline against current sources; complete required privacy and data-safety evidence before release.
- [ ] Record owner product/design acceptance and remaining limitations separately from implementation, tests, merge and release authorization.


## 15. Physical-device, supported-OS and accessibility qualification

Transferred from groups 1–5; these are forward tasks, not reopened milestones.

- [ ] **15.1 · Device setup (from 1–2):** Connect/sign/install/launch on the physical iPhone 15 Pro Max and verify actual workflows.
- [ ] **15.2 · Supported OS (from 2, 3, 5):** Run required flows on minimum supported iOS 18 and resolve compatibility findings.
- [ ] **15.3 · Accessibility (from 2–3):** Resolve retained native diagnostic failures, including labels, toolbar controls, contrast, Dynamic Type and clipped link controls; verify affected navigation/focus. C49's extended VoiceOver withdrawal applies only to chat and remains withdrawn, not passed.
- [ ] **15.4 · Physical cost (from 3–5):** Measure launch/reopen/generation latency, sustained memory, storage, battery and heat against defined targets.
- [ ] **15.5 · Data protection (from 3, 5):** Verify lock/protected-file behavior, interruption and hardware recovery; preserve originals and links.

## 16. Chat performance, OS recovery and disconnected operation

Transferred from group 5; reuse valid unchanged-source evidence and rerun affected checks after repairs.

- [ ] **16.1:** Establish clean scrolling latency and actual frame-budget evidence during generation; repair failures and recheck independently.
- [ ] **16.2:** Exercise actual OS memory pressure and remaining interruption/background/relaunch recovery cases.
- [ ] **16.3:** Verify full-app disconnected execution after model preparation, including source retrieval and failure recovery; host network-denial results alone do not close this item.

## 17. Model quality and production component selection

Transferred from group 4; coordinate with group 13 customization rather than duplicate its experiments.

- [ ] **17.1:** Resolve recorded Arabic/Iraqi language, citation and irrelevant-source retrieval failures against held-out acceptance cases.
- [ ] **17.2:** Select production models/runtime/retrieval components from quality and physical-device evidence; experimental baselines remain experimental until then.
- [ ] **17.3:** Verify provider replacement, app-owned data preservation, rollback, pinned versions and relevant licenses before adoption.

## 18. Product acceptance, data policy and delivery closure

Transferred from groups 1–5; coordinate with group 14 final workflow checks. Preserve existing stage authorization and required gates.

- [ ] **18.1:** Complete owner dark-mode design/product review and final simulator/physical interaction testing for implemented screens.
- [ ] **18.2:** Resolve permanent deletion, encryption/key recovery and production backup policy with affected recovery checks before release.
- [ ] **18.3:** Close outstanding required independent verification using groups 15–17 evidence; do not relabel historical blocked verdicts as passed.
- [ ] **18.4:** Reconcile outstanding storage/chat delivery and PR status from current repository evidence; complete authorized delivery only after required checks/reviews pass. This numbering change alone does not start chat Step 3 or authorize release.
