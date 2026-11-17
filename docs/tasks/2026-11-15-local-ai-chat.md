# Task: Connect local AI to chat, Steps 1 and 2

Status: November 17 phone chat crash traced to mixed GGML linkage and repaired below; owner confirms the installed update replies successfully on the iPhone. C49 generation/scrolling qualification remains open. Earlier chat PR #5 merged on November 15; that merge does not close qualification. The [current voice/chat task](2026-11-17-voice-chat.md) owns the new Step 3 draft and remaining merge gates.

Authority: C47 starts Step 1; C48 starts independent Step 2; C49 requests responsiveness fixes, withdraws extended VoiceOver testing from this task and requires compact evidence retention. No production model adoption, cloud fallback or release is authorized. Madar/Dakhl are unaffected.

Outcome: send to a prepared local model, continue saved conversations and ask about current app-owned records with visible sources. Saving a thought remains a separate Capture action.

## Scope and architecture

The existing experimental llama.cpp CPU adapter and reviewed Qwen3-0.6B Q4_K_M asset power chat. The model retains a 2048-token context and 256-token output cap. Its earlier Arabic/Iraqi quality failures still prevent production adoption.

Acceptance covers streaming and responsive editing/navigation; explicit context limits; multiline composer/keyboard; restrained motion; bottom following/manual reading/Latest; stop/retry/regenerate without duplicate turns; saved chat new/open/rename/delete; formatting/copy; current-memory sources; original-record protection; English/Arabic/Iraqi/mixed RTL; recovery; offline execution; replaceable MVVM interfaces; basic accessibility; measured performance and independent verification.

| Role | Actual implementation/boundary |
| --- | --- |
| Views | `native/MemoryOS/Features/Chat/`: render state, forward actions, own presentation-only focus/scroll/sheets |
| ViewModel | `native/LocalChat/Sources/ChatPresentation/ChatViewModel.swift`: feature state and injected use cases |
| Domain/use cases | `native/LocalChat/Sources/ChatCore/`: conversation/context/lifecycle rules; Foundation only |
| App-owned interfaces | `ChatModel`, `ChatRepository`, `ChatMemoryRetrieving` |
| Storage adapter | `native/LocalChat/Sources/ChatPersistence/`: versioned atomic local chat/draft files, separate from originals |
| Model adapter | `native/LocalTextEvaluation/`: pinned llama runtime and thin `LlamaChatModel` bridge |
| Composition/record adapter | `native/MemoryOS/Composition/`: concrete injection and current `LocalMemoryUseCases` snapshots |

Trace: `ChatView` → `ChatViewModel` → `ChatUseCases` → app-owned interfaces → adapters. Provider SDKs remain outside UI/domain. One app repository consumes the external reviewed upstream; no custom engine repository or fork was added.

Requests retain conversation context or show a limit instead of silently discarding turns. Memory requests read current active records, favor the current question and resolve referential follow-ups. Corrections replace evidence; Trash excludes it. Missing evidence prevents memory generation. Earlier AI interpretations are withheld from memory prompts with an explanation. The model cannot write original records.

Streaming preserves valid UTF-8 and coalesces updates. Chat archives, selected conversation and drafts survive relaunch; interrupted generations recover partial text. A forced kill within the 180 ms draft debounce can lose the latest unflushed keystrokes. Background handling flushes and joins/unloads generation; synchronous upstream load/decode may delay cancellation.

Skills: current installed catalogs were checked at implementation and independent-review stages. Project-local `.agents/skills/{swiftui-expert-skill,swiftui-ui-patterns,swift-concurrency,swift-testing-expert,swift-package-manager,swiftui-performance-audit,axiom-accessibility,axiom-security,ux-error-recovery,ux-loaders-and-progress,ux-heuristics-audit}/SKILL.md` cover the named concerns. `/Users/eros/.codex/skills/mattpocock-implement/SKILL.md` and `mattpocock-code-review/SKILL.md` guide implementation and independent review. C49 documentation cleanup applies current project rules and direct owner instructions; it adds no app scope. The scrolling follow-up reuses SwiftUI performance/expert, concurrency and testing skills for probe lifecycle, main-actor safety and deterministic regression coverage.

