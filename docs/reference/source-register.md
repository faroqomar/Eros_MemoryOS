# Source register and chronology

Consolidated on 2026-11-06. Preserve the original files. Use the new overview, registers, and current owner instructions to determine present direction.

## Original local documents

| ID | File | Size | SHA-256 |
| --- | --- | --- | --- |
| L01 | [Project_Idea.md](../../Project_Idea.md) | 244406 bytes; 1462 logical lines | `bd7c1f7e284691892c21b1e576acca89056b07bb9e2fadadd7f76cde0d4718c2` |
| L02 | [Project_Idea_Summary.md](../../Project_Idea_Summary.md) | 12530 bytes; 141 logical lines | `6aeddb93e8174532f7ad494eb18cc4f5eb4365ca2cf4b87e299e37835711b579` |
| L03 | [Project_Idea_Expanded_Summary.md](../../Project_Idea_Expanded_Summary.md) | 16647 bytes; 196 logical lines | `feff72608e17f143095d49bb93c65d1cc69dcab30972a6ee3fcdd20e64266635` |

Line counts use Python `splitlines()`, including a final unterminated line where present. Byte counts and hashes identify the exact original versions. The report's own date is November 2025. File-system timestamps are not evidence of owner approval or exact authorship.

All three files are research/planning sources. L02 and L03 summarize the same broad concept. Similar statements across them are not three independent approvals.

## L01 source map

| Lines | Topic |
| --- | --- |
| 1-70 | Title, research date, executive summary, and table of contents |
| 71-143 | Product concept, intended audiences, consent, and persona boundaries |
| 144-261 | Pipeline, technology options, and mobile/server split |
| 262-374 | Hybrid, temporal, conversational, cross-language, graph, and evidence-based retrieval |
| 375-442 | Writing-style profiles, possible training, controls, and disclosure |
| 443-518 | Events, themes, sentiment, relationships, conflicts, commitments, and corrections |
| 519-588 | Mobile capture, shortcuts, OCR/speech, and categories |
| 589-692 | Data controls, encryption, threat model, and historical compliance discussion |
| 693-783 | Quality metrics, recognition accuracy, feedback, and adversarial tests |
| 784-901 | Competitive, professional-edition, commercial, and deployment ideas |
| 902-1173 | Historic roadmap, budgets, risk register, ten suggested decisions, and hiring |
| 1174-end | Bibliography and repeated reference entries |

## Current conversation sources

The table below is a sanitized summary. The raw conversation is not copied into documentation or retained in Hindsight.

