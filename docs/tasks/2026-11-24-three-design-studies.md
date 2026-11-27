# Three everyday MemoryOS design studies

Status: complete HTML design proposals; owner selection and ordinary-user validation remain open.
Date: 2026-11-24. Scope: owner-requested interactive HTML design exploration.
Checklist IDs: no native implementation milestone is advanced by this study.

## Outcome and authority

The owner requested three distinct redesigns for ordinary daily users, with fictional demo data.
Each direction must reach an honestly reviewed 9/10 target for seven specified design criteria.
The owner authorized autonomous preparation and requested no questions while away.
The supplied eight-screen archive is inspiration, not a new native implementation approval.
Current [product overview](../product-overview.md), [owner vision](../owner-vision.md), and
[decision register](../decisions/decision-register.md) govern product meaning and dark appearance.
The native app and existing unrelated working changes remain untouched.

Deliverables: [one-file comparison and interactive demos](../../astryx-prototype/redesign-2026-11-24/index.html),
[Still](../../astryx-prototype/redesign-2026-11-24/01-still.html),
[Daybook](../../astryx-prototype/redesign-2026-11-24/02-daybook.html), and
[Commonplace](../../astryx-prototype/redesign-2026-11-24/03-commonplace.html).
Each standalone file contains its CSS, scripts, icons, and fictional examples.
The comparison file embeds all three demos and selected home captures; no server/CDN is required.
Changes live in browser memory and reset on reload. Each direction has independent sample state.

## Skill selection and responsibilities

Catalog concerns: visual composition, typography, everyday navigation, error recovery,
interactive prototypes, PDF reading, heuristic review, and accessible responsive controls.
Selected `/Users/eros/.codex/plugins/cache/claude-cowork/anthropic-skills/1.0.0/skills/frontend-design/SKILL.md`
for distinct visual directions and `/Users/eros/.codex/skills/mattpocock-prototype/SKILL.md` for comparison.
The explicit request for refined, tested designs overrides the prototype skill's skip-polish shortcut.
Selected the adjacent `critique/SKILL.md` plus `.agents/skills/ux-heuristics-audit/SKILL.md`
and `.agents/skills/ux-navigation/SKILL.md` for evidenced findings, wayfinding, and recovery.
Selected `/Users/eros/.codex/plugins/cache/openai-primary-runtime/pdf/26.1111.10934/skills/pdf/SKILL.md`
for the supplied reference. Bundled frontend topic references were absent; its entry point was available.
The audience, purpose, and simple personal tone came from the owner and current product records;
no generic skill interview was needed. No Swift or SDK changes justified loading implementation skills.

Main agent built Still and the comparison package. Separate builders owned Daybook and Commonplace.
A fresh book/review agent inspected all three; builders also performed focused cross-reviews.
Reviewers used their own browser tabs. No external provider/dependency was adopted.
App MVVM, database, SDK, migrations, physical-device benchmarks, and upstream integration checks
are N/A because these isolated HTML proposals change none of those layers.
Within each demo, local state and action handlers drive rendering; this is throwaway prototype code.
It is not evidence of production SwiftUI architecture or phone performance.

## Sources and book application

Image source: `/Users/eros/Downloads/MemoryOS — iPhone UI UX Design-png.zip`.
All eight screens were extracted to task scratch storage and visually inspected as a contact sheet.
Retained concepts: capture without filing first, hidden sidebar, source-linked understanding,
people/projects, reversible corrections, clear recording/import states, and simple connections.
Changes reduce competing emphasis and separate original wording, confirmed views, and suggestions.

