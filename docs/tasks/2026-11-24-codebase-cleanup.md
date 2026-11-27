# Owned codebase cleanup, November 24

## Objective and boundaries

Owner requests a codebase cleanup and proof that the roughly 23,000 source lines serve actual purposes. Audit the owned native app, packages, tests and build/CLI consumers; remove confirmed abandoned code. Preserve current behavior, app-owned originals, storage compatibility, Arabic/English, offline execution and useful verification. This is cleanup, not Step 3, model adoption or release. Existing semantic, benchmark and physical-device limitations remain unchanged.

Count physical lines, including comments/blank lines, from owned Swift/C-family source and Swift package manifests under `native/`. Exclude `.build`, bundled `Artifacts`, upstream source and `native/verification`. Start: 273 files, 24,811 source lines and 25,921 test lines. Historical web studies, original research and reference assets are outside the native count and retain their provenance. Tests and framework-discovered entry points are not dead merely because text search finds no caller.

## Acceptance and approach

- Map source files to app, package, CLI, lab or lock-test entry points and inspect suspected unused declaration chains.
- Confirm callers across app/package/tests, build settings, resources and scripts before deleting. Preserve protocol witnesses, delegates, Codable fields and migration compatibility.
- Retire only tests for removed, unreachable sample features. Move meaningful capture failure/draft/commit/Unicode checks to the current path before removing the old API.
- Run affected package tests, Release build/analysis, native controls and current connected UI flows. Use a compiler-backed unused-code scan as a diagnostic, with manual review of exceptions.
- Fresh independent verification must inspect the actual cleanup. Preserve required failed model evidence; do not infer semantic qualification from cleanup.
- Record source/line/storage totals, removal reasons, retained exceptions, dark captures and delivery. No huge per-file inventory in reviewed documentation.

Main owns evaluation/tooling review, test integration, final checks and records. Scoped builders inspect app and core packages; a fresh verifier checks standards and scope. Views remain presentation; feature ViewModels retain state; domain/use cases retain rules; existing adapters remain replaceable. No package/provider/schema selection changes.

## Selected skills

- `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md`: focused project recall and reviewed Markdown delivery.
- `/Users/eros/.codex/plugins/cache/claude-cowork/anthropic-skills/1.0.0/skills/evidence-first-reading/SKILL.md`: consumer evidence before deletion.
- `/Users/eros/.codex/skills/mattpocock-improve-codebase-architecture/SKILL.md` and `mattpocock-codebase-design/SKILL.md`: deletion test and useful module boundaries; owner authorizes implementation, so no proposal-only approval loop.
- `/Users/eros/.codex/skills/mattpocock-code-review/SKILL.md`: separate standards and task-scope checks against the task-start working tree, not the unrelated existing branch diff.
- `.agents/skills/swiftui-expert-skill/SKILL.md`, `swift-testing-expert/SKILL.md` and `axiom-accessibility/SKILL.md`: actual native consumers, meaningful replacement tests and current accessibility routes.

## Confirmed findings

- A disconnected sample catalog/detail/reminder island had only obsolete sample-test consumers. Current routes use app-owned records, personal profiles, real UUID birthdays and BrainMap projections. Remove the old sample source/UI/routes and obsolete state; preserve AppLanguage and current personal destinations.
- Remove unused theme color, unread excerpt query parameter, a no-op source assignment and unused import.
- The old records-owned draft/save API has no production consumer. Current Capture uses ChatViewModel.homeDraft and records.create. Move safety checks onto that path, then retire the shim.
- Retain evaluation lab/CLI roots, the isolated lock-test app, unavailable-platform adapters, provider contracts and active gated model regressions. Each has build/test/tool consumers. Historical outcomes remain distinct from current qualification.

## Verification and delivery

The [final receipt](../evidence/codebase-cleanup-2026-11-24/results.json) records 24,811→24,424 source lines and 25,921→25,750 test lines: 387 source and 171 test lines removed net, three files retired. All 18 module groups have identified app/package/CLI/lab/test/framework consumers. Retained interfaces, protocol hooks, serialization fields and active model regression tooling have explicit roles; this is not a proof that every remaining line is necessary.

A verified temporary [Periphery3.8.0](https://github.com/peripheryapp/periphery/tree/3.8.0) scan over a fresh mainapp/test index reports 6 current findings. Remove one unused import. Retain the five evidenced cache-test/callback/SwiftUI-binding/CaseIterable findings. Public package declarations and Codable/protocol requirements remain protected; manual package/entry-point review supplements the compiler. Discard stale 49-finding output; never delete against an old index.

Final Release analysis/build, 209 native controls, 127 LocalMemory tests, 70 LocalChat tests, strict formatting/linkage/whitespace and 3 current UI flows pass. All 9 capture/storage regression methods remain. Existing responsiveness-await/AppIntents compiler notices and historical accessibility/model/phone limits are recorded without a zero-warning or qualification claim. The UI flow source is unchanged by the final unused-import-only removal.

The [dark runtime capture](../evidence/codebase-cleanup-2026-11-24/home-dark.png) shows final-binary Home on iPhone 18 Pro Max / iOS 27.2 Simulator with no private content. Installed/canonical binary hashes match. No model trial or phone action occurred.

Artifact cleanup removes 3,715,905,302 logical bytes across 6,556 task-generated files, including the temporary scanner/cache, retries and Finder metadata. Five critical hashes match across cleanup; 20 original idea/design files (12,917,311 bytes) retain their aggregate hash. Canonical active Products/shared caches, pinned inputs, original/unique evidence, scoped review preimages and unrelated work remain. Removed source is documented by cleanup-only patches and Git history, not copied into the app.

Fresh standards and source-scope review found no unsafe removal or confirmed retained dead island; final handback/memory delivery status belongs to the receipt. No Git delivery or release is part of this cleanup.
