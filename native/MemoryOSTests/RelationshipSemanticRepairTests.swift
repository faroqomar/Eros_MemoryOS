import ChatCore
import CryptoKit
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private struct RelationshipRepairInputs: Decodable {
  let inputs: [Case]
  struct Case: Decodable {
    let id, language, query, questionDate: String
    let sources: [Source]
    let ownerAccount: String?
  }
  struct Source: Decodable {
    let id: UUID
    let text, createdAt, origin: String
    let kind: PersonalMemoryKind
  }
}

/// Diagnostics are restricted to the pinned, already consumed fictional fixture.
/// The app never logs prompts or generated private content through this test wrapper.
private actor RelationshipRepairTrace: StructuredChatModel {
  struct Call: Codable, Sendable {
    let stage: String
    let seconds: Double
    let output: String?
    let error: String?
  }
  let base: any StructuredChatModel
  private(set) var calls: [Call] = []
  init(base: any StructuredChatModel) { self.base = base }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let stage = grammar.contains("supported") ? "meaning-audit" : "proposal"
    let started = ProcessInfo.processInfo.systemUptime
    do {
      let raw = try await base.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
      calls.append(
        .init(
          stage: stage, seconds: ProcessInfo.processInfo.systemUptime - started,
          output: raw, error: nil))
      return raw
    } catch {
      calls.append(
        .init(
          stage: stage, seconds: ProcessInfo.processInfo.systemUptime - started,
          output: nil, error: String(describing: error)))
      throw error
    }
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await base.generate(turns: turns, onText: onText)
  }
  func unload() async { await base.unload() }
}

/// Consumed regression diagnostics only. Completion and structural assertions do not score meaning.
@Suite(.serialized) @MainActor struct RelationshipSemanticRepairTests {
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RELATIONSHIP_REPAIR_INPUT"] != nil),
    .timeLimit(.minutes(10)))
  func traceConsumedSemanticFailures() async throws {
    let environment = ProcessInfo.processInfo.environment
    let inputURL = URL(
      fileURLWithPath: try #require(environment["MEMORYOS_RELATIONSHIP_REPAIR_INPUT"]))
    let outputURL = URL(
      fileURLWithPath: try #require(environment["MEMORYOS_RELATIONSHIP_REPAIR_OUTPUT"]))
    let bytes = try Data(contentsOf: inputURL)
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try #require(digest == "b2adb4683bd208c4bfcc93ae71a8933ba5183d6a8a57d88c3d6783eb7fddd93c")
    let fixture = try JSONDecoder().decode(RelationshipRepairInputs.self, from: bytes)
    let selected = (environment["MEMORYOS_RELATIONSHIP_REPAIR_CASES"] ?? "fresh-02,fresh-10")
      .split(separator: ",").map(String.init)
    let allowed = Set(["fresh-02", "fresh-04", "fresh-07", "fresh-10", "fresh-14"])
    try #require(!selected.isEmpty && Set(selected).count == selected.count)
    try #require(Set(selected).isSubset(of: allowed))
    let configuration = try RuntimeTestModel.configuration()
    var rows: [[String: Any]] = []
    for caseID in selected {
      let item = try #require(fixture.inputs.first { $0.id == caseID })
      let directory = URL.temporaryDirectory.appending(
        path: "relationship-repair-" + UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: directory) }
      let memory = PersonalMemoryComposition.makeUseCases(directory: directory)
      let conversationID = UUID()
      let formatter = ISO8601DateFormatter()
      for source in item.sources {
        _ = try await memory.ingest(
          source: .init(
            id: source.id, conversationID: conversationID, text: source.text,
            createdAt: try #require(formatter.date(from: source.createdAt)),
            origin: source.origin, kind: source.kind))
      }
      let before = try await memory.snapshot()
      let model = RelationshipRepairTrace(
        base: LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel()))
      let useCases = RelationshipUnderstandingUseCases(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
      let viewModel = RelationshipViewModel(useCases: useCases)
      viewModel.selected = Set(item.sources.map(\.id))
      viewModel.question = item.query + "\nQuestion date: " + item.questionDate
      viewModel.ownerInterpretation = item.ownerAccount ?? ""
      viewModel.answerInArabic = item.language == "ar-IQ"
      let started = ProcessInfo.processInfo.systemUptime
      await viewModel.analyze()
      var row: [String: Any] = [
        "caseID": caseID, "seconds": ProcessInfo.processInfo.systemUptime - started,
        "calls": try JSONSerialization.jsonObject(with: JSONEncoder().encode(await model.calls)),
      ]
      if let error = viewModel.error { row["error"] = String(describing: error) }
      if let result = viewModel.result {
        row["proposal"] = try JSONSerialization.jsonObject(
          with: JSONEncoder().encode(result.proposal))
        row["insufficientEvidence"] = result.insufficientEvidence
      }
      let after = try await memory.snapshot()
      row["personalStateUnchanged"] = after == before
      #expect(after == before)
      #expect(!PersonalMemoryComposition.automaticMemoryQualified)
      await model.unload()
      rows.append(row)
      let result: [String: Any] = [
        "protocol":
          "Consumed fictional regression with actual app ViewModel and per-stage local-model trace; manual meaning review required.",
        "fixtureSHA256": digest, "model": configuration.selection,
        "modelSHA256": configuration.expectedSHA256, "results": rows,
      ]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: outputURL, options: .atomic)
    }
  }
}
