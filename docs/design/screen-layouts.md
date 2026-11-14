# People, Projects, Birthdays, and BrainMap layouts

Date: 2026-11-12. Status: **rejected by the owner on 2026-11-12**. Owner source: C13 in the [source register](../reference/source-register.md).

The owner rejected this proposal and its interactive study in the next turn. Preserve both as design history. The new reference-led localhost lab replaces this proposal as the current exploration.

The owner asked to define how these four screens look and behave. This specification completes a first design proposal. It does not record visual approval, native implementation, or device verification. The [interactive layout study](../../designs/2026-11-12-screen-layouts/screen-layouts.html) demonstrates the main navigation and detail states with fictional data. It covers a subset of this specification, not a working app.

## Design basis

Use the retained [Capture/sidebar reference](visual-reference-index.md): white surfaces, charcoal actions, simple typography, generous space, and hidden navigation. The rejected People-card concepts do not guide this proposal. The older BrainMap image supplies map/detail inspiration only.

The selected demo includes Capture, People/person details, Projects, Birthdays, and BrainMap (D22-D23). This task defines the latter four and their links back to Capture. Preserve R05-R06, R09-R10, R15-R16, R18-R20, and R30-R32 in the [feature register](../feature-register.md). Search, filters, layout measurements, source sheets, and editing interactions below are proposed design details. They do not select a storage schema, AI system, or production policy.

## Shared screen structure

| Priority | Placement | Proposed content and behavior |
| --- | --- | --- |
| 1 | Top safe area | Menu button at the leading edge; screen title; one trailing action when needed. Detail pages replace Menu with Back. |
| 2 | Below title | Search within the current section. Use a visible label or accessible label; show a clear action while text exists. |
| 3 | Main content | One vertical scroll area. Rows use text hierarchy and thin separators. Avoid repeated containers around each fact. |
| 4 | Bottom safe area | A compact `Capture a thought` action opens Capture. Keep the full microphone and composer on Capture. Preserve the origin so Back returns to the same screen. |

- Propose a 20-point content inset, an 8-point spacing unit, 16-point gaps within sections, and 28-point gaps between sections. Treat these as starting values for native review.
- Use a 28-point semibold screen title, 20-point section headings, 17-point body text, and 15-point metadata at default text size. Allow system text scaling. Use system typography for the native proposal; local Geist files remain an optional later typography choice.
- Use white backgrounds, charcoal primary controls, gray metadata, and subtle separators. Support a matching dark appearance later. Do not communicate status through color alone.
- Keep action targets at least 44 × 44 points. Allow names and labels to wrap. Avoid fixed row heights when the owner increases text size.
- The sidebar contains Capture, People, Projects, Birthdays, and BrainMap. Use `People` consistently; the reference's `Profiles` label becomes People in this proposal. Keep settings at the bottom when that screen is in scope.
- Opening the sidebar adds a scrim and moves focus into the menu. Selecting a section closes it. Close, a scrim tap, or the platform dismiss action returns focus to Menu. Preserve each section's search, filter, and scroll position during the session.
- Return from a detail or source page to the exact origin. Opening a person from BrainMap must return to the selected map node, rather than the People root.
- The native demo shows a small `Sample data` label. Use `Preview only` beside simulated reminder actions. Keep technical explanations out of ordinary app content.

## People

### List

Top to bottom: title and Menu; `Search people`; `Recently discussed`; people rows; Capture action. Use rows rather than collectible or full-portrait cards.

Each row contains a 48-point circular supplied image or neutral initials, name, latest linked topic, source date, and disclosure indicator. Show image origin in person details, not on every list row. Avoid inferred personality labels and relationship scores.

Sort by latest linked discussion, newest first. Put people with no discussions after that group, ordered by display name. Search names and explicitly stored aliases in Arabic and English. Define locale-aware matching during implementation; the layout study demonstrates a small sample search only.

Tap the full row to open person details. An empty list says `People you add will appear here` and offers `Capture a thought`. A no-match result says `No matching people` with `Clear search`. Do not ask for Contacts access to populate this demo.

### Person details

1. Back and the person's name.
2. A compact identity block: 72-point image/initials, display name, optional known alias, and `Edit details`.
3. `About`: short source-linked facts. Show `Not added` for missing values. Mark an owner-confirmed fact and a suggestion with text labels.
4. `Birthday`: known day/month or `Not added`; tap to open the birthday detail sheet.
5. `Discussions`: dated capture excerpts, newest first. Tap to open a source sheet showing title, date, speaker when supplied, and original excerpt. Keep original language and distinguish a summary.
6. `Projects`: linked project names; tap to open project details.
7. `Learn about this person`: one optional question, an answer field, `Save answer`, and `Skip`. Start with `How do you know this person?` Use owner answers as answers; do not invent facts. Keep unanswered questions out of the About facts.

