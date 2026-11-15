# Development, Swift, and UX skills

Date: 2026-11-14. The owner requested useful skills from [skills.sh](https://skills.sh/) for Swift development, package use, and engineering quality.

## Installation scope

Fourteen skills are installed under `.agents/skills/` in the MemoryOS project: seven Swift engineering skills and seven UX/interaction skills. Other projects' and global skills remain unchanged. Agent skills contain development instructions and references. They are not Swift application dependencies.

Use the installed skills on the next turn after the host refreshes skill discovery. Agents can read the listed `SKILL.md` files directly when discovery has not refreshed. Installation verification does not establish runtime invocation in a fresh host session.

## Skills for the three development steps

Owner sources: C45/C46, 2026-11-15. The owner requested a skill selection for each existing step after adding skills to T3 Code. This map adds the shared T3 workflow skills to the installed Swift/UX guidance. It does not start an app task or advance an active task to another step.

Before substantive work, read `/Users/eros/.t3/harness/instructions.md`, assess the current task against `/Users/eros/.t3/harness/catalog.md` and the project-local inventory below, then read the selected entry points. Use the smallest set that covers the work. Reassess when the stage or scope changes. Record the selected paths and their purpose in the existing task record; pass them to scoped helpers. A document-only task can use document checks without loading Swift implementation skills.

### Required task-specific search

Before **each task and each development step**, search the current installed catalog and project-local skill descriptions for the actual objective, changed behavior, stack, uncertainty, and risks. Search beyond the examples in this map. Tasks with different needs must receive different selections.

1. Identify the work that needs guidance, such as data migration, concurrency, navigation, package adoption, security, diagnosis, documentation, or delivery.
2. Search the installed catalog/descriptions with those concerns. Compare relevant candidates, including skills absent from this map. Read their entry points before applying them.
3. Add or substitute a better-fitting skill and skip irrelevant defaults. Keep the smallest sufficient set. If the search finds no useful addition, record that result and its reason.
4. Keep a short search/selection note in the current task record: concerns searched, selected paths and why they fit, and any material skipped candidate. Repeat the assessment when findings or scope change.

This rule requires research in the installed skills for each task. An external skill search may follow when an installed skill leaves a concrete gap; installation, downloads, service connections, and new work still follow existing authorization.

Shared entry points live at `/Users/eros/.t3/harness/skills/<full-skill-name>/SKILL.md`. Project-local entry points live at `.agents/skills/<skill-name>/SKILL.md`. Use the full `mattpocock-*` names from the catalog to avoid unrelated skills with the same short name.

| Step | Shared T3 skills to select when applicable | Project-local skills to select when applicable |
| --- | --- | --- |
| **1: Understand, plan, and implement** | `mattpocock-implement` for an authorized task; `mattpocock-codebase-design` for changed interfaces and replaceable adapters; `mattpocock-tdd` for behavior changes at agreed test interfaces. | `swiftui-expert-skill` for SwiftUI; `swift-concurrency` for tasks/actors; `swift-testing-expert` for unit/integration tests. Add the relevant native UX, package, accessibility, or security skill below. |
| **2: Independently verify, repair, and clean** | `mattpocock-code-review` to compare the actual change with both project standards and task requirements. Add `mattpocock-diagnosing-bugs` when a failure needs diagnosis. | Reuse the affected Swift/testing skills. Add `swiftui-performance-audit` for performance diagnosis, `axiom-accessibility` for native accessibility, `axiom-security` for security, and `ux-heuristics-audit` for changed flows. |
| **3: Review and deliver** | `mattpocock-code-review` for the final change; `mattpocock-pr` when writing/updating the PR body. Use `mattpocock-handoff` only when transferring unfinished work or session context. | Read the relevant skills for any final fixes. Reuse valid final-source evidence; repeat affected checks when a fix or dependency/base change invalidates it. |

### Select extra guidance by the actual work

| Work | Skill selection |
| --- | --- |
| Native layouts or controls | `mobile-ios-design` and the relevant `swiftui-ui-patterns` references, alongside SwiftUI guidance. |
| Routes/sidebar, failures, empty results, or background work | Select `ux-navigation`, `ux-error-recovery`, `ux-empty-states`, or `ux-loaders-and-progress` for the affected state. |
| Packages or SDKs | `swift-package-manager`; add concurrency/security guidance when those concerns change. |
| Unresolved product decisions | `mattpocock-grill-with-docs`; interview only for decisions that remain open. |
| Agreed requirements need a specification or dependent tickets | `mattpocock-to-spec` or `mattpocock-to-tickets`; use existing project records and tracker authorization. |
| Unfamiliar/version-sensitive external facts | `mattpocock-research` with current primary sources and the host's delegation rules. |
| Agent instructions or workflow guidance | `mattpocock-writing-for-agents`. |

### Apply the skills within MemoryOS rules

- **Architecture:** use the project's mandatory MVVM, app-owned interfaces/data, thin adapters, and upstream ownership rules. Generic deep-module or code-smell advice does not justify removing a required interface, adding speculative packages, or changing architecture.
- **Testing:** record the public test interfaces and observable outcomes in Step 1. Reuse interfaces and test scope already covered by the authorized task. Resolve a missing product/contract decision before dependent work; routine test choices stay with the agent. Use red/green cycles for meaningful behavior changes. Document and cosmetic edits use proportionate checks. Keep Swift Testing for suitable unit/integration tests and XCTest for UI/performance work.
- **Review:** record the comparison base and exact candidate source. Use the known task/PR base and originating task record when available. For uncommitted work, include the actual working diff and hashes. The review skill checks standards and requirements as separate axes; its scoped reviewers support the fresh independent app verifier. Main-agent document checks remain valid for documentation-only work. Reuse valid reviews and request focused rechecks after fixes.
- **Stage boundaries:** a builder review under `implement` does not replace independent Step 2. Follow the project's commit/push/PR/merge stage and authorization, rather than an example skill's instruction to commit at the end of implementation. Step 3 completes the existing delivery flow only after its required gates pass.
- **Tools and records:** use current T3 delegation, device, browser, secret, and PR tools. Keep one task/evidence record and the existing tracker. A skill's setup, publication, temporary-handoff, or background-agent recipe does not create extra authorization or override project record ownership.

The agent still performs project-scoped Hindsight recall on each T3 turn, preserves the required dark screenshot evidence, completes Step 2 cleanup, and checks final-source evidence before delivery. Skill selection alone proves none of these results.

## Swift engineering skills

| Skill | Use | Upstream source |
| --- | --- | --- |
| `swiftui-expert-skill` | State ownership, view structure, navigation, current APIs, localization, Arabic RTL, and accessibility patterns. | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) |
| `swift-concurrency` | Actor isolation, Sendable, cancellation, task ownership, and compiler diagnostics. | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) |
| `swift-testing-expert` | Swift Testing unit/integration tests, async tests, deterministic execution, and XCTest coexistence. | [AvdLee/Swift-Testing-Agent-Skill](https://github.com/AvdLee/Swift-Testing-Agent-Skill) |
| `swiftui-performance-audit` | Diagnose rendering, broad state updates, scrolling, CPU, and memory issues; distinguish source findings from measured performance. | [Dimillian/Skills](https://github.com/Dimillian/Skills) |
| `swift-package-manager` | Package manifests, version constraints, products, targets, local modules, and package resources. | [TalissonVitorino/kmp-ios-skills](https://github.com/TalissonVitorino/kmp-ios-skills) |
| `axiom-accessibility` | VoiceOver, Dynamic Type, contrast, touch targets, Reduced Motion, and navigation accessibility. | [CharlesWiltgen/Axiom](https://github.com/CharlesWiltgen/Axiom) |
| `axiom-security` | Keychain, file protection, privacy permissions, and security reviews for authorized native work. | [CharlesWiltgen/Axiom](https://github.com/CharlesWiltgen/Axiom) |

## UX and interaction skills

Added on 2026-11-14 at the owner's request for useful UX and UX-pattern guidance. Each selected source uses the MIT license.

| Skill | Use | Upstream source |
| --- | --- | --- |
| `mobile-ios-design` | Native iPhone conventions, system typography, touch interaction, safe areas, and adaptive layouts. | [wshobson/agents](https://github.com/wshobson/agents/tree/9c61ab243def98f72da12abd41cfcf5bcd91af9d/plugins/ui-design/skills/mobile-ios-design) |
| `swiftui-ui-patterns` | Concrete navigation, sheets, lists, async UI state, previews, and reusable component references. | [Dimillian/Skills](https://github.com/Dimillian/Skills/tree/05ba982bfeb0d77d3c97d4542b0ee15034d05f84/swiftui-ui-patterns) |
| `ux-heuristics-audit` | Review a real screen/flow against usability heuristics; report evidenced problems, severity, and concrete fixes. | [Uxcel heuristics audit](https://github.com/uxcel-lab/product-skills/tree/5007cd0241ccaa51ae2e4681f9618912dc10e239/ux/audits/heuristics) |
| `ux-navigation` | Wayfinding, current location, route labels, discoverability, and back/exit behavior. | [Uxcel navigation](https://github.com/uxcel-lab/product-skills/tree/5007cd0241ccaa51ae2e4681f9618912dc10e239/ux/components/navigation) |
| `ux-error-recovery` | Prevent mistakes, preserve input, explain failures, and provide an appropriate retry/cancel/undo path. | [Uxcel error recovery](https://github.com/uxcel-lab/product-skills/tree/5007cd0241ccaa51ae2e4681f9618912dc10e239/ux/flows/error-recovery) |
| `ux-empty-states` | Distinguish first use, no results, cleared lists, and failure; provide a relevant next action. | [Uxcel empty states](https://github.com/uxcel-lab/product-skills/tree/5007cd0241ccaa51ae2e4681f9618912dc10e239/ux/screens/empty-states) |
| `ux-loaders-and-progress` | Choose honest feedback for loading, measurable progress, background work, and interruption. | [Uxcel loaders/progress](https://github.com/uxcel-lab/product-skills/tree/5007cd0241ccaa51ae2e4681f9618912dc10e239/ux/components/loaders-and-progress) |

### Apply them to MemoryOS

1. In step 1, identify the user task and current accepted design. Use the relevant pattern skill, then native iOS/SwiftUI references for implementation. Load only the references needed for the task.
2. In step 2, the existing verifier uses the relevant usability lens and native/accessibility checks against the actual connected flow. Keep findings and evidence in the existing task record. Report only real issues and up to three useful priorities; do not invent findings to fill a report.
3. Preserve the selected Capture composition, hidden sidebar, dark-mode preference, approved scope, and owner design decisions. A general preference for tabs, persistent navigation, illustrations, or extra help does not replace those decisions. Skills do not authorize new screens or capabilities.
4. Treat web examples as conceptual guidance. Use native SwiftUI controls, iOS point-based touch targets, VoiceOver, Dynamic Type, Arabic/English and RTL, Reduced Motion, and the current design system. Verify applicable Apple guidance; do not transplant CSS, ARIA, hover, browser URLs, or desktop layout rules into the native app.
5. Treat generic timing, step-count, confidence, or conversion claims as heuristics rather than verified product requirements. Show determinate progress only when the operation can measure it. Otherwise show an honest state with an appropriate cancellation/recovery path. Do not invent percentages, completion times, or AI confidence.
6. Uxcel skills mention optional sibling audit skills and shared orchestration guidance that are not bundled in this selected set. Use their standalone core guidance. The project main-agent/independent-verifier workflow governs handoffs. C33 permits scoped subagents in all steps when useful, including independent checks and dependency work. Optional routes do not authorize automatic skill installs, repeated broad reviews, or new approval steps. Reuse existing `axiom-accessibility` for native accessibility and existing copy/design skills when relevant.
7. Pattern examples for autosave, account recovery, imports, AI, sync, or deletion do not authorize those product features or override current demo/data policies. Preserve the separate permission and provider-selection rules.

The exact `ux-patterns` pack from UX Patterns for Developers was reviewed but not installed: its pinned [LICENCE.md](https://github.com/thedaviddias/ux-patterns-for-developers/blob/a15991d6061c08f67ad2d4e6302e8e4ceaa3036f/LICENCE.md) restricts use to non-commercial purposes without a separate commercial license. The selected MIT alternatives fit MemoryOS's future commercial goal. No purchase or external connection was made.

Use the Codex-specific Axiom distributions. Their router files include topic references. Optional companion skills and external tools may remain uninstalled. Follow relevant bundled references directly when a companion is absent. Do not infer that an optional scanner ran.

The package-manager skill also discusses Kotlin Multiplatform. MemoryOS uses native SwiftUI. Its Kotlin examples do not change the selected stack. Route package tests to `swift-testing-expert` and retain XCTest UI tests. Its sample iOS version is an example, not permission to change MemoryOS's deployment target.

## Working rules

1. Read the relevant skill before a change. Load topic references as needed. Project instructions and current owner decisions take precedence.
2. Check the current Xcode/Swift version, language mode, concurrency settings, and supported iOS versions. Verify unfamiliar or version-sensitive APIs against current primary documentation and the compiler.
3. Keep feature views/view models, independent domain rules, local storage, and replaceable adapters. Keep provider SDKs outside views and domain code.
4. Use Swift Package Manager when a reviewed dependency or a local module has a concrete purpose. Compare Apple APIs and existing code before adding a package. Review maintenance, license, security, privacy, binary/model size, supported platforms, and transitive dependencies. Record the chosen version and retain the app's resolved dependency file. A skill example does not select its example dependency.
5. Start package diagnosis with the manifest, Xcode project, resolved versions, and exact error. Preserve lockfiles and unrelated caches. Do not reset caches, disable security checks, or update all dependencies as a routine first step.
6. Keep unit and integration tests isolated and behavior-focused. Keep XCTest for UI automation and performance metrics. Test relevant failures and concurrency boundaries; avoid tests that repeat implementation details.
7. Check dark mode, Arabic/English and mixed-direction text, Dynamic Type, VoiceOver, contrast, touch targets, and Reduced Motion for affected interfaces. Use T3 device tools for device interaction. Preserve the supplied Capture/sidebar composition and owner review boundaries.
8. Measure performance on supported physical hardware before claiming phone latency, memory, battery, or heat results. A simulator build cannot establish those results.
9. Keep cloud access and third-party AI transfers subject to the existing explicit permission and data-flow rules. Security guidance does not authorize accounts, sync, recording, imports, or live AI work.

The [commercial and engineering rules](commercial-engineering-rules.md) remain the verification requirements. Skills improve the available guidance; they cannot guarantee flawless work.

## Provenance and maintenance

Use the [installed source manifest](../../.agents/skills/manifest.json) for upstream repositories, exact revisions, source paths, license files, and installed-file hashes. The existing skill-installer helper installed the skills through its Git method after the archive download failed with `IncompleteRead`. No third-party installation script ran.

Review future skill updates before replacing the installed revisions. Preserve upstream license notices. Keep third-party skill text outside the Hindsight source allowlist; synchronize this reviewed project guide and `AGENTS.md` through the existing MemoryOS wrapper.

## Initial Swift installation verification

Verified on 2026-11-14:

- Seven skill entry points have matching names and non-empty descriptions in YAML frontmatter.
- The installed folders contain 118 files totaling 1,628,512 bytes, excluding the source manifest.
- Each local topic or script reference in the entry points resolves to an installed file.
- Each skill includes an MIT license notice from its pinned upstream revision. The source manifest records SHA-256 hashes for the installed files.
- The install used exact upstream Git revisions. No symbolic links remain in the installed folders.
- `AGENTS.md` routes future Swift work to the relevant skills and retains the project, package, privacy, device-tool, and verification boundaries.

This task changed development guidance and project documentation. It did not change the native source or add a Swift runtime dependency. No app build, app test, physical-device check, or fresh-session skill invocation is claimed for this installation.

## UX installation verification

Verified on 2026-11-14:

- Seven additional skill entry points have matching frontmatter names and non-empty descriptions.
- The UX set contains 48 files totaling 198,460 bytes. Each skill retains the upstream MIT license notice.
- Concrete bundled reference paths in the entry points resolve. The literal `references/<component>.md` in the SwiftUI skill is a template for adding a future reference, not a missing required file. Optional cross-skill routing remains optional as explained above.
- The source manifest now covers 14 skills and 166 files totaling 1,826,972 bytes, excluding the manifest. It records exact revisions and SHA-256 file hashes. All 118 files from the original seven skills still match their original hashes.
- The existing installer helper's Git preparation, validation, and copy functions installed the selected directories. No downloaded setup script or supplied skill script ran. Temporary installation checkouts were removed.

These checks establish installed files and provenance. Native UX improvements and step 2 results require later authorized app work. New skill discovery is expected on the next turn; no fresh-session invocation is claimed here.