| ID | Event | Meaning and authority |
| --- | --- | --- |
| C01 | Owner describes the personal app vision. | Source for idea capture, imported conversations, people/projects, audio/transcripts, conflicts, email/calendar, chosen reminders/rules, simple UI, hidden sidebar/custom tabs, local AI, Obsidian, documents, languages, and future devices/backends. These are requested goals. |
| C02 | Owner identifies iPhone 15 Pro Max and chooses phone-only processing over Mac assistance. | Confirmed device and local-use preference. No benchmark result follows from the device name. |
| C03 | Assistant researches options and explains a possible local architecture. | Source for supporting proposals, alternative tools, record separation, evidence links, corrections, saved views, resumable work, integration boundaries, and a small device test. Recommendations are not owner decisions. |
| C04 | Owner says not to build anything and requests minimal conversation in ASD-STE100. | Explicit implementation boundary and communication preference. This does not establish formal language-standard certification. |
| C05 | Owner asks how the app could be built; assistant gives six steps and a candidate stack. | Discussion only. Flutter, SQLite, llama.cpp, WhisperKit/whisper.cpp, and the stage sequence remain proposals. |
| C06 | Owner requests all new information documented, an isolated Hindsight connection, and a list spanning old and new ideas/decisions. | Authorizes this documentation and development-memory task. Does not authorize application code, deployment, or old scope expansion. |
| C07 | On 2026-11-07, owner requests a new Markdown decision file listing Wax and Cactus as options to choose, switch between, and experiment with. | Confirms the runtime-memory shortlist and switching goal. Authorizes the decision note. Final provider selection, implementation, and phone verification remain open. See [runtime memory options](../decisions/runtime-memory-options.md). |
| C08 | On 2026-11-07, owner requests whisper.cpp, WhisperKit, and AVAudioRecorder added to the documentation after discussing local Swift recording and Arabic/English transcription of new and imported audio. | Authorizes recording these candidates and their roles. Final models, engine selection, imported formats, and device performance remain open. See [audio options](../decisions/audio-recording-and-transcription.md). |
| C09 | On 2026-11-07, owner answers the remaining-decision list: app demo then feature-by-feature growth; Swift or Objective-C undecided; compare local models; consider an Obsidian vault or future app-owned storage; refine memory rules over time; request Telegram/Instagram/WhatsApp imports; ChatGPT first; birthdays first; supplied/imported/generated person images and questions about people. | Confirms direction and priorities while preserving undecided technical choices. See [demo and feature direction](../decisions/demo-and-feature-direction.md). Does not approve a final stack, unrestricted data transfers, automatic birthday actions, or implementation in this documentation task. |
| C10 | Later on 2026-11-07, owner accepts the Swift-with-SwiftUI recommendation. | Selects the iPhone app language and interface framework. Supersedes C09's undecided stack status and earlier assistant-only recommendations. No database/model choice, measured efficiency result, or implementation start follows. |
| C11 | After C10 on 2026-11-07, owner chooses a clickable interface with sample data as the first demo. | Resolves the demo-type question. Exact screens, interactions, and review criteria remain open. This scope answer does not authorize implementing live AI, imports, connections, storage, or the demo in this documentation task. |
| C12 | After C11 on 2026-11-07, owner chooses to include BrainMap when asked whether it should join Capture, People/person details, Projects, and Birthdays in the clickable demo. | Confirms BrainMap in the first sample-data demo's screen set. Does not select a production graph, working relationship extraction, final layouts, or implementation start in this documentation task. |
| C13 | On 2026-11-12, owner asks to start with finishing screen layouts: define how People, Projects, Birthdays, and BrainMap should look and behave. | Authorizes a layout and interaction specification and reviewable design study for these four sections. The resulting [proposal](../design/screen-layouts.md) does not record approval of its design choices or delivery of a native app. |
| C14 | On 2026-11-12, the owner rejects the C13 layouts and asks for deep online design-reference research, distinct variants using design skills, and one localhost app with annotations to highlight likes and dislikes. | Authorizes a local reference and design-review tool. The [reference-led lab](../design/reference-lab.md) replaces the rejected first proposal as current exploration. No new variant has approval; this request does not authorize publication or native delivery. |
| C15 | On 2026-11-12, the owner rejects all five reference-led variants, requests something simple, and directs the assistant to the already-decided home screen to understand the intended style. | The retained Capture/sidebar image now governs visual simplicity across the app. The [home-style proposal](../design/home-style.md) replaces the five-theme exploration. Preserve rejected history and local feedback. New other-screen layouts still need review. |
| C16 | On 2026-11-13, after installing Astryx, the owner says to use it to design the app. | Authorizes the separate [Astryx browser design prototype](../design/astryx-prototype.md), using the current Capture reference and fictional data. This does not replace SwiftUI as the native stack or authorize live AI, real recording, imports, provider connections, publication, or native release. The new screen layouts remain subject to owner review. |
| C17 | Later on 2026-11-13, the owner rejects the restrained Astryx result, asks to forget previous rules, and requests a complete wild redesign of the entire app. | Releases the prior visual constraints for this design task, including matching the old home image and using hidden-only navigation. Authorizes the [wild redesign](../design/wild-redesign.md): new compositions, color, typography, illustrations, navigation, and motion. This remains a design prototype, not a request to connect services or release a native app. The new result needs owner review. |
| C18 | The owner rejects the wild redesign during visual review. | Rejects that proposal. Its source and screenshots remain history; its direction is not approved. |
| C19 | When asked for an app or site that matches the desired visual style, the owner answers that they want Apple design. | Selects Apple as the positive visual reference. The [current proposal](../design/apple-inspired.md) interprets this as an iPhone app design language. This is a direction choice, not approval of the resulting screens or native delivery. |
| C20 | On 2026-11-13, the owner supplies Capture and sidebar screenshots, says to stick with them, and requests creating the SwiftUI project with navigation, fonts, shared controls, plus an iPhone connection check. | Authorizes this native foundation step and local build/device verification. The two screenshots are the active visual reference. Other screen layouts, live recording, AI, imports, production storage, publication, and release remain separate. See [native setup](../how-to/native-swiftui.md). |

Owner update C21, 2026-11-13: use dark mode for completed work. This is the standing preference for final previews, screenshots, and visual checks. The native app now defaults to dark mode. C20 remains the layout reference; its light palette is superseded for current delivery.

Owner update C22, 2026-11-13: the owner intends to sell the app in the future and asks which EU/other regulations, architecture, and maintenance practices to follow. The owner selects several markets with optional cloud AI/sync. Exact markets, business location, prices, providers, and launch date remain open. This goal does not authorize connecting or releasing services.

Owner update C23, 2026-11-13: after the commercial-readiness recommendations, the owner says to put them in the rules. This adopts the [commercial and engineering requirements](../how-to/commercial-engineering-rules.md) as standing project policy for later authorized work. It authorizes documentation and memory delivery. It does not select concrete dependencies or start production storage, cloud implementation, purchases, publication, deployment, or release.