## Verification and repairs

Fresh architecture and behavior reviewers inspected actual source/action traces and independently executed host checks. The [consolidated verification summary](../evidence/chat-step2-2026-11-15/verification-summary.md) retains findings, fixes, test outcomes, dependency pins and evidence limits.

| Check | Prior verified checkpoint |
| --- | --- |
| Chat domain/persistence/ViewModel | 24 functions pass |
| Real native runtime | 19 contracts pass normally and under OS network denial |
| Main-app integration | 22 functions pass |
| UI conversations/recovery/scrolling | Nine scenarios across initial and affected reruns; initial ambiguous source Done selector was fixed |
| Compilation/static checks | Release arm64 Simulator build/analyze, strict formatting and diff checks pass; earlier unsigned iPhone build also passes |
| Basic accessibility | Largest-text keyboard/navigation, English/Arabic semantic audits, Reduce Motion and touch controls pass within simulator scope |

Repairs: storage retry clears only storage errors; history displays errors and stays open on failed navigation; stopped wording claims retention rather than a guaranteed disk save; tests assert the latest assistant answer and nonempty partial text. Earlier builder repairs fixed rename persistence, large-text layout, manual scrolling and current-topic retrieval. A gated interruption-during-save reproduction found no model call and retained the draft.

Extended VoiceOver diagnostics did not pass reliably. C49 removes them from this task's acceptance requirements; this is a scope change, not a passing test. VoiceOver is the screen reader, distinct from spoken-command Voice Control. Basic labels, Dynamic Type, contrast, Reduce Motion and usable controls remain required.

Prior source identity: base HEAD `7e4297e165f03f3caf57de41f7fbec30135fe912`; [56-file manifest](../evidence/chat-step2-2026-11-15/final-source-sha256.json), SHA-256 `d9a54b72739dc02aa92fcc96382826946b01832c30adfc956d71e4e7bbaf0fd3`. [Checkpoint receipt](../evidence/chat-step2-2026-11-15/final-checks.json). These results precede C49 performance edits and do not certify the final repaired source. The main agent must record the affected rerun and final source identity below.

## Performance targets and baseline

Release, `ENABLE_TESTABILITY=NO`, CPU/Accelerate llama.cpp, fictional prompt: `List exactly five ways to organize study notes. Use numbered lines.` One cold request followed by three warm requests in new chats with weights retained. No accessibility-tree polling during the four measured generations. First usable text measures ViewModel delivery, not the first rendered pixel. Sampled RSS may miss transient peaks.

| Metric | Target | Unprofiled baseline |
| --- | --- | --- |
| Cold verify/load and first text | ≤15 s | First usable text 1.235 s |
| Warm first text | ≤3 s | 0.631 / 0.364 / 0.241 s |
| Generation speed | ≥8 tokens/s | 55-token replies, 66.5–97.5 tokens/s |
| Warm cancellation | ≤1 s | 0.01295 s; 109 UTF-8 bytes retained |
| Sampled process RSS | ≤1.5 GiB | Maximum 1.300 GiB |
| Responsiveness | <100 ms | Timer lateness 191.1 / 113.9 / 67.7 / 47.9 ms; target not established |
| Scrolling/rendering | ≤16.7 ms frame budget | Display-link p95 16.67 / 19.69 / 16.67 / 16.67 ms; maximum 202 / 196 / 17 / 29 ms. Proxies do not establish raster frame budget |

Baseline [conditions](../evidence/chat-2026-11-15/simulator-benchmark-context.json), [model counters](../evidence/chat-2026-11-15/simulator-model-measurements.json), [UI counters](../evidence/chat-2026-11-15/simulator-ui-measurements.json) and [manual-scroll proxy](../evidence/chat-2026-11-15/simulator-scroll-cadence.json) remain available. The manual-scroll sample had a 441.5 ms maximum gap and 424.0 ms timer lateness; it is not discarded in favor of cleaner runs.

