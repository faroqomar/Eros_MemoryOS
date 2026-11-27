import ChatCore
import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private actor GroundingModel: StructuredChatModel {
  let extracted: String?
  let resolution: String
  let relevant: Bool
  let scopeStatus: String
  let scopeSubjects: [String]
  private(set) var offeredScopes: [[[String]]] = []
  private(set) var collections: [[String: [String]]] = []
  let failAt: Int?
  private(set) var stages: [String] = []
  private(set) var payloads: [[String: String]] = []
  private(set) var unloads = 0

  init(
    extracted: String? = "Nadia", resolution: String = "complete",
    relevant: Bool = true, failAt: Int? = nil,
    scopeStatus: String = "complete", scopeSubjects: [String] = ["s0"]
  ) {
    self.extracted = extracted
    self.resolution = resolution
    self.relevant = relevant
    self.scopeStatus = scopeStatus
    self.scopeSubjects = scopeSubjects
    self.failAt = failAt
  }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) throws -> String {
    let stage =
      grammar.contains("scope-status ::=")
      ? "scope"
      : grammar.contains("subject ::=")
        ? "extract" : grammar.contains("resolution") ? "resolve" : "topic"
    stages.append(stage)
    let object =
      try JSONSerialization.jsonObject(with: Data(turns.last!.text.utf8)) as! [String: Any]
    payloads.append(object.compactMapValues { $0 as? String })
    collections.append(object.compactMapValues { $0 as? [String] })
    if stage == "scope", let candidates = object["candidates"] as? [[String: Any]] {
      offeredScopes.append(candidates.compactMap { $0["names"] as? [String] })
    }
    if stages.count == failAt { throw CancellationError() }
    let output: [String: Any]
    switch stage {
    case "scope":
      output = [
        "assessment": "Controlled requested scope.", "status": scopeStatus,
        "subjects": scopeSubjects,
      ]
    case "extract":
      output = [
        "assessment": "Controlled extraction.", "subjects": extracted.map { [$0] } ?? [],
      ]
    case "resolve":
      output = [
        "assessment": "Controlled query context.",
        "resolution": resolution,
      ]
    default: output = ["relevant": relevant]
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: output), as: UTF8.self)
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    Issue.record("Query grounding requires structured generation")
  }
  func unload() { unloads += 1 }
}

private struct GroundingCandidates: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.prefix(limit).map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
  }
}