`Edit details` uses a sheet. Require a name; make alias and image optional. Offer `Save` and `Cancel`. Explain validation beside the field and preserve the draft after an error. Saving edits changes sample state only in the eventual demo. A later production design must define history and conflict handling.

Image actions distinguish supplied, imported, and generated origins. Show initials when no image exists. In the demo, show the origin labels and a placeholder; do not invoke photo access, imports, or generation. Do not show a generated portrait as a verified photograph.

## Projects

### List

Top to bottom: title and Menu; `Search projects`; `All / Active / Tentative` filter; project summaries; Capture action. Preserve the distinction between a current plan and a possible idea.

Each summary contains project name, text status, a short current-plan line, and last source date. Limit previews to two lines and open the full text in details. Use thin separators and a small folder symbol, without progress bars, invented deadlines, or completion percentages.

Sort by newest linked capture within the selected filter. Put projects without captures last, ordered by name. Search project names and captured topic text. Tap to open project details. An empty list offers Capture; a no-match result offers `Clear search and filters`.

### Project details

1. Back, project name, and text status.
2. `Current plan`: owner-stated plan and its source. If no agreement exists, say `No agreed plan yet`.
3. `Ideas to consider`: tentative statements with a `Tentative` label. Preserve words such as "might" and any source-relative date. Do not create a due date from "next week".
4. `People`: linked names that open person details.
5. `Recent captures`: dated excerpts with type and source access, newest first.
6. `Add thought`: open Capture with a visible project chip. The owner can remove it before saving. Keep other capture links open to later correction design.

For the Website proposal example, display `No agreed plan yet` and `Might prepare a proposal next week` under ideas. The older static prototype's plan/reminder labels do not establish an agreed commitment. This specification proposes no task manager or non-birthday scheduling.

## Birthdays

### Agenda

Use an agenda rather than a full calendar grid. Top to bottom: title and Menu; `Search birthdays`; `Upcoming`; month groups; `Dates to check`; Capture action.

Each known-date row contains a day/month marker, person name, optional supplied image/initials, and reminder state such as `Off` or `Preview set`. Sort known birthdays by the next occurrence. Group by occurrence month and year, including the next year when needed. Put today's birthdays first with a `Today` label. Keep missing or conflicting dates in `Dates to check`, outside the upcoming order.

Search by person name and stored alias. If no date exists, offer `Add a birthday` through a person picker; do not require a year of birth. For no matches, offer `Clear search`. Do not calculate or show age without a supplied year.

### Birthday detail sheet

Tap a row to show the person, day/month, optional birth year, source, and reminder preview. Offer `Edit birthday`, `Open person`, and `Close`.

- Date editing requires a valid month and day. Birth year stays optional. Use unambiguous month names in summaries. Show a conflict with both dated sources and ask the owner to choose; do not pick one silently.
- Reminder preview starts `Off`. Turning it on reveals a proposed offset picker (`On the day`, `1 day before`, `1 week before`) and a time field. Start with 09:00 as an editable sample value, not a selected production policy.
- `Preview reminder` shows the exact example occurrence, local time, and time-zone label. `Save preview` changes the sample preference; show `Preview saved. No reminder scheduled.` Cancellation preserves the previous preference.
- The study uses a fixed sample date of 12 November 2026 in Asia/Baghdad. Ali's 12 May birthday therefore previews 12 May 2027. State this sample clock in the study; never pass it off as a live countdown.
- For a 29 February birthday, preserve the date and ask for a non-leap-year choice before showing a reminder preview. Do not assume 28 February or 1 March.
- Unknown or conflicting dates block the preview, with `Choose a date first`. A later production decision must settle recurrence, travel/time-zone changes, leap-day handling, notification permissions, and calendar versus notification delivery.

The demo requests no notification/calendar access and schedules nothing. Keep actual scheduling, message sending, and gift suggestions outside this proposal.

## BrainMap

### Overview and selection

Top to bottom: title and Menu; `Find a person, project, or thought`; `Map / List` switch; relationship canvas or equivalent list; selected-item details; Capture action.

Start with a small sample neighborhood around `You`. Propose at most seven visible nodes for the first demo; this is a legibility limit for the sample, not a production graph limit. Use a circle for a person, rounded rectangle for a project, and a document-shaped marker for a capture. Show the type in text when selected.