The [independent baseline performance review](../evidence/chat-step2-2026-11-15/performance-review.md) records a 91.952 s trace with 10 hangs, including 2439.62 ms during keyboard setup and 260.69 ms during generation. Sampled rich-text/selection work contributes to the generation interval; native inference runs on workers. Low main-thread coverage and XCTest snapshot overhead prevent attributing whole intervals to app CPU work. Profiled first usable text was 1.562 s, sampled RSS 1.233 GiB, maximum timer lateness 335.29 ms and display-link gap 401.37 ms. Raw baseline trace: `native/verification/chat-step2/memoryos-chat-step2-time-profiler.trace`.

C49 repair: value-only equatable reply/block views avoid reparsing unchanged blocks. The same subtree survives completion. Removing per-block text selection avoids its layout/bookkeeping path; the explicit Copy control remains. Manual Copy matched the saved 563-byte reply. [Compact result](../evidence/chat-step2-2026-11-15/c49-render-result.json) records the one changed source hash against the prior 56-file manifest.

Matched four-request check: maximum timer lateness fell from **149.84 ms to 45.78 ms**. Final cold/warm samples were 45.78 / 34.94 / 37.93 / 40.65 ms, with display-link p95 16.67 ms in all four. First usable text was 1.075 s cold and 0.159 / 0.137 / 0.146 s warm. These are generation proxies, not input-to-pixel or raster timings. A rejected intermediate candidate still had a 263 ms cold delay and was replaced.

Affected rerun: **22 app functions and six UI scenarios pass** on final renderer source: English follow-up/draft relaunch, stop/retry, Arabic semantic audit, large text, manual reading/Latest/reopen and scroll metric. Fresh verifier rechecked source/evidence and repaired the guard's missing-path false success. Completed-reply large-text and final dark capture are checked at handback.

The retained 47.837 s Time Profiler trace covers scrolling and generation through completion. No detected hangs occur in those action windows; four elsewhere coincide with automation snapshots. During scrolling, XCTest accounts for 4.96 of 5.28 sampled main-thread seconds. Earlier scroll probes still show 294/136 ms timer delays and 148/16.67 ms p95 cadence. That checkpoint did not establish clean scrolling responsiveness or the actual 16.7 ms frame budget. Do not treat absence of detected hangs as proof of a 100 ms bound. The follow-up below replaces the repeated-swipe measurement method.

### Simulator scrolling follow-up

Owner requests Simulator-only work for now and cannot operate the Device panel. The agent completed the gestures. Three continuous 6-second pans replace repeated swipe commands; the active scrolling windows total 17.25 seconds. Final Release results: maximum timer lateness **57.35 / 6.02 / 4.67 ms**, p95 display cadence **16.67 ms** in all three, maximum gaps **88.32 / 16.67 / 16.67 ms**. These pass the scrolling timer proxy; the first maximum gap prevents an every-frame claim.

A real probe bug truncated overlapping generation/scroll windows. The repair tracks both activities, closes only when both end, retains generation metrics, ignores duplicate completion, and marks background interruption. Six deterministic lifecycle tests cover the repair. The original overlap tests failed before the fix. Final **28 app functions + three UI scenarios pass**, as do standalone Release build/analyze, strict formatting and diff checks. The fresh verifier inspected source and test results.

Cold Retry followed by scrolling produced one complete 8.293-second window with 365 scrolling frames, first usable text 1.609 seconds, maximum timer delay **196.25 ms**, and maximum display gap **221.27 ms**. Keep this failed combined proxy. A separate profiled retry recorded 234.52 ms timer delay and 271.18 ms maximum gap. Its measured window contains 561 ms of sampled accessibility snapshot work within 1.65 seconds of main-thread samples. This explains why that profiled run cannot isolate app latency; it does not retroactively explain the unprofiled cold spike. Actual raster/input-to-pixel timing remains unverified.

The [existing compact result](../evidence/chat-step2-2026-11-15/c49-render-result.json) includes final source/executable hashes, individual samples, test bundle and trace paths. The selected continuous-pan method trace has no XCTest/automation symbols in its 5.6-second inspected window; that trace predates the probe repair and proves only the method diagnosis. Final dark [scroll/Latest capture](../evidence/chat-step2-2026-11-15/c49-scroll-final.png) shows the installed repaired build and the explicit output-limit message.

