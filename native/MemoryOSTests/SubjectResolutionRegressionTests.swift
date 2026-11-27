import ChatCore
import Foundation
import RetrievalCore
import Testing

@testable import MemoryOS

private actor ResolutionCandidates: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    Array(records.prefix(limit)).map { .init(sourceID: $0.id, score: 1) }
  }
}

private actor ResolutionTraceModel: StructuredChatModel {
  let base: any StructuredChatModel
  private(set) var outputs: [String] = []
  init(base: any StructuredChatModel) { self.base = base }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let output = try await base.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    outputs.append(output)
    return output
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await base.generate(turns: turns, onText: onText)
  }
  func unload() async { await base.unload() }
}

/// Consumed regression probes at the real subject/relevance seam. Candidate ranking is
/// deliberately bypassed to isolate the classifier; this is not a full-pipeline score.
@Suite(.serialized) @MainActor struct SubjectResolutionRegressionTests {
  private struct Probe: Decodable {
    let id: String
    let query: String
    let records: [Record]
    let expectedIDs: [String]
    let expectedNames: [String]?
    struct Record: Decodable {
      let id: String
      let text: String
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_SUBJECT_PROBES"] != nil))
  func consumedSubjectFailures() async throws {
    let environment = ProcessInfo.processInfo.environment
    let input = try #require(environment["MEMORYOS_SUBJECT_PROBES"])
    let output = try #require(environment["MEMORYOS_SUBJECT_RESULTS"])
    let probes = try JSONDecoder().decode(
      [Probe].self, from: Data(contentsOf: URL(fileURLWithPath: input)))
    try #require((1...12).contains(probes.count))
    let model = ResolutionTraceModel(
      base: LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel()))
    var results: [[String: Any]] = []
    for probe in probes {
      let before = await model.outputs.count
      let start = ProcessInfo.processInfo.systemUptime
      let search = LocalMeaningSearch(
        candidates: ResolutionCandidates(), model: model, unloadAfterSearch: false)
      var row: [String: Any] = ["id": probe.id, "query": probe.query]
      do {
        let hits = try await search.search(
          query: probe.query,
          records: probe.records.map { .init(id: $0.id, text: $0.text) }, limit: 8)
        let actual = hits.map(\.sourceID)
        row["actualIDs"] = actual
        row["passed"] = Set(actual) == Set(probe.expectedIDs)
        #expect(Set(actual) == Set(probe.expectedIDs), "Consumed subject regression: \(probe.id)")
      } catch {
        row["error"] = String(describing: error)
        row["passed"] = false
        Issue.record("Consumed subject regression \(probe.id): \(error)")
      }
      let outputs = Array(await model.outputs.dropFirst(before))
      row["outputs"] = outputs
      if let expected = probe.expectedNames {
        let wire: [String: Any]?
        if let first = outputs.first {
          wire = try JSONSerialization.jsonObject(with: Data(first.utf8)) as? [String: Any]
        } else {
          wire = nil
        }
        let names = wire?["subjects"] as? [String]
        let matched = names.map { Set($0) == Set(expected) } ?? false
        row["namedScopePassed"] = matched
        #expect(matched, "Consumed named-subject scope: \(probe.id)")
        if outputs.count >= 2 {
          let resolution =
            try JSONSerialization.jsonObject(with: Data(outputs[1].utf8))
            as? [String: Any]
          #expect(
            resolution?["resolution"] as? String == (expected.isEmpty ? "generic" : "complete"),
            "Consumed subject resolution: \(probe.id)")
        }
      }
      row["seconds"] = ProcessInfo.processInfo.systemUptime - start
      results.append(row)
      try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        .write(to: URL(fileURLWithPath: output), options: .atomic)
    }
    await model.unload()
  }
}
