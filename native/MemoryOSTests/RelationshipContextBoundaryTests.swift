import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor ContextBoundaryRepository: PersonalMemoryRepository {
  var snapshot = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { snapshot }
  func save(_ value: PersonalMemorySnapshot) { snapshot = value }
}

private actor ContextBoundaryModel: StructuredChatModel {
  private(set) var input: String?
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    if grammar.contains("assessment") {
      return #"{"assessment":"Controlled transport check.","supported":true,"complete":true}"#
    }
    input = turns.last?.text
    if grammar.contains("options") { return #"{"complete":true,"options":[]}"# }
    return
      #"{"complete":true,"events":[{"text":"A request to listen was made.","act":"request","citations":["P0"]}]}"#
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {}
  func unload() {}
}

struct RelationshipContextBoundaryTests {
  @Test(arguments: [RelationshipAnalysisFocus.discussion, .advice])
  func relationshipLensDoesNotBecomeFactualParticipantIdentity(focus: RelationshipAnalysisFocus)
    async throws
  {
    let memory = PersonalMemoryUseCases(repository: ContextBoundaryRepository())
    let source = PersonalMemorySource(text: "سلمى: ممكن تسمعيني؟", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let model = ContextBoundaryModel()
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
    _ = try await useCases.analyze(
      .init(
        sourceIDs: [source.id], question: "ماذا طلبت سلمى؟", relationship: .colleague, focus: focus)
    )
    let text = try #require(await model.input)
    let input = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    if focus == .discussion {
      #expect(input["relationship"] == nil)
    } else {
      #expect(input["relationship"] as? String == "colleague")
    }
    #expect(try await memory.snapshot().sources == [source])
  }
}
