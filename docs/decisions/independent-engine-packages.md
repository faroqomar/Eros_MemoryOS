# Replaceable upstream libraries

Updated on 2026-11-14. Owner sources: C26 and C27. Decisions: D30 and D31. D30 corrects the earlier C25/D29 interpretation. D31 adopts the research refinements as standing rules and requires their enforcement in step 2.

## Current direction

The owner meant upstream repositories such as Wax and transcription libraries. Keep one MemoryOS app repository and use small app-side adapters around selected upstream packages. Reuse maintained libraries before writing replacement engines. Extra custom engine repositories are not the current plan.

Wax and the documented speech/memory alternatives remain candidates. Naming a library here does not select a production dependency or start integration. Concrete versions, licenses, platform/model compatibility, and phone results still need review when the capability enters authorized scope.

## Small app structure

| Part | Responsibility |
| --- | --- |
| App and features | SwiftUI screens, navigation, feature state, and user actions. |
| Plain Swift core | App-owned records, product rules, and the small interfaces needed by actual integrations. |
| Integrations | Thin adapters that connect those interfaces to selected upstream libraries. |
| Tests | Core behavior, adapter contracts, connected app flows, and relevant benchmarks. |

Start with folders and existing targets. Add a separate local package or target when it provides a concrete testing or dependency boundary. Do not create empty packages, an adapter framework, or a shared contracts repository in advance.

At the first real SDK integration, establish a small local Swift package with an independent plain Swift core target and the integration target(s) that feature needs. Reuse equivalent existing module boundaries if present and record why they satisfy the rule. Keep these targets in the app repository. The current temporary demo does not need empty integration modules.

Keep recording, transcription, memory retrieval, and text-model execution as separate responsibilities. Create only the interfaces required for the implemented behavior. An interface defines the operations and results the app needs; an adapter translates those operations to the selected library. Views and domain rules must not import provider SDKs.

For example, a future Wax integration would live behind the app's memory interface. A future transcription integration would live behind a different interface. App use cases connect their results. Provider replacement should concentrate changes in the adapter and dependency selection, subject to capability and data compatibility.

## Work separately, adopt deliberately

1. Add a selected library through Swift Package Manager during step 1 of its authorized feature task. Use a reviewed release or exact revision and retain the app's resolved dependency file. Keep upstream source in its own repository/package checkout rather than copying it into app source.
2. Use a separate local upstream checkout and its own tests or a small experiment harness for library research or code changes. Library work there does not update the app's pinned dependency. Do not initialize custom engine repositories just to wrap third-party code.
3. When integration testing begins, use a local package override in a development configuration. Remove the override, select the reviewed package version/revision, and rerun affected app checks before delivery. Local overrides intentionally affect that development build.
4. Prefer upstream releases. Maintain a fork only when a concrete required patch cannot be supplied by the selected upstream release. Record the upstream revision, patch, license, maintenance cost, and route back to upstream. A maintained fork is additional work, not a default setup step.
5. Verify the adapter's expected behavior, failure/cancellation cases, and relevant offline/language support. When changing upstream code, run its applicable tests as well. Benchmark the connected feature on the supported physical device before making phone performance claims.
6. Adopt updates through the existing three-step app workflow, with a concrete dependency change, required checks, and existing review/merge approval boundaries.

Pin model assets and record their versions/checksums separately when applicable; a package version alone does not identify downloaded model content. Keep unsupported capabilities and structured errors visible to the app. Never add a silent cloud fallback.

## Keep information portable

MemoryOS owns original text/audio, stable IDs, source links/dates, transcript versions, user edits, confirmed facts, and relationships. A vendor index must not be the only durable copy. Keep extracted claims and AI interpretations distinct from user confirmations.

Preserve originals and corrected transcripts when comparing engines. Treat indexes and embeddings as derived data that can be rebuilt. Before replacing a provider that affects stored data, verify export/import or migration, correction/deletion behavior, backups, recovery, and rollback. Changing the dependency version alone cannot reverse a data migration.

This design limits coupling without promising zero integration work. Some replacements require an adapter change, data migration, index rebuild, or different model assets. Keep those changes reviewable and verify the affected app flow.

## Mandatory architecture and adoption rules