Consulted the supplied *Laws of UX*, second edition, Jon Yablonski, after iCloud hydration.
PDFKit verified 220 pages and readable text; OCR was unnecessary. The compact manifest records its hash.
Read full chapters Fitts (PDF 33–49), Miller (50–61), Hick (62–78), and Tesler (141–153), plus relevant
preface and chapters 1,5–8,10,12 passages. Inspected Figures 2-2/2-3/2-4/3-4/4-9/9-7.
The following page numbers are 1-based in the supplied reflowed PDF, not publisher printed pages.
Preparation during download also used the [author](https://lawsofux.com/book/),
[publisher contents](https://www.oreilly.com/library/view/laws-of-ux/9781098146955/), and
[publisher preview](https://api.pageplace.de/preview/DT0400.9781098146931_A49445128/preview-9781098146931_A49445128.pdf).

| Supplied PDF reference | Applied choice | Evidence in these designs |
| --- | --- | --- |
| Fitts 34,37–40,48 | Separated generous controls | At least 44px hit areas. The book lists Apple 44×44pt; CSSpx are a prototype proxy, not physical-phone evidence. |
| Miller 51,54–60 | Meaningful groups | Separate sources, decisions, and possibilities; no arbitrary seven-item menu limit. |
| Hick 63,70,75–77 | Recognizable choices when needed | Capture first; named destinations. The actual book prompted final visible Menu/Save/Record labels. |
| Postel 80–81,90–91 | Flexible input and recovery | Free-form safe text, RTL, enlarged text and preserved drafts. |
| Peak–End 94,107 | Clear completion and exits | Save receipts, undo, recording recovery and cancellation. |
| Aesthetic-usability 110,123–124 | Test behavior apart from appearance | Real draft/source/privacy/focus defects blocked high scores until repaired. |
| Von Restorff 127–128,136–137 | Restrained emphasis and noncolor cues | Distinct accents, status words, focus, contrast checks and reduced motion. |
| Tesler 142–153 | Avoid upfront filing | Capture without choosing a folder; disclose sources/transcripts and secondary choices in context. |
| Doherty 155–156,160–165 | Immediate honest feedback | Local receipts; clearly simulated import progress. No invented real-AI speed or completion ETA. |
| Responsibility 189–191 | Protect people in imperfect states | Temporary privacy, per-person confirmation, recovery; no silent transfers or claims about inner motives. |

The preface (PDF 7–8) frames principles as guidance rather than a replacement for user research.
The book supports these choices; it does not prescribe these layouts or certify a numerical rating.

## Distinct directions

| Direction | Composition and interaction | Visual language |
| --- | --- | --- |
| Still | Capture-led home, clear voice action, quiet recent list, persistent composer | Ink, lilac, system sans, generous pauses |
| Daybook | Writing surface, dated journal entries, chronological rediscovery | Warm charcoal, apricot, editorial serif plus sans |
| Commonplace | Compact capture, asymmetric collections, person/topic-led browsing | Forest, sage, overlapping initials, plain linked lists |

All three connect capture, sample recording pause/save/discard, conversation, sources, people,
projects, birthdays, connections, simulated import/cancel/pause, and privacy/settings.
Search has a no-results state. Edits retain original wording. Removal/capture has an undo path.
Temporary conversations avoid adding captured words to Memories and clear transient conversation state.
Prepared answers do not pretend to infer arbitrary new text. Audio controls disclose sample playback.
Arabic controls and RTL are previews; some fictional example content remains in its original language.

## Independent rubric and repairs

Scores are independent AI review judgments after repairs, not owner approval or measured user success.
The fresh reviewer did not build the prototypes and inspected rendered screens and connected actions.

| Criterion | Still | Daybook | Commonplace |
| --- | --- | --- | --- |
| Typography | 9 | 9.5 | 9 |
| Hierarchy | 9.5 | 9 | 9 |
| Spacing & density | 9 | 9 | 9 |
| Color & contrast | 9 | 9 | 9.5 |
| Iconography | 9 | 9 | 9 |
| Consistency & polish | 9 | 9 | 9 |
| Clarity | 9.5 | 9 | 9 |

Initial defects included lost drafts/focus, false zero-duration fallback, undersized playback/undo,
unrelated preset responses, wrong original-speaker attribution, shared person-confirmation state,
lost edited recording text, temporary capture entering Memories, and narrow/enlarged-text overflow.
A later fresh package review found a private Daybook draft left behind after mode-off; the repair
clears the capture field before navigation and clears transient drafts on exit. Independent recheck passed.
Builders repaired these; the main agent and fresh reviewer rechecked the affected behavior.
First root assertions that searched text inside an icon-only button or a closed transcript failed;
correct accessible-name/disclosure assertions then passed. These were harness errors, not hidden passes.

## Verification and evidence

Main browser: Chromium 157 on macOS (reported MacIntel); desktop browser viewport emulation.
No physical iPhone/Safari or native Simulator result is claimed. Dark appearance throughout.
Final layout/text audit: 128 route-width combinations at 320, 375, 430, and 1440 CSS px.
All inspected routes had no document horizontal overflow or undersized main controls.
Computed visible-text minimum ratios: Still 6.46:1, Daybook 6.41:1, Commonplace 6.80:1.
This covers inspected text, not a complete WCAG certification or all composite states.
Doubling computed home text sizes at 430px produced no document overflow or clipped header/main buttons.
The book prompted visible labels; resulting header/field wrapping issues at 320px/200% were repaired.
Fresh checks covered 320/375/430px with doubled font and line height, including actual text containment;
the final 128-layout audit also passed. A wrapped brand/word at extreme enlargement is a cosmetic tradeoff.
Live checks covered literal HTML-safe input, save/undo, draft return, recording pause/save,
actual edited transcript disclosure, source correctness, temporary clearing, and import cancel/pause.
JavaScript syntax checks passed. The comparison switched all three embedded apps, saved a capture,
and cleared it on restart. It made no external requests or real microphone/import/AI calls.

Selected final 430×932 dark captures; [source identities and compact results](../../astryx-prototype/redesign-2026-11-24/evidence/source-identity.json):
[Still home](../../astryx-prototype/redesign-2026-11-24/evidence/01-still-home.png),
[person](../../astryx-prototype/redesign-2026-11-24/evidence/01-still-person.png),
[Daybook home](../../astryx-prototype/redesign-2026-11-24/evidence/02-daybook-home.png),
[recording](../../astryx-prototype/redesign-2026-11-24/evidence/02-daybook-recording.png),
[Commonplace home](../../astryx-prototype/redesign-2026-11-24/evidence/03-commonplace-home.png),
[connections](../../astryx-prototype/redesign-2026-11-24/evidence/03-commonplace-connections.png), and
[Arabic](../../astryx-prototype/redesign-2026-11-24/evidence/03-commonplace-arabic.png).

## Delivery, cleanup, and remaining limits

No commit, PR, merge, native redesign, publication, deployment, or release occurs in this task.
Owner design selection and ordinary-user usability sessions remain open.
The supplied-book pass and final label/flow rechecks are complete. The [independent review](../../astryx-prototype/redesign-2026-11-24/evidence/review.md) retains findings and final ratings.
Cleanup removed 51 task-owned temporary files across two passes (10,535,019 bytes), including extracted references,
book text/renders, preview retries, syntax copies and resolved helpers. The new study folder grew from 0 to 1,098,708 bytes.
Retained originals, four HTML files, seven selected captures, review and compact manifest; unrelated active work and tool-managed caches stay untouched.
The [portable ZIP](../../astryx-prototype/MemoryOS-Designs-2026-11-24.zip) adds 714,014 bytes as a justified transport copy; its 14 entries pass CRC verification.
Evidence guard and local-link checks pass; final memory sync/check and useful recall are verified at handback.
Owner selection, ordinary-user sessions and physical iPhone/Safari validation remain open. No native/release claim follows.
