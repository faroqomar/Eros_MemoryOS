# Demo-first delivery and feature direction

Recorded on 2026-11-07. Owner sources: C09-C12 in the [source register](../reference/source-register.md). C10 selects Swift with SwiftUI. C11 selects a clickable interface demo with sample data. C12 includes BrainMap alongside Capture, People/person details, Projects, and Birthdays. These later choices supersede the earlier undecided stack, demo-type, and BrainMap-inclusion questions.

## Owner direction

1. **Delivery:** Start with a clickable interface demo using sample data (C11), then add and improve features one at a time (C09). The selected demo sections are Capture, People/person details, Projects, Birthdays, and BrainMap (C12). Individual screen layouts, interactions, and review criteria remain open. This is an interface demo; real recording/transcription, AI inference, imports, provider login, notifications, and production storage belong to later feature work. Scope selection does not start application implementation in this documentation task.
2. **Language and interface:** Use Swift for app logic and SwiftUI for the interface (C10). This is now an owner-confirmed choice, replacing the earlier C09 comparison between Swift and Objective-C. Earlier Flutter and Objective-C primary-stack options are superseded for current planning. Speed, battery use, RAM use, and related efficiency measures remain evaluation priorities; selection does not establish measured performance.
3. **Local AI:** Compare multiple candidate models through testing and analysis. Choose suitable models from measured results. No model is selected in advance, and different tasks may justify different models. Exact candidates, runtimes, and test thresholds remain open.
4. **Storage:** An Obsidian vault and a future app-owned storage system are under consideration. This interprets the owner's wording about Obsidian as a vault. Neither is selected as the authoritative store. File access, structured records, search indexes, encryption, backup, and migration remain open questions.
5. **Memory rules:** Refine the rules as the product develops. Exact behavior for automatic retention, duplicates, corrections, conflicting statements, and changed plans remains open. This does not authorize hidden policy changes or treating AI guesses as confirmed facts.
6. **Conversation imports:** Include Telegram, Instagram, and WhatsApp among the requested sources. The owner did not specify an order, export formats, or direct-account integrations. Other sources remain possible future additions.
7. **External AI:** Start with ChatGPT as the first external AI provider. This selects provider priority, not an authentication method, subscription entitlement, model, or data-upload policy. Local operation remains the default preference.
8. **Actions and reminders:** Start with birthdays only and expand later. Approval rules, notification timing, recurrence, date ambiguity, and notification-versus-calendar behavior remain open. Broader reminder/calendar requests remain future scope.
9. **Person profiles:** Support owner-supplied photos, an option to generate images, and reuse of a supplied chat/profile image when the imported material actually includes it. Ask questions about a person and learn from the owner's answers. Exact questions, image-generation provider, and processing location remain open.

## First demo sections

The clickable sample-data demo includes:

- Capture.
- People and person details.
- Projects.
- Birthdays.
- BrainMap.

BrainMap uses fictional sample connections for the demo. Including it does not select a production graph architecture or establish automatic relationship extraction, working AI, or a final approved design. Exact node interactions and navigation remain design work.

## Supporting proposals

These details are assistant recommendations, not additional owner decisions.

- Within the selected Swift/SwiftUI stack, reuse optimized native libraries through supported interfaces. Add Objective-C or Objective-C++ bridges only where a dependency requires them. Exact dependencies and bridge designs remain proposals.
- Measure representative Release builds on the actual iPhone. Compare task accuracy, completion time, peak RAM, storage, power use, and heat. Include model/runtime versions and comparable workloads. A language name alone does not establish the best battery life or memory use.
- Preserve sources and the owner's corrections while refining memory rules. Show which rules are active before allowing them to affect existing records.
- Keep person questions optional and brief so they do not block capture. Distinguish owner answers from model interpretations.
- Preserve each image's origin: supplied, imported, or generated. Treat generated images as representations, not verified photographs. Do not invent a missing chat image or assume an export includes profile photos.

Technical references: [Swift and C++ interoperability](https://www.swift.org/documentation/cxx-interop/), [Apple performance and metrics](https://developer.apple.com/documentation/xcode/performance-and-metrics), [profiling SwiftUI with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/). These establish available integration/profiling tools, not a measured Swift-versus-Objective-C result for MemoryOS.

## Next decisions

- Review the [People, Projects, Birthdays, and BrainMap layout proposal](../design/screen-layouts.md), dated 2026-11-12. It defines navigation, interaction states, and review criteria for these sections. Owner approval remains open. Capture retains its separate reference; language, framework, demo type, and BrainMap inclusion are already selected.
- Measure the selected stack with representative workloads during later authorized device experiments. Model/runtime choices remain open.
- Decide the store's authority, backup/restore behavior, and the role of the Obsidian vault.
- Define the first chat export format, birthday workflow, and person-profile questions when their features come next.
- Verify ChatGPT's supported authentication route for the intended app and select which information may leave the phone.

Wax/Cactus and audio candidates remain in their separate [runtime memory](runtime-memory-options.md) and [audio](audio-recording-and-transcription.md) notes. This record does not change those candidates or establish an implemented app, approved final design, or phone test result.
