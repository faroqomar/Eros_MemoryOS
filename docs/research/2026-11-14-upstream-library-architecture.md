# Upstream library architecture review

Date: 2026-11-14. The owner requested deep research into whether the simplified upstream-library plan is the best approach for MemoryOS.

Status: researched recommendation. D30 remains the adopted direction. The module layout and experiments below are proposed refinements, not implemented or newly selected dependencies.

## Recommendation

Keep one app repository, app-owned records and small interfaces, thin adapters, and reviewed Swift Package Manager dependencies. When the first real SDK integration begins, consider one local Swift package with a plain Swift core target and the integration targets needed by that feature. This provides useful compile-time boundaries without independent repository/release administration for our wrappers.

Keep the present sample-data foundation simple until real integrations enter scope. Create an interface for an actual replaceable dependency or testing boundary. Add use cases where they express product behavior; avoid a pass-through class for every UI action. Use initializer injection and a small app composition root.

This is an engineering judgment for MemoryOS's local-first, Arabic/English, provider-replacement requirements. Documentation supports the mechanisms; it does not prove a universal best architecture or establish runtime performance.

## Evidence and method

Reviewed primary Apple/Swift documentation, the original ports-and-adapters description, upstream source, release notes, and model publisher documentation. Retrieved source at these exact revisions:

| Repository | Inspected revision | Commit timestamp from GitHub |
| --- | --- | --- |
| Wax | `67da356544e145a02f97fcf9cf6be39a199ced74` | 2026-11-14 06:29:46 UTC |
| Argmax OSS Swift | `9f99b5cb6a907730543823ad271b82532782a899` | 2026-10-11 01:10:21 UTC |

Moving-branch and cached search results did not always show the same source state. Claims about provider defaults below use commit-pinned files. These revisions identify research snapshots, not selected production versions.

Read-only local checks reported Xcode 27.2 build 27B52 and Apple Swift 6.4.2. The app project declares iOS 18.0, Swift language mode 6.0, and complete strict concurrency. Compiler version and language mode are separate settings. These checks establish tool availability/settings, not package or physical-device compatibility. Evidence is source/document inspection and local tool help; implementation tests and benchmarks remain future work.

## Compare the alternatives

The maintenance and suitability judgments in this table are inferences from our requirements, not benchmark scores.

| Approach | Benefit | Cost or limitation | Fit for MemoryOS |
| --- | --- | --- | --- |
| SDK calls inside feature views | Short initial implementation. | UI and provider lifecycle/types become coupled; replacement crosses screens. | Suitable for disposable experiments, not the intended product boundary. |
| One app target with feature/core/adapter folders | Small setup and easy navigation. | Folder names alone do not create separate compiler modules. Dependency rules rely on review/checks. | Good for the current small demo and a limited initial integration. |
| One app repo plus a small local package with real targets | Core and provider dependencies can have explicit module boundaries and independent tests. | Some manifest/access-control work. | Recommended growth path when real SDK integrations justify it. |
| Separate repositories for our own wrapper engines | Independent release lifecycle and reuse across multiple consumers. | Cross-repo changes, compatibility matrices, releases, CI, and documentation overhead. | Reconsider after real independent consumers/owners exist. |
| Fork or vendor each upstream SDK from the start | Direct patch control. | We inherit patch/rebase, security-update, attribution, and maintenance work. | Use for a concrete required patch or distribution constraint, not routine integration. |

Apple documents keeping local packages in the app's repository and considering separate Git repositories as reuse across apps develops. Swift defines modules around build targets, rather than folder names. These mechanisms support a staged local-package approach. [Apple local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages.md), [Swift access control](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/AccessControl.html).

## A small enforceable structure

Proposed when the first authorized provider integration enters scope:

| Module or area | Dependency rule |
| --- | --- |
| App features and composition | Screens use app-owned models/interfaces. The composition root creates and injects implementations. |
| `MemoryCore` target | Product models, actual use cases, and required interfaces. No SwiftUI or provider dependencies. |
| Integration target(s) | Depend on `MemoryCore` and the chosen upstream product; convert SDK values into app-owned values. |
| Tests | Test core rules with controlled substitutes, and test each real adapter against the same observable contract. |

One local package can contain the core and actual adapter targets. Start with the target(s) needed by the first feature; do not scaffold unused engines, a DI framework, an event bus, or a plugin system. Keep recording, transcription, retrieval, and model execution as distinct responsibilities. Their results can have different capabilities and lifecycle needs.

