# Task: Select skills for the three development steps

Date: 2026-11-15. Owner sources: C45/C46. Decision: D35.

Scope: update local workflow guidance after the owner added T3 skills. This task does not execute an app checklist stage or include Git delivery.

Outcome: agents search the current installed skills for each task and each step, consider useful skills beyond the starting map, read selected entry points, and record concerns, paths, and selection reasons in the existing task record. The [skill map](../how-to/agent-skills.md#skills-for-the-three-development-steps) is the selection reference; AGENTS.md, the workflow, and the task template point to it.

## Selection and implementation

Read the shared T3 instructions/catalog and the installed entry points for `mattpocock-implement`, `mattpocock-codebase-design`, `mattpocock-tdd`, `mattpocock-code-review`, `mattpocock-pr`, and `mattpocock-handoff` to assess their stage fit. The selected entry-point root is `/Users/eros/.t3/harness/skills/<full-skill-name>/SKILL.md`.

Applied `/Users/eros/.t3/harness/skills/mattpocock-writing-for-agents/SKILL.md` for this document task, `/Users/eros/.codex/skills/t3-auto-skills/SKILL.md` for selection, and `/Users/eros/.codex/skills/t3-hindsight-required/SKILL.md` for project-scoped recall. Inspected the installed discovery skill and conditional research/specification/diagnosis guidance; no installation or external search was needed to select from the installed catalog.

Preserved the 14 project-local Swift/UX skills and their source manifest. Added conditional routing and a required task-specific search, including additions, substitutions, skips, and a reason when no additional skill fits. The map is a starting point rather than a fixed set for dissimilar tasks. Documented the project-specific treatment of skill examples about architecture, test interfaces, builder review, commits, trackers, temporary handoffs, and host tools.

## Document verification

Use the main-agent document-check exception. No Swift, package, app behavior, or runtime dependency changes enter this task. App builds, device checks, and benchmarks are N/A for this documentation change.

Acceptance checks: installed mapped entry points exist; changed document links resolve; each workflow step and task-template stage identifies its skill selection; previous stage/verification/merge rules remain intact; pre-existing local work remains outside this task.

Evidence and final document hashes: [verification receipt](../evidence/step-skills-2026-11-15/verification.json).

Dark document capture: [skill map](../evidence/step-skills-2026-11-15/skill-map-dark.png). This is a rendered excerpt of the changed Markdown on macOS 27.2.1, captured with headless Chrome. It is document evidence, not an iPhone, simulator, or app screenshot. The capture includes source paths and SHA-256 identity.

Cleanup: remove this task's temporary baseline copies, render input, and isolated browser profile after preserving the screenshot and verification receipt. Keep existing active/untracked/ignored project material. Record storage before/after and retained exceptions in the receipt.

Local result: guidance and document checks complete. All 26 mapped skill entry points and the new guidance links resolve. The dark document capture was inspected and is readable.

Memory delivery: see the retained [sync output](../evidence/step-skills-2026-11-15/memory-sync.log) and [final check](../evidence/step-skills-2026-11-15/memory-check.log). Claim completed delivery only when the final check reports zero pending and failed operations. Local document completion does not claim an app-stage pass, PR, or merge.