private actor GroundingRepository: PersonalMemoryRepository {
  var value: PersonalMemorySnapshot
  init(_ value: PersonalMemorySnapshot = .init()) { self.value = value }
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private actor GroundingSnapshots {
  var values: [LocalChatMemory.RecallSnapshot]
  init(_ values: [LocalChatMemory.RecallSnapshot]) { self.values = values }
  func next() -> LocalChatMemory.RecallSnapshot {
    values.count > 1 ? values.removeFirst() : values[0]
  }
}

struct KnownIdentityQueryGroundingTests {
  @Test(arguments: [false, true])
  func optInRemovesOnlyExtractionAndKeepsSourceAndTopicChecks(enabled: Bool) async throws {
    let source = ChatEvidence(id: UUID(), text: "نادية: الموعد الأحد. Cafe\u{0301}")
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: enabled)
    #expect(
      try await filter.selectRelevant(
        query: "When is Nadia’s appointment?", candidates: [source],
        identities: [.init(names: ["Nadia", "نادية"], canGroundQuery: true)]) == [source.id])
    #expect(
      await model.stages == (enabled ? ["scope", "topic"] : ["extract", "resolve", "topic"]))
    let payloads = await model.payloads
    if enabled {
      #expect(await model.offeredScopes == [[["Nadia"]]])
      #expect(payloads[0] == ["query": "When is Nadia’s appointment?"])
    } else {
      #expect(payloads[payloads.count - 2] == ["query": "When is Nadia’s appointment?"])
      let collections = await model.collections
      #expect(collections[collections.count - 2] == ["candidates": ["Nadia"]])
    }
    #expect(payloads.last!["passage"]!.utf8.elementsEqual(source.text.utf8))
    #expect(await model.unloads == 1)
  }

  @Test(arguments: [
    ("When does NADIA meet?", "Nadia", "NADIA"),
    ("متى موعد نادية؟", "نادية", "نادية"),
    ("When is مشروع النور due?", "مشروع النور", "مشروع النور"),
    ("Ask Jose\u{0301} about Friday.", "Jose\u{0301}", "Jose\u{0301}"),
  ])
  func originalQuerySpanBytesReachContextVerifier(query: String, alias: String, span: String)
    async throws
  {
    let model = GroundingModel()
    let source = ChatEvidence(id: UUID(), text: "A linked appointment on Sunday.")
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    #expect(
      try await filter.selectRelevant(
        query: query, candidates: [source],
        identities: [
          .init(names: [alias], documentIDs: [source.id], canGroundQuery: true)
        ]) == [source.id])
    #expect(await model.stages == ["scope", "topic"])
    let payload = try #require(await model.payloads.first)
    #expect(payload["query"]!.utf8.elementsEqual(query.utf8))
    #expect((await model.offeredScopes)[0][0][0].utf8.elementsEqual(span.utf8))
  }

  @Test(arguments: [
    ("When does Nadia meet?", ["Nad"]),
    ("متى موعد نادية؟", ["نادي"]),
    ("When does Nadia meet?", ["Tariq"]),
  ])
  func absentAndPartialNamesKeepExtraction(query: String, names: [String])
    async throws
  {
    let model = GroundingModel(extracted: nil, resolution: "generic")
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    _ = try await filter.selectRelevant(
      query: query, candidates: [.init(id: UUID(), text: "Sunday.")],
      identities: [.init(names: names, canGroundQuery: true)])
    #expect(await model.stages == ["extract", "resolve", "topic"])
  }

  @Test(arguments: [false, true])
  func sharedAliasesFallBackEvenForIneligibleProfileWithoutCandidates(otherEligible: Bool)
    async throws
  {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: ChatError.memorySubjectUnclear) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [
          .init(names: ["Nadia"], canGroundQuery: true),
          .init(names: ["Nadia"], canGroundQuery: otherEligible),
        ])
    }
    #expect(await model.stages == ["extract", "resolve"])
  }

  @Test(arguments: [false, true])
  func unknownMetadataAndDisabledDefaultKeepOrdinaryResolution(explicitMetadata: Bool) async throws
  {
    let model = GroundingModel()
    let filter =
      explicitMetadata
      ? SourceBoundedChatEvidenceFilter(model: model)
      : SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    _ = try await filter.selectRelevant(
      query: "When does Nadia meet?", candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
      identities: [
        .init(names: ["Nadia"], canGroundQuery: explicitMetadata)
      ])
    #expect(await model.stages == ["extract", "resolve", "topic"])
  }

  @Test func commonWordAliasCannotBypassGenericQueryResolution() async throws {
    let model = GroundingModel(
      extracted: nil, resolution: "generic", scopeStatus: "fallback",
      scopeSubjects: [])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let source = ChatEvidence(id: UUID(), text: "The appointment is Sunday.")
    #expect(
      try await filter.selectRelevant(
        query: "May I check the appointment?", candidates: [source],
        identities: [
          .init(names: ["May"], canGroundQuery: true)
        ]) == [source.id])
    #expect(await model.stages == ["scope", "extract", "resolve", "topic"])
    #expect(await model.payloads.last?["appLinkedSubject"] == nil)
  }

  @Test func topicRejectionAndUnrelatedPeopleStillExcludeEvidence() async throws {
    let model = GroundingModel(relevant: false)
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    #expect(
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [
          .init(id: UUID(), text: "Tariq meets Sunday."),
          .init(id: UUID(), text: "Nadia likes tea."),
        ], identities: [.init(names: ["Nadia"], canGroundQuery: true)]
      ).isEmpty)
    #expect(await model.stages == ["scope", "topic"])
    #expect(await model.payloads.last?["passage"] == "Nadia likes tea.")
  }

  @Test func unresolvedHintRefusesWithoutTopicCalls() async throws {
    let model = GroundingModel(scopeStatus: "unresolved", scopeSubjects: [])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: ChatError.memorySubjectUnclear) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.stages == ["scope"])
  }

  @Test
  func nonRequestedHintFallsBackToAnUnprofiledNamedSubjectWithoutWidening()
    async throws
  {
    let query = "When does Tariq meet in May?"
    let model = GroundingModel(
      extracted: "Tariq", scopeStatus: "fallback", scopeSubjects: [])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let sources = [
      ChatEvidence(id: UUID(), text: "May meets on Sunday."),
      .init(id: UUID(), text: "Tariq meets Friday."),
    ]
    let identities = [ChatEvidenceIdentity(names: ["May"], canGroundQuery: true)]
    let selected = try await filter.selectRelevant(
      query: query, candidates: sources, identities: identities)
    let baseline = SourceBoundedChatEvidenceFilter(model: GroundingModel(extracted: "Tariq"))
    #expect(
      selected
        == (try await baseline.selectRelevant(
          query: query, candidates: sources, identities: identities)))
    #expect(selected == [sources[1].id])
    #expect(await model.stages == ["scope", "extract", "resolve", "topic"])
    let payloads = await model.payloads
    #expect(payloads[0] == ["query": query])
    #expect(await model.offeredScopes == [[["May"]]])
    #expect(payloads[2] == ["query": query])
    #expect(await model.collections[2] == ["candidates": ["Tariq"]])
    #expect(await model.unloads == 1)
  }

  @Test func malformedHintVerdictDoesNotFallThroughToExtraction() async {
    let model = GroundingModel(scopeStatus: "invalid-verdict")
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: RetrievalError.self) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.stages == ["scope"])
    #expect(await model.unloads == 1)
  }

  @Test(arguments: [2, 3], [false, true])
  func cancellationDuringRejectedHintRecoveryPropagates(request: Int, owns: Bool) async {
    let model = GroundingModel(failAt: request, scopeStatus: "fallback", scopeSubjects: [])
    let filter = SourceBoundedChatEvidenceFilter(
      model: model, unloadAfterSelection: owns, useKnownIdentityHints: true)
    await #expect(throws: CancellationError.self) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.stages.count == request)
    #expect(await model.unloads == (owns ? 1 : 0))
  }

  @Test func eligibleHintCannotBypassExistingQuestionBounds() async {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: (any Error).self) {
      try await filter.selectRelevant(
        query: "Nadia " + String(repeating: "word ", count: 96),
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.stages.isEmpty)
    #expect(await model.unloads == 1)
  }

  @Test(arguments: [false, true], [1, 2])
  func cancellationRetainsLifecycleOwnershipAndReturnsNoSelection(owns: Bool, request: Int) async {
    let model = GroundingModel(failAt: request)
    let filter = SourceBoundedChatEvidenceFilter(
      model: model, unloadAfterSelection: owns, useKnownIdentityHints: true)
    await #expect(throws: CancellationError.self) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.unloads == (owns ? 1 : 0))
  }

  @Test func eligibilityChangesRejectInFlightChatEvidence() async throws {
    let id = UUID()
    let records = [MemorySearchRecord(id: id.uuidString, text: "Nadia meets Sunday.")]
    let before = LocalChatMemory.RecallSnapshot(
      records: records, identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    let after = LocalChatMemory.RecallSnapshot(
      records: records, identities: [.init(names: ["Nadia"])])
    let snapshots = GroundingSnapshots([before, after])
    let memory = LocalChatMemory(
      search: GroundingCandidates(),
      relevance: SourceBoundedChatEvidenceFilter(
        model: GroundingModel(), useKnownIdentityHints: true),
      readSnapshot: { await snapshots.next() })
    await #expect(throws: (any Error).self) {
      try await memory.retrieve(query: "When does Nadia meet?")
    }
    #expect(
      MemorySearchIdentity(names: ["Nadia"], canGroundQuery: true)
        != MemorySearchIdentity(names: ["Nadia"]))
  }

  @Test func largeIdentityCatalogKeepsOrdinaryResolver() async throws {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let identities = (0..<1_025).map {
      ChatEvidenceIdentity(names: [$0 == 0 ? "Nadia" : "Profile \($0)"], canGroundQuery: true)
    }
    _ = try await filter.selectRelevant(
      query: "When does Nadia meet?", candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
      identities: identities)
    #expect(await model.stages == ["extract", "resolve", "topic"])
  }
}

