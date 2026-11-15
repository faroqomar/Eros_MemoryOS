# Three-step development workflow

Adopted on 2026-11-14. Owner source: C24. Decision: D28. Apply this workflow to authorized MemoryOS tasks. The owner requested implementation, verification with architecture review and benchmarks, then review/push/merge.

Skill routing, C45/C46 (2026-11-15): before each task and each step, search the current installed catalog and project-local skill descriptions for that work's needs. Use the [step skill map](agent-skills.md#skills-for-the-three-development-steps) as a starting point and consider useful skills beyond it. Add, replace, or skip skills by actual fit. Read selected entry points and record the search concerns, paths, and selection reasons in the task record. Preserve the roles and exit criteria below.

## Roles and task size

The main agent coordinates the task, owns the final source, and handles delivery. Under C33, Steps 1, 2, and 3 may all use subagents when they improve the result, provide independent checks, or handle dependency work. There is no fixed two-agent limit. Give each helper a clear scope and owner; parallelize independent work and respect dependency order. Avoid duplicate work and unnecessary agents. Subagents delegate further only when their brief permits it. The main agent owns the merge.

App changes still need a fresh independent verifier who did not implement the reviewed work. Scoped helpers can support architecture, tests, dependencies, performance, or review without replacing that independence.

Documentation-only chores and reversible changes with no app behavior impact can use the main agent's document checks. App changes retain independent verification. Scale verification to the affected behavior and risk.

Keep one connected user outcome in progress. Use the [implementation checklist](../plans/implementation-checklist.md) as the inventory. Preserve its IDs and distinguish current scope from candidates and historical ideas. Start from the [task template](../templates/development-task.md); keep the task record as the shared handoff and evidence index. Do not create separate planning, testing, architecture, and review reports for the same small task.

## Screenshots at every step

Owner update C33 requires screenshot evidence in each step's handback. Capture the actual changed or newly added screens and relevant states in dark mode. Include before/after when it helps show the change, and Arabic/English, keyboard, or large-text states when affected. Save the files, identify the device/OS and simulator versus physical capture, associate them with the source revision/hashes, and show them to the owner.

For code/document-only work, provide a readable capture of the changed code, document, or results and label its type. Use fictional data and exclude private content/secrets. If the required screen cannot run or the capture tool is unavailable, record the screenshot gap as blocked. Do not fabricate UI changes or reuse an old screenshot as evidence of a new change. A screenshot does not establish behavior, owner acceptance, or phone performance on its own.

## Step 1: Understand, plan, and implement

Owner: main agent, with scoped subagents when useful.

Task-specific skill search: reassess the current catalog for this stage before choosing skills. Starting points: `mattpocock-implement` for authorized implementation, `mattpocock-codebase-design` for interface design, and `mattpocock-tdd` for behavior changes. Add the affected Swift/UX skills from the map. Use `mattpocock-writing-for-agents` for agent guidance changes.

