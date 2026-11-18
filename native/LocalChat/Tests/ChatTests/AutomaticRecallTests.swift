import ChatCore
import Foundation
import Testing

@Test func sourceVersionDetectsCorrectionsWithoutMistakingExcerptLabelsForEdits() throws {
  let evidence = ChatEvidence(
    id: UUID(), text: "[original; dated] Partial excerpt", sourceText: "Full original e\u{301}")
  #expect(evidence.matchesCurrentText("Full original e\u{301}"))
  #expect(!evidence.matchesCurrentText("Full original é"))
  #expect(!evidence.matchesCurrentText("Corrected text"))
  let decoded = try JSONDecoder().decode(ChatEvidence.self, from: JSONEncoder().encode(evidence))
  #expect(decoded == evidence)
  let legacy = try JSONDecoder().decode(
    ChatEvidence.self,
    from: Data("{\"id\":\"\(UUID().uuidString)\",\"text\":\"Legacy\"}".utf8))
  #expect(legacy.matchesCurrentText("Legacy"))
}

@Test func ordinaryChatRetrievesSavedContextBeforeAnswering() async throws {
  let evidence = ChatEvidence(id: UUID(), text: "[user-reported] Work starts at 10 AM")
  let memory = TestMemory([evidence])
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  _ = try await useCases.load()
  let state = try await useCases.generate(submittedText: "When should I leave for work?") { _ in }
  #expect(await memory.queries == ["When should I leave for work?"])
  let prompt = try #require(await model.requests.first?.first?.text)
  #expect(prompt.contains(evidence.id.uuidString))
  #expect(prompt.contains(evidence.text))
  #expect(state.conversations[0].messages.last?.sources == [evidence])
}

@Test func ordinaryChatWithNoRelatedMemoryStillAnswers() async throws {
  let memory = TestMemory([])
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  _ = try await useCases.load()
  let state = try await useCases.generate(submittedText: "Explain a rainbow") { _ in }
  #expect(await memory.queries == ["Explain a rainbow"])
  #expect(await model.requests.count == 1)
  #expect(state.conversations[0].messages.last?.status == .complete)
  #expect(await model.requests.first?.first?.text.contains("No matching saved evidence") == true)
}

@Test func ordinaryChatRefreshesCorrectedMemoryWithoutReusingOldAnswerAsEvidence() async throws {
  let id = UUID()
  let memory = TestMemory([ChatEvidence(id: id, text: "Work starts at 9 AM")])
  let model = TestModel()
  await model.setReply("Your work starts at 9 AM")
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  _ = try await useCases.load()
  _ = try await useCases.generate(submittedText: "What is my start time?") { _ in }
  await memory.replace([ChatEvidence(id: id, text: "Work starts at 10 AM")])
  _ = try await useCases.generate(submittedText: "What time now?") { _ in }
  let turns = try #require(await model.requests.last)
  #expect(turns.first?.text.contains("10 AM") == true)
  #expect(!turns.contains { $0.text.contains("9 AM") })
}

@Test func temporaryOrdinaryChatUsesRecallWithoutPersistingTheQuery() async throws {
  let repository = TestRepository()
  let memory = TestMemory([ChatEvidence(id: UUID(), text: "Likes quiet cafes")])
  let model = TestModel()
  let useCases = ChatUseCases(repository: repository, model: model, memory: memory)
  _ = try await useCases.load()
  _ = try await useCases.startTemporary()
  _ = try await useCases.generate(submittedText: "PRIVATE cafe question") { _ in }
  #expect(await memory.queries == ["PRIVATE cafe question"])
  #expect(await model.requests.first?.first?.text.contains("quiet cafes") == true)
  #expect(
    !String(decoding: try JSONEncoder().encode(await repository.snapshot), as: UTF8.self)
      .contains("PRIVATE"))
}
