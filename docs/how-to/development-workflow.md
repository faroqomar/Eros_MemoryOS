# Three-step development workflow

Adopted on 2026-11-14. Owner source: C24. Decision: D28. Apply this workflow to authorized MemoryOS tasks. The owner requested implementation, verification with architecture review and benchmarks, then review/push/merge.

## Roles and task size

The main agent coordinates the task, plans, implements, fixes findings, and handles delivery. One fresh verifier checks the completed app changes. The verifier reviews architecture and tests; a separate planner, tester, architect, or orchestrator is not needed. Use at most these two agents per task unless the owner requests a larger team. The verifier does not delegate further or merge.

Documentation-only chores and reversible changes with no app behavior impact can use the main agent's document checks. App changes retain independent verification. Scale verification to the affected behavior and risk.

Keep one connected user outcome in progress. Use the [implementation checklist](../plans/implementation-checklist.md) as the inventory. Preserve its IDs and distinguish current scope from candidates and historical ideas. Start from the [task template](../templates/development-task.md); keep the task record as the shared handoff and evidence index. Do not create separate planning, testing, architecture, and review reports for the same small task.

## Step 1: Understand, plan, and implement

Owner: main agent.

1. Identify the authorized checklist items, expected user outcome, dependencies, and existing approvals. Read current project instructions, perform project-scoped Hindsight recall, and load the relevant [Swift skills](agent-skills.md). Read only the additional files needed for this task.
2. Write short acceptance criteria that someone can check. Include relevant failure cases and the required device/build configuration. Resolve product or design choices before implementing the affected behavior. Routine implementation choices stay with the main agent.
3. Define the architecture before coding: feature state, independent domain/use cases, storage and adapter interfaces, data ownership, and any affected contracts. Reuse current components. Record a new dependency or material architecture choice with its rationale and compatibility limits.
4. Select the required tests, regression scope, benchmarks, and pass thresholds. Identify which existing checks can be reused. Mark non-applicable checks with a reason. A required check with no agreed threshold remains open.
5. Implement the connected flow and its behavior-focused tests. Run relevant checks while building and fix failures. Keep changes within the accepted scope.

Exit: implementation and tests exist; the task record identifies the exact source state, changed behavior, local check results, and any unresolved requirement. A missing requirement returns to this step. Do not call implementation verified before step 2.

## Step 2: Verify behavior, architecture, and performance

Owner: fresh verifier, with fixes by the main agent.

Give the verifier the task record, acceptance criteria, exact commit/diff or file hashes, evidence paths, and known limitations. Pass concise context rather than the full conversation. The verifier reads the actual implementation and tests instead of relying on the builder's summary.

Check the relevant parts of this matrix:

| Area | Verification |
| --- | --- |
| Code and architecture | Formatting, static analysis, compilation/concurrency diagnostics, module boundaries, dependency injection, and dependency/license changes. |
| Behavior | Unit/integration tests, UI tests, connected navigation, failure cases, and regression checks for affected consumers. |
| Interface | Dark appearance, English/Arabic and mixed-direction text, keyboard/safe areas, Dynamic Type, VoiceOver, contrast, touch targets, and Reduced Motion. |
| Data and privacy | When affected: offline use, interrupted work, migrations, backup/restore, deletion, source ownership, provider replacement, permissions, and cloud/account isolation. |
| Cleanup | Remove confirmed dead code and unnecessary generated/redundant files; preserve active work, original research, provenance, unique evidence, and Git metadata. Record storage before/after and verify retained hashes/links. |
| Performance | Relevant speed, responsiveness, memory, storage, and longer-running energy/thermal measurements against the step 1 targets. |

Use Swift Testing for suitable unit/integration tests and XCTest for UI automation and performance metrics. Tests check observable behavior and failures. A passing test cannot establish behavior it does not exercise.

For benchmarks, record the workload, fictional dataset and size, device/OS, toolchain, source revision, Release build configuration, measurement method, run count, and relevant device conditions. Compare baseline and candidate under the same conditions. Separate cold and warm runs where relevant. Record measured values, the chosen summary statistic, thresholds, and variability; do not infer speed from a code review.

Establish a reusable baseline for implemented core flows. Candidate measurements include launch time, capture/save/search latency when implemented, scrolling responsiveness, peak memory, and storage growth. Add battery, heat, recording, transcription, and model benchmarks when those features enter authorized scope. Step 1 selects concrete numeric targets; this workflow invents none.

Run affected tests and benchmarks for each change. Run the full agreed regression suite before merge. Run the full agreed benchmark suite at integration milestones, before release, and when a change affects shared performance paths. Reuse unchanged evidence only when its source, dependencies, configuration, and required coverage still apply; record that reuse.

Use the T3 device tools for device interaction. Simulator evidence must say simulator. Supported physical-device measurements are required for phone performance claims. If a device or tool is unavailable, record the blocked check and continue independent work. A blocked required check cannot receive a pass or merge-ready status.

The verifier records findings and a pass/fail/blocked result for each applicable criterion. The main agent fixes findings, then reruns affected checks. Request a focused verifier re-check for unresolved findings or fixes that change risk or invalidate evidence. Do not restart broad reviews after unchanged checks pass.

