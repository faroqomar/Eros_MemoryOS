# Task: <ID and connected user outcome>

Use with the [three-step workflow](../how-to/development-workflow.md). Replace placeholders when creating a task record. Keep only applicable detail.

Status: Not started / Step 1 / Step 2 / Step 3 / Complete

Checklist IDs: <existing IDs>

Authorized scope and decisions: <links or owner instruction>

Outcome: <what the user can do after this task>

Dependencies or blockers: <prerequisites, pending design/owner choices, or none>

## Step 1: Understand, plan, and implement

Acceptance criteria:

- [ ] <observable success behavior>
- [ ] <relevant failure or recovery behavior>
- [ ] <affected language/accessibility requirements>

Architecture and short plan: <responsibilities, reuse, contracts, and a few implementation steps>

Required tests and regression scope: <commands/suites or linked existing checks>

Benchmark scope: <workload, numeric thresholds, baseline, dataset, physical device, Release configuration, and repetitions; or justified N/A>

Implementation state: <source revision/diff or file hashes, changed behavior, test locations, and local results>

## Step 2: Verification

Verifier: <independent verifier; document-check exception only when applicable>

Source under verification: <exact commit or file hashes and configuration>

| Criterion/check | Pass/fail/blocked/N/A | Evidence or reason |
| --- | --- | --- |
| <acceptance criterion or required check> | <result> | <command, result, and evidence link> |
| Architecture and dependency review | <result> | <findings/evidence> |
| Relevant regression suite | <result> | <evidence> |
| Dead code and junk cleanup | <result> | <unused consumers checked, removed files/caches, retained exceptions, storage before/after, preservation hashes/links, and affected rechecks> |
| Benchmarks | <result> | <baseline/candidate values, conditions, variability, and thresholds> |

Mandatory [architecture/upstream checks](../how-to/development-workflow.md#mandatory-step-2-architecture-and-upstream-checks):

| Required check | Pass/fail/blocked/N/A | Implementation and evidence, or unaffected-scope reason |
| --- | --- | --- |
| Simple, enforceable core/adapter boundaries | <result> | <module/import/API/concurrency checks and justification for added complexity> |
| Reviewed SDK versions and model assets | <result> | <resolved dependency/configuration and asset version/checksum evidence> |
| Real adapter contracts | <result> | <provider/substitute tests, failure/cancellation cases, regressions> |
| Arabic/English and offline behavior | <result> | <expected multilingual results and explicit asset/offline checks> |
| Durable data, replacement, and recovery | <result> | <preserved originals/corrections, applicable rebuild/migration/restore evidence> |
| Relevant physical-device benchmarks | <result> | <Release baseline/candidate and thresholds> |

Missing implementation and main-agent repairs: <gaps, fixes, affected re-checks, and focused verifier outcome; or none>

An unavailable required check is blocked. Use N/A only with an unaffected-scope reason. Step 2 passes only after applicable implementation and evidence satisfy the rules.

Findings, fixes, and affected re-checks: <concise list or none>

Verification outcome: <pass/fail/blocked and any remaining limitation>

## Step 3: Review and delivery

Owner product/design acceptance, when required: <status and evidence>

Final source and evidence match: <commit/hashes and check result>

Documentation/checklist updates: <links>

Memory delivery: <latest check result; no pending/failed operations before claiming delivery>

Git delivery: <repository, base branch, PR, final head, required checks/reviews; or N/A with reason>

Merge authorization: <owner approval and approved PR/head, or pending>

Merge result: <verified merge commit, or actual unmerged state>

Remaining work and next outcome: <short note>
