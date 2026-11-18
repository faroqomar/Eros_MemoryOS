import CryptoKit
import Foundation
import LocalMemoryRetrieval
import RetrievalCore
import Testing

struct IndependentRecallTests {
  struct Fixture: Decodable {
    struct Record: Decodable {
      let id: String
      let text: String
    }
    struct Case: Decodable {
      let id: String
      let query: String
      let expectedIDs: [String]
    }
    let records: [Record]
    let cases: [Case]
  }
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RECALL_INDEPENDENT_FIXTURE"] != nil))
  func frozenIndependentRawAndDecoratedSources() async throws {
    let environment = ProcessInfo.processInfo.environment
    let file = try #require(environment["MEMORYOS_RECALL_INDEPENDENT_FIXTURE"])
    let model = try #require(environment["CACTUS_EVAL_MODEL_DIR"])
    let data = try Data(contentsOf: URL(fileURLWithPath: file))
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    #expect(digest == "69747eb3ddbc0bb60ae922bf954bc1301f4c8515f4c21b9591107e05ff10f41c")
    let fixture = try JSONDecoder().decode(Fixture.self, from: data)
    var rows: [[String: Any]] = []
    for provider in LocalRecallProvider.allCases {
      for decorated in [false, true] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
          "memoryos-retrieval-adapter-independent-" + UUID().uuidString)
        let search = LocalMemorySearch(
          directory: root, cactusModelDirectory: URL(fileURLWithPath: model), provider: provider)
        let records = fixture.records.map { row in
          MemorySearchRecord(
            id: row.id,
            text: (decorated
              ? "[original statement; 2026-11-18T12:00:00Z; meaning unresolved; not a confirmed fact] "
              : "") + row.text)
        }
        for item in fixture.cases {
          let start = ContinuousClock.now
          let hits = try await search.search(query: item.query, records: records, limit: 3)
          let duration = start.duration(to: .now).components
          let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
          let passed =
            item.expectedIDs.isEmpty ? hits.isEmpty : hits.first?.sourceID == item.expectedIDs.first
          rows.append([
            "provider": provider.rawValue, "decorated": decorated, "case": item.id,
            "expected": item.expectedIDs, "actual": hits.map(\.sourceID), "passed": passed,
            "seconds": seconds,
          ])
          #expect(passed, "\(provider.rawValue), decorated=\(decorated), case=\(item.id)")
        }
        try await search.close()
        try FileManager.default.removeItem(at: root)
      }
    }
    let output: [String: Any] = ["fixtureSHA256": digest, "minimumSimilarity": 0.65, "rows": rows]
    try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
      .write(to: URL(fileURLWithPath: "/tmp/memoryos-retrieval-adapter-independent-result.json"))
  }
}
