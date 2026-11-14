# SwiftUI foundation verification

Date: 2026-11-13. Owner source: C20. Scope: native foundation and iPhone readiness.

## Delivered source

The native project is `native/MemoryOS.xcodeproj`, with the shared MemoryOS scheme. It contains the SwiftUI entry point, shared typography/colors/controls, Capture, the overlay sidebar, seven section routes, Settings language selection, and temporary text memories. The remaining feature sections have placeholders.

The app follows the two [retained owner screenshots](../design/visual-reference-index.md). The implementation uses system fonts, iOS 18.0 as its minimum, Swift 6, and no third-party packages. Microphone and attachment actions display explanatory demo notices. They request no permissions and perform no capture or import.

## Environment and device readiness

- Xcode 27.2, build 27B52. iOS and iOS Simulator SDK 27.2.
- Verified destination: local iPhone 18 Pro Max simulator, iOS 27.2, identifier `8843F67E-B2AF-4605-A3AE-25D168BD1B28`.
- T3 `device_list` and `xcrun devicectl list devices` reported no physical iPhone.
- The signing identity check returned `0 valid identities found`. This does not prove whether Xcode has an Apple Account configured. The app's development team remains unset.
- The owner's physical iPhone 15 Pro Max connection, iOS version, trust, Developer Mode, and installation remain unverified. Follow [the physical-device steps](../how-to/native-swiftui.md#physical-iphone-readiness).

## Build and interaction checks

Evidence: [initial build log](../evidence/native-foundation-2026-11-13/build.log), [initial failure log](../evidence/native-foundation-2026-11-13/tests-initial-failure.log), and [final source hashes](../evidence/native-foundation-2026-11-13/source-hashes.json). The source hashes identify the project and Swift files for this verification. Logs and images stay outside the Hindsight Markdown allowlist.

The initial unsigned simulator build passed. It emitted the expected App Intents metadata warning because this app does not use App Intents. Xcode's test environment also printed debugger-version and simulator accessibility-loader notices. Those notices did not prevent the successful capture and recording checks.

The UI tests cover seven sidebar destinations, close/reopen behavior, disabled blank submission, typing a fictional thought through the keyboard, opening its temporary memory, process restart clearing that memory, and the recording-scope notice.

The initial test run passed temporary capture/reset and the recording notice. Its final menu-reopen check failed. The drawer now stays off screen when closed, disables its hit testing, and dismisses the composer keyboard when opened. A follow-up assertion that the drawer did not exist also failed: XCTest retains off-screen elements. The final assertion checks that the close control cannot receive taps, that the main menu can receive taps, and that the selected destination title appears. It waits for the visible state rather than testing removal from the view tree.

Pre-RTL-fix automated result: **3 tests passed, 0 failures**. Xcode reports `TEST SUCCEEDED`. The tests ran for 81.626 seconds; the complete test operation took 108.216 seconds, including setup. This result bundle remains at `native/.build/FoundationFinal.xcresult`.

The subsequent Arabic visual check found a closed-drawer strip on the opposite edge. The implementation applied an extra RTL sign change to an offset that SwiftUI already mirrors. The correction uses one negative horizontal offset for both directions. A new UI regression check selects Arabic through Settings, returns to Capture, verifies the Arabic label, and checks that the closed Settings row's frame lies outside the screen. Retain [the pre-fix image](../evidence/native-foundation-2026-11-13/capture-ar-before-fix.png) as failure evidence.

**Final corrected build: 4 tests passed, 0 failures; `TEST SUCCEEDED`.** The tests ran for 96.144 seconds; the full operation took 115.799 seconds. Evidence: [final test log](../evidence/native-foundation-2026-11-13/tests-passed.log) and `native/.build/FoundationRTLFinal.xcresult`. This run includes the Arabic regression and the three original checks against the corrected source.

Manual simulator checks confirm Capture and sidebar composition, opening the menu, selecting BrainMap, and returning to Capture. Retained screenshots:

- [Capture, English](../evidence/native-foundation-2026-11-13/capture-en.png).
- [Sidebar, English](../evidence/native-foundation-2026-11-13/sidebar-en.png).
- [Capture, Arabic, after the drawer correction](../evidence/native-foundation-2026-11-13/capture-ar.png).
- [Sidebar, Arabic](../evidence/native-foundation-2026-11-13/sidebar-ar.png).

The manual language check confirms native Arabic labels and mirrored header/composer positions. The post-fix Arabic screenshot confirms that the closed drawer leaves no visible strip. The largest accessibility text size keeps Capture's main controls visible and makes the sidebar list scroll. At that size the sidebar brand wraps and the composer placeholder shortens. The simulator text-size setting was restored to its original `large` value. Retained [Capture](../evidence/native-foundation-2026-11-13/capture-large-text.png) and [sidebar](../evidence/native-foundation-2026-11-13/sidebar-large-text.png) images document those limits.

VoiceOver focus order, Reduce Motion behavior, physical-phone keyboard/safe areas, and older iOS versions still require dedicated checks. The source includes accessibility labels, minimum 44-point controls, Dynamic Type, focus requests, an escape action, and reduced-motion handling. These measures do not establish a full accessibility audit.

## Preserved boundaries

The three original `Project_Idea*.md` SHA-256 hashes still match the source register. The two new owner screenshots preserve the original attachment bytes. Earlier browser designs remain unchanged. This workspace has no Git repository, so this task creates no commit or branch.

The app has no production database, local model, transcription, real recording, file import, provider connection, notification, sync service, publication, or release. Successful simulator checks do not establish physical iPhone launch or owner acceptance of the native design. Keep S11 and the unimplemented demo features unchecked.

## Dark-mode follow-up, C21

The owner requested dark mode for completed work and final checks. The app now forces dark appearance. The shared palette uses a dark canvas/sidebar, light text, contrasting icons, and a charcoal microphone control. The simulator system appearance is also dark. The C20 screenshots still define layout; their light palette and earlier light verification images are historical.

The updated simulator build passed. Manual checks confirmed Capture and the sidebar in dark mode, including opening and closing the menu. Evidence: [build log](../evidence/native-dark-mode-2026-11-13/build.log), [Capture](../evidence/native-dark-mode-2026-11-13/capture-dark.png), and [sidebar](../evidence/native-dark-mode-2026-11-13/sidebar-dark.png). The four-test run above predates this color-only change; no new interaction behavior or tests were added. The app remains open on dark Capture in the Device panel.