## Selected dark captures

All captures below are actual prior-checkpoint app states with fictional data: iPhone 18 Pro Max, iOS 27.2, arm64 **Simulator**. They are not new C49 performance evidence. C49 final-source captures: [completed reply](../evidence/chat-step2-2026-11-15/c49-chat.png) and [completed reply at maximum text](../evidence/chat-step2-2026-11-15/c49-large-text.png).

| State | Evidence |
| --- | --- |
| English / Arabic | [English](../evidence/chat-step2-2026-11-15/english-chat.png), [Arabic](../evidence/chat-step2-2026-11-15/arabic-chat.png) |
| Iraqi/mixed names | [Ali / Project Atlas](../evidence/chat-2026-11-15/arabic-iraqi-chat.png); this success does not reverse broader model-quality failures |
| Large text / keyboard | [Largest text](../evidence/chat-step2-2026-11-15/large-text-keyboard.png) |
| Current-memory evidence | [Corrected source](../evidence/chat-step2-2026-11-15/corrected-source.png), [missing evidence](../evidence/chat-step2-2026-11-15/missing-evidence.png) |
| Stop/retry / manual reading | [Retry](../evidence/chat-step2-2026-11-15/retry.png), [older messages](../evidence/chat-step2-2026-11-15/independent-reading-older.png) |
| Missing model | [Local recovery](../evidence/chat-2026-11-15/missing-model.png), [retry receipt](../evidence/chat-2026-11-15/missing-model-recovery.json) |
| Reduce Motion | [Enabled setting](../evidence/chat-2026-11-15/reduce-motion-setting.png), [generation recording](../evidence/chat-2026-11-15/reduce-motion-generation.mp4) |

Home/reopen retained two messages and 141 UTF-8 bytes as stopped partial output; [receipt](../evidence/chat-2026-11-15/background-recovery.json). Missing-model retry kept the assistant ID and message count after the reviewed model was restored. No cloud fallback exists.

## Remaining checks and delivery

- Generation and standalone scrolling timer proxies pass their recorded samples after C49 repairs. Combined generation/scrolling exceeds 100 ms; actual raster-frame and input-to-pixel qualification remain open.
- Owner connected the phone on November 17 and authorized diagnosis. iPhone performance, sustained heat/energy/memory, OS pressure recovery and protected-file behavior remain unverified.
- Minimum supported iOS 18 execution remains unavailable; this host exposes iOS 27.2 simulators.
- Full-app disconnected execution remains unverified. Host runtime OS network-denial tests pass; Simulator status-bar radio toggles are not network isolation.
- Owner product/design acceptance and final simulator testing remain open. Step 3 draft delivery is in progress; no merge or release is claimed.

