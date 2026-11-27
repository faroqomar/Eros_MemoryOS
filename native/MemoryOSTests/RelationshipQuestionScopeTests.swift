import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor QuestionScopeAnalyzer: RelationshipAnalyzing {
  private(set) var requests: [RelationshipAnalysisRequest] = []
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal {
    requests.append(input.request)
    return .init()
  }
}

@MainActor struct RelationshipQuestionScopeTests {
  @Test(arguments: [false, true])
  func specificQuestionRoundTripsWithoutUnrequestedCategories(arabic: Bool) async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let memory = PersonalMemoryComposition.makeUseCases(directory: directory)
    let sourceID = UUID()
    _ = try await memory.ingest(
      source: .init(
        id: sourceID, conversationID: UUID(), text: "The request has no reply yet.",
        origin: "fictional"))
    let before = try await memory.snapshot()
    let analyzer = QuestionScopeAnalyzer()
    let cases = RelationshipUnderstandingUseCases(memory: memory, analyzer: analyzer)
    let model = RelationshipViewModel(useCases: cases)
    model.selected = [sourceID]
    model.answerInArabic = arabic
    model.question = arabic ? "هل يوجد وعد؟\nومن طلب؟" : "Was there a promise?\nWho asked?"
    let originalQuestion = model.question
    await model.analyze()
    let request = try #require(await analyzer.requests.first)
    #expect(
      request.question == (arabic ? "Answer in Arabic.\n" : "Answer in English.\n")
        + originalQuestion)
    #expect(request.focus == .discussion)
    #expect(request.sourceIDs == [sourceID])
    let report = try #require(model.result)
    model.question = "Changed field"
    model.answerInArabic = !arabic
    await model.openSaved(report)
    #expect(model.question == originalQuestion)
    #expect(model.answerInArabic == arabic)
    await model.analyze()
    #expect(try await memory.snapshot() == before)
  }

  @Test(arguments: [false, true])
  func emptyQuestionKeepsDefaultTaskAndLegacyReportsReopen(arabic: Bool) async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let memory = PersonalMemoryComposition.makeUseCases(directory: directory)
    let sourceID = UUID()
    _ = try await memory.ingest(
      source: .init(
        id: sourceID, conversationID: UUID(), text: "A fictional saved statement.",
        origin: "fictional"))
    let analyzer = QuestionScopeAnalyzer()
    let cases = RelationshipUnderstandingUseCases(memory: memory, analyzer: analyzer)
    let model = RelationshipViewModel(useCases: cases)
    model.selected = [sourceID]
    model.mode = .topic
    model.answerInArabic = arabic
    await model.analyze()
    let prefix = model.mode.instruction + (arabic ? "\nAnswer in Arabic." : "\nAnswer in English.")
    #expect(await analyzer.requests.first?.question == prefix)
    let report = try await cases.analyze(
      .init(sourceIDs: [sourceID], question: prefix + "\nOriginal legacy question", focus: .topic))
    await model.openSaved(report)
    #expect(model.question == "Original legacy question")
    #expect(model.answerInArabic == arabic)
    #expect(model.mode == .topic)
  }

}
