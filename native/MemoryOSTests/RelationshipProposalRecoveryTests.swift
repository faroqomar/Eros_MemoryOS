import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor ProposalRecoveryRepository: PersonalMemoryRepository {
  private var state = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { state }
  func save(_ value: PersonalMemorySnapshot) { state = value }
}

private actor ProposalRecoveryModel: StructuredChatModel {
  let mode: String
  private(set) var stages: [String] = []
  private(set) var proposals = 0
  init(mode: String) { self.mode = mode }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) throws -> String {
    if grammar.contains("supported") {
      stages.append("audit")
      return
        #"{"assessment":"Controlled recovery transport check.","supported":true,"complete":true}"#
    }
    stages.append("proposal")
    proposals += 1
    if mode == "context" { throw ChatError.contextLimit }
    if mode == "cancel" { throw CancellationError() }
    if mode == "exhaust" || (mode == "schema" && proposals == 1) {
      return #"{"complete":true,"unadvertised":[]}"#
    }
    if mode == "domain" && proposals == 1 {
      return #"{"complete":true,"events":[{"text":"   ","act":"observation","citations":["P0"]}]}"#
    }
    return
      #"{"complete":true,"events":[{"text":"Noor has not replied.","act":"observation","citations":["P0"]}]}"#
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {}
  func unload() {}
}

struct RelationshipProposalRecoveryTests {
  @Test(arguments: ["schema", "domain", "exhaust", "context", "cancel"])
  func proposalRecoveryIsBoundedAndDoesNotRetryRuntimeOrCancellation(mode: String) async throws {
    let memory = PersonalMemoryUseCases(repository: ProposalRecoveryRepository())
    let source = PersonalMemorySource(text: "Noor has not replied.", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let before = try await memory.snapshot()
    let model = ProposalRecoveryModel(mode: mode)
    let cases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
    let request = RelationshipAnalysisRequest(sourceIDs: [source.id], question: "What is recorded?")
    switch mode {
    case "exhaust":
      await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
        try await cases.analyze(request)
      }
      #expect(await model.stages == ["proposal", "proposal"])
    case "context":
      await #expect(throws: RelationshipUnderstandingError.inputTooLarge) {
        try await cases.analyze(request)
      }
      #expect(await model.stages == ["proposal"])
    case "cancel":
      await #expect(throws: CancellationError.self) { try await cases.analyze(request) }
      #expect(await model.stages == ["proposal"])
    default:
      let result = try await cases.analyze(request)
      #expect(result.findings.count == 1 && !result.insufficientEvidence)
      #expect(result.findings.first?.evidence == [.init(sourceID: source.id, quote: source.text)])
      #expect(await model.stages == ["proposal", "proposal", "audit"])
    }
    #expect(try await memory.snapshot() == before)
  }
}
