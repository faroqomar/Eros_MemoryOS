import Foundation
import MemoryCore
import Testing

private actor ProvenanceRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct ProvenanceAnalyzer: RelationshipAnalyzing {
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal { .init() }
}

struct InterpretationProvenanceTests {
  private func prepared(_ memory: PersonalMemoryUseCases, sourceID: UUID) async throws
    -> RelationshipAnalysisInput
  {
    try await RelationshipUnderstandingUseCases(memory: memory, analyzer: ProvenanceAnalyzer())
      .prepare(.init(sourceIDs: [sourceID], question: "Review this interpretation"))
  }

  @Test func profileAnswerKeepsOwnerReviewWithoutFactPromotionAcrossRestoreAndUndo() async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let answer = "قد يكون عمر بحاجة إلى وقت إضافي."
    let snapshot = try await memory.answerProfileQuestion(
      profileID: PersonalMemorySnapshot.ownerID, question: "My interpretation", answer: answer,
      kind: .interpretation)
    let entry = try #require(snapshot.entries.first)
    let source = try #require(snapshot.sources.first)
    #expect(entry.isOwnerCorrected == nil && !entry.confirmed && entry.kind == .interpretation)
    #expect(entry.interpretationProvenance == .ownerReviewed)
    #expect(entry.text.utf8.elementsEqual(answer.utf8))
    #expect(source.text.utf8.elementsEqual(("My interpretation\n" + answer).utf8))
    #expect(
      try await prepared(memory, sourceID: source.id).memories.first?.layer
        == .confirmedInterpretation)
    let restored = PersonalMemoryUseCases(repository: ProvenanceRepository())
    _ = try await restored.restoreArchive(memory.exportArchive())
    #expect(
      try await prepared(restored, sourceID: source.id).memories.first?.layer
        == .confirmedInterpretation)
    let undone = try await memory.undo()
    #expect(undone.entries.isEmpty && undone.sources.first?.text == source.text)
  }

  @Test func explicitResolutionKeepsOriginalAndMarksReviewedInterpretation() async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let source = PersonalMemorySource(
      text: "Mira may prefer to discuss this later.", origin: "import")
    _ = try await memory.ingest(source: source)
    let snapshot = try await memory.resolve(sourceID: source.id, kind: .interpretation)
    let entry = try #require(snapshot.currentEntries.first)
    #expect(entry.isOwnerCorrected == nil && !entry.confirmed && entry.kind == .interpretation)
    #expect(entry.interpretationProvenance == .ownerReviewed)
    #expect(snapshot.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
    #expect(snapshot.sources.first?.origin == "import")
    #expect(
      try await prepared(memory, sourceID: source.id).memories.first?.layer
        == .confirmedInterpretation)
    let undone = try await memory.undo()
    #expect(undone.entries.isEmpty && undone.sources.first?.kind == nil)
    #expect(undone.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
  }

  @Test func actualAIProposalStaysUnreviewedUntilOwnerCorrectsIt() async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let source = PersonalMemorySource(text: "Mira may prefer to discuss this later.")
    _ = try await memory.ingest(source: source)
    let input = try #require(try await memory.nextAnalysisInput())
    let snapshot = try await memory.applyAnalysis(
      .init(memories: [.init(quote: source.text, kind: .interpretation)]), input: input)
    let entry = try #require(snapshot.currentEntries.first)
    #expect(entry.isOwnerCorrected == nil && !entry.confirmed)
    #expect(entry.interpretationProvenance == .aiProposed)
    #expect(try await prepared(memory, sourceID: source.id).memories.first?.layer == .aiHypothesis)
    let restored = PersonalMemoryUseCases(repository: ProvenanceRepository())
    _ = try await restored.restoreArchive(memory.exportArchive())
    #expect(
      try await prepared(restored, sourceID: source.id).memories.first?.layer == .aiHypothesis)
    _ = try await memory.updateEntry(id: entry.id, text: "My account: Mira asked for more time.")
    #expect(
      try await prepared(memory, sourceID: source.id).memories.first?.layer
        == .confirmedInterpretation)
    #expect(try await memory.snapshot().entries.first?.confirmed == false)
    #expect(
      try await memory.snapshot().sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
    let undone = try await memory.undo()
    #expect(undone.entries.first?.interpretationStatus == .aiProposed)
  }

  @Test(arguments: ["profile answer", "relationship account", "Owner report", "chat"])
  func originLabelsCannotBackfillOwnerReviewForLegacyInterpretations(_ origin: String) async throws
  {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let source = PersonalMemorySource(
      text: "Mira may prefer to discuss this later.", origin: origin, kind: .interpretation)
    _ = try await memory.ingest(source: source)
    let restored = PersonalMemoryUseCases(repository: ProvenanceRepository())
    _ = try await restored.restoreArchive(memory.exportArchive())
    let snapshot = try await restored.snapshot()
    #expect(snapshot.entries.first?.isOwnerCorrected == nil)
    #expect(snapshot.entries.first?.interpretationProvenance == nil)
    #expect(snapshot.entries.first?.confirmed == false)
    #expect(
      try await prepared(restored, sourceID: source.id).memories.first?.layer
        == .unreviewedInterpretation)
  }

  @Test(arguments: [false, true])
  func missingProvenanceFieldHonorsOnlyExplicitLegacyOwnerReview(_ reviewed: Bool) async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let snapshot = try await memory.answerProfileQuestion(
      profileID: PersonalMemorySnapshot.ownerID, question: "My account",
      answer: "Mira may need more time.", kind: .interpretation)
    let source = try #require(snapshot.sources.first)
    let archive = try await memory.exportArchive()
    var payload = try #require(
      JSONSerialization.jsonObject(with: archive) as? [String: Any])
    var entries = try #require(payload["entries"] as? [[String: Any]])
    entries[0].removeValue(forKey: "interpretationProvenance")
    entries[0]["isOwnerCorrected"] = reviewed
    payload["entries"] = entries
    let restored = PersonalMemoryUseCases(repository: ProvenanceRepository())
    _ = try await restored.restoreArchive(JSONSerialization.data(withJSONObject: payload))
    let layer = try await prepared(restored, sourceID: source.id).memories.first?.layer
    #expect(layer == (reviewed ? .confirmedInterpretation : .unreviewedInterpretation))
    #expect(try await restored.snapshot().entries.first?.interpretationProvenance == nil)
  }

  @Test(arguments: [false, true])
  func changingKindClearsInterpretationProvenanceAndUndoRestoresIt(_ aiProposed: Bool) async throws
  {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let source = PersonalMemorySource(text: "Mira may need more time.")
    _ = try await memory.ingest(source: source)
    if aiProposed {
      let input = try #require(try await memory.nextAnalysisInput())
      _ = try await memory.applyAnalysis(
        .init(memories: [.init(quote: source.text, kind: .interpretation)]), input: input)
    } else {
      _ = try await memory.resolve(sourceID: source.id, kind: .interpretation)
    }
    let changed = try await memory.resolve(sourceID: source.id, kind: .idea)
    #expect(changed.entries.first?.kind == .idea)
    #expect(changed.entries.first?.interpretationProvenance == nil)
    #expect(changed.entries.first?.interpretationStatus == nil)
    let undone = try await memory.undo()
    #expect(undone.entries.first?.kind == .interpretation)
    #expect(
      undone.entries.first?.interpretationStatus == (aiProposed ? .aiProposed : .ownerReviewed))
    #expect(undone.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
  }

  @Test func explicitReviewIsRequiredForGenericAddedInterpretation() async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let source = PersonalMemorySource(text: "Mira: Friday needs more thought.", kind: .fact)
    _ = try await memory.ingest(source: source)
    _ = try await memory.addEntry(
      text: "An unspecified interpretation", kind: .interpretation, sourceIDs: [source.id])
    let snapshot = try await memory.addEntry(
      text: "My reviewed interpretation", kind: .interpretation, sourceIDs: [source.id],
      confirmed: true, ownerReviewed: true)
    let interpretations = snapshot.entries.filter { $0.kind == .interpretation }
    #expect(interpretations.map(\.interpretationStatus) == [nil, .ownerReviewed])
    #expect(interpretations.allSatisfy { !$0.confirmed })
    let layers = try await prepared(memory, sourceID: source.id).memories.filter {
      $0.entry.kind == .interpretation
    }.map(\.layer)
    #expect(layers == [.unreviewedInterpretation, .confirmedInterpretation])
  }

  @Test func duplicateAIProposalCannotRewriteOwnerReviewedInterpretationSources() async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    let text = "I may need more time."
    let manual = try await memory.answerProfileQuestion(
      profileID: PersonalMemorySnapshot.ownerID, question: "My account", answer: text,
      kind: .interpretation)
    let reviewed = try #require(manual.entries.first)
    #expect(reviewed.isOwnerCorrected == nil && reviewed.interpretationStatus == .ownerReviewed)
    let source = PersonalMemorySource(text: text)
    _ = try await memory.ingest(source: source)
    let input = try #require(try await memory.nextAnalysisInput())
    let snapshot = try await memory.applyAnalysis(
      .init(memories: [.init(quote: text, kind: .interpretation, subjectKind: .selfProfile)]),
      input: input)
    #expect(snapshot.currentEntries.count == 1)
    #expect(snapshot.currentEntries.first == reviewed)
    #expect(snapshot.currentEntries.first?.sourceIDs.contains(source.id) == false)
  }

  @Test(arguments: ["fact", "idea", "summary"])
  func archivesRejectInterpretationProvenanceOnAnotherKind(_ kind: String) async throws {
    let memory = PersonalMemoryUseCases(repository: ProvenanceRepository())
    _ = try await memory.answerProfileQuestion(
      profileID: PersonalMemorySnapshot.ownerID, question: "My account",
      answer: "Mira may need more time.", kind: .interpretation)
    let archive = try await memory.exportArchive()
    var payload = try #require(
      JSONSerialization.jsonObject(with: archive) as? [String: Any])
    var entries = try #require(payload["entries"] as? [[String: Any]])
    entries[0]["kind"] = kind
    payload["entries"] = entries
    let invalid = try JSONSerialization.data(withJSONObject: payload)
    let restored = PersonalMemoryUseCases(repository: ProvenanceRepository())
    await #expect(throws: PersonalMemoryError.invalidArchive) {
      try await restored.restoreArchive(invalid)
    }
  }
}
