# Eros MemoryOS agent instructions

## Current authority and scope

- Read `README.md`, `docs/product-overview.md`, and `docs/decisions/decision-register.md` before substantive project work.
- Use `docs/feature-register.md` for feature scope. Use `docs/reference/source-register.md` for provenance.
- Current owner instructions outrank project documents. Current status records outrank conflicting old research.
- Owner preference, C21 (2026-11-13): use dark mode for completed work, final previews, screenshots, and visual checks. Keep the native app dark by default. The earlier light reference still defines layout; its white palette is historical. Apply this preference at handback in future project tasks.
- Preserve requested, confirmed, proposed, historical, superseded, implemented, and verified as different states.
- The owner initially requested documentation and an isolated Hindsight connection, with no build. On 2026-11-13, C20 authorizes the native SwiftUI foundation and a device readiness check. Keep this step limited to the supplied Capture/sidebar references, navigation, typography, shared controls, and temporary demo interactions. Publication, deployment, purchase, and release still require separate authorization.
- Keep the original three `Project_Idea*.md` files unchanged. Add interpretations and corrections in the new documents.
- Write new documentation in English. Use short sentences and explain technical terms. The owner requested minimal conversation using ASD-STE100 as a language reference. Do not claim certified compliance with that standard.

## Product boundaries

- Target the owner's iPhone 15 Pro Max first. Everyday use must not require a Mac or server.
- Treat local-first behavior, a simple capture screen, a hidden sidebar, Arabic and English support, and user-defined rules as owner requirements.
- ChatGPT, Claude, email, Obsidian, and future sync need explicit connection and data-flow decisions. Never add a silent cloud fallback.
- The owner selected Swift with SwiftUI on 2026-11-07 (C10), and a clickable interface demo with sample data (C11). Flutter and Objective-C are not the selected primary app stack. Database, model, and runtime choices remain proposals or candidates. No phone benchmark has passed. Stack and demo-scope selection do not start implementation in a documentation task.
- The old cloud stack, digital legacy persona, clinician use, enterprise use, budgets, and schedules are historical research. They do not expand the current personal app scope without a new decision.
- Product-memory design is separate from Hindsight memory for coding agents.

## Commercial readiness, architecture, and maintenance

Owner instruction, C23 (2026-11-13): apply the [commercial and engineering rules](docs/how-to/commercial-engineering-rules.md) to future planning, implementation, review, tests, and delivery. C22 records the future sales goal across several markets with optional cloud AI/sync. Exact markets and business location remain open.

