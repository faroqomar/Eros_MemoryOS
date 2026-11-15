# Native SwiftUI foundation

## Experimental local chat, C47, 2026-11-15

The main app now links the existing reviewed local runtime behind app-owned chat interfaces. Open Chat from the sidebar or Ask local AI in Capture. Capture's Save thought remains separate. The feature source supports multiline input, local conversation history, streaming, stop/retry/regenerate, current-memory evidence and copy. C48 Step 2 adds fresh architecture/behavior review, recovery repairs and stronger conversation assertions. Local Simulator checks, dark captures and cleanup pass. The [chat task](../tasks/2026-11-15-local-ai-chat.md) records source identity, measurements and the remaining performance/device/accessibility gates.

For model preparation, open Settings and choose Import local model. Select the existing reviewed `Qwen3-0.6B-Q4_K_M.gguf` file from Files. Its required SHA-256 is `ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a`. The app stages a coordinated copy, verifies its hash and keeps it under `Documents/ChatModels`. It does not download a model or send chat to a cloud service. Keep that file outside Git. Developers can reuse the already prepared evaluation asset instead of downloading a second copy. The app verifies it again before the first model load. The experimental model has known Arabic/Iraqi quality failures; source controls do not certify an answer.

The runtime XCFramework contains arm64 Simulator and iOS slices. Use `ARCHS=arm64` for generic build/test-compilation commands. Preserve the existing source/binary receipt and setup steps in the [runtime package](../../native/LocalTextEvaluation/README.md). The new app-owned [LocalChat package](../../native/LocalChat/README.md) describes archive limits, draft checkpoints, recovery and test commands. Chat archives are separate from original-record exports. Physical iPhone behavior and iOS 18 runtime compatibility remain unverified.

The remaining foundation/storage instructions retain dated context and their existing evidence boundaries.

Foundation date: 2026-11-13, C20. Current demo work: 2026-11-14, C28. The [complete interface demo task](../tasks/2026-11-14-complete-interface-demo.md) records the new source, checks, and remaining review stages. The foundation descriptions below are historical where the new task supersedes them.

Historical C28 additions include People/details, Projects with plans and tentative ideas, Birthdays/reminder choices, and a focused BrainMap with linked details and list presentation. Choose English or Arabic in Settings. People and Projects support name/topic search; clear search to recover from no results. The sidebar returns to each section's path and retained query. BrainMap retains its focus and presentation. That demo kept fictional records, temporary captures, and birthday choices in process memory; restarting reset changes. The local-storage task below supersedes temporary typed capture. Reminder choices schedule nothing. The project uses only Apple frameworks. Domain values compile without SwiftUI. `MemoryOSTests` uses Swift Testing; `MemoryOSUITests` retains XCTest UI automation.

## Current local storage

Checklist group 3, C35/C36, adds durable typed capture, manual people/projects/ideas, corrections with retained originals, stable links, reversible Trash and explicit Files JSON backup/restore. See the [storage task](../tasks/2026-11-14-local-storage-text-capture.md) and [storage decision](../decisions/local-record-storage.md). Source data lives in private Application Support SQLite. No recording, AI or cloud client enters this increment.

`LocalRecordsViewModel` coordinates injected core use cases. `native/LocalMemory` compiles independent MemoryCore and MemorySQLite targets. Composition owns the SQLite adapter, retryable session provider and bounded Files reader. The provider performs setup off the UI actor; Reload preserves the draft after initial failure. Views forward actions and render state.

Step 2 functional/storage tests, builds/analysis and dark Release simulator captures pass. Physical iPhone protection/performance, iOS 18 runtime and required accessibility findings remain blocked or unresolved. The device table below is historical foundation evidence; the current storage task records fresh discovery and no connected physical iPhone. The canonical app directory stays excluded from automatic OS backup. Manual archives contain readable data and need a trusted Files location.

## Historical foundation scope and reference

Use the supplied [Capture](../../designs/references/2026-11-13-native-foundation/capture.png) and [sidebar](../../designs/references/2026-11-13-native-foundation/sidebar.png) screenshots. The owner selected these references for this step. Acceptance of the native implementation remains separate.

The app includes a Capture screen, overlay sidebar, shared header and icon controls, and routes for Capture, BrainMap, Profiles, Projects, Memories, Birthdays, and Settings. Profiles is the reference's label for the planned People section. Other feature screens remain placeholders. Settings offers an English/Arabic interface preview. The selected language resets on process restart.

