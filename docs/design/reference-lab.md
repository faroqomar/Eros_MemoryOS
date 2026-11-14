# Reference-led design and annotation lab

Date: 2026-11-12. Owner source C14. Status: **all five directions rejected under C15**. Preserve this research and its variants as history. The current [home-screen style proposal](home-style.md) follows the owner's instruction to use the already-decided Capture home as the visual anchor.

The owner rejected the earlier [four-screen proposal](screen-layouts.md) and its visual study. The owner requested deep online reference research, distinct variants made with design skills, and one localhost review app with like/dislike annotations. This authorizes the local design tool. It does not select a native app design, expand product features, or authorize publication.

## Research sources

These are visual and interaction references. Their services, AI behavior, integrations, and business models are not MemoryOS requirements. Descriptions below are design interpretations for this exploration. Source pages were checked on 2026-11-12. Some browser navigation calls timed out while the pages continued loading; available content and official image URLs were inspected afterward. Do not treat a blocked visual as visually reviewed.

| Reference | Source | Useful design pattern | Proposed application |
| --- | --- | --- | --- |
| Capacities | [Mobile documentation](https://docs.capacities.io/reference/mobile), [product facts](https://capacities.io/about/facts) | Typed objects; separate content/properties/graph views; related content below an object. Official mobile screenshots inspected. | People and projects as readable objects with explicit relationships. |
| Heptabase | [Product](https://heptabase.com/), [mobile whiteboards](https://wiki.heptabase.com/newsletters/2024-07-02) | Spatial whiteboards, cards, clusters, and visible connections. Primary written sources reviewed. Image retrieval failed after bounded retries; no unavailable image is presented as inspected. | A map-led Atlas direction, with a selected-record inspector. |
| Dex | [Product and mobile preview](https://getdex.com/), [guide](https://getdex.com/docs/get-started) | Person context, relationship history, and a compact personal agenda. Official desktop and mobile images inspected. | People-first Circles direction, without business pipeline stages or automatic contacts access. |
| Day One | [iOS journal views](https://dayoneapp.com/guides/day-one-ios/journal-views-in-day-one-for-ios/) | Chronological entries, date hierarchy, and alternate List/Calendar/Media/Map perspectives. Official journal image inspected. | Editorial Almanac direction with dated memory excerpts and birthday month rhythm. |
| Things | [Product](https://culturedcode.com/things/) | Clear grouping, calm hierarchy, and project reading. Official product collage inspected. | Focus direction with one dominant item and compact supporting lists. No task manager or non-birthday actions follow. |
| mymind | [Spaces](https://mymind.com/how-to-get-the-most-out-of-spaces) | Visual collections and returning to a saved context. Primary written source reviewed; the home-page preview timed out. | Cabinet direction with mixed-size memory objects. Do not claim a visual copy of an uninspected screen. |
| MindNode | [Product](https://www.mindnode.com/), [map/outline example](https://www.mindnode.com/blog/2026.7) | Spatial branches and an outline view of related information. Official article and map/outline image inspected. | Different graph organizations and a non-spatial list alternative. |
| Reflect | [Product direction](https://reflect.app/blog/reflect-open), [backlinks](https://reflect.app/blog/automatically-add-backlinks-using-ai) | Daily writing and moving through linked notes. Primary written source reviewed. | Focus and Almanac source-linked reading flows. No provider or AI behavior is selected. |

Official screenshots stay attributed to their respective products. They appear only in the lab's References section, apart from original MemoryOS proposals. The lab uses locally cached assets and fictional app data. It makes no runtime requests to these products.

## Five design directions

Each direction covers People, Projects, Birthdays, and BrainMap. Composition and interaction differ as well as typography and color. Shared sample content makes comparison possible.

| Direction | Composition | People | Projects | Birthdays | BrainMap |
| --- | --- | --- | --- | --- | --- |
| Atlas | Spatial workspace; ink-blue grid and floating contextual objects | Relationship constellation | Clustered project boards | Date islands | Connected clusters and inspector |
| Almanac | Warm editorial journal; large serif titles and dated passages | Stories grouped by recent discussion | Project chapters | Month-led calendar and dated notes | An annotated relationship outline |
| Circles | People-led, compact personal address book; warm coral identity | Featured person and grouped people | Projects grouped by participants | Person-first birthday feature | Owner-centered relationship rings |
| Cabinet | Object library; olive paper, index tabs, mixed-size objects | Index and person dossiers | Folder-like collections | Date index and birthday cards | A cross-reference board |
| Focus | Dark reading surface; large typography and one dominant item | One person in focus with a compact switcher | Current context and tentative ideas | One upcoming birthday with the rest below | Selected relation trail with nearby records |

These names and styles are proposals. A like, dislike, or note identifies the exact variant, screen, detail state, language, and marked region. It does not approve the whole design.

## Local review tool

Run `python3 design-lab/server.py --port 5488` from the project root. Open `http://127.0.0.1:5488`. The server binds to loopback. Keep the server running during owner review.

- Switch between the five directions and the four selected screens. Open sample records and sources.
- Use References to inspect attributed images and the pattern behind each direction.
- Choose Browse to interact, or Like/Dislike/Note to mark an area. Drag a rectangle or choose element selection for touch and keyboard use.
- Add an optional note and category. Save feedback, reopen it, edit it, or delete it. Follow a saved annotation back to its screen.
- Save feedback to `design-lab/reviews/feedback.json`. Keep a browser cache for recovery and report storage errors. Feedback is local review data, outside Hindsight's Markdown allowlist.
- Export JSON or Markdown. Import a JSON export to restore or merge feedback. Do not send annotations to an external service.
- Use the Arabic preview to inspect mirrored composition and mixed-language text. This remains a browser proposal, not native Arabic or VoiceOver verification.

Review categories: Typography, Hierarchy, Spacing & density, Color & contrast, Iconography, Consistency & polish, Clarity, Overall. Categories are optional; unrated items stay unrated. There are no generated taste scores.

The implementation and verification record belongs in `design-lab/verification.json`. The lab is a local review tool with sample app interactions. Real capture, AI, imports, notifications, production persistence, native builds, and iPhone verification remain outside it.
