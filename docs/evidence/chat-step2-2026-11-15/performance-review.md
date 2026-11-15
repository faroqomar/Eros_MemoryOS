# Independent Time Profiler review

Result: **Blocked for the responsiveness gate.** The trace narrows several sampled paths but does not establish one corrective app-code change, a sub-100 ms main-thread stall result, or the 16.7 ms scrolling budget. No source or device state changed during this review.

Evidence: 91.952 s Time Profiler recording of the Release MemoryOS app, PID 70387, iPhone 18 Pro Max / iOS 27.2 Simulator. The main agent associates this capture with navigation, cold keyboard/fill, real local generation near 49 s, then attempted scrolling. The recording starts at 2026-11-15 17:02:18.481 +03:00. The numeric findings below summarize the trace; generated exports were removed under C53. The raw trace now resides at `native/verification/chat-step2/memoryos-chat-step2-time-profiler.trace`. The main agent moved it after these exports; embedded original paths in raw reports remain provenance. This verifier rehashed all 2,106 files across the trace and two retained result bundles with zero mismatches; all matched. The main task owns final source identity.

## Observed paths

The trace contains 10 reported hangs, totaling 5,533.23 ms; the largest is 2,439.62 ms. These are instrument-reported intervals, not sums of sampled CPU time. The sample contains no SwiftUI update/cause graph, animation-hitch or system-call lane. Main-thread sampling cannot explain the unsampled portions as either app blocking or host scheduling delay.

| Trace interval | Evidence | Interpretation |
| --- | --- | --- |
| 5.631–6.439 s: 808.12 ms | 224 ms main samples; 27.7% running coverage. Scoped samples summarized here; detailed exports are reproducible from the retained trace. `ChatView.body` has a 2 ms inclusive sampled frame; framework AttributeGraph/Swift runtime work occupies other paths. | Navigation has an observed delay. No expensive app function or concrete fix follows from this window. |
| 22.195–24.635 s: 2,439.62 ms | 532 ms main samples; 21.8% coverage. The sampled path includes text-selection gesture → `UITextView.becomeFirstResponder` → keyboard input reload (167 ms inclusive), plus keyboard layout/setup. Scoped samples summarized here; detailed exports are reproducible from the retained trace. | This window supports cold keyboard/input work as a sampled contributor. It does not attribute the full 2.44 s to UIKit CPU, prove host contention, or identify app archive/model work on the main thread. |
| 49.108–49.368 s: 260.69 ms | 81 ms main samples; 31.2% coverage. About 60 ms sit under SwiftUI text-selection/layout → attributed-text resolution → `NSAttributedString` conversion; Swift protocol-conformance lookup accounts for 59 ms self samples. `ChatView.swift:91` auto-scroll appears at 1 ms inclusive. Scoped samples summarized here; detailed exports are reproducible from the retained trace. | Generation coincides with a measurable rich-text/layout delay. The sampled native model work remains on other threads. This trace does not show expensive app formatting, JSON persistence, or synchronous llama execution on the main thread. |
| 79.255–79.603 s: 348.06 ms | All 62 ms main samples descend through `XCTElementSnapshotRequest` and accessibility snapshot APIs; 60 ms enter `AXUIElementCopyParameterizedAttributeValue`. File-open paths below this traversal load localized bundle strings. Scoped samples summarized here; detailed exports are reproducible from the retained trace. | Automation/accessibility snapshot work contributes to this interval. It cannot be counted as a clean manual-scrolling benchmark. It also does not prove that every reported delay comes from tools. |

Other intervals at 25.397 s and 25.705 s also contain XCTest snapshot paths (29/66 ms and 31/69 ms main samples respectively). These are overlaps, not independent timing sums. The overall hottest native symbols include ggml computation on worker threads. Their total sample weights do not establish main-thread stalls or first-render latency.

## Current disposition

This is the baseline review, not the final renderer verdict. C49 subsequently repaired reply rendering and measurement lifecycle; see [current result](c49-render-result.json) and the [task record](../../tasks/2026-11-15-local-ai-chat.md). Baseline numeric failures and attribution limits remain above. The retained trace permits regeneration of diagnostic exports. Combined latency, actual raster timing and physical qualification remain open.

Earlier Step 1 diagnostic: a 7.982-second Time Profiler capture reported one 319.78 ms hang at 3.049 seconds, with 174 ms sampled main-thread work (54.5% coverage). No raster/SwiftUI lanes were available. It did not establish cause or a passing frame budget. C53 retains this outcome and removes the redundant generated export.
