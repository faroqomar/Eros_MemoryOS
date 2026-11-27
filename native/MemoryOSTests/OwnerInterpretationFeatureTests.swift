import ChatCore
import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private actor OwnerInterpretationRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct OwnerInterpretationImageReader: PersonalImageReading {
  func readImage(at url: URL) throws -> Data { throw PersonalImageError.invalidImage }
}

private struct OwnerInterpretationAnalyzer: RelationshipAnalyzing {
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal { .init() }
}

private struct InterpretationCitationSearch: MemorySearching {
  let id: UUID
  let passage: String
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    [.init(sourceID: id.uuidString, score: 1, matchedText: passage)]
  }
}

@MainActor struct OwnerInterpretationFeatureTests {
  enum ManualPath: CaseIterable { case report, linkedReport, profileAnswer }
  enum Origin: CaseIterable { case manual, ai, unknown }

  @Test(arguments: ManualPath.allCases)
  func realManualReportPathRetainsOwnerReviewAndOriginalEvidence(_ path: ManualPath) async throws {
    let memory = PersonalMemoryUseCases(repository: OwnerInterpretationRepository())
    let original = PersonalMemorySource(text: "Mira: I need time to consider Friday.", kind: .fact)
    if path == .linkedReport { _ = try await memory.ingest(source: original) }
    let viewModel = PersonalMemoryViewModel(
      useCases: memory, imageImport: .init(reader: OwnerInterpretationImageReader()))
    await viewModel.load()
    let text = "تفسيري: ميرا تحتاج وقتاً للتفكير."
    #expect(
      await viewModel.addReport(
        text: text, kind: .interpretation, profileID: nil,
        question: path == .profileAnswer ? "How do you interpret this?" : nil,
        sourceIDs: path == .linkedReport ? [original.id] : []))
    let entry = try #require(viewModel.snapshot.currentEntries.first { $0.text == text })
    #expect(entry.isOwnerCorrected == nil && !entry.confirmed && entry.kind == .interpretation)
    #expect(entry.interpretationProvenance == .ownerReviewed)
    #expect(entry.text.utf8.elementsEqual(text.utf8))
    let input = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: OwnerInterpretationAnalyzer()
    ).prepare(.init(sourceIDs: entry.sourceIDs, question: "Explain this account"))
    #expect(input.memories.first { $0.id == entry.id }?.layer == .confirmedInterpretation)
    let collection = MemorySearchCollection.make(personal: viewModel.snapshot, local: .init())
    #expect(collection.document(entry.id)?.kind == .confirmedInterpretation)
    #expect(entry.sourceIDs.allSatisfy { collection.document($0)?.detail != "historicalOriginal" })
    if path == .linkedReport {
      #expect(viewModel.snapshot.sources.first?.text.utf8.elementsEqual(original.text.utf8) == true)
    } else {
      #expect(viewModel.snapshot.sources.first?.text.hasSuffix(text) == true)
    }
  }

  @Test func searchSeparatesActualAIProposalFromUnspecifiedLegacyInterpretation() async throws {
    let memory = PersonalMemoryUseCases(repository: OwnerInterpretationRepository())
    let legacy = PersonalMemorySource(
      text: "Mira may need more time.", origin: "profile answer", kind: .interpretation)
    _ = try await memory.ingest(source: legacy)
    let source = PersonalMemorySource(text: "Rana may prefer a quiet place.")
    _ = try await memory.ingest(source: source)
    let input = try #require(try await memory.nextAnalysisInput())
    let snapshot = try await memory.applyAnalysis(
      .init(memories: [.init(quote: source.text, kind: .interpretation)]), input: input)
    let legacyEntry = try #require(snapshot.entries.first { $0.sourceIDs == [legacy.id] })
    let aiEntry = try #require(snapshot.entries.first { $0.sourceIDs == [source.id] })
    let collection = MemorySearchCollection.make(personal: snapshot, local: .init())
    #expect(collection.document(legacyEntry.id)?.kind == .unreviewedInterpretation)
    #expect(collection.document(aiEntry.id)?.kind == .hypothesis)
    #expect(legacyEntry.interpretationStatus == nil && aiEntry.interpretationStatus == .aiProposed)
  }

  @Test(arguments: Origin.allCases)
  func chatCitationPreservesPassageAndSeparatesInterpretationProvenance(_ origin: Origin)
    async throws
  {
    let memory = PersonalMemoryUseCases(repository: OwnerInterpretationRepository())
    let passage = "قد تكون ميرا بحاجة إلى وقت إضافي. Cafe\u{0301}"
    let expectedLabel: String
    switch origin {
    case .manual:
      _ = try await memory.answerProfileQuestion(
        profileID: PersonalMemorySnapshot.ownerID, question: "My interpretation",
        answer: passage, kind: .interpretation)
      expectedLabel = "owner-reviewed interpretation"
    case .ai:
      _ = try await memory.ingest(source: .init(text: passage))
      let input = try #require(try await memory.nextAnalysisInput())
      _ = try await memory.applyAnalysis(
        .init(memories: [.init(quote: passage, kind: .interpretation)]), input: input)
      expectedLabel = "AI-proposed hypothesis"
    case .unknown:
      _ = try await memory.ingest(
        source: .init(text: passage, origin: "Owner report", kind: .interpretation))
      expectedLabel = "author unknown"
    }
    let personal = try await memory.snapshot()
    let entry = try #require(personal.entries.first)
    let snapshot = LocalChatMemory.makeSnapshot(local: [], personal: personal)
    #expect(
      snapshot.records.filter { entry.sourceIDs.map(\.uuidString).contains($0.id) }
        .allSatisfy { !$0.text.contains("historical original") })
    let retrieval = LocalChatMemory(
      search: InterpretationCitationSearch(id: entry.id, passage: passage),
      readSnapshot: { snapshot })
    let evidence = try await retrieval.retrieve(query: "Mira")
    let citation = try #require(evidence.first)
    #expect(evidence.count == 1 && citation.id == entry.id)
    #expect(
      citation.text.contains(expectedLabel) && citation.text.contains("not an established fact"))
    #expect(citation.sourceDigest != nil && citation.matchesCurrentText(passage))
    #expect(!citation.matchesCurrentText(passage.precomposedStringWithCanonicalMapping))
    #expect(citation.text.utf8.suffix(passage.utf8.count).elementsEqual(passage.utf8))
    #expect(!entry.confirmed && entry.text.utf8.elementsEqual(passage.utf8))
  }
}
