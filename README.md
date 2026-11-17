# Eros MemoryOS

**Voice chat repair, 2026-11-17:** Home recording now opens a conversation with an audio message, expandable transcript and local reply; typed follow-ups stay together. Controls use native Liquid Glass, and the marked footer is removed. After the owner rejected tiny-model English accuracy, the measured small Q5_1 upgrade passes host/Simulator checks. The owner now reports the phone checklist works. The requested Step 2 rerun has repaired microphone lifecycle, adapter composition, timing and recovery-copy findings; 14 selected UI tests, package/native checks, signed builds and cleanup pass. The owner confirms normal phone header behavior; an intermittent Simulator capture/rendering observation remains unresolved. Numerical language/device qualification remains open. See the [plan, agent tracker and results](docs/tasks/2026-11-17-voice-chat.md).

**Voice recording and transcription, group 6 Step 2:** independent review repaired model-replacement and empty-draft recovery defects. On November 17 the owner deferred accessibility work; prior diagnostics remain failed, not passed. Owner functional phone acceptance is recorded in the November 17 follow-up; measured language accuracy and device qualification remain open. Xcode currently lists the phone as disconnected. See the [task and evidence](docs/tasks/2026-11-15-voice-transcription.md).

**Earlier local chat delivery:** [PR #5](https://github.com/faroqomar/Eros_MemoryOS/pull/5) merged on November 15. That merge does not close its generation/scrolling, raster timing or remaining OS/offline qualifications. November 17 voice/chat changes now have their own Step 3 draft delivery; see the [current task](docs/tasks/2026-11-17-voice-chat.md) and [historical chat evidence](docs/tasks/2026-11-15-local-ai-chat.md).

Eros MemoryOS is a proposed personal memory app. You add ideas, recordings, chats, emails, and documents. The app connects this information to people, projects, and reminders.

The current target device is the owner's iPhone 15 Pro Max. Everyday capture, memory, and AI processing should work on the phone. A Mac must not be required for everyday use. Optional external services need a separate choice.

**Current result, 2026-11-14: checklist group 3, Step 2 blocked after independent review and repairs.** Local SQLite capture retains originals, correction history, stable links, reversible Trash and explicit JSON backup/restore. The review found and closed exact-Unicode preservation and storage-open retry bugs. Local checks pass: 21 storage functions, 17 app unit functions, 13 functional UI scenarios, Release builds/analysis, cleanup and dark Release captures. Physical iPhone protection/performance, iOS 18 runtime and unresolved accessibility checks block passage. See the [task record](docs/tasks/2026-11-14-local-storage-text-capture.md) and [storage decision](docs/decisions/local-record-storage.md). C37 authorizes Step 3; [draft PR #3](https://github.com/faroqomar/Eros_MemoryOS/pull/3) is open. Merge remains blocked and no release starts. The earlier interface demo status below remains its own evidence.

**Status, 2026-11-14: Step 2 is blocked after independent review and interface repairs.** The native sample demo includes Capture, hidden navigation, People, Projects, Birthdays, BrainMap, and Arabic/English in dark mode. Local checks cover 12 passing functional UI scenarios across recorded runs, 7 unit tests, Release analysis/build, and unsigned iPhone compilation. Two accessibility diagnostic methods still fail; measured text growth and rendered colors contradict specific warnings, while unlocated findings remain unresolved. Physical iPhone checks and iOS 18 runtime validation remain open. See the [task record](docs/tasks/2026-11-14-complete-interface-demo.md) for source identity, repairs, reused evidence, and blockers. Step 2 cleanup now passes; it removes unused enum APIs and reclaims 984.45 MiB of generated/redundant files. The owner merged PR #1 on 2026-11-14; owner visual acceptance and the listed verification gaps remain open. The new group 3 task adds local storage. Recording, AI, scheduling, and release remain separate.

**Local AI evaluation, C38–C44, 2026-11-15: the verified C40 Simulator experiment is merged in [PR #4](https://github.com/faroqomar/Eros_MemoryOS/pull/4).** Downloads, actual SDK contracts, canonical dependency checks and repeated multilingual comparisons remain verified. The original selected dataset has 450 completed Simulator operations plus 15 explicit MLX-unavailable cases; MLX runs separately on the Mac. Model quality still fails production adoption. Follow-up repairs isolate the lab packages from the main app, verify dirty Cactus checkouts, replace failing collection headers with scalable heading rows, and correct recovery text. The final four UI tests pass, including both unfiltered English/Arabic accessibility audits. Open `native/MemoryOS.xcodeproj` for the main app; the experimental lab has its own `native/MemoryOSAILab.xcodeproj` in this same repository. See the [lab build instructions](native/LocalAIEvaluation/README.md), [measured comparisons](docs/evidence/local-ai-2026-11-14/resume-summary.md) and [current task evidence](docs/tasks/2026-11-14-local-ai-phone-evaluation.md). Step 3 merged the reviewed experiment as `7e20302`; physical-device readiness, iOS 18 runtime compatibility and production selection remain separate. Group 5 chat is a separate task under Step 2 review; it is not a result of this evaluation.

Private canonical repository: [https://github.com/faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS), connected as `origin`. The owner merged [PR #1](https://github.com/faroqomar/Eros_MemoryOS/pull/1) into `main` at `1cd6d1e6cf3d056586afbc8fab66766dd8c9dfee`. That merge does not resolve the verification gaps above.

Workflow update C33: each step may use scoped subagents when useful. Step 2 removes confirmed dead/useless/temporary files while preserving source and evidence. Each step shows screenshots of changes. A requested Step 3 includes merge after required review/checks and any required product/design acceptance pass, without another routine merge confirmation.

The earlier Capture/sidebar foundation passed a simulator build and four UI tests on 2026-11-13. The current task expands those screens and adds new checks; earlier results do not verify the new source.

Historical implementation inventory, 2026-11-12: [SwiftUI tools, design references, and feature checklist](docs/plans/implementation-checklist.md). The owner requested native implementation and iPhone launch, with this inventory first. Native work has not started at this checkpoint.

Design update, 2026-11-12: the owner rejected the first proposal and all five later design directions. The current [home-screen style proposal](docs/design/home-style.md) uses the already-decided Capture home as the visual anchor for the remaining sections. The localhost annotation tool remains available. New other-screen layouts still need review; native work remains separate.

Design update, 2026-11-13: the owner requested using Astryx to design MemoryOS. The separate [Astryx browser prototype](docs/design/astryx-prototype.md) follows the retained home reference and uses fictional sample data. This is a reviewable design, not an approved native interface or a change to the selected SwiftUI stack.

Historical design direction, 2026-11-13: the owner rejected the restrained Astryx version and released previous visual rules. The resulting [wild redesign](docs/design/wild-redesign.md) was also rejected. Both versions remain design history.

Historical design direction, C19: the owner selected Apple design as the positive reference. The [Apple-inspired prototype](docs/design/apple-inspired.md) remains a browser study.

Current direction, C20: the owner returned to the supplied [Capture](designs/references/2026-11-13-native-foundation/capture.png) and [sidebar](designs/references/2026-11-13-native-foundation/sidebar.png) screens and requested the SwiftUI project foundation plus an iPhone connection check. Open `native/MemoryOS.xcodeproj` in Xcode. The implementation follows these two layout references; C21 sets dark mode as the standing preference for completed work, previews, and final checks. Other screen layouts still need review.

## Read in this order

1. [Product overview](docs/product-overview.md): what the app should do and how it should feel.
2. [Complete feature register](docs/feature-register.md): current requests, proposed supporting features, and links to old ideas.
3. [Decision register](docs/decisions/decision-register.md): confirmed direction, proposed choices, and open questions.
4. [Historical research](docs/reference/historical-research.md): the broader 2025 vision and its current status.
5. [Build outline](docs/plans/build-outline.md): a proposed sequence, without dates or implementation approval.
6. [Source register](docs/reference/source-register.md): original documents, hashes, conversation sources, and changes in direction.
7. [Hindsight setup](docs/how-to/hindsight.md): the separate development-memory bank and verification commands.
8. [Development workflow](docs/how-to/development-workflow.md): the three steps, useful subagents and independent verification, cleanup, screenshot handbacks, and merge requirements, and [task template](docs/templates/development-task.md).

Owner direction, C22/C23 (2026-11-13): prepare for future sales in several markets with optional cloud AI/sync. Follow the standing [commercial and engineering rules](docs/how-to/commercial-engineering-rules.md) for privacy, modular architecture, app-owned records, safe upgrades, maintenance, and market assessments. Exact markets, storage/providers, implementation, and launch readiness remain open.

New decision, 2026-11-07: [Wax and Cactus runtime memory options](docs/decisions/runtime-memory-options.md). Both remain candidates for future experiments. Plan for switching without losing app-owned records; no final runtime is selected.

Audio candidates, 2026-11-07: [AVAudioRecorder, WhisperKit, and whisper.cpp](docs/decisions/audio-recording-and-transcription.md). Recording and local Arabic/English transcription have separate roles. Model choices and phone results remain open.

## Meaning of status labels

- **Requested:** the owner asked for the feature. Its detailed behavior and delivery stage may remain open.
- **Confirmed:** the owner gave an explicit constraint, fact, or instruction.
- **Proposed:** the assistant suggested an approach. The owner has not selected it.
- **Historical:** an older research document contains the idea. It is not current implementation approval.
- **Superseded:** a newer owner instruction replaces the old direction for current planning.
- **Open:** the owner or a technical test must resolve the question.
- **Verified:** a recorded check supports a narrow result. It does not prove unrelated results.

## Original documents

The three original documents remain unchanged:

- [Original research report](Project_Idea.md)
- [Original summary](Project_Idea_Summary.md)
- [Original expanded summary](Project_Idea_Expanded_Summary.md)

They describe a wider cloud-based product, including digital legacy and professional use. Read the new status records before using an old statement as a current decision.

## Development memory

Project ID: `memoryos`. Hindsight bank: `project-memoryos`.

Hindsight indexes reviewed project documentation for development. This connection does not select Hindsight as the app's runtime memory system. The existing Mac service uses external AI for extraction; it is not an example of a fully on-device product.

```sh
./scripts/memory recall --query 'What is confirmed for MemoryOS and what remains proposed?'
./scripts/memory check
```

For this documentation task and its verification record, see the [update log](docs/log/2026-11-06-documentation.md).
