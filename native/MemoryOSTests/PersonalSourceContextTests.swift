import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor SourceContextRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct SourceContextImageReader: PersonalImageReading {
  func readImage(at url: URL) throws -> Data { throw PersonalImageError.invalidImage }
}

private actor SourceContextAnalyzer: RelationshipAnalyzing {
  private(set) var calls = 0
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal {
    calls += 1
    return .init()
  }
}

@MainActor struct PersonalSourceContextTests {
  private struct Fixture {
    let memory: PersonalMemoryUseCases
    let model: PersonalMemoryViewModel
    let before: PersonalMemorySource
    let selected: PersonalMemorySource
    let tiedAfter: PersonalMemorySource
    let farAfter: PersonalMemorySource
    let linked: PersonalMemorySource
    let standalone: PersonalMemorySource
  }

  private func fixture() async throws -> Fixture {
    let memory = PersonalMemoryUseCases(repository: SourceContextRepository())
    let conversation = UUID()
    func source(_ number: String, _ time: TimeInterval, _ text: String, conversationID: UUID?)
      -> PersonalMemorySource
    {
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000" + number)!,
        conversationID: conversationID, text: text, createdAt: Date(timeIntervalSince1970: time),
        origin: "Fictional saved original", kind: .conversationOnly)
    }
    let before = source("10", 100, "Fictional earlier message.", conversationID: conversation)
    let selected = source(
      "20", 200, "Fictional cafe\u{301} — العربية 🙂 unchanged.", conversationID: conversation)
    let tiedAfter = source(
      "21", 200, "Fictional same-time next message.", conversationID: conversation)
    let farAfter = source("30", 300, "Fictional farther message.", conversationID: conversation)
    let linked = source(
      "40", 201, String(repeating: "Fictional linked original. ", count: 180),
      conversationID: UUID())
    let standalone = source("50", 199, "Fictional standalone original.", conversationID: nil)
    // Arrival order differs from chronological order; nil conversation IDs never create adjacency.
    for item in [farAfter, linked, tiedAfter, standalone, selected, before] {
      _ = try await memory.ingest(source: item)
    }
    _ = try await memory.addLink(from: selected.id, to: linked.id, label: "Owner link")
    _ = try await memory.addLink(from: standalone.id, to: selected.id, label: "Reverse owner link")
    let model = PersonalMemoryViewModel(
      useCases: memory, imageImport: .init(reader: SourceContextImageReader()))
    await model.load()
    return .init(
      memory: memory, model: model, before: before, selected: selected, tiedAfter: tiedAfter,
      farAfter: farAfter, linked: linked, standalone: standalone)
  }

  @Test func sourceReaderUsesSavedNeighborsAndExplicitLinksWithoutWideningAnalysis() async throws {
    let value = try await fixture()
    let beforeRead = try await value.memory.snapshot()
    let analyzer = SourceContextAnalyzer()
    let understanding = RelationshipUnderstandingUseCases(memory: value.memory, analyzer: analyzer)
    let request = RelationshipAnalysisRequest(
      sourceIDs: [value.selected.id], question: "What is supported by this original?")
    let beforeInput = try await understanding.prepare(request)
    let context = try #require(value.model.sourceContext(value.selected.id))
    #expect(context.source.text.utf8.elementsEqual(value.selected.text.utf8))
    #expect(context.source.createdAt == value.selected.createdAt)
    #expect(context.source.origin == value.selected.origin)
    #expect(context.adjacent.map(\.id) == [value.before.id, value.tiedAfter.id])
    let collection = MemorySearchCollection.make(personal: beforeRead, local: .init())
    #expect(
      collection.document(value.selected.id)?.contextIDs.filter { $0 != value.selected.id }
        == context.adjacent.map(\.id))
    #expect(collection.document(value.standalone.id)?.contextIDs.isEmpty == true)
    #expect(
      !context.adjacent.contains {
        $0.id == value.farAfter.id || $0.id == value.linked.id || $0.id == value.standalone.id
      })
    #expect(Set(context.linked.map { $0.1.id }) == [value.linked.id, value.standalone.id])
    #expect(Set(context.linked.map { $0.0.label }) == ["Owner link", "Reverse owner link"])
    let linked = try #require(context.linked.first { $0.1.id == value.linked.id }?.1)
    #expect(linked.text.utf8.elementsEqual(value.linked.text.utf8))
    #expect(value.model.sourceContext(value.standalone.id)?.adjacent.isEmpty == true)
    let input = try await understanding.prepare(request)
    #expect(input.sources.map { $0.source.id } == [value.selected.id])
    #expect(input == beforeInput)
    #expect(await analyzer.calls == 0)
    #expect(try await value.memory.snapshot() == beforeRead)
  }

  @Test func sourceReaderKeepsOriginalBytesAfterCorrectionAndDropsDeletedContext() async throws {
    let value = try await fixture()
    let added = try await value.memory.resolve(sourceID: value.selected.id, kind: .fact)
    let entry = try #require(added.entries.first)
    _ = try await value.memory.updateEntry(
      id: entry.id, text: "Fictional owner correction", confirmedChange: true)
    await value.model.load()
    #expect(
      value.model.sourceContext(value.selected.id)?.source.text.utf8.elementsEqual(
        value.selected.text.utf8) == true)
    #expect(await value.model.forgetSource(value.before.id))
    #expect(await value.model.forgetSource(value.linked.id))
    let current = try #require(value.model.sourceContext(value.selected.id))
    #expect(current.adjacent.map(\.id) == [value.tiedAfter.id])
    #expect(current.linked.map { $0.1.id } == [value.standalone.id])
    #expect(value.model.sourceContext(value.before.id) == nil)
    #expect(await value.model.forgetSource(value.selected.id))
    #expect(value.model.sourceContext(value.selected.id) == nil)
    #expect(value.model.sourceContext(value.standalone.id)?.linked.isEmpty == true)
  }
}
