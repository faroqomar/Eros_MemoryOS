import ChatCore
import CryptoKit
import Foundation
import LocalMemoryRetrieval
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

// These runtime checks share the app's local model resources.
@Suite(.serialized) @MainActor struct AutomaticRecallRuntimeTests {
  @Test func actualLocalRecallAnswersAcrossChatsAndHonorsCorrectionsAndPrivateLifetime()
    async throws
  {
    let root = URL.temporaryDirectory.appending(path: "recall-connected-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let search = LocalMemorySearch(
      directory: root,
      cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
      provider: .hybrid, minimumSimilarity: -1)
    let sourceID = UUID()
    let sources = RuntimeRecallSources(id: sourceID)
    let model = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let memory = LocalChatMemory(
      search: search, relevance: ChatComposition.makeRelevanceFilter(coordinator: model),
      readRecords: { await sources.records() })
    let repository = RuntimeRecallRepository()
    let chat = ChatUseCases(repository: repository, model: model, memory: memory)
    _ = try await chat.load()
    let first = try await chat.generate(submittedText: "What color is my bicycle?") { _ in }
    let firstReply = try #require(first.conversations.first?.messages.last)
    #expect(firstReply.sources.map(\.id) == [sourceID])
    #expect(firstReply.text.localizedCaseInsensitiveContains("yellow"))
    await sources.correct()
    _ = try await chat.newConversation()
    let corrected = try await chat.generate(submittedText: "What color is my bicycle?") { _ in }
    let correctedReply = try #require(corrected.conversations.first?.messages.last)
    #expect(correctedReply.sources.map(\.id) == [sourceID])
    #expect(correctedReply.text.localizedCaseInsensitiveContains("blue"))
    #expect(!correctedReply.text.localizedCaseInsensitiveContains("yellow"))
    _ = try await chat.startTemporary()
    let privateReply = try await chat.generate(submittedText: "PRIVATE: What color is my bicycle?")
    { _ in }
    #expect(
      privateReply.conversations.first(where: \.isTemporary)?.messages.last?.sources.map(\.id) == [
        sourceID
      ])
    #expect(
      privateReply.conversations.first(where: \.isTemporary)?.messages.last?.text
        .localizedCaseInsensitiveContains("blue") == true)
    _ = try await chat.endTemporary()
    #expect(
      !String(decoding: try JSONEncoder().encode(await repository.value), as: UTF8.self).contains(
        "PRIVATE"))
    let none = try await memory.retrieve(query: "What is my passport number?")
    #expect(none.isEmpty)
    await model.unload()
    try await search.close()
  }

  @Test func frozenMixedLanguageFixturePassesActualHybridRetrievalAndLocalRelevance() async throws {
    let bytes = Data(Self.frozenFixture.utf8)
    let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try #require(hash == "00fb9b613e2036ecd95e01b8c1bc4b43b40c727a3fcfcd3942cc0f7509ddbf3b")
    let fixture = try JSONDecoder().decode(RuntimeRecallFixture.self, from: bytes)
    try #require(fixture.records.count == 8 && fixture.cases.count == 12)
    let root = URL.temporaryDirectory.appending(path: "recall-frozen-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let provider = LocalStoreProvider(directory: root.appending(path: "store"))
    let session = try await provider.open()
    var ids: [String: UUID] = [:]
    var sourceTexts: [UUID: String] = [:]
    for record in fixture.records {
      let saved = try await session.useCases.create(kind: .capture, text: record.text)
      ids[record.id] = saved.id
      sourceTexts[saved.id] = record.text
    }
    let search = LocalMemorySearch(
      directory: root.appending(path: "indexes"),
      cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
      provider: .hybrid, minimumSimilarity: -1)
    let observedSearch = RuntimeRecallObservedSearch(base: search)
    let coordinator = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let memory = LocalChatMemory(
      provider: provider, personalMemory: nil, search: observedSearch,
      relevance: ChatComposition.makeRelevanceFilter(coordinator: coordinator))
    var matchedCases = 0
    var candidatePositiveHits = 0
    var returnedPositiveHits = 0
    var falsePositiveCases = 0
    var runtimeErrors = 0
    for item in fixture.cases {
      let expected = Set(try item.expectedIDs.map { try #require(ids[$0]) })
      let started = Date()
      do {
        let evidence = try await memory.retrieve(query: item.query)
        let candidates = await observedSearch.lastIDs
        let actual = Set(evidence.map(\.id))
        let candidateCovered = expected.isSubset(of: candidates)
        let matched = actual == expected
        if !expected.isEmpty && candidateCovered { candidatePositiveHits += 1 }
        if !expected.isEmpty && expected.isSubset(of: actual) { returnedPositiveHits += 1 }
        if !actual.subtracting(expected).isEmpty { falsePositiveCases += 1 }
        if matched { matchedCases += 1 }
        #expect(candidateCovered, "Candidate coverage failed: \(item.id)")
        #expect(matched, "Final evidence IDs differ: \(item.id)")
        #expect(evidence.first?.id == item.expectedIDs.first.flatMap { ids[$0] })
        #expect(
          evidence.allSatisfy { value in
            guard let source = sourceTexts[value.id] else { return false }
            return value.sourceDigest != nil && value.matchesCurrentText(source)
              && value.text.range(of: source, options: .literal) != nil
          }, "Source bytes changed: \(item.id)")
        print(
          "MEMORYOS_RECALL_CASE id=\(item.id) candidateCovered=\(candidateCovered) matched=\(matched) returned=\(actual.count) seconds=\(Date().timeIntervalSince(started))"
        )
      } catch {
        runtimeErrors += 1
        Issue.record("Retrieval runtime failure for \(item.id)")
      }
    }
    await coordinator.unload()
    try await search.close()
    #expect(candidatePositiveHits == 6)
    #expect(returnedPositiveHits == 6)
    #expect(falsePositiveCases == 0)
    #expect(runtimeErrors == 0)
    #expect(matchedCases == 12)
    print(
      "MEMORYOS_RECALL_SUMMARY cases=12 matched=\(matchedCases) candidatePositiveHits=\(candidatePositiveHits) returnedPositiveHits=\(returnedPositiveHits) falsePositiveCases=\(falsePositiveCases) runtimeErrors=\(runtimeErrors)"
    )
  }

  // Frozen independently before relevance-component evaluation; now a consumed regression set.
  // Preserve its UTF8 bytes, including decomposed accents, and its original SHA-256.
  private static let frozenFixture = #"""
    {
      "version": 1,
      "purpose": "Fresh independent fictional retrieval check. Freeze before candidate generalization run. Do not reveal inputs to implementers before consumed regressions pass.",
      "records": [
        {
          "id": "r01",
          "text": "حيدر ما يروح للجامعة بالباص؛ يروح مشي لأن بيته قريب."
        },
        {
          "id": "r02",
          "text": "رنا تداوم من البيت يوم الأربعاء، وباقي أيام الدوام تروح للمكتب."
        },
        {
          "id": "r03",
          "text": "In Project Lantern، نراجع فواتير المشتريات آخر يوم من كل شهر."
        },
        {
          "id": "r04",
          "text": "Renée meets her language tutor at the library on Saturday mornings."
        },
        {
          "id": "r05",
          "text": "Salim stopped drinking coffee in the evening. He now chooses mint tea after dinner."
        },
        {
          "id": "r06",
          "text": "مها تحب تقرأ روايات تاريخية بالعطلة، وما تحب قصص الرعب."
        },
        {
          "id": "r07",
          "text": "The Juniper team sends its weekly progress note on Thursday afternoon."
        },
        {
          "id": "r08",
          "text": "Huda takes her dog to the park before breakfast."
        }
      ],
      "cases": [
        {
          "id": "q01",
          "query": "حيدر شلون يوصل للجامعة؟",
          "expectedIDs": [
            "r01"
          ],
          "intent": "Iraqi Arabic transport paraphrase with source negation"
        },
        {
          "id": "q02",
          "query": "رنا بأي يوم ما تحتاج تروح للمكتب؟",
          "expectedIDs": [
            "r02"
          ],
          "intent": "Iraqi Arabic workplace negation"
        },
        {
          "id": "q03",
          "query": "When does Lantern check supplier bills?",
          "expectedIDs": [
            "r03"
          ],
          "intent": "Mixed language budget-related paraphrase"
        },
        {
          "id": "q04",
          "query": "Where does Renée have her language lessons?",
          "expectedIDs": [
            "r04"
          ],
          "intent": "Canonical Unicode equivalence and activity paraphrase"
        },
        {
          "id": "q05",
          "query": "What does Salim drink after his evening meal now?",
          "expectedIDs": [
            "r05"
          ],
          "intent": "Current choice after explicit change"
        },
        {
          "id": "q06",
          "query": "مها شنو نوع الكتب اللي تفضّلها بوقت الفراغ؟",
          "expectedIDs": [
            "r06"
          ],
          "intent": "Arabic preference paraphrase with negative distractor"
        },
        {
          "id": "q07",
          "query": "حيدر شنو رقم جوازه؟",
          "expectedIDs": [],
          "intent": "Same person but absent passport topic"
        },
        {
          "id": "q08",
          "query": "شنو رقم هاتف رنا؟",
          "expectedIDs": [],
          "intent": "Same person but absent contact topic"
        },
        {
          "id": "q09",
          "query": "What is the Lantern office street address?",
          "expectedIDs": [],
          "intent": "Same project but absent location topic"
        },
        {
          "id": "q10",
          "query": "What is Renée’s blood type?",
          "expectedIDs": [],
          "intent": "Same person but absent medical attribute"
        },
        {
          "id": "q11",
          "query": "Which bank does Salim use?",
          "expectedIDs": [],
          "intent": "Same person but absent banking topic"
        },
        {
          "id": "q12",
          "query": "What is the melting point of silver?",
          "expectedIDs": [],
          "intent": "General knowledge query unrelated to supplied records"
        }
      ],
      "assertions": {
        "positive": "Expected source ranks first; extra IDs separately reported.",
        "negative": "No returned source IDs; these ask unrelated predicates, not missing details of a relevant event.",
        "score": "Report positive recall, case accuracy, false-positive cases separately. This fixture does not qualify generation/extraction."
      }
    }
    """# + "\n"
}

private actor RuntimeRecallSources {
  let id: UUID
  let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
  var text = "My bicycle is bright yellow."
  init(id: UUID) { self.id = id }
  func correct() { text = "My bicycle is blue." }
  func records() -> [MemorySearchRecord] {
    LocalChatMemory.records(
      local: [
        LocalRecord(
          id: id, kind: .capture, originalText: "My bicycle is bright yellow.", text: text,
          createdAt: createdAt)
      ], personal: nil)
  }
}

private actor RuntimeRecallRepository: ChatRepository {
  var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ snapshot: ChatSnapshot) throws {
    try snapshot.validateDurable()
    value = snapshot
  }
}

private struct RuntimeRecallFixture: Decodable {
  struct Record: Decodable {
    let id: String
    let text: String
  }
  struct Case: Decodable {
    let id: String
    let query: String
    let expectedIDs: [String]
  }
  let records: [Record]
  let cases: [Case]
}

private actor RuntimeRecallObservedSearch: MemorySearching {
  let base: any MemorySearching
  private(set) var lastIDs: Set<UUID> = []
  init(base: any MemorySearching) { self.base = base }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    lastIDs = []
    let hits = try await base.search(query: query, records: records, limit: limit)
    lastIDs = Set(hits.compactMap { UUID(uuidString: $0.sourceID) })
    return hits
  }
}
