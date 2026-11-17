# Voice messages and Liquid Glass chat

Status: Step 2 rerun finished. Independent source review, repaired functional checks, builds and cleanup pass. Full qualification remains BLOCKED by measured language/device/rendering limits below. The owner confirms the phone checklist and header visibility after sidebar/keyboard actions. Exact installed build identity and numerical phone measurements were not independently captured. Step 3 [draft PR #6](https://github.com/faroqomar/Eros_MemoryOS/pull/6) is open; unresolved required checks still block merge.
Checklist scope: groups 5 (chat) and 6 (voice); preserve their existing quality/performance limitations.

## Outcome and acceptance

- Remove the marked composer footer, including the warning and Done row. Preserve keyboard dismissal through native interaction.
- Apply native Liquid Glass to navigation/composer/record controls on supported iOS; retain a material fallback on iOS 18. Keep dark mode and Arabic/English RTL.
- Finishing a Home recording creates one new conversation. Show the original audio as the user's message, with playback, duration and a chevron to reveal the transcript.
- Save audio before processing. Show transcription state, then generate the local AI reply from the transcript. Typed follow-ups stay in that conversation.
- Keep pending/error voice work durable and retryable without duplicate conversations/messages. Never fabricate a transcript or send placeholder text to AI.
- Keep original audio, recording/transcript/source IDs, corrections and existing chats. Silence, permission denial, unavailable models, cancellation, termination and save failures need visible recovery.
- Add an obvious Recordings navigation entry for existing audio and transcripts. This is optional management, not a detour in the main recording-to-chat flow.
- No cloud fallback, private conversation retention in project evidence, or phone-data deletion.

## Architecture and responsibilities

Views render state and forward actions. ChatCore owns serializable voice references/pending states and idempotent chat transitions; ChatPresentation owns chat feature state and injected use cases. AudioWorkflow owns recording/transcription through existing AudioCore interfaces. App composition connects a thin audio-to-chat adapter. SDKs and filesystem access stay in adapters. Original audio remains in AudioLibrary; chat stores stable references and the transcript used for its reply.

Existing Whisper providers/models remain reviewed candidates, not newly qualified engines. Inspect installed/bundled speech-asset availability and provide a concrete setup path; do not confuse the Qwen text model with the speech model. Prefer reuse of the already reviewed local asset when packaging is appropriate; no silent download.

## Agent tracker and dependency order

| Agent | Responsibility | State |
| --- | --- | --- |
| voice_plan_review | Challenge lifecycle, recovery, storage boundaries and acceptance before edits | Complete: contracts below |
| voice_chat_core | Voice lifecycle and package tests; then controlled speech candidate comparison | Complete: 30 offline comparison operations and cancellation check |
| voice_audio_bridge | Save/transcribe handoff and adapter tests; then capture/PCM diagnosis | Complete: PCM diagnosis and permanent mono/stereo regressions |
| voice_glass_ui | Footer removal, glass controls, voice card/disclosure and recording navigation | Complete; final dark Simulator captures reviewed |
| Main agent | Integration, model packaging, native checks and evidence | Rerun complete; signed update built; not installed during this rerun |
| voice_final_review | Independent architecture/behavior review, coordinator tests and revised quality plan | Complete: workflow and final model wiring reviewed |

## Verification plan

Meaningful tests: backward archive decoding; voice linkage persistence; transcription success/silence/failure; retry without duplicates; text follow-ups; reopening and termination recovery; no generation before usable transcript; original audio unchanged. Run LocalChat/LocalAudio tests, affected app workflow tests, real-provider smoke with fictional audio, and native UI checks. Capture dark voice pending/ready/disclosed states with fictional data outside the repository. Record simulator/device and source identity.

Build simulator and signed phone Release; verify inference linkage and signature. Preserve installed phone data. T3 previously cannot control the physical phone, so owner verification stays distinct from simulator proof. Target UI state visibility within one second after finish (excluding permission/system UI), no main-thread inference, and measurable end-to-end timing on a short known fixture. Physical latency/accuracy qualification remains open until measured.

Skills: project `.agents/skills/{swiftui-expert-skill,swift-concurrency,swift-testing-expert,ux-error-recovery}/SKILL.md`; SwiftUI `references/liquid-glass.md`. These cover native APIs, asynchronous ownership, failure contracts and recovery. Review current Apple glass documentation and compile against the installed SDK. Accessibility audit remains deferred by owner; basic labels, touch controls and RTL remain.

## Plan review decisions

Independent reviewer requires persisted pendingVoice on the conversation before transcription. Use immutable job/recording IDs; resolve by explicit conversation identity, never current selection. Commit the voice user/assistant pair and remove pending state atomically. Retry identifies existing work by recording ID. App-owned VoiceTranscribing returns transcript ID, passage references and a text snapshot. Audio files remain in AudioLibrary. A failed cross-store handoff leaves saved audio available through Start chat in Recordings. Join/unload the text model before speech processing to prevent concurrent engine memory use. Initial packaging used pinned tiny weights; the measured replacement below supersedes that choice. Build-time hash checks and no runtime download remain required. Distinguish speech assets from chat weights.

## Implementation and independent review

- Domain: `native/LocalChat/Sources/ChatCore/VoiceModels.swift`, `ChatModels.swift`, `ChatUseCases.swift`. Presentation: `ChatPresentation/ChatViewModel.swift`. Optional Codable fields preserve older archives. A recording resolves idempotently to one pending/completed voice conversation; follow-ups remain there.
- Audio use case: `native/MemoryOS/Domain/AudioWorkflow.swift`; thin bridge: `Composition/AudioChatTranscriber.swift`. Canonical transcripts retain passage IDs and original-audio hashes. No clear speech becomes a recoverable error; it never becomes an AI prompt.
- Composition: `Composition/LocalInferenceCoordinator.swift` serializes both text and speech providers and unloads resident text weights before speech. `MemoryOSApp` injects the shared coordinator. Views only call ViewModels; core packages have no SwiftUI or provider SDK imports.
- UI: `CaptureView`, `ChatView`, `ChatVoiceCard`, `AudioLibraryView`, sidebar/section routes and `Theme` implement direct finish/send, durable pending/error cards, transcript disclosure, playback and native glass controls.
- Packaging: `scripts/bundle-speech-model.py` checks the reviewed asset before copying it. Invalid/missing input fails without replacing the prior valid output. The app bundles the Whisper MIT notice; weights remain outside Git. Build override is documented in `native/LocalTranscription/README.md`.
- Review repairs: manual transcription previously bypassed chat inference serialization; switching an unfinished recording to typed chat could retain an active microphone. Shared coordination and interruption on Capture disappearance close both paths. App tests also caught empty provider output being classified as generic failure; it now returns `noSpeech` before persistence.
- Cancellation limit: a canceled request waiting behind native inference releases after that active operation finishes, then skips the provider. This preserves exclusivity; immediate queued-cancel latency is not promised.

## Earlier verification

- Independent LocalChat: 44 functions pass, including durable pending work, explicit conversation targeting, idempotent retry, cancellation, save failures, large transcripts and follow-ups. LocalAudio: 17 functions pass with parameterized recovery/validation cases.
- Final repair run: 24 native functions in four suites pass, including coordinator ordering/cancellation, audio workflow/model storage, real bundled Whisper and digital silence. The three-second fictional English fixture took 14.62 seconds; process peak was 1,124,302,848 bytes on iPhone 18 Pro Max Simulator / iOS 27.2. This is one Simulator smoke measurement, not phone performance. The earlier 1.69-second tiny result is superseded for the selected model.
- Final signed generic iPhone Release build passes; embedded engine linkage, deep signature verification, runtime manifest and bundled model hash pass. Initial tiny workflow was installed in place without removing app data. At that checkpoint the larger-model repair had not been installed; later owner acceptance is recorded below.
- Connected UI test passes: original recording, transcript disclosure, AI reply, typed follow-up and reopening. Three earlier test attempts exposed SwiftUI identifier propagation; explicit card containment retains controls, and the test checks visible transcript text. Play/stop and pending retry/cancel targets now have explicit touch areas.
- Direct Simulator capture also completed pause and finish/send into a new voice conversation. This is workflow evidence only. The owner reports that phone recording/playback works but the English transcript is inaccurate; physical quality acceptance failed.

## Recognition quality follow-up

Preserve the installed workflow while diagnosing capture conversion and recognition separately. Compare the current multilingual tiny model with pinned multilingual small-q5_1 on the same existing fictional English, Arabic, mixed, names and noise fixtures; report word errors, elapsed time and resident memory. Keep private phone audio outside project records. Choose a replacement only from measured results, retain original recordings and prior transcript provenance, and verify the revised phone build with the owner. This describes the comparison plan; the measured selection and later owner acceptance follow below.

Capture diagnosis: six 16 kHz Int16 mono CAF probes preserved exact samples and frame counts across buffer boundaries. Four 44.1/48 kHz mono/stereo probes preserved duration within one sample, frequency and amplitude. These are host synthetic checks, not inspection of the owner's recording. The existing tiny baseline repeated its earlier per-category WER with expected detected languages. Candidate settings keep CPU, greedy decoding, automatic language and zero temperature unchanged for the first comparison.

Upgrade preparation: model-specific import indexes preserve earlier tiny folders while avoiding their unintended precedence over upgraded bundled weights. Seven native functions pass for model storage and the unchanged tiny smoke path. Ordinary chat retry stays idempotent; Recordings → Transcribe explicitly appends a fresh result without rewriting prior chat text.

## Measured replacement decision

Same five immutable mono fixtures, three fresh offline processes per model, M1 Pro / macOS 27.2.1. Only model size/quantization changed: CPU, four threads, greedy, auto-language and zero temperature/fallback remain fixed. Expected detected languages and names stayed consistent.

| Fixture | Tiny WER / median seconds | Small Q5_1 WER / median seconds |
| --- | --- | --- |
| English | 18.75% / 0.459 | 6.25% / 1.747 |
| English with noise | 25% / 0.428 | 6.25% / 1.943 |
| Names | 0% / 0.443 | 0% / 1.761 |
| Iraqi wording, synthetic | 54.55% / 0.538 | 36.36% / 1.964 |
| Mixed speech | 83.33% / 0.625 | 41.67% / 1.934 |

The English discrepancy is numeric formatting, not the earlier name/preposition errors. No natural-speech accuracy claim follows from these fixtures. Iraqi/mixed results still fail the existing ≤20% clean-speech target. Small's largest process peak was 624.4 MiB versus 302.2 MiB for tiny. Choose small Q5_1/auto as the measured English repair candidate; physical acceptance remains required.

On a byte-identical 600.49-second fictional clip, cancellation requested after one second returned in 0.321 seconds. RSS fell from 526,434,304 bytes at cancellation to 200,753,152 after awaited cleanup; baseline was 69,861,376. Remaining allocator/cache memory is not claimed as a leak-free steady state. The shared inference lease remains required.

The candidate is pinned at upstream revision `5359861c739e955e79d9a303bcbc70fb988958b1`, 190,085,487 bytes, SHA-256 `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`. Build selection feeds both hash verification and runtime bundle manifest selection. No runtime network download or cloud fallback.

The permanent stereo regression found AVAudioConverter's default selected the left channel. Enabling downmix preserves both channels, with measured expected amplitude and duration; all comparison fixtures and microphone capture are mono. Final LocalTranscription tests pass: ten functions, including six exact mono and two stereo cases. The independent verifier reviewed model identity, import isolation, bundle replacement and historical transcript preservation without a blocking finding.

## Earlier repair evidence and delivery

Source: dirty tree over `9c11150cdb013976cef59b02d3a110b758374776`; 88 app/audio/chat/transcription source, test, config and resource files aggregate to SHA-256 `ea9ce975171bcb289d095db6a35e4a7d6b1941dbcda655146b6a933ee98bc5a2`. This identity belongs to the earlier repair checkpoint; the Step 2 identity below supersedes it. Strict formatting passed for 79 Swift files; whitespace and project plist checks passed. The independent verifier rechecked final logs and built assets without a blocking source finding. Missing/invalid model metadata still defaults to small; required bundle-manifest tests catch packaging omissions.

Earlier captures remain in the published local artifact folder; the final Step 2 captures below supersede them for current review. Portable [tiny](../evidence/voice-2026-11-15/voice-chat/tiny-auto-summary.json), [small](../evidence/voice-2026-11-15/voice-chat/small-q5_1-auto-summary.json) and [cancellation](../evidence/voice-2026-11-15/voice-chat/small-cancellation.json) receipts retain the measured comparison. All use fictional data; no phone benchmark follows.

Cleanup scoped to resolved task-owned temporary logs, model-copy probes and raw fictional comparison runs: 80,792,810 bytes before, zero after. Separate agent cleanup removed a reproducible 19,215,656-byte long fixture and approximately 184 KB of PCM probes. Retained exceptions: active build products/caches for the next phone update, test result bundles, selected dark captures and compact summaries. Original references, existing work, model weights and phone history remain untouched.

Earlier delivery checkpoint: the signed replacement was ready while the phone was away. The owner subsequently reports that the supplied phone checklist works and requests a Step 2 rerun. Existing chats retain their historical transcript; explicit Recordings → Transcribe creates a fresh result. Quantitative phone cost, measured natural Iraqi/mixed accuracy and broader release qualification remain separate from this owner functional acceptance.

## Step 2 rerun

Scope: current chat/Home/history, voice capture-to-chat, transcript/source preservation, larger-model packaging, native glass, recovery and affected shared paths. Fresh `step2_voice_verifier` owns independent core/architecture/test review; `step2_voice_ui_audit` owns UI/recovery/dependency and cleanup review. The main agent runs native/connected checks, repairs findings and records final evidence. That rerun did not authorize Git delivery; the subsequent Step 3 request below does.

Skills reassessed: project SwiftUI, concurrency and Swift Testing for state/isolation/contracts; `swiftui-performance-audit` for affected rendering and measurement limits; `ux-error-recovery` for saved-work and retry states. Existing accessibility deferral remains; basic labels/touch/RTL checks stay in scope. The project `axiom-accessibility` skill and its focus reference guided a rejected visual diagnostic; no accessibility policy change remains. Source and tests, not prior reviewer conclusions, determine the rerun outcome.

Review repairs: `AudioComposition.makeFeature` now constructs/injects `AudioChatTranscriber`; `AudioViewModel` only updates presentation state. Both Capture and embedded Recordings call `leaveCapture` when leaving, including permission-pending/paused cases. Tests preserve exact audio bytes, save the interrupted draft through the UI action and start another recording. Voice processing now resets typed-reply timing and measures its own first text/cancellation; its regression failed before repair and passes afterward. Model recovery text no longer instructs small-model users to import tiny.

Test repairs: always seed fresh UUID voice fixtures, require the pending state, identify the voice-bearing message and prove the same message survives reopening with its unique follow-up. Current navigation helpers use header history, ignore offscreen drawer controls and return from Memories through Home without creating a new conversation. Scroll tests reopen their own UUID-marked conversation. Separate functional large-text coverage preserves the original deferred accessibility audit unchanged.

| Independent check | Result and evidence |
| --- | --- |
| MVVM, dependency direction and use-case behavior | PASS: traced Capture/Recordings → AudioViewModel → AudioWorkflow and ChatView → ChatViewModel → ChatUseCases; composition-only adapter construction. Core packages build without UI/provider imports; focused reviewer recheck closed the repair findings. |
| Canonical repository, upstream ownership and reviewed assets | PASS: separate upstream checkouts, matching resolved Argmax/ArgumentParser pins, all 531 materialized llama source hashes and all three slices of each inference framework match their receipts. No local mirrors/edited delivery override. Model revision/hash above stays selected. MIT/Apache license review remains valid; distribution notices remain later release work. |
| Real adapter contracts, errors and cancellation | PASS for affected local scope: actual bundled Whisper smoke, real local text replies, controlled failures/retry/cancel and inference exclusivity. Existing same-input WhisperKit comparison is reused for unchanged upstream adapter source; live OS call/route qualification remains open. |
| Arabic/English, offline and asset behavior | Functional owner acceptance and local English/RTL/model replacement checks; prior network-denied candidate comparison reused. FAILED quality qualification: synthetic Iraqi/mixed small-model WER still 36.36%/41.67% against ≤20%; natural speech is unmeasured. No cloud path added. |
| App-owned data, replacement and recovery | PASS for affected IDs/originals/corrections, archive compatibility, save retry, interrupted capture and voice-chat recovery. Complete audio backup/restore and OS write-kill/locked-device protection qualification remain open; tests do not substitute for these checks. |
| Physical cost and supported OS | BLOCKED: no measured phone baseline/candidate latency, RSS, heat/battery or iOS 18 runtime result. Owner checklist acceptance is separate. Current Xcode device record is disconnected, so this rerun's signed repair is not installed. |
| Accessibility | Owner-deferred audits remain deferred. Basic labels, touch actions, large-text composer and Arabic navigation remain in the functional rerun. |

Fresh verifier tracker: `step2_voice_verifier` completed core/lifecycle/MVVM review and focused timing, composition and test-identity rechecks; `step2_voice_ui_audit` completed UI/dependency/cleanup review and focused capture/model-copy repairs. The main agent owns executable evidence and remaining qualification status.

Final executable results: LocalChat **45**, LocalAudio **17** and LocalTranscription **10** test functions pass. Native Release tests pass **62 functions in 13 suites**, plus the fictional fixture seed. The refined interruption/save/restart regression passes with all **15 AudioWorkflow functions**. **14 unique UI tests** pass across the final affected runs: Home separation/follow-ups, stop/retry, history/drafts/rename/delete, memory corrections/Trash, large-text keyboard, English/Arabic navigation, voice transcription/reply/reopening and scrolling. Initial selector failures were repaired; a restored-source two-test English/Arabic navigation smoke also passes. Unchanged core/adapter evidence remains applicable after visual probes were reverted.

Release generic iPhone build/static analysis, embedded inference linkage and deep signature checks pass on restored source. The bundled small model identity above remains verified. Strict formatting passes for 79 Swift files; whitespace and plist checks pass. This rerun has not installed its code repairs on the disconnected phone.

Measurements: the three-second fictional bundled-Whisper smoke took **19.3505 seconds**, process peak **718,110,720 bytes**, one Simulator run. Three native scroll signpost durations were **2.367354 / 2.367413 / 2.366644 seconds**. These measure gesture/deceleration duration, not raster/input latency. No baseline/candidate speed improvement or phone-performance claim follows. Earlier combined-generation/scrolling proxy failure and actual frame-budget qualification remain open.

Visual observation: some Simulator sidebar-reopen/keyboard-dismiss captures omit header glyphs while controls still respond. XCTest and device-tool captures both show it. Identity-transition, animation-scope, shared-glass-container and assistive-focus probes did not reliably resolve it; all four were reverted. The owner repeated the exact sequence on the iPhone and reports the header stays visible. Keep this as an unresolved Simulator rendering/capture observation with unknown cause, not a confirmed phone defect or a passed Simulator visual check.

Final source: dirty tree over `9c11150cdb013976cef59b02d3a110b758374776`; **88 files**, aggregate SHA-256 `a6a3acaa4a78100afab615577dd04b955039e8e7201df2f66f015e5669f4b73b`. Restored source matches the successful functional run exactly. [Compact results](../evidence/voice-2026-11-15/voice-chat/results.json) and [identity/method](../evidence/voice-2026-11-15/voice-chat/source-identity.json) retain counts, measurements and executable/screenshot hashes. Test bundles stay in local build caches and may be pruned; observed results are compacted, not represented as portable raw bundles.

New dark evidence, iPhone 18 Pro Max / iOS 27.2 **Simulator**, fictional data: [Home](../evidence/voice-2026-11-15/voice-chat/home.png), [voice/transcript/reply from the passing test](../evidence/voice-2026-11-15/voice-chat/voice-transcript.png), [keyboard without the removed footer](../evidence/voice-2026-11-15/voice-chat/keyboard.png), and [unresolved header capture](../evidence/voice-2026-11-15/voice-chat/header-rendering-unresolved.png). The first three show their observed complete states; they do not erase the fourth. The fresh Step 3 [transcribing capture](../evidence/voice-2026-11-15/voice-chat/transcribing.png) closes the earlier pending-state screenshot gap on the same Release source.

Rerun cleanup: removed 11 superseded build logs (**4,423,640 logical / 4,444,160 allocated bytes → 0**) and 29 temporary diagnostic/export files (**3,376,938 logical / 3,850,240 allocated bytes → 0**) after compacting outcomes. Removed one unused 51-byte Swift token; the independent reviewer confirmed no consumer. Retained active build products/SwiftPM caches/test bundles for the next update and unresolved evidence, upstream/model assets, original references and phone data. Repaired old log references; retained receipts, hashes and links are checked. No raw owner communications entered project evidence.

## Step 3 delivery review

The owner requested Step 3 on November 17. Main branch already contains earlier chat PR #5 at `86cf5f57b1684f9da2ef302a21c039bdc68e6c93`; this delivery uses `feat/voice-chat-recording` from that identical source tree. No app source changes in Step 3. Fresh Standards and Spec reviewers independently matched the 88-file Step 2 identity; Standards also matched all five linkage-script/probe hashes. No new implementation findings. The main agent corrects stale delivery/integration text and retains the qualification blocks.

Skills: `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md` for separate standards/spec checks, `/Users/eros/.codex/skills/mattpocock-pr/SKILL.md` for reviewable draft delivery, and `/Users/eros/.codex/skills/docs-sync/SKILL.md` for affected current records. C50–C52 personal-goal/roadmap edits and unrelated architecture/skill evidence remain local and outside this draft.

Documentation cleanup removes 16 files (resolved logs, duplicate gallery wrappers and used upload/receipt copies): **3,305,659 logical / 3,338,240 allocated bytes → 0**. Compact receipts retain outcomes; historical PNGs, original fixtures/source identities and unresolved accessibility/measurement diagnostics remain. Current fictional captures/receipts become portable evidence; published external links and active build/model caches remain for their existing consumers. No user history or original reference is deleted. Final evidence/link/index checks and actual draft delivery are recorded below.

Step 3 capture check: the unchanged fictional seed XCTest passes, then T3 device controls open its recording as a new chat. The retained dark pending card shows on-device transcription and Cancel; the same session then produces its local reply. This adds visual evidence without changing source or replacing the recorded performance/phone limits.

Delivery: [draft PR #6](https://github.com/faroqomar/Eros_MemoryOS/pull/6), source commit `101f391b596bcb81227fd572f76d779c2aeba9e3`, base `86cf5f57b1684f9da2ef302a21c039bdc68e6c93`. Both independent reviews found no new implementation defect. Staged source matches the tested 88-file digest; evidence guard, whitespace and 228 relative documentation links pass. No hosted checks/branch protection are configured; required project gates still block merge. No release, phone installation or new app feature in Step 3. Final documentation memory delivery is checked at handback.
