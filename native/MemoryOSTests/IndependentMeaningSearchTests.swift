import Foundation
import LocalMemoryRetrieval
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private actor IndependentMeaningMemoryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

/// Frozen before repaired semantic outputs. Six queries/eight fictional originals.
/// Root runs this alone so the real Cactus and app-selected 4B inference do not compete.
@Suite(.serialized) @MainActor struct IndependentMeaningSearchTests {
  @Test(.timeLimit(.minutes(10)))
  func heldOutMeaningSearchRequiresExactTopicPersonAndDeletionSets() async throws {
    let texts = [
      "Nadia: Please message me instead of phoning without warning.",
      "Nadia: I prefer tea without milk.",
      "Lina: Call me before you come to my house.",
      "سيف: أفضل نناقش المشكلة بهدوء، مو بالصراخ.",
      "باسم: إذا نختلف أحتاج يوم وحدي قبل النقاش.",
      "Project Willow: The launch moved from August to September after review.",
      "Weather bulletin: light rain is expected tomorrow.",
      "Noor: My bicycle has a punctured tire.",
    ]
    let memory = PersonalMemoryUseCases(repository: IndependentMeaningMemoryRepository())
    let sources = texts.enumerated().map { index, text in
      PersonalMemorySource(
        id: UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", index + 101))!,
        text: text, createdAt: Date(timeIntervalSince1970: 1_700_300_000 + Double(index)),
        origin: "fictional independent search fixture", kind: .conversationOnly)
    }
    for source in sources { _ = try await memory.ingest(source: source) }
    let cases: [(String, String, Set<Int>)] = [
      ("english-meaning", "How should I contact Nadia without interrupting her?", [0]),
      ("arabic-meaning", "شلون سيف يحب نعالج الخلاف؟", [3]),
      ("same-person-wrong-topic", "What drink does Nadia prefer?", [1]),
      ("other-person-same-topic", "What advance contact does Lina request before a visit?", [2]),
      ("unrelated-negative", "What antibiotic dose treats pneumonia?", []),
      ("deleted-original", "What source describes Noor's bicycle puncture?", []),
    ]
    let directory = URL.temporaryDirectory.appending(
      path: "memoryos-independent-meaning-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let keyword = LocalMemorySearch(
      directory: directory.appending(path: "keyword"), cactusModelDirectory: nil, provider: .wax)
    let cactus = LocalMemorySearch(
      directory: directory.appending(path: "semantic"),
      cactusModelDirectory: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"].map {
        URL(filePath: $0)
      } ?? Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
      provider: .cactus, minimumSimilarity: -1)
    let model = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let useCases = MemorySearchUseCases(
      keyword: keyword, semantic: LocalMeaningSearch(candidates: cactus, model: model),
      readCollection: {
        MemorySearchCollection.make(personal: try await memory.snapshot(), local: RecordSnapshot())
      })
    for (id, query, expectedIndexes) in cases {
      if id == "deleted-original" {
        _ = try await memory.forgetSource(sourceID: sources[7].id, confirmed: true)
      }
      let before = try await memory.snapshot()
      let started = Date()
      do {
        let found = try await useCases.search(query: query, mode: .semantic)
        let expected = Set(expectedIndexes.map { sources[$0].id })
        let actual = Set(found.map(\.id))
        #expect(actual == expected, "Frozen exact subject/topic set failed: \(id)")
        #expect(
          found.allSatisfy { hit in
            before.sources.contains {
              $0.id == hit.id
                && Data($0.text.utf8).range(of: Data(hit.passage.utf8)) != nil
            }
          }, "Search changed or invented a source quotation: \(id)")
        #expect(try await memory.snapshot() == before, "Search mutated originals: \(id)")
        print(
          "INDEPENDENT_MEANING \(id) exact=\(actual == expected) expected=\(expected.sorted { $0.uuidString < $1.uuidString }) actual=\(actual.sorted { $0.uuidString < $1.uuidString }) elapsed=\(Date().timeIntervalSince(started))"
        )
      } catch {
        Issue.record("Independent semantic case \(id) failed: \(error)")
        #expect(try await memory.snapshot() == before)
      }
    }
    try await cactus.purge()
    try await cactus.close()
    try await keyword.close()
    await model.unload()
  }
}