Owner adoption C27/D31 applies to future authorized planning, implementation, verification, and delivery. Apply these rules in step 1 and enforce them as step 2 exit requirements:

1. Keep one app repository with small feature areas, app-owned interfaces, and thin integration adapters. Prefer maintained upstream releases. Add a fork, package, target, or abstraction for a concrete need, with a recorded reason. Do not create custom engine repositories solely to wrap third-party code.
2. Keep provider SDKs out of views and domain rules. Use actual module boundaries when SDK integrations begin. Verify that the plain Swift core builds without provider dependencies and that adapter public APIs use app-owned values rather than SDK types. Keep recording, transcription, retrieval, and text-model execution independently replaceable. Use initializer injection and clear ownership of SDK instances; check concurrency across those boundaries.
3. Adopt reviewed SDK versions/revisions and retain the app's resolved dependency file. Use the appropriate resolved-version checks for the build path. Verify the final delivered configuration after removing development-only overrides. Review products, traits, transitive dependencies, platform/toolchain requirements, and licenses. Version and verify model assets/configuration separately from package resolution.
4. Keep one logical canonical source for app-owned originals, stable IDs, source links, corrected transcripts, and confirmed facts. Keep interpretations distinct and provider indexes rebuildable. Prove the affected export/rebuild or migration, correction/deletion, backup/restore, and recovery behavior before adopting an update that changes durable information.
5. Test the adapter contract against real provider behavior and controlled substitutes or a relevant alternative. Include applicable errors, unsupported capabilities, cancellation, interruption, offline use, and asset preparation/recovery. Run upstream tests when changing upstream code, plus affected app integration/regression checks.
6. Evaluate provider/model configurations on fictional Arabic, Iraqi Arabic, English, and mixed-language examples with recorded expected results and step 1 acceptance criteria. Check the selected revision's actual defaults. An English-only embedding default does not establish Arabic semantic retrieval; a library's on-device label does not establish offline initialization. Keep model downloads explicit and prevent silent cloud fallback.
7. Measure the affected connected flow on the supported physical phone in Release configuration before claiming phone speed, memory, storage, energy, or thermal results. Record baseline/candidate, dataset, model assets, conditions, repetitions, thresholds, and variability. Use the existing proportional test/benchmark scope; do not invent performance or quality results from source review.

During step 2, the independent verifier records pass/fail/blocked/N/A with evidence for each applicable rule. N/A requires a concrete scope reason; an unavailable device or unmet required criterion is blocked, not N/A. The main agent implements missing in-scope requirements and fixes findings, then affected checks and focused independent verification must pass against the final source state. If a necessary repair requires a new product/provider decision or exceeds task authorization, record the blocker and obtain that decision rather than expanding scope.

Step 2 cannot pass with unresolved required failures, missing implementation, or missing evidence. Policy adoption does not execute an app task, select a provider/database/model, establish a benchmark, or authorize a specific merge/release.

## Research review

Research update, 2026-11-14: the [source-based architecture review](../research/2026-11-14-upstream-library-architecture.md) supports D30 with staged local package/target boundaries and provider-fit/asset-lifecycle checks, including Wax's inspected default English-only embedding model. C27/D31 subsequently adopts the applicable recommendations as the mandatory rules above. The research remains dated source evidence; adoption is not a provider choice, architecture implementation, or phone result. Recheck current upstream facts at each affected integration/update.

## Historical interpretation

D29 initially interpreted C25 as a plan for new custom repositories named `Eros_MemoryEngine` and `Eros_Speech`. The owner clarified under C26 that they meant upstream repositories such as Wax and asked for less complexity. D30 supersedes that custom-repository plan. No custom engine repository was created and no engine implementation or provider selection resulted from that proposal.

## References

- [Apple: adding package dependencies](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).
- [Apple: testing a dependency through a local package override](https://developer.apple.com/documentation/xcode/editing-a-package-dependency-as-a-local-package).
- [Swift Package Manager: dependency versions](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/).
- [Current runtime memory candidates](runtime-memory-options.md) and [recording/transcription candidates](audio-recording-and-transcription.md).
- [Three-step workflow](../how-to/development-workflow.md) and [commercial/engineering requirements](../how-to/commercial-engineering-rules.md).
