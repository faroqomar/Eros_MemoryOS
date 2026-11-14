# Wild MemoryOS redesign

Date: 2026-11-13. Owner source C17. Status: new design proposal for owner review.

**Rejected under C18.** The owner rejected this result, then selected Apple design as the positive reference under C19. Use the [Apple-inspired proposal](apple-inspired.md) as the current direction. This version's source and inspected screenshots are retained under `astryx-prototype/archives/02-wild-rejected/`. It did not complete final flow verification.

The owner rejected the restrained Astryx result and requested a complete, adventurous redesign. This explicitly releases the previous visual rules. Matching the old home image, keeping white-and-charcoal styling, and hiding navigation are no longer constraints on this task.

## Direction

Use an expressive editorial system: ink and warm paper, acid yellow, coral, cobalt, and sage. Pair bold self-hosted Geist with italic serif display accents. Give each screen a distinct composition while keeping the same visual identity.

- Capture uses a typographic poster, a rotating recording bloom, a simulated waveform, and tactile note fragments.
- People uses original illustrated fictional portraits and an asymmetric character gallery.
- Projects uses custom illustrated covers with project context and links to sources.
- Birthdays uses a large calendar poster and a preview of the existing reminder interaction.
- BrainMap uses an orbital composition with colored nodes, source connections, a selected-record panel, and a list alternative.
- Detail screens and settings use the new typography, illustration, color, and spacing.

The mobile navigation dock stays visible. Desktop uses a side rail and wider compositions. Page changes use the View Transitions API when available. Browsers without it retain direct navigation. Reduced-motion mode removes animation.

## Scope and provenance

This is the existing Astryx browser prototype, redesigned under the new owner instruction. All people and notes are fictional. Text capture, recording simulation, sample attachments, optional person questions, source links, and birthday previews use local demo state. Reload resets that state. The task does not add production AI, real recording, imports, notifications, provider connections, or a native release.

SwiftUI remains the selected native product stack. This browser design does not prove native behavior or iPhone performance.

The illustrations are app-owned SVG. Portraits represent fictional people and are not photographs. Geist is self-hosted from the existing design assets; its license is retained at `astryx-prototype/public/fonts/OFL.txt`. No external font service is required.

The previous home-reference source, screenshots, and verification reports remain in `astryx-prototype/archives/01-home-reference/`. The separate annotation lab and its historical feedback are unchanged. Earlier verification does not establish that the new design passes.

## Run and review

The current prototype uses `http://localhost:5491`. From `astryx-prototype/`:

```sh
NEXT_TELEMETRY_DISABLED=1 npm run build
NEXT_TELEMETRY_DISABLED=1 npm start
```

The build compiles the app-owned Astryx theme before Next.js. New review screenshots and checks belong under `astryx-prototype/evidence/wild/`. Only sanitized project Markdown enters development memory.
