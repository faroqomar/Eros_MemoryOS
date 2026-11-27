import ChatCore
import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private struct FrozenAliasCase: Sendable {
  enum Review: Sendable { case explicit, suggested, unknown, owner }
  struct Profile: Sendable {
    let name: String
    var aliases: [String] = []
    var review: Review = .explicit
    var kind: PersonalProfileKind = .person
  }
  let query: String
  let profiles: [Profile]
  let passages: [String]
  let expected: Set<Int>
  let hintExtractions: Int
  var links: [(Int, Int)] = []
  var expectsClarification = false

  // Frozen independently of the implementation. Fixtures are fictional and never app history.
  static let all: [Self] = [
    .init(
      query: "Where is Celia's rehearsal?", profiles: [.init(name: "Celia")],
      passages: [
        "Celia's rehearsal is in the blue hall.", "Celia bought a kettle.",
        "Dario's rehearsal is in the red hall.",
      ], expected: [0], hintExtractions: 0),
    .init(
      query: "شنو مكان اجتماع لين؟", profiles: [.init(name: "Lina", aliases: ["لين"])],
      passages: [
        "الاجتماع في القاعة الصغيرة.", "أفضل الشاي بدون سكر.",
        "رامي: اجتماعي في المكتبة.",
      ], expected: [0], hintExtractions: 0, links: [(0, 0), (0, 1)]),
    .init(
      query: "Did أوركيد confirm the museum visit?",
      profiles: [.init(name: "Orchid", aliases: ["أوركيد"], kind: .project)],
      passages: [
        "أوركيد confirmed the museum visit for Tuesday.",
        "Orchid needs new printer paper.", "Cedar confirmed a museum visit for Friday.",
      ],
      expected: [0], hintExtractions: 0),
    .init(
      query: "When is Rose's workshop?", profiles: [.init(name: "Rose")],
      passages: [
        "Rose scheduled her workshop for June 6.", "The garden rose flowered yesterday.",
        "Mila's workshop is on June 8.",
      ], expected: [0], hintExtractions: 0),
    .init(
      query: "May I see the train times?", profiles: [.init(name: "May")],
      passages: [
        "Trains leave at 08:10 and 09:40.", "May collects old postcards.",
        "Buses leave at noon.",
      ], expected: [0], hintExtractions: 0),
    .init(
      query: "What did Daniel Park say about the permit?",
      profiles: [.init(name: "Daniel Park"), .init(name: "Daniel")],
      passages: [
        "Daniel Park: The permit is approved.", "Daniel: The permit is pending.",
        "Daniel Park: Lunch is at noon.",
      ], expected: [0], hintExtractions: 1),
    .init(
      query: "What time did Star choose for dinner?",
      profiles: [
        .init(name: "Imani", aliases: ["Star"]),
        .init(name: "Lucia", aliases: ["Star"]),
      ],
      passages: ["Imani chose seven for dinner.", "Lucia chose eight for dinner."],
      expected: [], hintExtractions: 1, expectsClarification: true),
    .init(
      query: "What did Ana and Basil each say about lunch?",
      profiles: [.init(name: "Ana"), .init(name: "Basil")],
      passages: ["Ana: Lunch at noon.", "Basil: Lunch at one.", "Ana: My bike is broken."],
      expected: [0, 1], hintExtractions: 1),
    .init(
      query: "What did Ilan promise about the delivery?", profiles: [.init(name: "Mona")],
      passages: ["Mona promised to deliver the parcel today.", "The package label is blue."],
      expected: [], hintExtractions: 1),
    .init(
      query: "What date did Priya choose for the concert?", profiles: [.init(name: "Priya")],
      passages: [
        "The concert is set for April 9.", "Please bring the blue folder.",
        "Tomas: The concert is set for May 2.",
      ],
      expected: [0], hintExtractions: 0, links: [(0, 0), (0, 1)]),
    .init(
      query: "What did Robin say about the ferry?",
      profiles: [.init(name: "Robin", review: .owner)],
      passages: [
        "Robin: The ferry departs at six.", "Robin likes chess.",
        "Leah: The ferry departs at nine.",
      ], expected: [0], hintExtractions: 1),
    .init(
      query: "What does Nad plan for Saturday?",
      profiles: [
        .init(name: "Nadia", aliases: ["Nad"], review: .suggested),
        .init(name: "Nico", review: .unknown),
      ],
      passages: [
        "Nadia plans to visit the library on Saturday.",
        "Nadia plans to paint on Monday.", "Nadir plans to visit the library on Saturday.",
      ],
      expected: [0], hintExtractions: 1),
  ]
}

