# Wax evaluation adapter

This package connects the real pinned Wax SDK to `AIEvaluationCore.MemoryIndexAdapter`. It uses fictional records from the shared evaluation suite. It does not connect the app's production record database.

`WaxEvaluationAdapter` exports:

```swift
public actor WaxMemoryIndexAdapter: MemoryIndexAdapter {
  public init(directory: URL)
  public func rebuild(records: [SourceRecord]) async throws
  public func search(query: String, limit: Int) async throws -> [RetrievedSource]
  public func close() async throws
}
```

The composition root must supply an experiment directory. The adapter creates a unique child directory for each index build and removes only its generated children. Keep canonical data outside those children. `close()` releases the index and removes its generated directory. A failed input validation preserves the previous index. The adapter rejects concurrent operations with a visible unavailable error.

The manifest pins Wax 0.1.47 revision `e4587f8cebb76aa92ece008253f13c66b756e68b` and passes an empty SwiftPM traits set. The adapter disables vectors, async enrichment, structured memory and access-stat ranking. Each query requests `textOnly` and checks the effective retrieval mode. This release uses its own context budget and has no public `maxContextTokens` or `inferTimeRange` search options. The current suite uses short sources and no relative-time query. Long-context retrieval remains outside these results. This measures Wax lexical retrieval, not multilingual semantic memory. The source checkout can still contain upstream bundled model resources; empty traits prevent those embedding products from linking.

The adapter preserves source IDs through metadata. Wax can deduplicate identical text, so the adapter groups byte-identical source text and stores all canonical IDs for that text. Search expands those IDs and enforces the requested limit. Original records stay immutable in the caller's corpus. Results retain Wax scores without treating scores as calibrated probabilities.

Run contracts with:

```sh
swift test --package-path native/LocalAIIntegrations -c release
```

Run the same fictional suite used by the app lab with:

```sh
swift run --package-path native/LocalAIIntegrations -c release wax-evaluation \
  --source-identity REVIEWED-COMMIT-OR-SOURCE-MANIFEST \
  --toolchain 'EXACT-OUTPUT-FROM-swift---version'
```

The runner writes JSON to standard output. It records lexical source IDs, retrieval timings, host process lifetime RSS high-water and current index logical file bytes. It marks text generation as outside this retrieval experiment. It cannot establish phone battery, phone heat, model quality, semantic search quality or a production winner. The runner does not claim airplane-mode verification.

Stock 0.1.47 passes the current host contracts but fails iOS compilation in desktop broker/Git helpers. The explicit [iOS guard patch](Patches/README.md) has separate source and compiler evidence. Use the documented local workspace override for that experimental configuration. The canonical manifest has no implicit override. Supply `--sdk-patch-sha256 SHA256` to the host runner when testing a patched SDK so the JSON records its provenance.

Dependency/build/contract results belong to the current task evidence, not to these instructions. Preserve `Package.resolved` after successful resolution. Test simulator compilation against the final resolved source separately from host contracts.