The composer adds temporary text to Memories. Closing the process clears it. Use fictional text during review. The microphone and attachment buttons explain that their functions come later. The app requests no microphone, file, photo, calendar, or notification permissions. It has no network client or production database.

## Historical foundation project structure

- `native/MemoryOS.xcodeproj`: native Xcode project and shared MemoryOS scheme. No project generator or third-party package is required.
- `native/MemoryOS/App`: entry point, selected section, language, draft, and temporary memories.
- `native/MemoryOS/DesignSystem`: colors, semantic system fonts, header, and icon control.
- `native/MemoryOS/Features`: Capture, sidebar, root navigation, and section placeholders.
- `native/MemoryOSUITests`: navigation, temporary capture/reset, and recording-boundary checks.

The implementation uses Swift 6 and an iOS 18.0 minimum. This minimum is a foundation setting, not evidence of the owner's current iOS version. The installed SDK is iOS 27.2. System typography provides native English/Arabic glyphs and Dynamic Type. Existing Geist files remain available for later review; this build does not bundle them. C21 makes dark mode the default for completed work and final checks. The app forces dark appearance and uses a dark canvas, a slightly lighter sidebar, light text, and contrasting controls. The supplied screenshots remain the layout reference; their light palette is historical.

Controls have at least 44-point targets and descriptive accessibility labels. The drawer hides the underlying screen from accessibility, supports an escape action, and requests focus changes. Reduced Motion disables its transition. Safe-area insets keep the composer above the home indicator and keyboard. These code measures do not establish a complete VoiceOver or accessibility audit.

## Build and run

Open `native/MemoryOS.xcodeproj`, choose the MemoryOS scheme, choose an available iPhone simulator, and run.

From the repository root:

```sh
xcodebuild -project native/MemoryOS.xcodeproj -scheme MemoryOS \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath native/.build CODE_SIGNING_ALLOWED=NO build

xcodebuild -project native/MemoryOS.xcodeproj -scheme MemoryOS \
  -destination 'platform=iOS Simulator,id=8843F67E-B2AF-4605-A3AE-25D168BD1B28' \
  -derivedDataPath native/.build CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO test
```

The device identifier above belongs to this machine's current simulator. Use `xcodebuild -project native/MemoryOS.xcodeproj -scheme MemoryOS -showdestinations` to identify another destination. In T3 Code, open devices with `device_list` and `device_open`. Use the returned `agent-device` command for launches, UI actions, and screenshots.

## Physical iPhone readiness

Observed on this machine:

| Check | Result |
| --- | --- |
| Xcode | 27.2, build 27B52 |
| iOS and simulator SDK | 27.2 |
| T3 iOS device | iPhone 18 Pro Max simulator, iOS 27.2, local host |
| Physical iPhone | None reported by T3 discovery or `xcrun devicectl list devices` |
| Code-signing identity | `security find-identity -v -p codesigning` reports zero valid identities |
| Owner's iPhone 15 Pro Max | Connection, iOS version, trust, Developer Mode, and installed-app behavior remain unverified |

To run on the owner's phone:

1. Connect the unlocked iPhone by USB and accept Trust This Computer if it appears. Select the phone in Xcode's device destination menu.
2. Enable Developer Mode under Settings > Privacy & Security when Xcode requests it. Complete the required restart and confirmation.
3. Add the owner's Apple Account in Xcode > Settings > Apple Accounts. In the MemoryOS target's Signing & Capabilities, choose the owner's team and keep automatic signing enabled. This project leaves the team unset. Xcode must create or obtain development signing assets.
4. Keep the bundle identifier unique if Xcode reports a conflict. Confirm that the phone runs iOS 18 or later, choose it as the run destination, and run MemoryOS.
5. Verify launch, reference layout, keyboard, sidebar, English/Arabic text, and accessibility on the physical phone. Record this separately from simulator evidence.

Apple documents [running on devices and simulators](https://developer.apple.com/documentation/xcode/building-and-running-an-app), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), and [automatic signing](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html). Do not copy signing secrets into project files or development memory.

## Historical foundation verification and limits

The initial simulator build passed. The build emitted Apple's metadata notice: `Metadata extraction skipped, no AppIntents.framework dependency found`. This project does not use App Intents.

See [the verification record](../verification/2026-11-13-swiftui-foundation.md) for final results and retained evidence. A build or simulator run does not complete physical iPhone launch, owner design acceptance, the other demo screens, production persistence, or performance evaluation. No release or publication occurred.