private actor FrozenAliasRepository: PersonalMemoryRepository {
  private var value: PersonalMemorySnapshot
  init(_ value: PersonalMemorySnapshot) { self.value = value }
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct FrozenAliasCandidates: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
  }
}

private enum FrozenAliasFailure: Error {
  case callBudget, invalidInput, timedOut, unexpectedStreaming
}

private actor FrozenAliasMeter: StructuredChatModel {
  struct Counts: Sendable {
    var scope = 0
    var extraction = 0
    var resolution = 0
    var topic = 0
    var maximumRequestedTokens = 0
    var inputBytesPreserved = true
    var scopeStatus: String?
    var scopeSubjectCount = 0
  }
  private let underlying: any StructuredChatModel
  private let query: Data
  private let passages: Set<Data>
  private let allowsKnownIdentityHints: Bool
  private var counts = Counts()

  init(
    _ model: any StructuredChatModel, query: String, passages: [String],
    allowsKnownIdentityHints: Bool
  ) {
    underlying = model
    self.query = Data(query.utf8)
    self.passages = Set(passages.map { Data($0.utf8) })
    self.allowsKnownIdentityHints = allowsKnownIdentityHints
  }

  func measurements() -> Counts { counts }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    if grammar.contains("scope-status ::=") {
      counts.scope += 1
    } else if grammar.contains("subject ::=") {
      counts.extraction += 1
    } else if grammar.contains("resolution") {
      counts.resolution += 1
    } else {
      counts.topic += 1
    }
    counts.maximumRequestedTokens += maximumOutputTokens
    guard counts.scope <= (allowsKnownIdentityHints ? 1 : 0),
      counts.extraction <= 1, counts.resolution <= 1, counts.topic <= passages.count,
      counts.maximumRequestedTokens <= (allowsKnownIdentityHints ? 480 : 320) + 16 * passages.count
    else { throw FrozenAliasFailure.callBudget }
    guard let text = turns.last?.text,
      let row = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
      let sentQuery = row["query"] as? String
    else { throw FrozenAliasFailure.invalidInput }
    counts.inputBytesPreserved = counts.inputBytesPreserved && Data(sentQuery.utf8) == query
    if let passage = row["passage"] as? String {
      counts.inputBytesPreserved =
        counts.inputBytesPreserved && passages.contains(Data(passage.utf8))
    }
    let checkingScope = grammar.contains("scope-status ::=")
    let output = try await underlying.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    if checkingScope,
      let response = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
    {
      counts.scopeStatus = response["status"] as? String
      counts.scopeSubjectCount = (response["subjects"] as? [String])?.count ?? 0
    }
    return output
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    throw FrozenAliasFailure.unexpectedStreaming
  }

  func unload() async { await underlying.unload() }
}

@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_IDENTITY_HINT_COMPARISON"] == "1")
)
@MainActor struct FreshIdentityHintComparisonTests {
  private struct Result: Sendable {
    let selected: Set<Int>
    let error: String?
    let originalBytesPreserved: Bool
    let counts: FrozenAliasMeter.Counts
    let seconds: Double
  }

  @Test(.timeLimit(.minutes(30)))
  func frozenAliasesPreserveAccuracyAndMeasureActualModelCalls() async throws {
    try await compare(FrozenAliasCase.all, prefix: "FROZEN_IDENTITY_HINT ")
  }