- Tap a node to select it. Strengthen its outline, highlight direct links, and open a lower detail sheet. Keep the selected node visible above the sheet.
- The sheet shows name, type, linked records, and a short explanation of the connection. Show a source action for each relationship. `Open person`, `Open project`, or `Open thought` navigates to that record. Back restores node selection and map position.
- For the demo, `You` means the owner of a capture. It does not imply friendship strength, sentiment, or agreement. A line means the linked source mentions or connects the records. The source sheet explains which meaning applies.
- A solid line represents a sample stored link. A dashed line represents a suggested link. Include this two-item legend and text status in details. A suggestion remains a suggestion; selection does not confirm it.
- Search highlights a matching node and offers an accessible result list. Choosing a result focuses its neighborhood. No match offers `Clear search`. Preserve the root when canceling.
- The native design permits pan and pinch zoom. Also provide labeled zoom and `Fit map` controls. Fit includes the active neighborhood and accounts for the sheet. A tap on empty space closes the sheet. Do not require dragging to select a record.
- Avoid moving nodes during reading. Reduced Motion uses immediate repositioning. A later layout engine must preserve a readable selection; no graph library or extraction mechanism follows from this design.

### Equivalent list

`List` shows the same nodes as named rows. Expanding a row reveals related record names, link status, and sources. Match search and selection between Map and List. This is the full alternative for VoiceOver, large text, and anyone who prefers rows. Every record and source available on the map must also be reachable here.

For an isolated record, show `No linked records yet` and `Open record`. For an empty map, show `Capture a thought to start connecting your information`. For a missing target, keep the relationship context and show `Record unavailable` rather than a blank destination.

## Shared states and language

| State | Layout and behavior |
| --- | --- |
| Loading | Keep title/navigation stable. Show short placeholder rows and `Loading…`; do not erase content already on screen during a refresh. The static study has no real loading work. |
| Empty | Explain what appears here and offer the relevant capture/date action. Do not fill the screen with example content once the owner has real data. |
| No search results | Preserve the query and offer Clear. Distinguish this from an empty collection. |
| Read error | Show an inline explanation and `Try again`. Keep available content and return navigation. |
| Invalid edit | Keep the sheet and entered values. Place an error beside the relevant field and announce it to assistive technology. |
| Missing source | Show `Source unavailable`; keep a known fact's label and provide Back. Do not invent a citation. |
| Interrupted edit | Retain the draft during the session; require a discard choice before losing entered changes. Persistent draft recovery remains future storage work. |
| Offline | Permit navigation over available local records. The sample-data demo has no network dependency. A later connection error must not trigger an external fallback. |

Arabic layout uses the same content order with a leading-edge menu on the right, mirrored directional arrows, and right-aligned labels. Keep each name and source in its original language. Use bidirectional isolation for mixed Arabic/English names, dates, and identifiers. Do not reverse photographs or reorder graph relationships to imply different meaning. Keep input and focused actions visible above the keyboard.

Native review must cover narrow widths, large text, VoiceOver labels and reading order, dark appearance, reduced motion, and safe areas. At large text sizes, stack date/action metadata below names and offer the BrainMap list. A browser layout study cannot verify these native behaviors.

## Review scenarios

These are acceptance criteria for later demo implementation and owner review, not executed test results.

- [ ] People: search Ali; open his profile; inspect a source; open his Website proposal; return to the original profile/list state.
- [ ] Person questions: skip without an answer; enter an answer; cancel an edit without changing saved sample values. Show a missing image as initials.
- [ ] Projects: switch Active/Tentative; open Website proposal; find tentative wording without an invented commitment or deadline; open a capture source.
- [ ] Birthdays: open Ali; change and cancel a preview; save a sample preview; verify `No reminder scheduled`. Show Sara with no date and a leap-day case that needs a choice.
- [ ] BrainMap: select Ali and Website proposal; inspect link status and its source; open a record and return; perform the same journey using List.
- [ ] Shared: show empty, no-match, loading, read-error, missing-source, and invalid-edit states without blocking Back or losing a draft.
- [ ] Language/access: inspect Arabic/mixed text, large text, keyboard, VoiceOver, touch targets, dark appearance, and reduced motion on the native demo.
- [ ] Owner review: record approval or requested revisions for each of the four layouts. Keep native build/device results separate.

## Delivery state

The written layout proposal and interactive study are ready for review. The study demonstrates section navigation, People/project details, a source sheet, birthday preview choices, and map/list selection. Full edit flows, graph pan/zoom, state preservation across all paths, the complete state matrix, Arabic localization, and native accessibility remain specified work. No application source changes or native checks belong to this delivery.
