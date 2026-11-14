# Home-screen style for the local review app

Date: 2026-11-12. Owner source C15. Current direction: match the already-decided Capture home screen. Other-screen layouts remain proposals.

The owner rejected Atlas, Almanac, Circles, Cabinet, and Focus. The owner asked for a simple interface and directed the assistant back to the existing home screen. This supersedes the interpretation that each section should explore an independent theme.

## Visual authority

Use the [owner-supplied Capture and sidebar image](../../designs/references/capture-sidebar-owner-reference-2026-11-07.png). Preserve its original bytes.

- White surfaces and generous empty space.
- Charcoal controls and ordinary, system-like typography.
- A header with a leading menu button and a normal-sized title.
- A large central microphone and a short recording label on Capture.
- A thin outlined bottom composer with an attachment control, text field, and send control.
- A sidebar that stays hidden until opened.

The owner's current instruction establishes this image as the style anchor for the app. It does not approve new layouts or establish native device verification.

## Layout proposal

| Screen | Essential content | Secondary content |
| --- | --- | --- |
| Capture | Match the central microphone, open space, and bottom composer. | Sample interaction feedback stays brief. No real recording. |
| People | Names, neutral person icons, and a short discussion preview. | Birthday, projects, sources, and optional questions appear after opening a person. |
| Projects | Folder icons, project names, and short context. | Tentative wording, related people, and sources appear in details. |
| Birthdays | A small date marker and person name. | Reminder preview controls appear after opening a birthday. No scheduling. |
| BrainMap | A few readable nodes, thin links, and a list alternative. | Selected-record details appear only after a node selection. |

Use one coherent style. Remove promotional headings, ornamental type, colored themes, dossiers, staged paper/folders, relationship rings, large date features, and decorative grids from the main view. These changes remove visual treatment, not requested product capabilities.

## Local review behavior

The existing local app remains at `http://localhost:5488`. Capture becomes the first screen so the owner can compare it with the reference. The other four sections follow the same controls and spacing. Keep local region/element annotations and export/import. Hide the feedback editor and annotation toolbar until needed.

Retain the rejected variants, source research, and their existing annotations as history. Do not delete or relabel the owner's saved feedback. New Home style feedback uses its own variant ID. The historical [reference lab record](reference-lab.md) preserves the earlier exploration.

Arabic layout and source access remain part of the browser proposal. Real capture, AI, imports, notifications, native implementation, and physical iPhone verification remain separate work. Record browser checks in `design-lab/home-style-verification.json`.