extension KnownIdentityQueryGroundingTests {
  @Test func collectiveScopeUnionsOnlyRelevantOriginalsWithPerSourceAssociations() async throws {
    let model = GroundingModel(scopeSubjects: ["s0", "s1"])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let first = ChatEvidence(id: UUID(), text: "The appointment is Sunday. Cafe\u{0301}")
    let second = ChatEvidence(id: UUID(), text: "الموعد الثلاثاء.")
    let other = ChatEvidence(id: UUID(), text: "Unrelated person's appointment is Friday.")
    let query = "Compare Nadia and طارق appointments."
    #expect(
      try await filter.selectRelevant(
        query: query, candidates: [first, second, other],
        identities: [
          .init(names: ["Nadia"], documentIDs: [first.id], canGroundQuery: true),
          .init(names: ["طارق"], documentIDs: [second.id], canGroundQuery: true),
        ]) == [first.id, second.id])
    #expect(await model.stages == ["scope", "topic", "topic"])
    let payloads = await model.payloads
    let collections = await model.collections
    #expect(payloads[0] == ["query": query])
    #expect(payloads[1]["passage"]!.utf8.elementsEqual(first.text.utf8))
    #expect(payloads[2]["passage"]!.utf8.elementsEqual(second.text.utf8))
    #expect(collections[1]["requestedSubjects"] == ["Nadia", "طارق"])
    #expect(collections[1]["matchedSubjects"] == ["Nadia"])
    #expect(collections[1]["appLinkedSubjects"] == ["Nadia"])
    #expect(collections[2]["appLinkedSubjects"] == ["طارق"])
  }

  @Test(arguments: [false, true])
  func unknownRequestedPersonRefusesWholeScopeEvenAlongsideKnownPeople(twoKnown: Bool) async {
    let model = GroundingModel(scopeStatus: "unresolved", scopeSubjects: [])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let query =
      twoKnown
      ? "Compare Nadia, Tariq and Mira appointments." : "Compare Nadia and Mira appointments."
    var identities = [ChatEvidenceIdentity(names: ["Nadia"], canGroundQuery: true)]
    if twoKnown { identities.append(.init(names: ["Tariq"], canGroundQuery: true)) }
    await #expect(throws: ChatError.memorySubjectUnclear) {
      try await filter.selectRelevant(
        query: query, candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: identities)
    }
    #expect(await model.stages == ["scope"])
    #expect(await model.payloads == [["query": query]])
  }

  @Test func knownContextOnlyNameCannotAdmitItsOwnUnrelatedRecords() async throws {
    let model = GroundingModel(scopeSubjects: ["s0"])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let right = ChatEvidence(id: UUID(), text: "Nadia promised to call Tariq Sunday.")
    let wrong = ChatEvidence(id: UUID(), text: "Tariq promised a different call Friday.")
    #expect(
      try await filter.selectRelevant(
        query: "What did Nadia promise Tariq?", candidates: [right, wrong],
        identities: [
          .init(names: ["Nadia"], canGroundQuery: true),
          .init(names: ["Tariq"], canGroundQuery: true),
        ]) == [right.id])
    #expect(await model.stages == ["scope", "topic"])
    #expect(await model.collections.last?["requestedSubjects"] == ["Nadia"])
    #expect(await model.payloads.last?["query"] == "What did Nadia promise Tariq?")
  }

  @Test func unknownContextOnlyPersonDoesNotRequireInventedProfile() async throws {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let right = ChatEvidence(id: UUID(), text: "Nadia promised to call Mira Sunday.")
    #expect(
      try await filter.selectRelevant(
        query: "What did Nadia promise Mira?", candidates: [right],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)]) == [right.id])
    #expect(await model.stages == ["scope", "topic"])
  }

  @Test(arguments: [
    ("complete", []), ("complete", ["s9"]), ("complete", ["s0", "s0"]),
    ("fallback", ["s0"]), ("unresolved", ["s0"]),
  ])
  func invalidCollectiveSelectionsCannotReachTopicVotes(status: String, slots: [String]) async {
    let model = GroundingModel(scopeStatus: status, scopeSubjects: slots)
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: RetrievalError.self) {
      try await filter.selectRelevant(
        query: "When does Nadia meet?",
        candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
        identities: [.init(names: ["Nadia"], canGroundQuery: true)])
    }
    #expect(await model.stages == ["scope"])
  }

  @Test(arguments: [("متى موعد ونادية؟", "نادية"), ("And فNadia?", "Nadia")])
  func attachedArabicConjunctionKeepsExactAliasAndQueryBytes(query: String, name: String)
    async throws
  {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let source = ChatEvidence(id: UUID(), text: "An explicitly linked appointment.")
    #expect(
      try await filter.selectRelevant(
        query: query, candidates: [source],
        identities: [.init(names: [name], documentIDs: [source.id], canGroundQuery: true)]) == [
          source.id
        ])
    #expect(await model.offeredScopes == [[[name]]])
    #expect(await model.payloads.first?["query"] == query)
    #expect(await model.stages == ["scope", "topic"])
  }

  @Test(arguments: [("وليد", "ليد"), ("Nadia Noor", "Nadia")])
  func explicitFullNameExcludesAnotherProfilesContainedAlias(full: String, short: String)
    async throws
  {
    let model = GroundingModel()
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let source = ChatEvidence(id: UUID(), text: "A linked original.")
    #expect(
      try await filter.selectRelevant(
        query: "When does \(full) meet?", candidates: [source],
        identities: [
          .init(names: [short], canGroundQuery: true),
          .init(names: [full], documentIDs: [source.id], canGroundQuery: true),
        ]) == [source.id])
    #expect(await model.offeredScopes == [[[full]]])
  }

  @Test(arguments: ["بNadia", "Alina", "ناديان"])
  func arbitraryLettersCannotBeStrippedToInventAlias(word: String) async throws {
    let model = GroundingModel(extracted: nil, resolution: "generic")
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    _ = try await filter.selectRelevant(
      query: "Topic \(word)?", candidates: [.init(id: UUID(), text: "A topic.")],
      identities: [
        .init(names: ["Nadia", "Ali", "نادية"], canGroundQuery: true)
      ])
    #expect(await model.stages == ["extract", "resolve", "topic"])
  }

  @Test(arguments: [("وليد", "ليد"), ("Nadia Noor", "Nadia")])
  func sharedLongNameCannotPromoteAnotherProfilesContainedShortName(full: String, short: String)
    async
  {
    let model = GroundingModel(extracted: full)
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: ChatError.memorySubjectUnclear) {
      try await filter.selectRelevant(
        query: "When does \(full) meet?",
        candidates: [.init(id: UUID(), text: "\(short) meets Sunday.")],
        identities: [
          .init(names: [full], canGroundQuery: true), .init(names: [full], canGroundQuery: true),
          .init(names: [short], canGroundQuery: true),
        ])
    }
    #expect(await model.offeredScopes.isEmpty)
    #expect(await model.stages == ["extract", "resolve"])
  }

  @Test func sharedCommonWordKeepsGenericBaselineAndCannotSelectEitherOwner() async throws {
    let model = GroundingModel(extracted: nil, resolution: "generic")
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let source = ChatEvidence(id: UUID(), text: "The appointment is Sunday.")
    #expect(
      try await filter.selectRelevant(
        query: "May I check the appointment?", candidates: [source],
        identities: [
          .init(names: ["May"], canGroundQuery: true), .init(names: ["May"], canGroundQuery: true),
        ]) == [source.id])
    #expect(await model.stages == ["extract", "resolve", "topic"])
    #expect(await model.offeredScopes.isEmpty)
  }

  @Test func missingHistoryReturnsOnlySupportedContributionWithoutInventingSecondEvidence()
    async throws
  {
    let model = GroundingModel(scopeSubjects: ["s0", "s1"])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    let source = ChatEvidence(id: UUID(), text: "Nadia meets Sunday.")
    #expect(
      try await filter.selectRelevant(
        query: "Compare Nadia and Tariq appointments.", candidates: [source],
        identities: [
          .init(names: ["Nadia"], canGroundQuery: true),
          .init(names: ["Tariq"], canGroundQuery: true),
        ]) == [source.id])
    #expect(await model.collections.last?["requestedSubjects"] == ["Nadia", "Tariq"])
    #expect(await model.collections.last?["matchedSubjects"] == ["Nadia"])
  }

  @Test(arguments: [4, 5])
  func candidateCapUsesAllProfilesOrLeavesOriginalQueryToBaseline(count: Int) async throws {
    let names = Array(["Nadia", "Tariq", "Mira", "Zaid", "Sahar"].prefix(count))
    let model = GroundingModel(scopeSubjects: (0..<count).map { "s\($0)" })
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    _ = try await filter.selectRelevant(
      query: "Compare " + names.joined(separator: ", ") + " appointments.",
      candidates: [.init(id: UUID(), text: "Nadia meets Sunday.")],
      identities: names.map { .init(names: [$0], canGroundQuery: true) })
    #expect(
      await model.stages == (count == 4 ? ["scope", "topic"] : ["extract", "resolve", "topic"]))
    #expect(await model.offeredScopes.first?.count == (count == 4 ? 4 : nil))
  }

  @Test func cancellationAfterFirstGroupVoteCannotPublishPartialSelection() async {
    let model = GroundingModel(failAt: 3, scopeSubjects: ["s0", "s1"])
    let filter = SourceBoundedChatEvidenceFilter(model: model, useKnownIdentityHints: true)
    await #expect(throws: CancellationError.self) {
      try await filter.selectRelevant(
        query: "Compare Nadia and Tariq appointments.",
        candidates: [
          .init(id: UUID(), text: "Nadia meets Sunday."),
          .init(id: UUID(), text: "Tariq meets Friday."),
        ],
        identities: [
          .init(names: ["Nadia"], canGroundQuery: true),
          .init(names: ["Tariq"], canGroundQuery: true),
        ])
    }
    #expect(await model.stages == ["scope", "topic", "topic"])
    #expect(await model.unloads == 1)
  }

  @Test(arguments: [PersonalProfileKind.person, .project])
  func ownerCreationAndNameEditExplicitlyGroundProfiles(kind: PersonalProfileKind) async throws {
    let memory = PersonalMemoryUseCases(repository: GroundingRepository())
    let created = try await memory.createProfile(kind: kind, name: "Nadia", aliases: ["نادية"])
    let profile = try #require(created.profiles.first { $0.kind == kind })
    #expect(profile.isSuggested == false)
    #expect(
      MemorySearchIdentity.make(personal: created, availableDocumentIDs: []).first {
        $0.names.contains("Nadia")
      }?.canGroundQuery == true)
    #expect(
      LocalChatMemory.makeSnapshot(local: [], personal: created).identities.first {
        $0.names.contains("Nadia")
      }?.canGroundQuery == true)
    var legacy = PersonalMemorySnapshot()
    legacy.profiles.append(PersonalProfile(kind: kind, name: "Nadia"))
    let cases = PersonalMemoryUseCases(repository: GroundingRepository(legacy))
    let edited = try await cases.updateProfile(
      id: legacy.profiles.last!.id, name: "Nadia", aliases: [])
    #expect(edited.profiles.last?.isSuggested == false)
    let undone = try await cases.undo()
    #expect(undone.profiles.last?.isSuggested == nil)
    #expect(
      !MemorySearchIdentity.make(personal: undone, availableDocumentIDs: []).contains {
        $0.canGroundQuery
      })
    let restored = try await PersonalMemoryUseCases(repository: GroundingRepository())
      .restoreArchive(try await memory.exportArchive())
    #expect(restored.profiles.first { $0.id == profile.id }?.isSuggested == false)
  }

  @Test func legacyUnknownSelfAndSuggestedProfilesRemainIneligible() throws {
    var snapshot = PersonalMemorySnapshot()
    snapshot.profiles[0].isSuggested = false
    snapshot.profiles.append(PersonalProfile(kind: .person, name: "Legacy"))
    var proposed = PersonalProfile(kind: .project, name: "Proposed")
    proposed.isSuggested = true
    snapshot.profiles.append(proposed)
    let decoded = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(
      !MemorySearchIdentity.make(personal: decoded, availableDocumentIDs: []).contains {
        $0.canGroundQuery
      })
    #expect(
      !LocalChatMemory.makeSnapshot(local: [], personal: decoded).identities.contains {
        $0.canGroundQuery
      })
  }

  @Test(arguments: [false, true])
  func mergeAndPhotoOnlyActionsDoNotConfirmUnknownNames(reviewedTarget: Bool) async throws {
    var snapshot = PersonalMemorySnapshot()
    let first = PersonalProfile(kind: .person, name: "Nadia")
    var target = PersonalProfile(kind: .person, name: "Nadia Noor")
    if reviewedTarget { target.isSuggested = false }
    snapshot.profiles += [first, target]
    let memory = PersonalMemoryUseCases(repository: GroundingRepository(snapshot))
    let photographed = try await memory.setPhoto(
      profileID: first.id, data: Data([1]), origin: .supplied)
    #expect(photographed.profiles.first { $0.id == first.id }?.isSuggested == nil)
    let merged = try await memory.mergePeople(from: first.id, into: target.id, confirmed: true)
    #expect(merged.profiles.first { $0.id == target.id }?.isSuggested == nil)
    #expect(
      !MemorySearchIdentity.make(personal: merged, availableDocumentIDs: []).contains {
        $0.canGroundQuery
      })
  }

  @Test func actualAIProposalStaysSuggestedUntilOwnerEditsAndLaterAnalysisPreservesReview()
    async throws
  {
    let memory = PersonalMemoryUseCases(repository: GroundingRepository())
    let source = PersonalMemorySource(text: "Nadia likes tea.")
    _ = try await memory.ingest(source: source)
    let input = try #require(try await memory.nextAnalysisInput())
    let proposed = try await memory.applyAnalysis(
      .init(memories: [
        .init(quote: source.text, kind: .fact, subjectName: "Nadia", subjectKind: .person)
      ]), input: input)
    let profile = try #require(proposed.profiles.first { $0.name == "Nadia" })
    #expect(profile.isSuggested == true)
    #expect(
      !MemorySearchIdentity.make(personal: proposed, availableDocumentIDs: []).contains {
        $0.canGroundQuery
      })
    _ = try await memory.updateProfile(id: profile.id, name: "Nadia", aliases: ["نادية"])
    let second = PersonalMemorySource(text: "Nadia meets Sunday.")
    _ = try await memory.ingest(source: second)
    let next = try #require(try await memory.nextAnalysisInput())
    let updated = try await memory.applyAnalysis(
      .init(memories: [
        .init(quote: second.text, kind: .fact, subjectName: "Nadia", subjectKind: .person)
      ]), input: next)
    #expect(updated.profiles.first { $0.id == profile.id }?.isSuggested == false)
    #expect(
      MemorySearchIdentity.make(personal: updated, availableDocumentIDs: []).first {
        $0.names.contains("Nadia")
      }?.canGroundQuery == true)
  }
}