1. Identify the authorized checklist items, expected user outcome, dependencies, and existing approvals. Read current project instructions, perform project-scoped Hindsight recall, and load the relevant [development, Swift, and UX skills](agent-skills.md). Read only the additional files needed for this task.
2. Write short acceptance criteria that someone can check. Include relevant failure cases and the required device/build configuration. Resolve product or design choices before implementing the affected behavior. Routine implementation choices stay with the main agent.
3. Apply the [mandatory MVVM, repository, and engine rules](commercial-engineering-rules.md#mandatory-mvvm-repository-and-engine-rules) before coding. Map actual files to View, ViewModel, domain/use case, app-owned protocol, adapter, and composition root. Identify app versus upstream repository ownership and pinned revisions when affected. Define feature state, data ownership, and contracts. Reuse current components; do not choose another architecture or invent custom engine repositories. Record any required owner decision rather than guessing.
4. Select the required tests, regression scope, benchmarks, and pass thresholds. Identify which existing checks can be reused. Mark non-applicable checks with a reason. A required check with no agreed threshold remains open.
5. Implement the connected flow and its behavior-focused tests. Run relevant checks while building and fix failures. Keep changes within the accepted scope.
6. Provide the screenshot evidence required above for the changed/new result. Record helper scopes and dependency handoffs in the task record.

Exit: implementation and tests exist; the task record identifies the exact source state, changed behavior, local check results, and any unresolved requirement. A missing requirement returns to this step. Do not call implementation verified before step 2.

## Step 2: Verify behavior, architecture, and performance

Owner: fresh independent verifier, with fixes by the main agent and scoped subagents when useful.

Task-specific skill search: reassess the current catalog for this stage before choosing skills. Starting points: `mattpocock-code-review` for separate standards and task-requirement checks, plus the affected native testing, accessibility, security, performance, and UX skills. Use `mattpocock-diagnosing-bugs` for failures that need diagnosis. Apply the document-only exception above when no app behavior changes.

Give the verifier the task record, acceptance criteria, exact commit/diff or file hashes, evidence paths, and known limitations. Pass concise context rather than the full conversation. The verifier reads the actual implementation and tests instead of relying on the builder's summary.

Check the relevant parts of this matrix:

| Area | Verification |
| --- | --- |
| Code and architecture | Formatting, static analysis, compilation/concurrency diagnostics, module boundaries, dependency injection, and dependency/license changes. |
| Behavior | Unit/integration tests, UI tests, connected navigation, failure cases, and regression checks for affected consumers. |
| Interface | Dark appearance, English/Arabic and mixed-direction text, keyboard/safe areas, Dynamic Type, VoiceOver, contrast, touch targets, and Reduced Motion. |
| Data and privacy | When affected: offline use, interrupted work, migrations, backup/restore, deletion, source ownership, provider replacement, permissions, and cloud/account isolation. |
| Cleanup | Remove confirmed dead code and useless generated/redundant/temporary files, obsolete backups, and unused caches; preserve active work, original research, provenance, unique evidence, and Git metadata. Record storage before/after and verify retained hashes/links. |
| Performance | Relevant speed, responsiveness, memory, storage, and longer-running energy/thermal measurements against the step 1 targets. |

Use Swift Testing for suitable unit/integration tests and XCTest for UI automation and performance metrics. Tests check observable behavior and failures. A passing test cannot establish behavior it does not exercise.

For benchmarks, record the workload, fictional dataset and size, device/OS, toolchain, source revision, Release build configuration, measurement method, run count, and relevant device conditions. Compare baseline and candidate under the same conditions. Separate cold and warm runs where relevant. Record measured values, the chosen summary statistic, thresholds, and variability; do not infer speed from a code review.

Establish a reusable baseline for implemented core flows. Candidate measurements include launch time, capture/save/search latency when implemented, scrolling responsiveness, peak memory, and storage growth. Add battery, heat, recording, transcription, and model benchmarks when those features enter authorized scope. Step 1 selects concrete numeric targets; this workflow invents none.

Run affected tests and benchmarks for each change. Run the full agreed regression suite before merge. Run the full agreed benchmark suite at integration milestones, before release, and when a change affects shared performance paths. Reuse unchanged evidence only when its source, dependencies, configuration, and required coverage still apply; record that reuse.

Use the T3 device tools for device interaction. Simulator evidence must say simulator. Supported physical-device measurements are required for phone performance claims. If a device or tool is unavailable, record the blocked check and continue independent work. A blocked required check cannot receive a pass or merge-ready status.

The verifier records findings and a pass/fail/blocked result for each applicable criterion. The main agent fixes findings, then reruns affected checks. Request a focused verifier re-check for unresolved findings or fixes that change risk or invalidate evidence. Do not restart broad reviews after unchanged checks pass.

Owner update C32 makes cleanup part of every Step 2. Inspect tracked, untracked, and ignored project files. Confirm actual consumers before deleting code; framework entry points, tests, and retained historical studies need their own scope judgment. Clear reproducible caches after the affected checks finish. Remove temporary task outputs, obsolete backups, and unused generated files, including task-owned external temporary files when safe. Preserve active/shared temporary state and unique evidence; move evidence to its retained location before deleting the temporary copy. Move unique test results out of cache folders first and preserve referenced paths or update their links. Retain uncertain or active material with a reason. Record the removed paths/categories, storage before/after, retained exceptions, preservation checks, affected tests, and screenshot evidence in the existing task record. Recheck app cleanup with the same independent verifier. Cleanup does not turn unresolved verification findings into a pass.

### Mandatory step 2 architecture and upstream checks

Owner adoption C27/D31 makes the [architecture and adoption rules](../decisions/independent-engine-packages.md#mandatory-architecture-and-adoption-rules) mandatory for future app tasks. Plan and implement them in step 1. Step 2 must verify the actual implementation and close gaps before passing.

C34 explicitly requires MVVM and the existing app/upstream ownership rules. The verifier must inspect actual source, record file/symbol evidence, and check each applicable item below. A folder name, class suffix, diagram, or statement that the rules were read cannot substitute for this review.

- **MVVM:** trace an affected user action from View to ViewModel to use case. Check that Views contain presentation and input forwarding, ViewModels own feature state and action coordination, and product rules live in the domain. View-local UI state and stateless display components remain valid; do not require empty ViewModels.
- **Dependency direction:** inspect imports, constructors, and calls. Views/ViewModels must not call concrete databases, network clients, or engine SDKs. Domain code must build without SwiftUI/UIKit or provider/storage implementation dependencies. Verify initializer injection from the composition root and app-owned values across adapter APIs.
- **Behavior tests:** check affected ViewModel state/action/error transitions and use-case rules through controlled dependencies, plus adapter contracts when affected. Test observable outcomes; file names or mirrored implementation assertions do not prove separation.
- **Git repositories and engines:** verify one canonical app repository, upstream-owned engine source in its own checkout/package, justified forks, reviewed pinned revisions, and removal of delivery overrides. Confirm that no copied engine implementation, unnecessary custom engine repository, or unapproved provider selection entered the change.
- **Replaceability and data:** inspect separate implemented recording/transcription/retrieval/model contracts, app-owned originals/IDs/corrections, and rebuildable provider indexes. Apply the existing contract, multilingual/offline, recovery/upgrade, and physical-device checks below when affected.

Record pass/fail/blocked/N/A for these items with code and test evidence. Repair required in-scope violations and obtain the focused independent recheck before Step 2 can pass. An unaffected item needs a reason; an unavailable required check stays blocked. This rule does not claim that the existing sample demo already complies or authorize a separate refactor outside the active task.

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

Owner: main agent, with scoped subagents when useful, required owner product/design decisions, and repository checks.

Task-specific skill search: reassess the current catalog for this stage before choosing skills. Starting points: `mattpocock-code-review` for final-source review and `mattpocock-pr` for the PR description. Use `mattpocock-handoff` when another agent/session must continue unfinished work. Reuse applicable verified evidence and keep the exact final head tied to it.

1. Complete the [mandatory documentation cleanup](#step-3-documentation-cleanup). Review the final diff, verification evidence, and remaining limitations. Confirm that the source state matches the evidence. Obtain any required design/product acceptance. A verifier pass does not replace owner approval.
2. Update the existing checklist and task record. Keep implemented, verified, owner-approved, and merged distinct. Synchronize changed reviewed documentation with `./scripts/memory sync`, then `./scripts/memory check`; require no pending or failed delivery before claiming memory delivery complete.
3. Confirm the Git repository, remote, base branch, final commit, configured checks, and existing authorization for push/PR actions. Push the reviewed changes and open/update the PR within that authorization. Follow the host's PR linking and monitoring rules.
4. Verify required CI checks and reviews on the actual PR head. If changes or a base update invalidate evidence, rerun the affected checks and review. Do not merge a different or unverified head.
5. C33 supplies standing owner authorization to push, open/update the PR, and merge when Step 3 is requested for an authorized task. After review and push, merge the verified final head once required checks/reviews and any required product/design acceptance pass. Do not ask for a second routine merge confirmation or stop at PR creation and call the step complete. Honor task-specific holds. A failed/unavailable required check still blocks merge; this rule does not authorize release, deployment, or unrelated scope.
6. Verify the actual merge result, then record the PR, reviewed head, merge commit, checks, remaining work, and required screenshot evidence. Keep pre-merge and post-merge documentation states accurate. Synchronize any later reviewed documentation changes through the same project memory wrapper.

Exit: verified merge evidence for tasks requiring merge. If a task ends before merge, report its actual state, such as blocked by a named required check or an explicit task-specific hold. For documentation-only tasks with no Git delivery in scope, report local document completion and memory delivery without claiming a merge.

### Step 3 documentation cleanup

C53 (2026-11-15) makes this mandatory for every Step 3, including work already cleaned in Step 2. Before commit, push or handback:

1. Review task-related tracked, untracked and ignored documentation/evidence and task-owned temporary artifacts. Identify their current consumers and purpose.
2. Remove confirmed unnecessary, duplicate, superseded or generated material. Consolidate useful facts into the current task record and canonical reference; repair links when removing or moving a file. Keep necessary active diagnostics outside `docs/` in ignored task storage.
3. Preserve original research, provenance, durable decisions, user data, active work and unique evidence for unresolved findings. Record uncertain retained material with a reason. Preserve truthful failure and unavailable-check status.
4. Record aggregate storage before/after, removal categories and retained exceptions in the existing task record or cleanup receipt. Check links, source/evidence identity, and the [evidence guard](#evidence-retention). Reuse unchanged verification; rerun affected checks if cleanup touches app inputs or behavior.

Exit: no confirmed unnecessary task material remains, retained links/evidence are valid, and cleanup results are recorded. Cleanup never changes merge or release gates.

## Efficiency and completion rules

- Keep one short task record. Link existing decisions, source files, logs, and screenshots instead of copying them into several documents.
- Batch independent reads and checks when safe. Keep edits and dependent operations sequential. Run required checks; repeat or broaden them when changes, failures, or unresolved risk justify it.
- Keep the verifier idle until there is a concrete implementation to inspect. Use relevant skills within the main/verification roles; add scoped helpers under C33 when they improve the result or handle dependency work.
- Ask the owner for missing product/design choices, scope changes, or required approvals. Proceed with routine work already covered by authorization.
- No task may claim complete verification from a build alone, flawless coverage, physical-device results from a simulator, or a merge from a push.

The [commercial and engineering rules](commercial-engineering-rules.md), current owner instructions, and project scope remain authoritative.

## Setup status

On 2026-11-14, `git rev-parse --show-toplevel` returned `fatal: not a git repository (or any of the parent directories): .git` in this workspace. Repository/remote setup must be resolved before Git delivery. This workflow setup did not initialize Git or push anything. This observation does not block local documentation work. Recheck it before a future delivery task.

Later on 2026-11-14, C31 authorizes the private canonical repository [faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS), connected as `origin`. The `main` bootstrap contains ignore rules; the project uses `feat/native-interface-demo` for draft review. The earlier no-Git observation is historical. See the [active task](../tasks/2026-11-14-complete-interface-demo.md) for current PR/source state and unresolved merge gates.

## Evidence retention

C49 (2026-11-15): evidence means the result needed to assess a claim, not every output generated along the way. Keep one current task record, preferably 100–150 lines; a compact verification summary/results receipt; and selected dark captures. Preserve failures and limitations in that record. Avoid repeated reviews and per-attempt receipts.

Do not store raw runtime dumps, profiler call trees, copied diagnostic source or generated file-by-file preservation inventories in `docs/`. Active raw traces/result bundles may stay in ignored task storage while needed for a current finding. Summarize and remove resolved retries, duplicate captures and obsolete caches. Preserve original research, source/reference assets, user records, active work and useful unresolved evidence. Record before/after storage totals, removal categories and retained exceptions in one short cleanup result.

Run `python3 scripts/check-evidence.py <changed evidence folders/files and task record>` before handback. Run it without arguments before commit to inspect staged content, including uncommitted new files once staged. Limits: evidence text 1,000 lines/64 KiB per file; changed text within one evidence folder 3,000 lines/256 KiB; task record 200 lines/32 KiB; no evidence file with more than 100 SHA-256 values. These are maximums, not targets. Do not evade the guard by splitting/minifying dumps. Unchanged historical files are not scanned by default. A compact source manifest can establish exact source identity; verifying preservation does not require retaining every generated-file hash.