Owner update C32 makes cleanup part of every Step 2. Inspect tracked, untracked, and ignored project files. Confirm actual consumers before deleting code; framework entry points, tests, and retained historical studies need their own scope judgment. Clear reproducible caches after the affected checks finish. Move unique test results out of cache folders first and preserve referenced paths or update their links. Retain uncertain or active material with a reason. Record the removed paths/categories, storage before/after, preservation checks, and affected tests in the existing task record. Recheck app cleanup with the same independent verifier. Cleanup does not turn unresolved verification findings into a pass.

### Mandatory step 2 architecture and upstream checks

Owner adoption C27/D31 makes the [architecture and adoption rules](../decisions/independent-engine-packages.md#mandatory-architecture-and-adoption-rules) mandatory for future app tasks. Plan and implement them in step 1. Step 2 must verify the actual implementation and close gaps before passing.

Record pass/fail/blocked/N/A and evidence for each row in the existing task record:

| Required check | Evidence when applicable |
| --- | --- |
| Simple, enforceable boundaries | One app repo; justified targets/packages/forks; independent core build; provider-free view/domain code; app-owned adapter API values; correct dependency and concurrency ownership. |
| Reviewed dependencies and assets | Selected SDK product/version/revision, final resolved configuration without development overrides, dependency/license review, and model/configuration versions/checksums. |
| Real adapter contracts | Provider and substitute/alternative results, affected app regression tests, unsupported capabilities, errors, cancellation, and interruption. |
| Arabic/English and offline behavior | Recorded fictional multilingual cases and expected results, actual selected model/defaults, prepared/missing/interrupted asset behavior, and offline execution without silent cloud fallback. |
| Durable data and replacement | Original records/IDs/corrections survive the affected switch/update; required export/rebuild or migration, correction/deletion, backup/restore, and recovery checks pass. |
| Relevant physical-device benchmarks | Release baseline/candidate with the same workload/model/device conditions, recorded measurements/variability, and the step 1 thresholds. |

The main agent must implement missing requirements and repair failures within the authorized task, then rerun affected checks and obtain the focused independent re-check. Record a blocking owner decision when a repair requires scope or provider/product choices not already authorized. A checkbox saying a rule was read does not prove implementation.

N/A requires an explicit unaffected-scope reason. A missing required device, implementation, threshold, or result is blocked rather than N/A. The current sample-data demo does not require adding unused engines or packages to satisfy this policy.

Exit: acceptance criteria, the applicable mandatory architecture/upstream checks, and other required checks pass against the identified final source state, with evidence and no unresolved blocking findings. Record owner visual acceptance separately when required.

## Step 3: Review, push, and merge

Owner: main agent, with owner decisions and repository checks.

1. Review the final diff, verification evidence, and remaining limitations. Confirm that the source state matches the evidence. Obtain any required design/product acceptance. A verifier pass does not replace owner approval.
2. Update the existing checklist and task record. Keep implemented, verified, owner-approved, and merged distinct. Synchronize changed reviewed documentation with `./scripts/memory sync`, then `./scripts/memory check`; require no pending or failed delivery before claiming memory delivery complete.
3. Confirm the Git repository, remote, base branch, final commit, configured checks, and existing authorization for push/PR actions. Push the reviewed changes and open/update the PR within that authorization. Follow the host's PR linking and monitoring rules.
4. Verify required CI checks and reviews on the actual PR head. If changes or a base update invalidate evidence, rerun the affected checks and review. Do not merge a different or unverified head.
5. Merge only with explicit owner authorization for the concrete PR/head and passing required checks/reviews. The standing workflow describes the process; it does not approve a future merge, release, publication, or deployment.
6. Verify the actual merge result, then record the PR, reviewed head, merge commit, checks, and remaining work. Keep pre-merge and post-merge documentation states accurate. Synchronize any later reviewed documentation changes through the same project memory wrapper.

Exit: verified merge evidence for tasks requiring merge. If a task ends before merge, report its actual state, such as ready for review or awaiting merge approval. For documentation-only tasks with no Git delivery in scope, report local document completion and memory delivery without claiming a merge.

## Efficiency and completion rules

- Keep one short task record. Link existing decisions, source files, logs, and screenshots instead of copying them into several documents.
- Batch independent reads and checks when safe. Keep edits and dependent operations sequential. Run required checks; repeat or broaden them when changes, failures, or unresolved risk justify it.
- Keep the verifier idle until there is a concrete implementation to inspect. Use the relevant skills inside the two roles instead of creating a role for each skill.
- Ask the owner for missing product/design choices, scope changes, or required approvals. Proceed with routine work already covered by authorization.
- No task may claim complete verification from a build alone, flawless coverage, physical-device results from a simulator, or a merge from a push.

The [commercial and engineering rules](commercial-engineering-rules.md), current owner instructions, and project scope remain authoritative.

## Setup status

On 2026-11-14, `git rev-parse --show-toplevel` returned `fatal: not a git repository (or any of the parent directories): .git` in this workspace. Repository/remote setup must be resolved before Git delivery. This workflow setup did not initialize Git or push anything. This observation does not block local documentation work. Recheck it before a future delivery task.

Later on 2026-11-14, C31 authorizes the private canonical repository [faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS), connected as `origin`. The `main` bootstrap contains ignore rules; the project uses `feat/native-interface-demo` for draft review. The earlier no-Git observation is historical. See the [active task](../tasks/2026-11-14-complete-interface-demo.md) for current PR/source state and unresolved merge gates.
