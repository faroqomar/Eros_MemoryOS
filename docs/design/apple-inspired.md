# Apple-inspired MemoryOS prototype

Owner sources: C18 rejects the wild result; C19 selects Apple design as the positive reference. Status: design proposal for owner review.

## Interpretation

The working reference is Apple's iPhone app design language. Use system typography, clear section hierarchy, grouped content, familiar navigation, and restrained color. Keep the content layer opaque. Use a subtle translucent navigation layer. This is an app design interpretation, not an Apple product, a native system component, or a claim of complete Human Interface Guidelines compliance.

Official references consulted:

- [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios): primary tasks, familiar interaction, and comfortable reach.
- [Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search): tabs for app sections and sidebars at wider sizes.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): separate functional navigation from content; use material effects sparingly.

## Screen direction

- Capture: a recording preview, an inline note field, and recent notes with their original context.
- People: searchable grouped rows with initials. Profiles show linked projects, birthdays, notes, and the optional existing question flow.
- Projects: simple folder tiles and related source notes.
- Birthdays: a compact calendar week, upcoming people, and the existing reminder preview.
- BrainMap: a quiet linked-record canvas, a map/list control, and readable selected-record details.
- Settings: light/dark appearance and English/Arabic preview choices.

Use system fonts available on the viewing device. No Apple font file or logo is distributed. Icons use the installed icon library; they are not presented as SF Symbols. The browser navigation material approximates a visual effect and does not implement native Liquid Glass.

## Prototype scope

The implementation remains in `astryx-prototype/` with Astryx Core and CLI 0.7.15. All people, source notes, dates, and map connections are fictional. Text, person answers, language, and appearance changes live in demo state and reset on reload. Recording and reminders are simulations. No real microphone, provider login, AI, imports, or notifications are added.

SwiftUI remains the selected native stack. Browser results do not verify native layout, VoiceOver, device performance, or production persistence.

The restrained and wild designs remain archived under `astryx-prototype/archives/`. The separate annotation lab and its feedback are unchanged.

## Run and review

From `astryx-prototype/`:

```sh
NEXT_TELEMETRY_DISABLED=1 npm run build
NEXT_TELEMETRY_DISABLED=1 npm start
```

The design runs on `http://localhost:5491`. The earlier official Astryx example on port 5490 is unrelated to the current prototype. Screenshots and new check results belong under `astryx-prototype/evidence/apple/`. Only reviewed project Markdown enters development memory.
