# Runtime memory options: Wax and Cactus

Recorded on 2026-11-07. Owner source: C07 in the [source register](../reference/source-register.md).

## Decision and status

**Confirmed:** Keep Wax and Cactus as candidate options for the iPhone app's memory system. Plan for switching between them and comparing experiments before choosing a final system.

This decision records the shortlist and the switching goal. It does not select a production memory dependency, approve implementation, or establish that either option works on the owner's phone. No experiment has run. The local LLM remains open. A later owner decision, D21/C10, selects Swift with SwiftUI for the app; see [current demo direction](demo-and-feature-direction.md).

**Assistant recommendation:** Evaluate Wax first. Build MemoryOS-specific memory rules around reusable components. Keep a custom memory engine as a fallback if the candidates fail important requirements.

## Candidate options

### Wax

- Role: local memory storage and retrieval inside the app.
- Its documentation describes an embedded Swift library with keyword and meaning-based search.
- Its save operation does not use an LLM to extract facts. MemoryOS would supply extraction, corrections, and product rules.
- Its documentation says the structured graph's Swift CRUD interface is package-internal. People, relationships, and fact history may need app-owned records or another integration.
- Status: shortlisted; no MemoryOS integration or iPhone verification.

Source: [Wax repository and Swift app documentation](https://github.com/christopherkarani/Wax#swift-app).

### Cactus-based memory option

- Role: local AI execution and retrieval components, combined with MemoryOS-owned storage and memory rules.
- Cactus is not a complete replacement for Wax's memory store. A Cactus-based option needs an adapter, meaning code that connects its available components to the app's memory interface.
- Earlier mobile SDK documentation described Swift bindings, embeddings, and a local vector index. Current upstream documentation points to `cactus-engine` for the earlier general inference SDK. The current main package focuses on Python tools and local models.
- Verify the exact maintained mobile package, version, iOS API, model support, and retrieval features before an experiment. Do not assume old examples describe the current package.
- Status: shortlisted; exact mobile integration unresolved; no MemoryOS integration or iPhone verification.

Sources: [current Cactus repository](https://github.com/cactus-compute/cactus), [Cactus engine package referenced by upstream](https://pypi.org/project/cactus-engine/). Documentation reviewed on 2026-11-07; package support can change.

These options cover different technical roles. We can compare complete memory configurations, and could use Wax with a Cactus model runtime if compatibility permits. That combination is a proposal, not a verified integration.

## Proposed switching design

The following design supports the owner's switching goal. Update C23/D27, 2026-11-13: app-owned source records, replaceable adapters, and rebuildable provider indexes are now standing [engineering requirements](../how-to/commercial-engineering-rules.md). Exact APIs, storage choices, and experiments remain open; this policy does not establish implementation or verification.

1. Keep app-owned copies of original captures, stable record IDs, source links, dates, relationships, and corrections. A provider-specific index must not be the only copy.
2. Define one memory interface for saving, searching, correcting, deleting, and rebuilding an index. Require source IDs in retrieval results. Implement missing provider behavior in the adapter and report unsupported operations.
3. Connect the chosen local LLM through a separate model interface. Changing the memory option should not force a model change. Check model/runtime compatibility; arbitrary models are not interchangeable.
4. Keep separate experimental indexes for each option. Rebuild from the app-owned records when switching. Do not assume Wax and Cactus share a file format or embedding format. Recompute meaning-search vectors when changing embedding models.
5. Preserve the original records during a switch. Verify record counts, source links, corrections, and deletions before using the new index. Keep the previous working configuration available for rollback.

The memory store keeps information outside the LLM. Adding a memory does not require retraining the model. Switching is a planned workflow; no instant live-switch feature exists.

## Proposed experiment acceptance

Use the same fictional Arabic, Iraqi Arabic, English, and mixed-language examples for each configuration. Keep the model and retrieval settings comparable where possible, and record differences.

- After model downloads, save and retrieve records in airplane mode on the iPhone 15 Pro Max.
- Find a known detail and show its original source. Report missing evidence instead of inventing an answer.
- Correct and delete information, restart the app, and verify the resulting answers and records.
- Switch options and rebuild indexes without losing sources, relationships, or corrections. Verify rollback.
- Record answer quality, retrieval quality, response time, storage, app memory use, battery use, and heat.

Choose numeric targets after reviewing initial measurements. A successful desktop run or upstream benchmark does not prove phone performance. Do not upload captures or enable a cloud fallback as part of a local experiment.

## Development-memory boundary

The existing Hindsight bank, `project-memoryos`, remains the separate documentation memory for coding agents. Listing Wax and Cactus here does not replace, migrate, or reconfigure that service.

Related records: [decision register](decision-register.md), [product overview](../product-overview.md), [Hindsight workflow](../how-to/hindsight.md).


## Evaluation implementation update, C38, 2026-11-14

The owner starts checklist group 4 Step 1. The [evaluation task](../tasks/2026-11-14-local-ai-phone-evaluation.md) now owns its contract, common fictional corpus, provisional budgets, isolated lab and actual results. The keyword control is implemented. Wax adapter source is prepared, but dependency resolution/compilation and contracts remain blocked. Cactus needs a supported reviewed native configuration; old Python/package references do not establish that configuration. The [current upstream review](../reference/2026-11-14-local-ai-support.md) records exact candidate pins and support limits. No target-phone experiment or final selection has passed. The earlier no-experiment statement describes the November 7 checkpoint.

## Measured Simulator update, C39–C40, 2026-11-15

Step 1 now completes real Wax/Cactus retrieval and llama.cpp model comparisons, with separate actual Mac MLX tests and an explicit Simulator-unavailable path. All required downloads and canonical dependency checks finish. The [measured summary](../evidence/local-ai-2026-11-14/resume-summary.md) replaces the earlier unfinished-integration checkpoint.

Builder recommendation: llama.cpp CPU/Accelerate is the current Simulator text-runtime baseline; Wax lexical is the lower-cost provider baseline. Corrected Cactus last-token retrieval remains a replaceable semantic experiment. Both providers return unrelated sources for the no-evidence query. Qwen3-1.7B improves source citation behavior over 0.6B but still fails the Iraqi/Arabic requirements. No production model/provider is adopted.

These experiment choices keep canonical originals, IDs, source links and corrections in the existing app-owned store. Indexes are derivatives. The historical custom-engine fallback recommendation does not override D30/C26: use upstream libraries and thin app-owned interfaces, without starting a new custom engine repository. Physical phone cost, human review and independent Step 2 remain separate.

## Main-app integration authorized, 2026-11-18

The owner authorizes implementing Wax and Cactus for automatic local recall before chat replies. The [integration task](../tasks/2026-11-18-local-recall-integration.md) connects both existing pinned providers through app-owned interfaces, with hybrid retrieval as the initial composition. This supersedes the earlier evaluation-only implementation boundary for this narrow path. It does not assert production quality, physical qualification or release readiness.

Keep original records and corrections authoritative. Returned IDs and exact passages require fresh source validation after search. Queries remain transient, including private-session queries. A separate semantic extraction gate remains disabled after failed local-model diagnostics; retrieval integration alone does not pass it.
