# Task: Group 6 real voice recording and transcription

Status: full group 6 qualification remains BLOCKED on measured language quality and device qualification. The owner reports the later phone checklist works and requested another Step 2 review; see the [current voice/chat rerun](2026-11-17-voice-chat.md). Record owner functional acceptance separately from numerical benchmarks and exact installed-build identity. Accessibility stays deferred. The dated November 15 evidence below is historical.
Checklist: [group 6](../plans/implementation-checklist.md#6-add-real-voice-recording-and-transcription).
Scope: microphone capture, audio import, local engine comparison, language checks, transcript correction/source links/export, and recovery. Step 2 authorizes independent checks, repairs and cleanup. The November 17 Step 3 request authorizes review, cleanup and draft Git delivery; required qualifications still block merge. No release or cloud transfer starts.

## Step 1 plan and acceptance

- Record, pause, resume and save with explicit microphone permission; never resume the microphone without a user action after interruption.
- Import bounded supported audio, reject unsupported/damaged data, and retain the original bytes.
- Run WhisperKit and whisper.cpp against identical fictional recordings and retain separate engine/model results.
- Cover English, Iraqi Arabic, mixed speech, names and noise. Label synthesized fixtures; they cannot establish natural Iraqi speech accuracy.
- Correct timestamped passages without replacing the original audio or original transcript; retain unknown/uncertain speaker status.
- Link recordings to real local person/source UUIDs; retain associations in transcript exports.
- Recover saved audio and interrupted drafts/jobs after relaunch; explain permission, storage, decoding and model failures.
- Keep the existing Capture layout, dark appearance, Arabic/English, native controls, Dynamic Type and Reduce Motion.

Architecture: `AudioLibraryView`/recording sheet → `AudioViewModel` → audio use cases → app-owned capture/transcription/repository protocols → Apple recording/file adapters and pinned upstream SDK adapters. `AudioComposition` constructs dependencies. The plain Swift `AudioCore` target owns source IDs, metadata, jobs, passages and corrections; `AudioPersistence` owns atomic metadata/audio storage. Existing MemoryCore UUIDs supply person/source associations. Audio uses a versioned separate store so this step does not silently change the existing text archive contract.

The main agent owns UI, composition, integration and task evidence. Scoped helpers own `LocalAudio` domain/persistence/tests, Apple capture/import/playback, and `LocalTranscription` SDK integration/comparison. Helpers do not act as the later independent Step 2 verifier. Upstream source remains in its own checkout/package; no custom engine repository or copied engine source.

Skill search: installed catalog and project skill guide checked for SwiftUI, isolation/cancellation, package adoption, durable audio, native permissions, testing and recovery. Selected `.agents/skills/swiftui-expert-skill/SKILL.md`, `swift-concurrency/SKILL.md`, `swift-testing-expert/SKILL.md`, `swift-package-manager/SKILL.md`, `ux-error-recovery/SKILL.md`, and `ux-loaders-and-progress/SKILL.md`. Implementation workflow: `/Users/eros/.codex/skills/mattpocock-implement/SKILL.md`. Relevant test seams are the public audio library, replaceable capture/transcription contracts, and ViewModel actions; the Step 1 request already authorizes architecture and relevant tests. Separate feature redesign and broad unrelated audits are unnecessary.

Builder checks: Swift 6 core/persistence tests; import/recording and ViewModel failure transitions; actual adapter compilation/execution; existing LocalMemory/LocalChat regressions; main-app build/static analysis; connected dark Simulator states. Check transcript export original hashes and source links. Never count substitutes as actual engine/OS verification.

Benchmark plan: same immutable input bytes, multilingual model family/size and documented decode settings per engine; report processing seconds, real-time factor, model bytes, process memory and reference-text WER. Three repeated runs where runtime permits; cold and warm values separate. Engineering targets: no source mutation; all valid references/IDs survive corrections/export/restart; cancellation returns recoverable state; no processing on the UI actor. Candidate quality threshold: WER ≤20% per clean language category and ≤35% noisy speech, with exact names reported separately. These are builder evaluation thresholds, not owner-approved production quality. Physical iPhone battery/heat/latency remain blocked until that device is available.

Environment: Xcode 27.2 (27B52), Swift 6.4.2; app Swift 6 strict concurrency, minimum iOS 18. T3 discovery lists iPhone 18 Pro and Pro Max simulators on iOS 27.2; no physical iPhone.

## Current results

Implemented:

- Real microphone record/pause/resume/save through AVAudioRecorder; explicit localized permission and recoverable failures.
- WAV, M4A, MP3, AIFF, CAF and FLAC import after full decode validation; security-scoped access spans validation and copy.
- Recording/import limits: 250 MiB and two hours. Transcription limit: 15 minutes per operation.
- Native audio library, playback at passage timestamps, separate engine results and editable transcript passages.
- Original audio hashes, original recognized text, correction history, uncertain words and unknown speaker labels remain available.
- Associations use actual local person/source UUIDs. JSON transcript export retains recording, person, source and correction associations.
- Model folder import validates before atomically switching the active model. Runtime has no model download or remote fallback.
- Background/interruption handlers stop capture or processing; reopening marks unfinished work interrupted. Recovery uses written audio and restarts transcription.
- Audio files use complete iOS file protection. Audio/model directories are excluded from OS backup; a complete audio backup/restore feature remains open.

Architecture inspected during builder review:

- `native/LocalAudio/Sources/AudioCore`: independent records, public contracts and library use cases.
- `native/LocalAudio/Sources/AudioPersistence`: atomic versioned storage, original hashes, validation and recovery.
- `native/MemoryOS/Domain/AudioCapture.swift` and `AudioWorkflow.swift`: capture contracts and orchestration.
- `native/MemoryOS/Features/Audio`: ViewModel action/state management and native Views.
- `native/MemoryOS/Composition`: Apple capture/inspection/playback, model storage and dependency wiring.
- `native/LocalTranscription`: separate WhisperKit/whisper.cpp adapters and shared bounded PCM decoding.
- Views and ViewModels use injected app-owned use cases. SDKs stay in adapters; composition owns concrete dependencies.

Builder repairs: checked lifecycle generation after suspension points to prevent late microphone start; blocked sheet dismissal while permission/work is pending; retained save retry after the recorder closes; ignored delayed events for superseded drafts; capped scheduled recording with duration headroom; surfaced snapshot/storage failures; retained word annotations for speaker-only edits and original recognition after text corrections. Focused helper rechecks found no remaining findings in their assigned scope. They do not constitute Step 2.

## Checks and source identity

| Check | Recorded result |
| --- | --- |
| LocalAudio public domain/persistence tests | 13 passed |
| Capture/workflow isolated tests using production sources | 13 passed |
| LocalTranscription package tests | 5 passed |
| Existing LocalMemory / LocalChat regressions | 21 / 24 passed |
| Xcode app unit tests | 45 passed |
| Foundation UI tests, iPhone 18 Pro Max Simulator / iOS 27.2 | 5 passed |
| Debug Simulator build | Passed |
| Release Simulator build and static analysis | Passed |
| Unsigned Release generic iOS compilation | Passed; no physical execution |
| Actual host SDK inference with network denied | 30/30 operations completed |

UI checks cover English/Arabic audio-library opening without microphone activation, sidebar routing, Arabic navigation, and saved text across relaunch. They do not verify the entire recording/transcription flow. Unit checks cover permission denial, background races, pause/resume, save retry, damaged/unsupported input, low-storage recovery, model replacement, cancellation, originals, associations and corrections/export.

Final adapter changes received package tests, the repeated host comparison and Release builds/analysis. Earlier app unit results are reused for unchanged domain/ViewModel source. Five Release UI tests passed after the launch-path fix; the later passage button-style change received a Release build/analysis and direct playback/edit separation recheck. Existing upstream llama umbrella-header warnings remain. Initial SDK API/build errors were repaired before the passing runs.

Source: base HEAD `9c11150cdb013976cef59b02d3a110b758374776`, with uncommitted task changes. Aggregate SHA-256 across 72 app/package/test/manifest/preparation files: `2275f960186ea8d9c7bea28879941e1fdc4811a7d8271bacb6ea882bea9449d4`. Ignored `native/verification/audio-step1/source-identity.json` records the exact set. Source identity is not a commit or release.

Step 1 compact outcomes and source/model/fixture identities remain retained. Compact Step 2 results remain in the receipt below. Step 3 removes resolved raw build/test retries; unresolved accessibility/measurement diagnostics remain in ignored `native/verification/audio-step2`. Test bundles are local cache artifacts and may be pruned by later Xcode runs.

## Transcription comparison

See [compact measurements](../evidence/voice-2026-11-15/comparison.json), [interactive comparison](../evidence/voice-2026-11-15/comparison.html) and [reproduction, pins and licenses](../../native/LocalTranscription/README.md).

Both adapters ran the same five fictional local TTS recordings, three fresh processes per engine, on M1 Pro / macOS 27.2.1. The macOS sandbox denied network during inference. OS/CoreML caches persist between processes; elapsed time includes model loading and inference. No microphone or personal recordings entered this dataset.

WhisperKit v1.1.1 and whisper.cpp v1.9.5 use multilingual tiny models. Exact dependency/model hashes remain in the package and preparation receipts. The 22 model files total 157,090,259 bytes and remain outside app source.

| Recording | WhisperKit WER / median seconds | whisper.cpp WER / median seconds |
| --- | --- | --- |
| English | 18.75% / 1.230 | 18.75% / 0.634 |
| Iraqi wording, synthetic Arabic voice | 54.55% / 1.187 | 54.55% / 0.737 |
| Mixed Arabic/English | 83.33% / 1.149 | 83.33% / 0.663 |
| Names in English | 0% / 0.974 | 0% / 0.503 |
| English with background noise | 37.5% / 0.979 | 25% / 0.434 |

First English runs took 11.851 / 9.391 seconds; whole-process peak memory reached 211.9 / 301.3 MiB. WER uses NFKC Unicode words and case folding, without Arabic spelling/dialect normalization. Both engines fail the builder targets for Iraqi wording and mixed speech; WhisperKit also fails the noisy threshold. Synthetic Arabic cannot qualify natural Iraqi accents. Neither model has production acceptance.

A separate 600.49-second fictional repeated recording cancelled one second after invocation returned CancellationError within 0.104 seconds for WhisperKit and 1.317 seconds for whisper.cpp. This tests adapter cancellation, not calls or process termination. Uncertainty thresholds remain heuristic; an unflagged word is not necessarily correct. Automatic speaker identification is not implemented.

## Required captures and remaining limits

The owner released the occupied Simulator session. Standalone Release launch exposed a DYLD failure: the embedded whisper framework lacked an executable-relative runtime search path. Added `@executable_path/Frameworks` to both app configurations; Release build/analysis, bundle inspection, five Release UI tests and subsequent standalone launch passed. The first Release test command needed arm64/testability overrides for its test targets. Initial build success did not establish standalone launch. App captures now come from T3 device tools on iPhone 18 Pro Max Simulator / iOS 27.2 in dark mode.

Both real adapters completed the same fictional recording inside the Simulator app. WhisperKit correction and speaker-label changes saved while preserving original recognition. A manual playback check found SwiftUI List combining two automatic button actions; explicit borderless passage buttons separate playback from editing. The final installed Release build passed standalone relaunch, passage playback without opening the editor, original-recognition disclosure, correction persistence and Files export. Exported JSON retains one real local fictional-person UUID, one source UUID, original/corrected text, timestamps and the unchanged audio hash. Microphone denial shows recovery text and creates no draft; permission was reset afterward. Models and the fictional recording were prepared through file sync; the system Files import flow remains distinct from this observation.

Physical iPhone 15 Pro Max, iOS 18 runtime, natural Iraqi speech, actual microphone recording, real calls/routes, low-storage OS behavior, termination during writes/inference, device thermal/battery/latency and complete airplane-mode app behavior remain unverified. Controlled tests and unsigned compilation do not substitute for these results. These qualification limits do not claim physical readiness, production accuracy or Step 2 acceptance.

Current captures: [voice library](../evidence/voice-2026-11-15/screenshots/library.png), [corrected and original transcript](../evidence/voice-2026-11-15/screenshots/corrected-transcript.png), [microphone denied](../evidence/voice-2026-11-15/screenshots/permission-denied.png). All show the final source above, installed Release, iPhone 18 Pro Max Simulator / iOS 27.2, dark mode and fictional data.

Compact launch-repair evidence: ignored `native/verification/audio-step1/launch-repair.json` and `simulator-transcript-export.json`. The November 17 rerun removed the superseded raw build/test logs after preserving these outcomes. Builder diagnostic and Swift Package Manager skills guided the packaging repair; no new dependency or later stage started.

## Cleanup and evidence retention

Removed four task-owned isolated test/typecheck/fixture-seeding/empty screenshot-export folders after preserving results: allocated storage 168,812,544 bytes before, zero after. Helpers separately removed 130,921,519 bytes of owned scratch/build artifacts. Removed two superseded captures (165,446 bytes); current capture total changed from 362,420 to 196,974 bytes. Retained the app build/test bundle, compact comparison, fixture/source/model receipts, active diagnostics and external upstream/model caches for later verification. Preserved original research, existing edits, Git metadata and the fictional simulator fixture. No broad cache cleanup or unrelated deletion ran.

Evidence guard passed for the compact task/comparison files; all 94 checked local documentation paths exist. `git diff --check` passed.
Existing unrelated documentation edits were present at task start and are preserved.

## Step 2 independent verification

Fresh Standards and Spec reviewers inspected actual source, contracts and builder evidence. Selected `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md`, project `swiftui-expert-skill`, `swift-concurrency`, `swift-package-manager`, `swift-testing-expert`, `axiom-security` and `axiom-accessibility` entry points for independent architecture, durable files, model imports and native accessibility. The main agent repairs findings; reviewers recheck them. No broader redesign or provider selection starts.

F1: shape-only model import could accept corrupt files, switch the pointer and remove a usable model. A regression reproduced the loss before repair. Installation now validates staged bytes against reviewed provider hashes before committing; cancellation or rejection preserves the previous pointer and files. WhisperKit runtime uses the same pinned tiny fingerprint. Controlled transaction tests use a small injected validator; separate production-validator tests reject damaged assets for both engines.

F2: pre-byte recording-start failure could strand an empty interrupted draft and block retry. The workflow now closes the capture session and rolls back only empty interrupted metadata. Nonempty and saved originals remain untouched. Recover/Save handles old empty interrupted drafts after restart; delayed interruptions ignore only IDs removed by this repository instance. Tests cover immediate retry, partial-byte preservation, restart, failed persistence and symlink refusal.

Local rechecks: 49 Release app unit functions and six UI methods pass; the unfiltered accessibility audit remains failed. Core repair tests pass 17 functions (26 executions), isolated workflow tests pass 9 functions, and adapter tests pass 6. Both real engines transcribed the unchanged English fixture after validation repair under denied host networking. Unchanged inference settings preserve the prior 30-run comparison and its failed thresholds. See the compact [Step 2 receipt](../evidence/voice-2026-11-15/step2/results.json) for final builds, audit failures and current captures.

Accessibility repairs use brighter secondary text, a labelled 44-point confirmation icon with a large-content preview, scalable content headings and wider actions. Enlarged English/Arabic measurements pass for recording controls and the transcription heading; this does not waive the unfiltered diagnostic failures. Actual large-Arabic capture exposed an LTR sheet despite an RTL parent; explicit direction/locale now covers the library and correction sheet, and the new import icon/text ordering assertion passes. The sheet repair received focused independent source review.

Step 2 source identity: base HEAD remains `9c11150cdb013976cef59b02d3a110b758374776`; 72-file worktree aggregate `1bf511e2f74e7de4ad888504a2d96febaebd756dc5d5dca66b80353655931d43`. Independent Spec and Standards reviewers closed F1/F2. The main agent retains remaining failed/blocked checks; no acceptance or delivery claim follows.

Files verification: the system picker imported the fictional English WAV and rejected damaged audio and a same-shaped damaged WhisperKit folder. Both installed model pointers and both original recording hashes remained unchanged after rejection. No microphone or personal audio entered these checks.

Remaining unfiltered diagnostics: post-scroll English contrast on an unlocated element, model-import text scaling in both languages, and Arabic Start clipping before/after scroll. Required native accessibility remains failed. Other qualification gates include no physical iPhone or iOS 18 runtime, natural Iraqi recordings, calls/routes, OS low-storage/termination recovery, thermal/battery measurements or complete disconnected app flow. Audio backup/restore and deletion remain production gaps, not passed checks. These limits block full Step 2 acceptance.

Step 2 captures: [model rejection](../evidence/voice-2026-11-15/step2/model-rejected.png), [largest Arabic RTL](../evidence/voice-2026-11-15/step2/arabic-largest.png). Current source above; installed Release, iPhone 18 Pro Max Simulator/iOS 27.2, dark mode. Correction-sheet layout and physical behavior are not certified by these captures. Final unsigned iOS compilation/static analysis and strict Swift formatting pass.

Step 2 cleanup: removed 560,635,904 allocated bytes of package caches, 723,300,352 allocated bytes of derived caches before rebuilding, 84,567,198 logical bytes of helper scratch, 200,704 allocated bytes of task-owned Files fixtures and 957,359 logical bytes of superseded diagnostic extracts. Removed unused `AudioViewModel.selectedID` after confirming it had no reader. Retained current app products, final-UI result bundle, full-unit log/summary, original fixtures/model assets, source identities and unresolved evidence; retained hashes pass. These deletion totals do not claim net savings after rebuilding. Unrelated work and original records remain intact. The final verifier accepts scoped cleanup and keeps Step 2 blocked. The agent released its Device session without shutting down the Simulator.

November 17 device attempt: Xcode detects the owner's iPhone (`iPhone16,2`), but T3 still omits it after the prescribed failed-open discovery retry. Automated interaction stopped. The owner later installed, trusted and opened the app manually, then reported chat crashing after model import. [Chat diagnosis and repair](2026-11-15-local-ai-chat.md#november-17-physical-phone-chat-crash) correct incompatible llama/Whisper GGML linkage. Phone recording, voice benchmarks and new automated captures remain unavailable. Selected project `swift-testing-expert/SKILL.md` for test scope and `swiftui-performance-audit/SKILL.md` for measurement limits; this device discovery did not verify voice behavior.

Step 3: authorized November 17; draft delivery in the current voice/chat record; no commit/push/merge authorized by the Step 2 request.
Memory delivery uses `./scripts/memory sync` followed by `./scripts/memory check`; the handback reports the observed queue result. Current source and this record outrank stale knowledge-page summaries.