  fileprivate func compare(
    _ fixtures: [FrozenAliasCase], prefix: String,
    scopeExpectations: [Int: (String, Int)] = [:]
  ) async throws {
    let model = try #require(try RuntimeTestModel.makeModel() as? any StructuredChatModel)
    do {
      // Both arms use warm resident weights. The runtime resets context for every JSON request.
      _ = try await model.generateJSON(
        turns: [.init(role: .user, text: "Return {\"ready\":true}.")],
        grammar: #"root ::= "{" "\"ready\":" "true" "}""#, maximumOutputTokens: 16)
      for (index, fixture) in fixtures.enumerated() {
        let snapshot = try await snapshot(fixture, index: index)
        let records = snapshot.sources.map {
          MemorySearchRecord(id: $0.id.uuidString, text: $0.text)
        }
        let identities = MemorySearchCollection.make(personal: snapshot, local: .init())
          .identityAliases
        let chatIdentities = LocalChatMemory.makeSnapshot(local: [], personal: snapshot).identities
        let expectedEligible = fixture.profiles.filter { $0.review == .explicit }.count
        #expect(identities.filter(\.canGroundQuery).count == expectedEligible)
        #expect(chatIdentities.filter(\.canGroundQuery).count == expectedEligible)
        var outcomes: [Bool: Result] = [:]
        for hinted in index.isMultiple(of: 2) ? [false, true] : [true, false] {
          let result = await run(
            fixture, hinted: hinted, model: model, records: records, identities: identities)
          outcomes[hinted] = result
          emit(index: index, hinted: hinted, fixture: fixture, result: result, prefix: prefix)
          #expect(
            result.selected == fixture.expected, "Frozen source set, case \(index), hint \(hinted)")
          #expect(
            result.error == (fixture.expectsClarification ? "ambiguous" : nil),
            "Supported answers cannot pass through refusal, case \(index), hint \(hinted)")
          #expect(result.originalBytesPreserved && result.counts.inputBytesPreserved)
          if !hinted || expectedEligible == 0 { #expect(result.counts.scope == 0) }
          if hinted && fixture.hintExtractions == 0 { #expect(result.counts.scope == 1) }
          if hinted, result.counts.scope == 1, let expectedScope = scopeExpectations[index] {
            #expect(result.counts.scopeStatus == expectedScope.0)
            #expect(result.counts.scopeSubjectCount == expectedScope.1)
          }
          if result.counts.scope == 1 {
            switch result.counts.scopeStatus {
            case "complete":
              #expect(result.counts.extraction == 0 && result.counts.resolution == 0)
              #expect((1...4).contains(result.counts.scopeSubjectCount))
            case "fallback":
              #expect(result.counts.extraction == 1 && result.counts.resolution == 1)
              #expect(result.counts.scopeSubjectCount == 0)
            case "unresolved":
              #expect(result.counts.extraction == 0 && result.counts.resolution == 0)
              #expect(result.counts.topic == 0 && result.counts.scopeSubjectCount == 0)
            default:
              Issue.record("Invalid collective scope measurement, case \(index)")
            }
          } else {
            #expect(result.counts.extraction == 1 && result.counts.resolution == 1)
            #expect(result.counts.scopeStatus == nil && result.counts.scopeSubjectCount == 0)
          }
        }
        let baseline = try #require(outcomes[false])
        let hinted = try #require(outcomes[true])
        #expect(
          hinted.selected.subtracting(fixture.expected)
            .isSubset(of: baseline.selected.subtracting(fixture.expected)),
          "Hint introduced a false positive, case \(index)")
        #expect(
          fixture.expected.subtracting(hinted.selected)
            .isSubset(of: fixture.expected.subtracting(baseline.selected)),
          "Hint introduced a false negative, case \(index)")
      }
      await model.unload()
    } catch {
      await model.unload()
      throw error
    }
  }

  private func snapshot(_ fixture: FrozenAliasCase, index: Int) async throws
    -> PersonalMemorySnapshot
  {
    func id(_ offset: Int) -> UUID {
      UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index * 100 + offset))!
    }
    var value = PersonalMemorySnapshot()
    var profileIDs: [UUID] = []
    for (offset, item) in fixture.profiles.enumerated() {
      let owner = item.review == .owner
      var profile = PersonalProfile(
        id: owner ? value.selfProfileID : id(offset + 50), kind: owner ? .selfProfile : item.kind,
        name: item.name, aliases: item.aliases)
      profile.isSuggested = item.review == .unknown ? nil : item.review == .suggested
      if owner { value.profiles[0] = profile } else { value.profiles.append(profile) }
      profileIDs.append(profile.id)
    }
    value.sources = fixture.passages.enumerated().map {
      .init(
        id: id($0.offset + 1), text: $0.element, createdAt: Date(timeIntervalSince1970: 10_000),
        origin: "Fictional independent fixture", kind: .conversationOnly)
    }
    let memory = PersonalMemoryUseCases(repository: FrozenAliasRepository(value))
    for (profile, source) in fixture.links {
      _ = try await memory.addLink(
        from: profileIDs[profile], to: value.sources[source].id, label: "Owner association")
    }
    return try await memory.snapshot()
  }

  private func run(
    _ fixture: FrozenAliasCase, hinted: Bool, model: any StructuredChatModel,
    records: [MemorySearchRecord], identities: [MemorySearchIdentity]
  ) async -> Result {
    let meter = FrozenAliasMeter(
      model, query: fixture.query, passages: fixture.passages, allowsKnownIdentityHints: hinted)
    let search = LocalMeaningSearch(
      candidates: FrozenAliasCandidates(), model: meter, unloadAfterSearch: false,
      useKnownIdentityHints: hinted)
    let start = ContinuousClock.now
    var selected: Set<Int> = []
    var failure: String?
    var preserved = true
    do {
      let hits = try await withThrowingTaskGroup(of: [MemorySearchHit].self) { group in
        group.addTask {
          try await search.search(
            query: fixture.query, records: records, limit: records.count,
            identityAliases: identities)
        }
        group.addTask {
          try await Task.sleep(for: .seconds(90))
          throw FrozenAliasFailure.timedOut
        }
        defer { group.cancelAll() }
        return try await group.next()!
      }
      for hit in hits {
        guard let index = records.firstIndex(where: { $0.id == hit.sourceID }),
          let passage = hit.matchedText
        else {
          preserved = false
          continue
        }
        preserved = preserved && Data(passage.utf8) == Data(records[index].text.utf8)
        preserved = preserved && selected.insert(index).inserted
      }
    } catch MemorySearchFailure.ambiguousSubject {
      failure = "ambiguous"
    } catch FrozenAliasFailure.timedOut {
      failure = "timeout"
    } catch {
      failure = "other"
    }
    let elapsed = start.duration(to: .now).components
    return .init(
      selected: selected, error: failure, originalBytesPreserved: preserved,
      counts: await meter.measurements(),
      seconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
  }

  private func emit(
    index: Int, hinted: Bool, fixture: FrozenAliasCase, result: Result, prefix: String
  ) {
    let row: [String: Any] = [
      "case": index, "hint": hinted, "seconds": result.seconds,
      "selected": result.selected.sorted(), "expected": fixture.expected.sorted(),
      "error": result.error.map { $0 as Any } ?? NSNull(),
      "extractionCalls": result.counts.extraction, "resolutionCalls": result.counts.resolution,
      "topicCalls": result.counts.topic,
      "scopeCalls": result.counts.scope,
      "scopeStatus": result.counts.scopeStatus.map { $0 as Any } ?? NSNull(),
      "scopeSubjectCount": result.counts.scopeSubjectCount,
      "maximumRequestedTokens": result.counts.maximumRequestedTokens,
      "originalBytesPreserved": result.originalBytesPreserved && result.counts.inputBytesPreserved,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) {
      print(prefix + String(decoding: data, as: UTF8.self))
    }
  }
}