Use explicit non-public SDK imports where suitable so SDK types cannot appear in an adapter's public API. Swift's SE-0409 supports this interface check. It does not remove the SDK from the linked application, create a sandbox, or prove that feature files obey the desired dependency rule. Keep the target dependency graph and an import check/review as additional controls. [Swift import visibility proposal](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0409-access-level-on-imports.md).

The underlying pattern is ports and adapters: keep application behavior testable independently of external technology. This is a small use of that pattern, not a requirement to add a large architecture framework. [Original description by Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture).

## What the upstream source changes about our decision

### Wax: Arabic fit is a separate question from architecture

The inspected `Memory` implementation selects e5 for a new store under automatic embedding selection, while retaining the existing built-in provider for an older store. Its public surface is an actor with asynchronous operations. [Pinned Memory implementation](https://github.com/christopherkarani/Wax/blob/67da356544e145a02f97fcf9cf6be39a199ced74/Sources/Wax/Memory.swift).

The e5-small-v2 publisher explicitly limits that model to English. Inference: we cannot accept this default as evidence of Arabic/Iraqi-Arabic semantic retrieval. This does not mean Wax cannot store Arabic or cannot use another model. Evaluate a compatible multilingual embedding implementation on the intended phone and dataset before adopting that configuration. [Model publisher's limitations](https://huggingface.co/intfloat/e5-small-v2).

Wax exposes an `EmbeddingProvider` interface with dimensions, normalization, identity, similarity, execution mode, and query/document embedding operations. Its comments describe rejecting an incompatible similarity mode when reopening an index. This supports investigating another provider, while also showing why changing embeddings requires compatibility/rebuild checks. The existence of the interface does not verify a particular multilingual model integration. [Pinned embedding interface](https://github.com/christopherkarani/Wax/blob/67da356544e145a02f97fcf9cf6be39a199ced74/Sources/WaxVectorSearch/Embeddings/EmbeddingProvider.swift).

Wax's structured-memory documentation identifies the underlying Swift graph storage types/engine calls as package-only details. Inference: do not assume a library's internal people/facts graph supplies our public product API. Keep MemoryOS relationships, corrections, and source-backed facts under app ownership unless a supported public integration satisfies them. [Pinned structured-memory documentation](https://github.com/christopherkarani/Wax/blob/67da356544e145a02f97fcf9cf6be39a199ced74/Sources/WaxCore/WaxCore.docc/Articles/StructuredMemory.md).

The inspected manifest requires Swift tools 6.2, declares iOS 17, exposes multiple products/traits, and enables MiniLM/E5 embeddings by default. Review the selected product, traits, model resources, and resolved dependencies. A manifest dependency list alone does not establish which binaries/resources end up in the app or their size; inspect the resolved build. [Pinned Wax manifest](https://github.com/christopherkarani/Wax/blob/67da356544e145a02f97fcf9cf6be39a199ced74/Package.swift).

### Argmax/WhisperKit: adapters need to absorb real upgrade changes

The v1.0.0 release renamed the package and CLI, removed deprecated APIs, and changed several signatures. It also documented concurrency limits of top-level kit instances at that release. This is a concrete reason to keep provider values and instance ownership inside an adapter. Check the selected release's current isolation/Sendable behavior instead of treating that historical note as a permanent property. [Argmax v1.0.0 release](https://github.com/argmaxinc/argmax-oss-swift/releases/tag/v1.0.0).

The inspected Swift 6.2 manifest offers separate WhisperKit, SpeakerKit, and TTSKit products and an umbrella product; it uses Swift 6 language mode. Choose the required product rather than importing every kit for convenience, and inspect the compiler-selected manifest. This is a build-scope choice; actual app size/speed still needs measurement. [Pinned toolchain-specific manifest](https://github.com/argmaxinc/argmax-oss-swift/blob/9f99b5cb6a907730543823ad271b82532782a899/Package%40swift-6.2.swift).

The inspected WhisperKit configuration defaults `download` to true and supports local model/tokenizer paths. The app should control asset preparation and user-visible download state, then verify offline execution with all required files present. A library being on-device does not establish that its default initialization performs no network activity. [Pinned configuration](https://github.com/argmaxinc/argmax-oss-swift/blob/9f99b5cb6a907730543823ad271b82532782a899/Sources/WhisperKit/Core/Configurations.swift).

Release v1.1.1 documents a cancellation fix: incomplete model downloads now throw rather than returning a partially populated directory as a successful result. Include cancellation and incomplete-asset recovery in adoption tests. This is upstream release evidence, not a test result for MemoryOS. [Argmax v1.1.1 release](https://github.com/argmaxinc/argmax-oss-swift/releases/tag/v1.1.1).

## Four protections worth keeping

1. **Own the information, not just a wrapper.** Keep one logical canonical store for original records, stable IDs, corrections, transcript revisions, and source links. Use vendor indexes as derived projections when possible. Logical ownership need not mean several duplicate primary databases. Choose the concrete storage design separately.
2. **Adopt versions deliberately.** Review a release/revision and retain the app's `Package.resolved`. Configure integration/release builds to use resolved versions and reject accidental resolution changes. Pin model assets/configuration separately. A lockfile does not validate model files, migrations, or runtime behavior. SwiftPM documents explicit remote version requirements and notes that local path dependencies do not enforce version constraints. [SwiftPM dependency guidance](https://docs.swift.org/latest/documentation/packagemanagerdocs/addingdependencies/).
3. **Experiment outside the app's normal dependency state.** Use an upstream checkout and its tests/harness first. Apple supports a local package override for app integration; that override changes the development app's dependency intentionally. Remove it and verify the final resolved configuration before delivery. Keep a fork only when a required patch warrants its maintenance. [Apple local override](https://developer.apple.com/documentation/xcode/editing-a-package-dependency-as-a-local-package.md).
4. **Prove replacement and recovery.** A small adapter limits source changes. It cannot prove data-format, capability, model, concurrency, or performance compatibility. Test the swap using preserved app-owned records, verified export/rebuild or migration, and a recovery path.

Local `xcodebuild -help` on this machine confirms `-disableAutomaticPackageResolution` and `-onlyUsePackageVersionsFromResolvedFile` prevent resolution to versions outside the resolved file. `-skipPackageUpdates` has a different description: skipping remote updates. Select flags for the actual build path and test them when CI is configured; do not treat the third flag alone as a version-adoption policy.

## Proposed evidence before adopting a provider

| Check | Required evidence |
| --- | --- |
| Build and dependency boundary | Compile the core without provider dependencies; compile the real adapter with the reviewed SDK/toolchain and supported platform. Inspect public API/import boundaries. |
| Adapter contract | Observable success/failure behavior, source-ID mapping, cancellation, deletion/correction where applicable, and unsupported capability handling. |
| Offline and asset lifecycle | Prepared model/tokenizer assets, explicit missing-asset state, interrupted-download recovery, and successful offline execution without silent network fallback. |
| Arabic and English quality | Fictional Arabic, Iraqi Arabic, English, mixed-language examples, names, and dates; known-answer retrieval or transcription expectations. |
| Replaceability | Candidate and controlled substitute/alternative implementation exercise the same app contract. Verify retained source data, corrected text, deletion, and rebuilt/migrated results. |
| Durable-data update | Backup/restore, interrupted migration, schema/export compatibility, and an actually usable recovery path. |
| Device performance | Same physical phone, Release configuration, workload/data, and model assets for baseline/candidate. Record cold/warm timing, memory, storage, and relevant energy/thermal results. |

Step 1 chooses numeric acceptance thresholds. This research does not supply invented speed or accuracy targets. A full migration framework and performance lab need not precede the first demo; implement the checks relevant to the first real capability and expand them as durable data and workloads grow.

## Decision and implementation boundary

D30 remains the current policy: one app repository, small replaceable integrations, and controlled upstream adoption. The recommended improvement is the timing and placement of a few real local targets, plus explicit provider-fit/replacement evidence. It does not require custom engine repositories or a permanent fork of Wax.

Architecture fit and library fit are separate decisions. This review supports the architecture direction, while Wax, WhisperKit, alternatives, concrete storage, and model configurations still require the relevant authorized experiment. No package dependency was added, no library/model was installed for this review, and no app behavior or benchmark result changed.

Related records: [current upstream-library decision](../decisions/independent-engine-packages.md), [commercial/engineering rules](../how-to/commercial-engineering-rules.md), and [three-step workflow](../how-to/development-workflow.md).