Cleanup: C49 replaces repeated logs/call trees, copied diagnostic sources and per-file preservation inventories with one compact review and selected captures. Obsolete VoiceOver retry bundles are removed. Active baseline trace and passing result bundles remain under ignored `native/verification/chat-step2/`. Original research, source/reference assets, user app records, reviewed models, unrelated work and Git metadata are preserved. [Before/after totals and exceptions](../evidence/chat-step2-2026-11-15/cleanup-summary.json). The [retention rule](../how-to/development-workflow.md#evidence-retention) and `scripts/check-evidence.py` prevent future oversized evidence additions.

Build/run lesson: use arm64 for the reviewed binary; finish with a standalone Release build using `ENABLE_TESTABILITY=NO`, install it, then open it. Wait for dependent actions and refresh UI references after transitions.

Memory delivery: current Markdown governs. Run project `./scripts/memory sync` then `check` after final C49 edits; claim delivery only with no pending/failed operations. Do not index raw logs or app records.

## Step 3 delivery

C53 requires documentation cleanup in every Step 3. The rule, workflow and template were updated before delivery work. Catalog selection: `/Users/eros/.codex/skills/{mattpocock-code-review,mattpocock-pr,mattpocock-writing-for-agents}/SKILL.md` cover standards/spec review, PR evidence and concise standing rules. No app source changed in this stage.

Independent standards and spec reviewers confirm **57 source files match** the baseline manifest plus C49 overlays, with no new source finding. Reuse the corresponding core/runtime/app/UI checks and Release build/analysis; the required full qualification remains blocked by the limitations above. Repository inspection found no branch protection, rulesets or hosted workflow; that does not waive project gates.

C53 cleanup removes 14 redundant logs/exports/captures and consolidates superseded advice; [totals and retained exceptions](../evidence/chat-step2-2026-11-15/cleanup-summary.json). Links and evidence guard are checked before commit. The documentation preview shows the new standing rule and delivery status. PNG capture is blocked while the host downloads its browser; this is not a new app or phone benchmark.

Historical November 15 delivery: branch `feat/local-ai-chat`, base `7e4297e165f03f3caf57de41f7fbec30135fe912`; [draft PR #5](https://github.com/faroqomar/Eros_MemoryOS/pull/5), source commit `20070f8`. Merge blocked. Unrelated personal-context/roadmap documentation remains local. Memory sync/check reported pending documentation with zero failed operations; delivery is not yet confirmed.

## November 17 physical-phone chat crash

Owner imported the reviewed model and repeatedly observed process termination on Send. Two iPhone 15 Pro Max reports (iOS 27.0.1) show SIGABRT in `ggml_backend_buffer_name` during `llama_model_load_from_file`. Their executable UUID matches the installed pre-fix build. Its static llama code imports 47 GGML/GGUF symbols from the older Whisper dylib; incompatible buffer layouts cause the abort. Earlier tests ran the engines separately and missed their interaction.

Repair: `scripts/prepare-llama-evaluation.py` wraps the same pinned CPU/Accelerate archives in a dynamic framework exporting only `llama_*`. GGML/GGUF/C++ internals stay private. No model, upstream pin, UI, domain or storage changes. Package README files correct the earlier claim that Whisper's two-level namespace alone isolated static llama.

Regression: the original combined host loader aborts with the same native path. `scripts/check-inference-coexistence.py` now runs actual Qwen generation and Whisper transcription in both initialization orders; both pass sequentially (concurrent engine use is not tested). `scripts/check-inference-linkage.py` rejects the original app and passes the rebuilt signed phone app. All 19 real-model native chat contracts pass. Signed iPhone and arm64 Simulator Release builds pass, including embedded-library checks. Physical install completed without uninstalling the app; the owner confirms Chat now replies successfully. This is owner-reported behavior, not an automated phone benchmark. New phone capture remains unavailable because T3 does not expose this phone. Accessibility remains deferred per owner; no accessibility pass is claimed.

Skills: `/Users/eros/.codex/skills/mattpocock-diagnosing-bugs/SKILL.md` guides reproduction and cause validation; project `.agents/skills/{swift-package-manager,swift-concurrency,swift-testing-expert}/SKILL.md` guide binary packaging, worker-path inspection and runtime regression. A fresh reviewer independently confirmed the diagnosis and final three slices, both app linkages and strict phone signing; no blocking findings. Compact final checks and source identity: [repair receipt](../evidence/chat-step2-2026-11-15/iphone-linkage-repair.json). Cleanup removes two superseded reproducer files (4,374,293 bytes); diagnostics fall from 7,850,482 to 3,476,189 bytes. November 17 retention correction: that diagnostic folder was untracked, not ignored. After owner confirmation, all 11 resolved diagnostic files (3,476,508 bytes) were deleted; the compact receipt remains. No phone conversation archive was copied into the repository.

## November 17 Capture interaction repair

Home Send now uses the shared chat ViewModel and displays the active conversation within Capture without selecting another sidebar section. Save as memory is a separate explicit action. The microphone starts recording on Capture; pause/resume/save and failure recovery stay there. The plus button opens the library/import tools. Existing phone history and model files are preserved.

Independent review found and closed pending-permission navigation and cold-load input issues. The same SwiftUI/navigation/concurrency/testing skills guide the repair; no provider or domain boundary changes. Owner video/chat content is excluded from evidence. Temporary diagnostics stay outside the repository; resolved crash logs were removed as recorded above. Home Send, explicit memory save/relaunch and library opening pass UI checks; the first Send assertion needed fresh-conversation setup because it appended to a restored draft. Independent review has no remaining source finding. Signed phone Release build, signature and inference-linkage checks pass; the update is installed. Final workflow rerun passes all 10 tests, including leaving Capture during pending permission; eight capture-use-case tests also passed. Direct microphone denial stays inline on Capture without opening the library. A dark iPhone 18 Pro Max / iOS 27.2 Simulator capture is kept outside the repository at `/tmp/memoryos-flow-review/capture-permission.png`; no owner content is present. Physical operation of the revised flow still needs owner verification.

## November 17 fresh Home chats and conversation layout

Owner clarification: each conversation started from Home is separate; follow-ups remain together. Explicit history selection resumes an older conversation. The supplied ChatGPT screenshots guide layout only; no reference chat text or personal images enter the repository. Scope includes a compact header, trailing user bubbles, unboxed replies, a filled composer and searchable sidebar history. MemoryOS branding, direct Home recording, explicit Save as memory and local archives remain.

Architecture: Capture binds a separate persisted Home draft in ChatViewModel. ChatUseCases atomically transfers that draft into a new/reusable untouched conversation; failed saves retain the input. Optional archive data preserves older-file decoding. View state controls Home reset and panels; domain/repository boundaries remain unchanged. History sorts by latest message and retains renamed empty chats. Selected skills: project `swiftui-expert-skill`, `ux-navigation`, `swift-concurrency`, and `swift-testing-expert` for native layout, history navigation, asynchronous selection and draft recovery. Accessibility work remains deferred by owner.

Acceptance: two Home submissions create separate conversations; follow-ups and reopened history retain their own messages; both drafts survive relaunch; failed saves preserve input; repeated New Chat avoids blank history spam. Validate these contracts, the connected Simulator flow and dark rendered states. Preserve existing performance limitations; this layout change does not establish a new device benchmark or release pass. All 34 package tests pass, including backward decoding, failed-save recovery and persisted independent drafts; a fresh reviewer independently reran them and found no remaining blocking source issue. The connected Home A/follow-up/Home B/history flow and conversation-draft relaunch pass on the iPhone 18 Pro Max / iOS 27.2 Simulator. Four distinct UI scenarios pass: fresh Home/history, reply/draft relaunch, history rename/reopen/delete, and corrected/trashed memory sources. The fresh-Home scenario passed again after final recovery-control repairs. Dark conversation/sidebar captures use fictional data and remain outside the repository at `/tmp/memoryos-chat-layout-{conversation,history}.png`; they show the Simulator test build, not the physical phone. Signed phone Release compilation, signature and inference-linkage checks pass; the update is installed without uninstalling. Physical interaction still needs owner verification because T3 cannot control the phone.

Source identity: base `9c11150cdb013976cef59b02d3a110b758374776`; sorted path/NUL/content/NUL SHA-256 for the 11 changed app/domain/presentation files is `8378fb987bc1ab1b440fb7c5698da007c73b30c05b73148ecc24ef75a3607595`. Strict Swift formatting and diff checks pass. Personal reference screenshots and chat content were not copied into project evidence. No commit, push or merge occurs in this follow-up.

Arabic empty-chat controls render in RTL; visual capture: `/tmp/memoryos-chat-layout-arabic.png`. These checks do not qualify Arabic model accuracy. Cleanup removed 6 resolved logs/superseded captures (1,882,479 bytes); current selected screenshots and test result bundles remain.

November 17 delivery refresh: GitHub confirms PR #5 merged as `86cf5f57b1684f9da2ef302a21c039bdc68e6c93`. Earlier draft status above describes its original handback. The current voice/chat record carries later owner functional acceptance, final source/tests and Step 3 qualification limits. No merge or release of the new voice changes follows from that earlier merge.
