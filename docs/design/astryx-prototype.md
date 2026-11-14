# Astryx design prototype

Date: 2026-11-13. Owner source C16. Status: design proposal for owner review.

**Historical version, rejected under C17.** The owner later rejected this restrained design and released the earlier visual rules. Use the [wild redesign](wild-redesign.md) as the current proposal. The original source and evidence are retained under `astryx-prototype/archives/01-home-reference/`. Checks below describe this historical version.

The owner requested using Astryx to design MemoryOS. This task creates a separate clickable browser prototype under `astryx-prototype/`. Swift with SwiftUI remains the selected native stack. No native build or device result follows from this design.

## Visual authority

The [retained Capture/sidebar reference](../../designs/references/capture-sidebar-owner-reference-2026-11-07.png) and [home-style instructions](home-style.md) govern the design. Keep the central charcoal microphone, bottom composer, white surfaces, restrained system typography, and hidden sidebar. New layouts for other sections remain proposals.

The prototype uses Astryx Core, CLI, and Neutral 0.7.15. It extends the Neutral theme with the reference's monochrome colors and system fonts. The custom theme is compiled before the Next.js build. The browser does not need a remote font service.

Astryx's `blank` page template supplies the Layout and LayoutContent scaffold. Its `ai-chat-landing` template supplies a composer reference. The owner's home image overrides the template's suggested layout and extra content: the composer stays at the bottom and the recording control stays central. The scaffold copies remain under `astryx-prototype/templates/` for attribution. They are excluded from application compilation.

## Review flows

- Capture: type a thought, inspect its original text, try a labeled recording simulation, or select a fictional attachment.
- People: search fictional names, open a person, follow a linked project or source, and try an optional question.
- Projects: read sample context and tentative ideas. Open the original note or a linked person.
- Birthdays: open a sample birthday and switch a reminder preview on or off. The prototype schedules nothing.
- BrainMap: select a sample connection, open its record, or switch to a list.
- Language: switch between English and Arabic. The layout mirrors for Arabic.

The text, people, dates, and links are fictional. Capture and answer changes live only in browser state and reset on reload. The prototype does not request microphone access, import real files, connect services, infer relationships, run AI, or schedule notifications. A sample transcript does not represent a recording result.

## Run and build

From the project root:

```sh
cd astryx-prototype
npm ci
NEXT_TELEMETRY_DISABLED=1 npm run build
NEXT_TELEMETRY_DISABLED=1 npm start
```

Open `http://localhost:5491`. The server binds to loopback only. Use `npm run dev` for later authorized prototype edits. The earlier official Astryx example on port 5490 is separate.

The initial dependency setup reused an APFS clone of the already-installed example dependencies and the local npm cache. `package-lock.json` records this prototype's own dependency set. The prototype has no symlink to the example's dependency folder.

## Evidence boundary

Build output belongs under `astryx-prototype/.next/`. Screenshots and check results belong under `astryx-prototype/evidence/`. These artifacts are outside the development-memory source allowlist. Only this sanitized record and other reviewed project Markdown enter Hindsight.

Browser checks do not establish native layout, VoiceOver behavior, phone performance, real recording, AI quality, persistence, or notifications. The existing annotation lab and historical variants remain separate and unchanged.

## Verification, 2026-11-13

- The production build and TypeScript check pass. The build compiles the app-owned Astryx theme first.
- Fourteen browser flow groups pass. They cover capture, recording simulation, sample attachments, menu dismissal and focus, search, empty states, person questions, linked records, source access, Back navigation, birthdays, map/list views, language switching, and reset on reload.
- All five sections fit widths of 320, 390, 430, and 1280 CSS pixels in English and Arabic: 40 screen/width combinations, with no horizontal overflow failures.
- The final layout check confirms that Arabic map links mirror with their nodes and that the sidebar matches the preview's top and bottom edges.
- The checked browser flows report no console errors, page errors, or external requests.
- Astryx's build diagnostic reports 12 passing checks, no warnings, and no failures. Its source diagnostic reports no failures and one warning group for custom styles and SVG use. These are the token-based geometry and graph lines needed for the retained reference; the warning remains visible in the source report.
- The original reference hash remains `2e289d834aa721e65c58b7ac96be83f63ee072f5c0ce160fd90c8e9acf004c71`.

The detailed results are `astryx-prototype/evidence/verification.json`, `final-layout-verification.json`, `astryx-build-doctor.json`, and `astryx-doctor.json`. The final layout report records the production build ID. The English screenshots are also available in the self-contained `evidence/design-review.html` screen viewer.

Earlier cold browser checks on this Mac took about 16 to 30 seconds to become interactive. This session used an Intel Node.js installation under Rosetta. The cause of that host-side delay is not fully isolated. Startup performance remains open; these browser checks are not an iPhone benchmark. The static review viewer allows visual inspection without loading the app runtime.