Owner update C24, 2026-11-14: the owner requests a smaller workflow and proposes three steps: understand/plan/implement checklist items; verify architecture, behavior, tests, speed, and benchmarks; then review, push, and merge. After discussing a main agent plus a fresh verifier, architecture and test criteria in step 1, and explicit merge approval, the owner asks to organize the workflow. This adopts D28 and authorizes the [workflow guide](../how-to/development-workflow.md), [task template](../templates/development-task.md), project instruction links, and memory delivery. It does not start an app feature, establish a benchmark result, or authorize a specific push, merge, publication, or release.

Owner update C25, 2026-11-14: the owner requests separate repositories for memory and voice/transcription components, independent development, future component replacement, and maintainable upgrades that protect the app. The assistant initially recorded D29 as a proposal for custom engine repositories. C26 corrects that interpretation: the owner meant upstream libraries. No custom engine repository, provider integration, benchmark, publication, or release resulted from the earlier proposal.

Owner clarification C26, 2026-11-14: the owner asks to remove complexity and explains that the repositories they meant are libraries brought into the project, such as Wax. D30 supersedes D29's custom-engine repository plan. The [corrected decision](../decisions/independent-engine-packages.md) keeps one app repository with small interfaces/adapters, pinned upstream packages, separate upstream checkouts when needed, and controlled testing/adoption. This records the clarified architecture direction without selecting Wax or another production provider, creating a fork, or starting integration.

