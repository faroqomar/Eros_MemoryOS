# Native four-tab design and Brain marks

## Scope

On 2026-11-26 the owner requested implementation of the supplied dark mobile design and five Brain logo ideas selectable from Settings. The [source register](../reference/source-register.md#owner-selected-native-layout-2026-11-26) identifies the five attachments. MemoryOS uses its own typography, mint accent, tab treatment and original marks. The screenshots supplied layout direction. Personal content stays in the original attachments.

## Implementation

- **Record** keeps the microphone, existing audio import, text composer, save action and local chat. Conversations use a full-width timeline with distinct speaker labels. The chosen mark appears on the idle recording control and MemoryOS replies.
- **Brain** shows the focused item and its saved direct connections. The graph shows up to four distinct neighbors for readability. The full list, focus picker, detail links and memory search remain available. Larger accessibility text sizes use the full list.
- **Calendar** offers month and week views with date navigation and today's date. It displays complete saved birthday dates, including yearless birthdays, using the Gregorian calendar and the device time zone. Partial dates remain available through Saved Birthdays. The existing editor and detail reuse the same birthday use cases. Reminders still require explicit schedule approval.
- **Notes** offers original saved records, organized memory, People and Projects collections, and a memory search shortcut. People and Projects use the existing app-owned collections. Add information, undo, and organized-memory backup remain accessible.
- **Sidebar** gives access to Settings, saved chats and other existing features. The dock mirrors with the interface in Arabic and uses two columns at accessibility text sizes.
- **Brain marks** are Constellation, Ripple, Orbit, Branches and Aperture. Settings stores the choice on the device. It applies immediately to the Brain tab, sidebar, graph, idle Record control and assistant replies. Constellation is the default.
- **State** persists across tab switches during the app session. The selected Calendar range and day, Notes filter, Brain focus and inline Record conversation keep their current values. The existing explicit Home action resets the inline conversation and prevents an earlier asynchronous action from reopening it.

Views use the existing view models and session presentation state. The Calendar consumes injected birthday records. The graph uses saved connections. Brain-mark preference uses a single UI preference key. The implementation uses the existing packages, model configuration, storage schema and data paths.

## Skills

- `.agents/skills/mobile-ios-design/SKILL.md` and `.agents/skills/ux-navigation/SKILL.md` guided the tab, drawer and screen structure.
- `.agents/skills/swiftui-expert-skill/SKILL.md` guided SwiftUI composition and shared presentation state.
- `.agents/skills/axiom-accessibility/SKILL.md` guided tap regions, accessibility labels and traits, Dynamic Type and Arabic layout.
- `.agents/skills/swift-testing-expert/SKILL.md` guided use of XCTest for the new UI flows.

## Verification

Independent review traced the local data, date matching, navigation and shared mark preference. It identified lost tab state and an asynchronous Record reset race. Both fixes are in the current source. Swift format lint, Swift parsing for the updated copy, the whitespace check, and the Xcode 27.2 Release simulator test build passed.

The first Arabic drawer run found the Language control below the visible Settings area. The control now sits between Brain mark and Local AI and opens a menu. The Arabic drawer test passed on the rebuild.

A date lookup could miss saved birthdays. Calendar-generated `DateComponents` included a false leap-month flag. Stored month/day components had no flag. Foundation compared the keys as equal and returned different hashes. The index now uses an integer month and day. The Swift probe reproduced the mismatch and verified the replacement across 24 locale, time-zone and date combinations. The day actions now precede the birthday rows so people can reach them when the agenda grows.

An accessibility snapshot showed a node button's frame spanning the graph. Screen readers use the Focus and Direct connections lists for the same navigation. The visual graph supports touch. Larger accessibility text sizes use the lists.

All five selected XCTest UI cases passed on iPhone 18 Pro and 18 Pro Max simulators with iOS 27.2. The Calendar test passed twice with fresh launches. It saved a fictional birthday, found it on the selected day, and opened its detail without scheduling a reminder. The five-mark test verified every choice and persistence across a relaunch. The workspace test checked the four tabs and preserved the inline Record conversation, Calendar's week view, and Notes' saved-record selection. The existing English and Arabic sidebar routes passed. The test driver now waits for the named input and scrolls controls above the dock before tapping.

The final Release build passed a fresh workspace route test after the graph accessibility change. The focus picker opened and tapping a visible neighbor changed focus on the simulator.

The Notes screenshot shows the existing automatic-memory qualification notice. Saved records and manual organization are available in this build.

Removed seven superseded simulator test and capture folders. They held 227.1 MiB. The selected dark captures and the active build remain available.

## Dark-mode captures

The iPhone 18 Pro Max captures use fictional project fixtures on iOS 27.2. The working tree was based on commit `e5735fa`. Release simulator executable SHA-256 `1777fbdc1f058350a956043e60c681c40e63ec8df818e6ec69063e5ee12db515`. The populated Calendar capture uses the iPhone 18 Pro with iOS 27.2 and executable SHA-256 `7528bee6f9aacc9eb80ccafd665b39230d13fa295ef9c885e73790965f9a9b21`.

- [Record](../evidence/native-four-tab-design-2026-11-26/record.png)
- [Brain with Orbit selected](../evidence/native-four-tab-design-2026-11-26/brain.png)
- [Brain after choosing a connection](../evidence/native-four-tab-design-2026-11-26/focused.png)
- [Calendar](../evidence/native-four-tab-design-2026-11-26/calendar.png)
- [Calendar with saved birthdays](../evidence/native-four-tab-design-2026-11-26/calendar-birthdays.png)
- [Notes](../evidence/native-four-tab-design-2026-11-26/notes.png)
- [Sidebar](../evidence/native-four-tab-design-2026-11-26/sidebar.png)
- [Five Brain marks in Settings](../evidence/native-four-tab-design-2026-11-26/brain-mark-settings.png)

## Follow-up screen review

The owner requested another pass over every screen. We reviewed all 13 app destinations and their connected views. The goal was to make daily actions easier to find, give each screen a clear purpose, and preserve the saved records and permission rules behind the interface.

| Screen or flow | Finding | Change |
| --- | --- | --- |
| Record and Chat | Major, user control and visibility. Chat showed the Record title and crowded its controls into one row. | Give normal and temporary chat their own titles. Keep an explicit microphone exit. Compact the Record shortcuts and improve recording, composer, loading, and recovery feedback. |
| Saved chats, rename, and chat sources | Minor, recognition and recovery. Empty results, drafts, and source errors were easy to miss. | Clarify the search and recovery actions. Show draft previews, named row actions, and explicit source status. Keep rename and source details readable at larger sizes. |
| Recordings, import, recording details, and passage editor | Major, visibility and error prevention. Import guidance was weak and a long recording list buried transcription settings at the largest text size. | Explain supported imports. At accessibility sizes, put transcription settings before recordings. Improve playback and transcript controls and keep the editor open while saving a correction. |
| Brain and focus picker | Major, efficiency. The chart could precede its primary actions or fill the screen with a single node. | Place focus controls first. Show the chart for connected items at standard sizes. Make the empty state lead to Record. Keep the full connection list and focus picker. |
| Calendar, saved birthdays, date editor, and reminder review | Major, visibility and error prevention. Week navigation did not identify the week. An empty day could appear during loading. | Show the actual date range. Put the agenda above large-text date choices. Give loading, errors, and missing people their own actions. Keep saved-date correction and explicit schedule approval. |
| Notes, personal history, backup, and restore | Major, reachability. The Add and Undo bar competed with the dock. | Move both actions to a reachable row with 44-point targets. Explain People and Projects in the collection rows. Show original sources once they exist. |
| Saved records, record detail, edit, Trash, and linking | Major, recovery. Create was below records and the link picker could reach a dead end. | Put creation first. Add refresh and explain the state when all eligible records are already linked. Preserve corrections and the existing deletion flow. |
| People, Projects, profiles, memory detail, and information editor | Major, reachability. Long collections buried create and link actions. | Move common actions above lists. Give searches a recovery path. Keep the information editor's Save action reachable. |
| Search and source context | Major, recovery and consistency. A failed search could look like an empty one. The top-level route had two titles. | Distinguish loading, failure, and empty results. Retry the relevant action. Use one title at the root and dismiss the keyboard when the sidebar opens. |
| Understand, source picker, report, and evidence | Minor, efficiency. The source picker required scanning a long list. | Add source search and clearer status. Keep links to original evidence available. |
| Rules and views, editors, and rule test | Major, recognition and reachability. Create actions and the selected saved view were easy to miss. | Put create actions first and show the active view. Reflow actions at large text sizes. Keep preview and apply separate interactions. |
| Sidebar, dock, Settings, and model import | Major, consistency and reachability. Drawer search had no clear action. Labels competed at large sizes and the mark list pushed Language below the first screen. | Add clear search, selected states, and responsive labels. Put Language first. Use a mark grid with a large-text list. |

The review prioritized reachable primary actions, accurate recovery messages, and predictable navigation in English and Arabic. It applied `ux-heuristics-audit`, `ux-navigation`, `ux-empty-states`, `mobile-ios-design`, `swiftui-expert-skill`, `axiom-accessibility`, and `swift-testing-expert` from `.agents/skills/`. The independent source reviewer checked action targets, data and permission paths, keyboard handling, and test identifiers. Visible input prompts use stronger contrast.

### Follow-up verification

The Release simulator builds, strict Swift format lint, and whitespace check passed. The all-destination route test passed. A long recording list could bury Local transcription at the largest text size, so the app now places those settings before the list at accessibility sizes. XCTest reached those controls in English at both sizes and in Arabic at standard size. The largest Arabic run stopped in Settings because the Language menu did not open below the mark alternatives. The final build puts Language first. A live simulator check opened the menu at the largest text size, selected Arabic and reached recording, audio import, Local transcription and model-folder import.

The iPhone 18 Pro Max tests passed for the Arabic drawer, the sidebar search keyboard, week navigation and tab state, and all five marks including persistence across relaunch. The iPhone 18 Pro tests passed for an unscheduled saved birthday, applying and undoing a rule with a saved source and view, and correcting, linking, trashing and restoring a record across relaunch. Test helper updates account for populated lists and the record link picker’s combined name and type label. The source review covered connected sheets and details. The device checks exercised selected paths on simulators.

Removed 161.9 MiB from five superseded test and capture folders after matching the retained screenshots to their originals. Current verification artifacts and the build remain available.

### Follow-up dark-mode captures

The working tree is based on `e5735fa`. All captures use fictional data and iOS 27.2 simulators.

- iPhone 18 Pro Max, follow-up Release executable `8fd499c6dc5e575e36c7d3e113179e6f3251592f4a76472a272f613c7a75d69d`. [Record](../evidence/native-four-tab-design-2026-11-26/polish/record.png), [Brain](../evidence/native-four-tab-design-2026-11-26/polish/brain.png), [Calendar](../evidence/native-four-tab-design-2026-11-26/polish/calendar.png), [Notes](../evidence/native-four-tab-design-2026-11-26/polish/notes.png).
- iPhone 18 Pro, same executable. [Recordings](../evidence/native-four-tab-design-2026-11-26/polish/recordings.png), [Birthdays](../evidence/native-four-tab-design-2026-11-26/polish/birthdays.png), [Rules and views](../evidence/native-four-tab-design-2026-11-26/polish/rules.png).
- iPhone 18 Pro Max, refreshed Release executable `c6516aa1f848cf188e799b6570185c2d6a119d12b7d55ed9615c2f5f276e979e`. [Sidebar](../evidence/native-four-tab-design-2026-11-26/polish/sidebar.png), [People](../evidence/native-four-tab-design-2026-11-26/polish/people.png), [Projects](../evidence/native-four-tab-design-2026-11-26/polish/projects.png), [Search](../evidence/native-four-tab-design-2026-11-26/polish/search.png), [Understand](../evidence/native-four-tab-design-2026-11-26/polish/understand.png), [Chat](../evidence/native-four-tab-design-2026-11-26/polish/chat.png).
- iPhone 18 Pro Max, final Release executable `e6af1801eab222bb579b0a951bd440cbcf42f3e82f34e0bd9e0f9fb0b0f2990c`. [Settings and all five Brain marks](../evidence/native-four-tab-design-2026-11-26/polish/settings.png), [Language menu at the largest text size](../evidence/native-four-tab-design-2026-11-26/polish/largest-language.png).

## November 27 delivery

The owner requested a push and merge of the current workspace. PR #7 had already merged at `bb0b2be`. [PR #8](https://github.com/faroqomar/Eros_MemoryOS/pull/8) merged the four-tab app, groups 8–9, the codebase cleanup, and the design studies at `4c0ac02`. The [groups 8–9 verification](2026-11-18-understanding-organization.md#november-24-cross-thread-diagnosis-and-safety-repair) still records failed relationship and person resolution and a cold-history replay over the 300-second case deadline. Those qualification results remain open after the merge.

Delivery cleanup removed 0 files and 0 bytes. The retained exceptions are linked evidence, the requested portable ZIP, and original concept artwork. Ignored model assets, build products, and local diagnostics stay on the Mac. The captures above document the recorded Simulator builds.