- Mandatory architecture, C34 (2026-11-14): use **MVVM (Model-View-ViewModel)** for SwiftUI features, with independent domain/use cases and thin replaceable adapters. Views render state and forward user actions; ViewModels own feature state and call injected use cases; domain models/rules stay independent of SwiftUI, storage implementations, and provider SDKs. Views and ViewModels must not call databases, network services, or engine SDKs directly. Keep view-local presentation state in Views; do not create empty ViewModels for stateless display components. Follow the [explicit MVVM, repository, and engine rules](docs/how-to/commercial-engineering-rules.md#mandatory-mvvm-repository-and-engine-rules). Step 1 must map actual files and dependencies to these roles. Step 2 must inspect code, trace actions, and test the boundaries; naming folders or classes is not evidence of compliance. This policy update does not certify the existing demo or start a refactor.
- Keep the app local-first and use a modular monolith. Keep one private canonical MemoryOS app repository. “Separate engine repositories” means selected upstream library repositories/checkouts, not new custom memory/speech engines. Keep upstream source outside app source, pin reviewed versions, and integrate through small app-owned interfaces and thin adapters. Keep real core/integration targets in the app repository when SDK integration begins. Fork only for a justified required patch. Recording, transcription, retrieval, and model execution remain independently replaceable. Do not infer a provider selection, new repository, or integration from these rules.
- Keep original records, stable IDs, source links, user corrections, and confirmed facts under MemoryOS ownership. Keep AI interpretations distinct. Provider indexes must be rebuildable. Do not make a vendor index the only copy.
- Inject dependencies through small interfaces. Views must not call databases or external providers. Keep vendor SDKs outside the domain and UI. Choose concrete databases, providers, and models through separate recorded decisions.
- Owner clarification C26/D30, 2026-11-14: the separate repositories mean upstream libraries such as Wax, not new custom memory/speech engines. Follow the [replaceable upstream library decision](docs/decisions/independent-engine-packages.md). Keep one app repository, small app-owned interfaces, and thin integration adapters; add targets/packages only for a concrete need. Pin reviewed dependencies and retain upstream source in its own checkout when working on it. Use a local override for explicit integration testing; fork only for a justified required patch. Keep recording/transcription independently replaceable, preserve app-owned data, and verify affected contracts, upgrades/recovery, and performance. D30 supersedes the custom-repository interpretation in D29; no provider selection or integration starts from this clarification alone.
- Owner adoption C27/D31, 2026-11-14: follow the [mandatory architecture and adoption rules](docs/decisions/independent-engine-packages.md#mandatory-architecture-and-adoption-rules) in future project work. Establish real core/integration target boundaries when actual SDK integration begins, pin SDK/model assets, preserve app-owned data and recovery, verify contracts and Arabic/English/offline behavior, and measure relevant physical-device performance. Step 2 must check implementation and evidence, require in-scope repairs and affected re-checks, and block passage on unresolved required findings. Use justified N/A only for unaffected scope; unavailable required checks remain blocked. This adopts rules without starting a new app feature or selecting a library.
- Keep cloud AI and sync optional and separate. Define permissions and data flows before connection. Require explicit permission before third-party AI transfers. Use end-to-end encrypted sync with a reviewed key-recovery design; explain the readable data required by cloud AI. Never introduce a silent cloud fallback.
- Version stored data, export formats, and sync contracts. Verify migration, backup/restore, deletion propagation, conflict handling, provider switching, and recovery before the affected production release.
- Require formatting, static analysis, compilation/concurrency checks, relevant automated tests, dependency/license review, and documented architecture decisions. Verify authorization and account isolation for cloud services. Exclude secrets and private content from logs.
- Assess GDPR/ePrivacy, AI Act, Cyber Resilience Act, consumer rights, accessibility, Apple distribution/billing/trader requirements, and each target market's privacy, recording, tax, and sales rules. Record applicability, evidence, obligations, and justified exemptions. Recheck current primary sources before launch or a material data-flow change. Do not claim universal compliance from a checklist.
- Require release evidence for data safety, privacy controls, applicable cloud isolation, accessibility, and supported physical-device performance. Use OWASP MASVS as a mobile security baseline. A build alone does not establish commercial readiness.
- These rules authorize documentation and govern later authorized work. They do not start cloud implementation, select a dependency, or authorize purchases, publication, deployment, or release.

## Three-step development workflow

- Owner updates C45/C46, 2026-11-15: before each task and each requested step, search the current installed skill catalog for that task's scope and risks, including useful skills beyond the [step skill map](docs/how-to/agent-skills.md#skills-for-the-three-development-steps). Treat the map as a starting point; choose, add, replace, or skip skills by actual fit. Read selected entry points and record paths and selection reasons in the task record. Reassess when scope changes. Keep project-local guidance and existing stage authorization, independent verification, and acceptance gates.
- Owner shorthand, 2026-11-14: in MemoryOS, interpret "step 1", "step 2", and "step 3" (including "start/continue step N" and minor spelling variants) as the stages below for the active checklist task, unless the owner names another procedure:
  - **Step 1:** understand the checklist task, plan architecture and acceptance criteria, implement, and write/run relevant tests. Owner: main agent, with subagents when useful.
  - **Step 2:** independently verify behavior, architecture, tests, and relevant performance/benchmarks; remove confirmed dead code and junk files, fix findings, and rerun affected checks. Owners: fresh verifier and main agent for fixes, with scoped subagents when useful.
  - **Step 3:** review the final result, clean the documentation under the mandatory Step 3 cleanup rule, update records, push/open the PR, and merge the verified final head once required checks/reviews and any required product/design acceptance pass. A Step 3 request supplies standing authorization for this normal delivery flow; do not ask for a second routine merge confirmation. Owner: main agent, with subagents when useful.
- Resolve the target task from current context. Ask only when the target remains ambiguous or required approval is missing; honor authorization already supplied. Complete the requested stage without assuming permission to start later stages. These shortcuts persist across future MemoryOS conversations through this file.
- Follow the [development workflow](docs/how-to/development-workflow.md): (1) understand, plan, and implement; (2) independently verify behavior, architecture, tests, and relevant benchmarks; (3) review, push, and merge within existing authorization.
- Owner update C33, 2026-11-14: all three steps may spawn subagents when they improve the result, provide independent checks, or handle dependency work. The main agent coordinates ownership, handoffs, and dependency order. Use focused scopes and avoid duplicate work; size the team to the task and available concurrency. C33 replaces the earlier two-agent limit. Keep a fresh independent verifier for app changes. Subagents delegate further only when their brief authorizes it; the main agent owns merge decisions. Documentation-only chores can use main-agent document checks or a focused reviewer.
- Define architecture, acceptance criteria, tests, and benchmark targets in step 1. Use the [task template](docs/templates/development-task.md) as the shared plan and evidence record. Keep one connected outcome in progress and preserve existing checklist IDs.
- Every app step 2 must include the [mandatory architecture/upstream checks](docs/how-to/development-workflow.md#mandatory-step-2-architecture-and-upstream-checks). The verifier inspects actual implementation; the main agent supplies missing in-scope implementation before passing. These rules persist for future MemoryOS tasks.
- Owner update C32, 2026-11-14: cleanup is required in Step 2. Check tracked, untracked, and ignored project files. Remove code with no actual consumers and confirmed generated or redundant junk, including temporary task files, obsolete backups, and unused caches. Include task-owned temporary files outside the project when safe. Preserve original research, source/reference assets, historical provenance, active work, unique verification evidence, and Git metadata. Move unique results out of cache folders before clearing caches. Record removal reasons, retained exceptions, and storage before/after; verify retained hashes/links and run affected checks. Framework-discovered entry points and tests are not dead code. App cleanup needs the existing verifier's focused recheck.
- C33 requires screenshots at every step. Show the actual changed/new screens and relevant interaction states in dark mode, with device/OS, simulator or physical status, and source identity. Save and show the captures in the handback. For code/document-only work, capture the changed code, document, or results and label the evidence. Record an unavailable capture as blocked; never invent a screenshot or present an old one as a new change. Use fictional data and exclude private content/secrets.
- Required checks must pass against the final source state. Keep simulator results, physical-device benchmarks, owner product/design acceptance, and merge evidence distinct. Under C33, complete an authorized Step 3 through merge rather than stopping at push/PR creation. Unresolved required findings, unavailable required checks, or task-specific holds still block merge. This does not authorize new app scope, deployment, publication outside the authorized repository, or release.

## Swift engineering skills

- Use the project-local skills in `.agents/skills/` for relevant Swift work. See [the skill inventory and usage rules](docs/how-to/agent-skills.md).
- Read `swiftui-expert-skill` for SwiftUI implementation or review, `swift-concurrency` for task/actor isolation, and `swift-testing-expert` for unit/integration tests. Keep XCTest for UI automation and performance metrics.
- Read `swift-package-manager` when evaluating, adding, updating, or extracting packages. Check the current toolchain, supported iOS versions, license, maintenance, transitive dependencies, privacy effects, and package resolution before adoption. Record the selected version and preserve the app's resolved dependency file.
- Use `swiftui-performance-audit` for performance diagnosis, `axiom-accessibility` for native accessibility, and `axiom-security` for relevant iOS security work. SwiftUI references also cover localization and Arabic RTL.
- Load only the references needed for the task. Check current Apple/Swift documentation and compiler availability before using newer APIs. Skill examples do not change the project's deployment target, architecture, design decisions, or authorized scope.
- T3 device tools govern device interaction even when a skill suggests another tool. An unavailable optional Axiom tool or companion skill does not authorize installing or running it without assessing the task scope. Use available read-only inspection first.
- These skills guide engineering work. Verify each change with the checks required by the commercial and engineering rules; installing skills does not establish app correctness or release readiness.

## UX and interaction skills

- Use the [installed UX skill guide](docs/how-to/agent-skills.md#ux-and-interaction-skills) for relevant UI work: `mobile-ios-design`, `swiftui-ui-patterns`, `ux-heuristics-audit`, `ux-navigation`, `ux-error-recovery`, `ux-empty-states`, and `ux-loaders-and-progress`.
- In step 1, choose the pattern for the actual user task and implement it with native SwiftUI guidance. In step 2, the existing verifier checks the connected flow and records evidenced usability issues and fixes in the current task record. Load only relevant skills/references; use the main-agent/independent-verifier roles and scoped subagents under C33.
- Preserve accepted layouts, hidden sidebar, dark appearance, Arabic/English and RTL, accessibility, and product scope. Adapt web examples to native iOS. Skill examples and generic numeric heuristics do not override owner decisions or establish measured results. Show measured progress honestly and preserve input/recovery behavior where implemented.
- Use extra agents under C33 when useful. Optional skill orchestration and sibling audits do not authorize automatic downloads, service connections, or broader design work. Follow the project guide when a suggested companion is absent.

## Required Hindsight recall

For each task and user turn in T3 Code, read and follow `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md` before substantive work. Use this project's bank only.

```sh
./scripts/memory recall --query 'A focused English question for this task'
```

The wrapper pins `--project memoryos`. The shared CLI defaults to a different project if called without a project argument. Do not use that default. Do not query or write another project's bank for MemoryOS work.

If recall fails, report the error. Use the bounded recovery in the required skill. Do not claim successful memory use or silently proceed with dependent changes after unresolved failure.

## Mandatory Step 3 documentation cleanup

Owner instruction C53, 2026-11-15: every Step 3 includes documentation cleanup before commit, push, or handback, even when Step 2 already cleaned evidence. Review task-related documentation and artifacts; remove confirmed unnecessary, duplicate, superseded and generated material. Consolidate useful outcomes into the existing canonical records, repair links, and retain only evidence needed to assess current results or unresolved findings. Preserve original research, source provenance, decisions, user data, active work and unique required evidence. Keep removal totals and retained exceptions in the existing task record or cleanup receipt; run the evidence guard and link checks. Cleanup must preserve failed/unavailable results and does not waive delivery gates. Follow the [Step 3 cleanup procedure](docs/how-to/development-workflow.md#step-3-documentation-cleanup).

## Compact evidence retention

Owner clarification, 2026-11-17: do not retain raw chats or personal conversation content in project documentation or under `native/verification`. Keep temporary build/crash diagnostics outside the repository and remove resolved diagnostics after extracting a compact result without conversation content. Never copy owner screen recordings into project evidence. Use fictional data for UI checks; preserve the user's app-owned phone history.

Owner instruction C49, 2026-11-15: retain useful proof, not every tool output. Keep one current task record (aim for 100–150 lines), compact final results and selected dark captures. Summarize failures, repairs and remaining limits accurately. Do not place raw runtime output, call-tree exports, copied diagnostic source or large generated per-file inventories in `docs/`. Keep necessary active diagnostics in ignored task storage; remove resolved retries and superseded captures after preserving their outcome. Preserve original research, source references, user data, active work and the evidence needed for unresolved findings. Record cleanup totals and exceptions without a file-by-file dump.

Run `python3 scripts/check-evidence.py <changed evidence folders/files and task record>` before handback and `python3 scripts/check-evidence.py` against staged content before commit. The guard bounds text size, aggregate changed evidence and hash inventories; it does not certify evidence quality. Do not split or minify dumps to evade it. Extend an existing short record rather than creating repeated receipts. Unchanged historical evidence is outside the guard's default scope.

C49 also removes extended VoiceOver conversation testing from the current local-chat task's required checks. Record it as withdrawn, not passed. Basic accessibility labels, larger text, readable contrast, Reduce Motion and usable touch controls remain in scope. This is not a waiver of other tasks' or release requirements.

## Recording and delivery

- Keep durable decisions and verified results in reviewed project Markdown.
- Index only `README.md`, `AGENTS.md`, and reviewed Markdown under `docs/`. `FULLSTACK.md` is also allowlisted if a future authorized task creates it.
- Keep raw conversations, personal chat exports, recordings, contact data, credentials, hidden reasoning, and original research files outside the source allowlist.
- Raw session retention, automatic seeding, and codebase surveys remain disabled. Preserve global opt-in settings and other projects' mappings.
- The shared service uses `openai-codex` for extraction. Send only sanitized project documentation. Do not describe this development service as fully local AI.
- After document changes, run `./scripts/memory sync`, then `./scripts/memory check`. Report delivery only when the check has no pending or failed operations.
- Verify useful recall from this bank before claiming retrieval works. Do not treat an empty knowledge-page search as proof that memory is absent.
- `check` can synchronize files; it is not a read-only health command. Use `status` for read-only delivery state.
- Prefer bounded relevant reads and reuse unchanged-source verification. Never replace another contributor's work or delete a bank without authorization.