Owner adoption C27, 2026-11-14: after the [deep source-based architecture review](../research/2026-11-14-upstream-library-architecture.md), the owner asks to write the rules, follow them consistently, and ensure their implementation in step 2. D31 adopts the [mandatory architecture/adoption rules](../decisions/independent-engine-packages.md#mandatory-architecture-and-adoption-rules) and [step 2 checks](../how-to/development-workflow.md#mandatory-step-2-architecture-and-upstream-checks). Architecture and acceptance criteria still begin in step 1; step 2 must inspect implementation, require in-scope repairs, and verify evidence before passing. This authorizes the policy/documentation update and memory delivery. It does not select a provider, start a new app capability, establish tests/benchmarks, or authorize a specific merge/release.

The initial documentation session used 2026-11-06 as its working date. C07-C12 record later requests and owner direction on 2026-11-07 in conversation order. C10 selects the stack, C11 selects the demo type, and C12 confirms BrainMap inclusion. Individual earlier turn timestamps were not supplied, so none are invented.

Owner instruction C28, 2026-11-14: proceed to Step 1 of checklist group 2, the complete interface demo. The supplied scope includes Capture, hidden sidebar navigation, fictional People/details, sample Projects/plans/ideas, Birthdays/reminder choices, BrainMap connections/details, Arabic/English and mixed content, and iPhone launch/review. This authorizes planning, native sample-data implementation, and builder checks under the existing workflow. New screen layouts remain subject to owner visual review. Real recording, imports, AI, production persistence, scheduling, independent Step 2, push/merge, and release remain separate. See the [task record](../tasks/2026-11-14-complete-interface-demo.md).

Owner instruction C29, 2026-11-14: “step 2” continues the same complete-interface-demo task under the adopted three-step workflow. This authorizes independent verification, in-scope repairs, and affected rechecks. It does not start Step 3 or approve designs, merge, publication, or release. The [task record](../tasks/2026-11-14-complete-interface-demo.md) records the blocked verdict and evidence.

Owner instruction C30, 2026-11-14: “step 3” requests review and delivery for the current complete-interface-demo task. At that checkpoint, verification and separate concrete merge approval remained required. C33 later supersedes the separate routine merge-confirmation rule with standing Step 3 authorization; required verification remains.

Owner instruction C31, 2026-11-14: after learning that no remote exists, the owner asks to create a new private GitHub repository, connect it, and treat it as the original/main repository. The resulting canonical repository is [https://github.com/faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS), connected as `origin`, not an upstream-library fork. This authorizes private repository creation and project delivery; it does not approve a failed verification gate or an app release.

Owner instruction C32, 2026-11-14: the owner adds cleanup of dead code and unnecessary junk files to Step 2. Apply it to the current task before project delivery and to future Step 2 work. The [workflow](../how-to/development-workflow.md), task template, and AGENTS.md require consumer checks, protected evidence/source retention, measured cleanup, affected tests, and the existing verifier's focused recheck.

Owner instruction C33, 2026-11-14: the owner asks to allow subagents in Steps 1, 2, and 3 for better results and dependency work; requires Step 2 to clean dead code, useless files, and temporary outputs; requires Step 3 to merge after review/push; and requests screenshots of changes and additions at every step. D33 and the workflow/AGENTS/task template adopt this as a standing rule. It replaces the earlier fixed two-agent limit and separate routine merge confirmation. Required verification and any required product/design acceptance remain; the instruction does not claim that the current app's blocked checks passed or authorize an app release.

## What changed

1. The 2025 research focused on digital legacy and self-insight, with a cloud-oriented architecture and several possible audiences.
2. The current owner request focuses on a personal app for daily capture, people, projects, selected reminders, and conversation understanding.
3. The current device is an iPhone 15 Pro Max. On-phone processing is the preferred default.
4. Cloud AI, email, Obsidian, and later device sync remain optional integration goals. Their data flows and automatic behavior need selection.
5. The owner requested documentation and a separate development-memory bank while retaining the no-app-build boundary.

## Prior research links retained from the conversation

These links explain candidate components or integration questions. They are not selected dependencies. Provider rules and versions must be checked again when implementation begins.

- [llama.cpp iPhone example](https://github.com/ggml-org/llama.cpp/blob/master/examples/llama.swiftui/README.md)
- [WhisperKit / Argmax Swift components](https://github.com/argmaxinc/argmax-oss-swift)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [Qwen3-1.7B model card](https://huggingface.co/Qwen/Qwen3-1.7B)
- [Flutter native integration](https://docs.flutter.dev/platform-integration/platform-channels)
- [SQLite full-text search](https://www.sqlite.org/fts5.html)
- [Hindsight local deployment](https://github.com/vectorize-io/hindsight/blob/main/hindsight-docs/docs-integrations/local-mcp.md)
- [Khoj](https://github.com/khoj-ai/khoj)
- [Memvid](https://github.com/memvid/memvid)
- [Obsidian storage](https://help.obsidian.md/Files+and+folders/How+Obsidian+stores+data)
- [Apple continued background processing](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)
- [Gmail API](https://developers.google.com/workspace/gmail/api/guides)
- [ChatGPT and API billing](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform)
- [Claude API billing](https://support.claude.com/en/articles/8977456-how-do-i-pay-for-my-claude-api-usage)
- [Supabase self-hosting](https://supabase.com/docs/guides/self-hosting)
- [Convex self-hosting](https://docs.convex.dev/self-hosting)

The earlier research found useful components, not a verified ready-made iPhone-only product. Hindsight and Khoj were discussed as computer/server-oriented options. Memvid's native iPhone support was not established. A custom memory layer over existing components was the assistant's recommendation.

## Runtime memory research, 2026-11-07

- [Wax](https://github.com/christopherkarani/Wax): candidate embedded memory store and retrieval library.
- [Cactus](https://github.com/cactus-compute/cactus): candidate AI/retrieval components for a memory configuration. Current upstream points to [cactus-engine](https://pypi.org/project/cactus-engine/) for the earlier general SDK. Exact mobile version and APIs need verification.

These external sources support candidate descriptions, not MemoryOS test results. C07 records the owner's shortlist. The assistant's Wax-first recommendation and switching design remain proposals in the [decision note](../decisions/runtime-memory-options.md).

## Audio documentation, 2026-11-07

C08 records WhisperKit and whisper.cpp as local transcription candidates, and Apple's [AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) as a recording candidate. The [audio decision note](../decisions/audio-recording-and-transcription.md) links their official sources and explains multilingual model selection, imported voice notes, and proposed checks. These are documented options, not verified MemoryOS integrations.

## Memory source boundary

Hindsight indexes the new sanitized Markdown only. The original files are outside the allowlist. No raw session, private chat export, personal profile data, or recording is ingested by this task. Current Markdown remains authoritative over extracted memory.

## Local storage authorization, 2026-11-14

C35: the owner requests Step 1 of checklist group 3, “Add reliable local storage and text capture.” The six requested outcomes cover SQLite evaluation and original-record ownership, saved typed thoughts across app reopen, stable linked people/projects/ideas/captures, source-preserving corrections, deletion/export/backup/restore behavior, and operation without external services. This starts this local-storage implementation; Step 2, Step 3, AI, recording, remote sync and release remain separate. See the [task record](../tasks/2026-11-14-local-storage-text-capture.md) and [storage decision](../decisions/local-record-storage.md).

C36, 2026-11-14: the owner requests Step 2 for the active checklist group 3 local-storage task. This authorizes independent verification, in-scope repairs, required cleanup, affected checks and fresh evidence under the standing workflow. It does not start Step 3 or authorize release.

C37, 2026-11-14: the owner requests Step 3 for checklist group 3 local storage. This authorizes final review, scoped commit/push and private PR delivery, followed by merge only when required gates pass under C33. The request does not waive blocked physical-device/minimum-runtime checks, unresolved accessibility findings or required product/design acceptance.