extension FrozenAliasCase {
  // New independent corpus. Existing consumed declarations above are unchanged.
  fileprivate static let collective: [Self] = [
    .init(
      query: "What did Elodie and Karim say about the garden visit?",
      profiles: [.init(name: "Elodie"), .init(name: "Karim")],
      passages: [
        "Elodie suggested visiting the garden on Sunday.",
        "Karim proposed visiting the garden on Tuesday.",
        "Leila will visit the garden on Friday.",
      ], expected: [0, 1], hintExtractions: 1),
    .init(
      query: "What did Tomas ask Aisha to bring to the picnic?",
      profiles: [.init(name: "Tomas")],
      passages: [
        "Tomas asked Aisha to bring a blanket to the picnic.",
        "Aisha asked Tomas to bring plates to the picnic.",
        "Tomas bought a blanket for his bedroom.",
      ], expected: [0], hintExtractions: 1),
    .init(
      query: "What did Helena and Pavel decide about the workshop budget?",
      profiles: [.init(name: "Helena"), .init(name: "Pavel")],
      passages: [
        "Helena capped the workshop budget at 90.",
        "Pavel set his workshop budget at 110.", "Helena scheduled a music lesson for Monday.",
        "Nora set the workshop budget at 70.",
      ], expected: [0, 1], hintExtractions: 1),
    .init(
      query: "What arrival times did Salma and Victor give for the ferry?",
      profiles: [.init(name: "Salma"), .init(name: "Victor")],
      passages: [
        "Salma will arrive at the ferry terminal at 09:00.",
        "Emil will arrive at the ferry terminal at 10:00.", "Salma prefers lentil soup.",
      ],
      expected: [0], hintExtractions: 1),
    .init(
      query: "What did M and Quentin choose for the celebration?",
      profiles: [
        .init(name: "Mariam", aliases: ["M"]), .init(name: "Marina", aliases: ["M"]),
        .init(name: "Quentin"),
      ],
      passages: [
        "Mariam chose a garden celebration.", "Marina chose a restaurant celebration.",
        "Quentin chose a beach celebration.",
      ],
      expected: [], hintExtractions: 1, expectsClarification: true),
    .init(
      query: "شنو اتفقت ياسمين وMazen بخصوص زيارة المتحف؟",
      profiles: [
        .init(name: "Yasmin", aliases: ["ياسمين"]),
        .init(name: "Mazen", aliases: ["مازن"]),
      ],
      passages: [
        "ياسمين: أفضل نزور المتحف يوم الخميس.",
        "Mazen: Thursday works for the museum visit.", "Yaseen will visit the museum on Saturday.",
      ],
      expected: [0, 1], hintExtractions: 1),
    .init(
      query: "What did Jun, Petra, and Leon each choose for the weekend trip?",
      profiles: [.init(name: "Jun"), .init(name: "Petra")],
      passages: [
        "Jun chose the seaside for the weekend trip.",
        "Petra chose the mountains for the weekend trip.",
        "Leon chose the city for the weekend trip.",
      ],
      expected: [], hintExtractions: 1, expectsClarification: true),
    .init(
      query: "What instructions did Deniz and Olga give for the delivery?",
      profiles: [.init(name: "Deniz")],
      passages: [
        "Deniz asked the driver to ring the bell for the delivery.",
        "Olga asked the driver to knock twice for the delivery.", "Deniz enjoys quiet music.",
      ],
      expected: [], hintExtractions: 1, expectsClarification: true),
  ]
}

@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_COLLECTIVE_SCOPE_COMPARISON"] == "1")
)
@MainActor struct FreshCollectiveScopeComparisonTests {
  @Test(.timeLimit(.minutes(30)))
  func frozenRequestedSubjectsPreserveUnionRolesAndExplicitUnknowns() async throws {
    try await FreshIdentityHintComparisonTests().compare(
      FrozenAliasCase.collective, prefix: "FROZEN_COLLECTIVE_SCOPE ",
      scopeExpectations: [
        0: ("complete", 2), 1: ("complete", 1), 2: ("complete", 2), 3: ("complete", 2),
        4: ("unresolved", 0), 5: ("complete", 2), 6: ("unresolved", 0), 7: ("unresolved", 0),
      ])
  }
}
