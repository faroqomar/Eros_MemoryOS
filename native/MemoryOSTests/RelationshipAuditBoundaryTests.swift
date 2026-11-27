import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor AuditBoundaryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

private actor AuditBoundaryModel: StructuredChatModel {
  let proposal: String
  private(set) var auditRequest: String?
  init(proposal: String) { self.proposal = proposal }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    if grammar.contains("supported") {
      auditRequest = turns.last?.text
      return #"{"assessment":"Controlled boundary check.","supported":true,"complete":true}"#
    }
    return proposal
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {}
  func unload() {}
}

struct RelationshipAuditBoundaryTests {
  /// Exercises the real adapter payload for each output shape. This does not judge model meaning.
  @Test(arguments: RelationshipAnalysisFocus.allCases)
  func auditReceivesAllClaimsAndCitationsWithoutTheGeneratorCapacityFlag(
    focus: RelationshipAnalysisFocus
  ) async throws {
    let source = PersonalMemorySource(
      conversationID: UUID(), text: "Mina: I can review the text on Tuesday if useful.",
      kind: .conversationOnly)
    let memory = PersonalMemoryUseCases(repository: AuditBoundaryRepository())
    _ = try await memory.ingest(source: source)
    let before = try await memory.snapshot()
    let raw = proposal(focus: focus)
    let model = AuditBoundaryModel(proposal: raw)
    _ = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    ).analyze(
      .init(
        sourceIDs: [source.id], question: "What does the source support?",
        draftRequested: focus == .draft, focus: focus))
    let request = try #require(await model.auditRequest)
    let parts = request.components(separatedBy: "\nProposed answer to check, not evidence:\n")
    try #require(parts.count == 2)
    let actual = try #require(
      JSONSerialization.jsonObject(with: Data(parts[1].utf8)) as? [String: Any])
    var expected = try #require(
      JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    expected.removeValue(forKey: "complete")
    #expect(actual["complete"] == nil)
    #expect(
      try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys])
        == JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]))
    #expect(try await memory.snapshot() == before)
  }

  private func proposal(focus: RelationshipAnalysisFocus) -> String {
    switch focus {
    case .discussion:
      #"{"complete":true,"events":[{"text":"Mina offered a review on Tuesday.","act":"offer","citations":["P0"]}]}"#
    case .draft:
      #"{"complete":true,"events":[{"text":"Mina offered a review on Tuesday.","act":"offer","citations":["P0"]}],"draft":"Thanks. May I send the text first?"}"#
    case .patterns:
      #"{"complete":true,"hypotheses":[{"text":"Mina may want to help.","kind":"interpretation","citations":["P0"],"alternative":"Mina may be checking availability.","counterevidence":["P0"]}]}"#
    case .advice:
      #"{"complete":true,"options":[{"text":"Ask about the review scope.","citations":["P0"],"downside":"This needs another exchange."}]}"#
    case .conversation, .topic, .period:
      #"{"complete":true,"summary":{"title":"Review offer","text":"Mina offered to review the text on Tuesday if useful.","citations":["P0"]}}"#
    }
  }
}
