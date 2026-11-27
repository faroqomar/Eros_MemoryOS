import Foundation
import LocalMemoryRetrieval
import RetrievalCore
import Testing

@testable import MemoryOS

/// Builder corpus. These examples are consumed development data, not independent qualification.
struct MemorySearchKnownAnswerTests {
  @MainActor
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RUN_SEARCH_COMPARISON"] == "1"),
    .timeLimit(.minutes(10)))
  func compareCurrentMethodsWithoutPromotingFailedSemanticQuality() async throws {
    let texts = [
      "Mira's birthday is May 12.", "Mira and I agreed to meet on Saturday.",
      "Mira asked me to call before visiting.", "عمر يفضل أن نتحدث بهدوء عندما نختلف.",
      "عمر وعد بإرسال صور الرحلة يوم الجمعة.", "The Cedar project launches in June.",
      "My bicycle has a punctured tire.", "I prefer coffee without sugar.",
    ]
    let documents = texts.enumerated().map { offset, text in
      let id = UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", offset + 1))!
      return MemorySearchDocument(
        id: id, text: text, kind: .original,
        date: Date(timeIntervalSince1970: 1), originalText: nil, detail: "originalStatement",
        destination: .source(id))
    }
    let cases: [(String, String, Set<Int>)] = [
      ("english-literal", "birthday", [0]),
      ("english-meaning", "weekend meeting agreement", [1]),
      ("english-linked", "Saturday", [1]),
      ("arabic-literal", "الجمعة", [4]),
      ("arabic-meaning", "كيف نخفف الخلاف في كلامنا؟", [3]),
      ("no-source", "prescription antibiotic dosage for pneumonia", []),
    ]
    let collection = MemorySearchCollection(
      documents: documents,
      connections: [
        .init(from: documents[1].id, to: documents[2].id, label: "same discussion")
      ])
    let environment = ProcessInfo.processInfo.environment
    let model =
      environment["CACTUS_EVAL_MODEL_DIR"].map { URL(filePath: $0) }
      ?? Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus")
    let directory = URL.temporaryDirectory.appending(
      path: "memoryos-known-search-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let keyword = LocalMemorySearch(
      directory: directory.appending(path: "keyword"), cactusModelDirectory: nil, provider: .wax)
    let semanticCandidates = LocalMemorySearch(
      directory: directory.appending(path: "semantic"), cactusModelDirectory: model,
      provider: .cactus, minimumSimilarity: -1)
    let languageModel = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let semantic = LocalMeaningSearch(candidates: semanticCandidates, model: languageModel)
    let useCases = MemorySearchUseCases(
      keyword: keyword, semantic: semantic, readCollection: { collection })
    var rows: [[String: Any]] = []
    for mode in MemorySearchMode.allCases {
      for (id, query, expectedIndexes) in cases {
        var expected = Set(expectedIndexes.map { documents[$0].id })
        if mode == .linked, expected.contains(documents[1].id) { expected.insert(documents[2].id) }
        let start = ContinuousClock.now
        let found = try await useCases.search(query: query, mode: mode)
        let actual = Set(found.map(\.id))
        let duration = start.duration(to: .now).components
        rows.append([
          "method": mode.rawValue, "case": id, "exact": actual == expected,
          "expected": expected.map(\.uuidString).sorted(), "actual": found.map { $0.id.uuidString },
          "truePositive": actual.intersection(expected).count,
          "falsePositive": actual.subtracting(expected).count,
          "falseNegative": expected.subtracting(actual).count,
          "seconds": Double(duration.seconds) + Double(duration.attoseconds) / 1e18,
        ])
        // Keep identical truth sets and mismatch measurements for all methods. Word matching
        // cannot satisfy nonliteral meaning queries; those remain visible comparative misses.
        // Gate lexical/linked contracts on literal cases, and meaning search on the entire set.
        let contractApplies = mode == .semantic || !id.contains("meaning")
        if contractApplies {
          #expect(
            actual == expected, "\(mode.rawValue): \(id); quality gate remains open on mismatch")
        }
        print(
          "MEMORYOS_SEARCH_CASE method=\(mode.rawValue) case=\(id) exact=\(actual == expected) expected=\(expected.count) actual=\(actual.count) contract=\(contractApplies)"
        )
      }
    }
    try await keyword.purge()
    try await semanticCandidates.purge()
    try await keyword.close()
    try await semanticCandidates.close()
    let output = URL(
      filePath: environment["MEMORYOS_SEARCH_COMPARISON_REPORT"]
        ?? "/tmp/memoryos-search-known-answer-results.json")
    try JSONSerialization.data(
      withJSONObject: [
        "kind": "builder-known-answer-not-independent", "minimumSimilarity": -1, "limit": 12,
        "semanticVerification": "pinned Qwen3 4B local topic and subject check",
        "rows": rows,
      ], options: [.prettyPrinted, .sortedKeys]
    ).write(to: output)
  }
}
