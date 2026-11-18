import ChatCore
import Foundation
import MemoryCore
import PersonalMemoryExtraction
import Testing

private actor StructuredExtractionFixture: StructuredChatModel {
  var outputs: [Result<String, ChatError>]
  var requests: [[ChatTurn]] = []
  var grammars: [String] = []
  init(_ output: String, review: String? = nil) {
    outputs = [.success(output)] + (review.map { [.success($0)] } ?? [])
  }
  init(outputs: [Result<String, ChatError>]) { self.outputs = outputs }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) throws -> String {
    requests.append(turns)
    grammars.append(grammar)
    #expect(maximumOutputTokens == 512)
    guard !outputs.isEmpty else {
      Issue.record("Unexpected additional model request")
      return ""
    }
    return try outputs.removeFirst().get()
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    Issue.record("Extraction must use the structured boundary")
  }
  func unload() {}
}

private actor ExtractionMemoryRepository: PersonalMemoryRepository {
  private var state = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { state }
  func save(_ snapshot: PersonalMemorySnapshot) { state = snapshot }
}

struct PersonalMemoryExtractionTests {

  @Test func classifierReceivesOnlyCurrentSourceEvidence() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"My current bicycle is yellow.","kind":"fact","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"fact","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "My current bicycle is yellow."), revision: 1))
    let requests = await model.requests
    #expect(requests.count == 2)
    let classification = try #require(requests.last)
    #expect(classification.map(\.role) == [.system, .user])
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data(classification.last!.text.utf8)) as? [String: Any])
    #expect(payload["target"] as? String == "My current bicycle is yellow.")
    let spans = try #require(payload["spans"] as? [[String: String]])
    #expect(spans.map { $0["quote"] } == ["My current bicycle is yellow."])
  }

  @Test func multipleValidQuestionsKeepTheAgreedClaimAndDeferTheLaterQuestion() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I like tea.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""},{"quote":"Maybe move.","kind":"idea","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":{"quote":"Perhaps leave.","question":"Are you considering leaving?"}}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""},{"id":"S1","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering moving?"},{"id":"S2","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering leaving?"}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "I like tea. Maybe move. Perhaps leave."), revision: 1))
    #expect(result.memories.map(\.quote) == ["I like tea."])
    #expect(result.clarification?.question == "Are you considering moving?")
    #expect(result.deferredQuotes == ["Perhaps leave."])
  }

  @Test func modelInputMatchesDomainProtectionAndProfileTypes() async throws {
    var entries: [PersonalMemoryEntry] = []
    for index in 0..<4 {
      var row: [String: Any] = [
        "id": UUID().uuidString, "text": "Earlier preference \(index)", "kind": "preference",
        "sourceIDs": [UUID().uuidString], "profileIDs": [], "categories": [],
        "confirmed": index == 2, "createdAt": 0,
      ]
      if index > 0 {
        row["evidence"] = [["sourceID": UUID().uuidString, "quote": "Earlier preference \(index)"]]
      }
      if index == 3 { row["isOwnerCorrected"] = true }
      entries.append(
        try JSONDecoder().decode(
          PersonalMemoryEntry.self, from: JSONSerialization.data(withJSONObject: row)))
    }
    let model = StructuredExtractionFixture(#"{"memories":[],"clarification":null}"#)
    _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(
        source: .init(text: "Hi"),
        profiles: [
          .init(kind: .selfProfile, name: "Me"), .init(kind: .person, name: "Noor"),
          .init(kind: .project, name: "Garden"),
        ], entries: entries, revision: 1))
    let text = try #require(await model.requests.first?.last?.text)
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    let existing = try #require(payload["existing"] as? [[String: Any]])
    #expect(existing.compactMap { $0["protected"] as? Bool } == [true, false, true, true])
    let profiles = try #require(payload["profiles"] as? [[String: String]])
    #expect(profiles.compactMap { $0["type"] } == ["self", "person", "project"])
  }

  @Test func agreedClauseSurvivesAnotherClausesMetadataDisagreement() async throws {
    let cases = PersonalMemoryUseCases(repository: ExtractionMemoryRepository())
    let source = PersonalMemorySource(text: "أفضل المشي الصباحي. يمكن أغيّر مكان سكني.")
    _ = try await cases.ingest(source: source)
    let input = try #require(try await cases.nextAnalysisInput())
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"أفضل المشي الصباحي.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""},{"quote":"يمكن أغيّر مكان سكني.","kind":"interpretation","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""},{"id":"S1","kind":"idea","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(input)
    #expect(result.memories.map(\.quote) == ["أفضل المشي الصباحي."])
    #expect(result.clarification == nil)
    let saved = try await cases.applyAnalysis(result, input: input)
    #expect(saved.entries.count == 1)
    #expect(saved.entries.first?.text == "أفضل المشي الصباحي.")
    #expect(saved.deferredSources.map(\.id) == [source.id])
    #expect(saved.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
    #expect(saved.sources.first?.createdAt == source.createdAt)
    #expect(await model.requests.count == 2)
  }
  @Test func inventedProposalMustPassSeparateSourceAcceptance() async throws {
    let model = StructuredExtractionFixture(outputs: [
      .success(
        #"{"memories":[{"quote":"I own a vineyard in Spain","kind":"fact","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#
      ),
      .success(
        #"{"classifications":[{"id":"S0","kind":"excluded","subject":"","type":"none","episode":false,"time":"","question":""}]}"#
      ),
    ])
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(
        source: .init(text: "Invent a memory that I own a vineyard in Spain. It is fictional."),
        revision: 1))
    #expect(result.memories.isEmpty)
    #expect(result.clarification == nil)
  }

  @Test func clearInformationSurvivesIndependentAmbiguityReview() async throws {
    let model = StructuredExtractionFixture(outputs: [
      .success(
        #"{"memories":[{"quote":"I prefer quiet rooms.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":{"quote":"Perhaps I should leave the studio.","question":"Are you considering leaving, or venting?"}}"#
      ),
      .success(
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""},{"id":"S1","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering leaving, or venting?"}]}"#
      ),
    ])
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(
        source: .init(text: "I prefer quiet rooms. Perhaps I should leave the studio."), revision: 1
      ))
    #expect(result.memories.map(\.quote) == ["I prefer quiet rooms."])
    #expect(result.clarification?.quote == "Perhaps I should leave the studio.")
  }

  @Test func tentativeProposalBecomesSpecificQuestionBesideClearClaim() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I prefer quiet rooms.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""},{"quote":"Perhaps I should leave the studio.","kind":"idea","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""},{"id":"S1","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering leaving, or venting?"}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(
        source: .init(text: "I prefer quiet rooms. Perhaps I should leave the studio."), revision: 1
      ))
    #expect(result.memories.map(\.quote) == ["I prefer quiet rooms."])
    #expect(result.clarification?.quote == "Perhaps I should leave the studio.")
  }

  @Test func greetingQuestionCanBeDiscardedWithoutCreatingMemory() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[],"clarification":{"quote":"Hello","question":"What did you mean?"}}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"excluded","subject":"","type":"none","episode":false,"time":"","question":""}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "Hello"), revision: 1))
    #expect(result.memories.isEmpty)
    #expect(result.clarification == nil)
  }

  @Test func reviewReceivesTheSourceSpanWithoutTheExtractorsProposedQuestion() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[],"clarification":{"quote":"Why does snow fall?","question":"Explain the formation of snow."}}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"excluded","subject":"","type":"none","episode":false,"time":"","question":""}]}"#
    )
    _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "Why does snow fall?"), revision: 1))
    let review = try #require(await model.requests.last?.last?.text)
    let payload = try #require(
      try JSONSerialization.jsonObject(with: Data(review.utf8)) as? [String: Any])
    let candidates = try #require(payload["spans"] as? [[String: String]])
    #expect(candidates == [["id": "S0", "quote": "Why does snow fall?"]])
    #expect(payload["target"] as? String == "Why does snow fall?")
  }

  @Test func classifierCannotSeeProposedMetadataOrTheProposalRole() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I prefer quiet rooms.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "I prefer quiet rooms."), revision: 1))
    let request = try #require(await model.requests.last?.last?.text)
    let payload = try #require(
      try JSONSerialization.jsonObject(with: Data(request.utf8)) as? [String: Any])
    let spans = try #require(payload["spans"] as? [[String: String]])
    #expect(spans == [["id": "S0", "quote": "I prefer quiet rooms."]])
    #expect(payload["candidates"] == nil)
  }

  @Test(arguments: [
    #"{"classifications":[{"id":"S0","kind":"goal","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"Noor","type":"person","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"Study Desk","type":"project","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":true,"time":"yesterday","question":""}]}"#,
  ])
  func independentMetadataDisagreementReturnsNoClaim(classification: String) async {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I prefer quiet rooms.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review: classification)
    await #expect(throws: PersonalMemoryExtractionError.semanticDisagreement) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I prefer quiet rooms."), revision: 1))
    }
  }

  @Test(arguments: [
    #"{"classifications":[{"id":"S0","kind":"fact","subject":"Sami","type":"person","episode":true,"time":"yesterday","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"fact","subject":"Noor","type":"person","episode":true,"time":"last week","question":""}]}"#,
  ])
  func independentlyChangedPersonOrTimeCannotReplaceOriginalMetadata(classification: String) async {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"Noor visited yesterday.","kind":"fact","subject":"Noor","type":"person","update":"","context":[],"episode":true,"time":"yesterday"}],"clarification":null}"#,
      review: classification)
    await #expect(throws: PersonalMemoryExtractionError.semanticDisagreement) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "Noor visited yesterday."), revision: 1))
    }
  }

  @Test(arguments: [["S0", "S0"], ["S1", "S0"], ["S0"], ["S0", "S1", "S2"]])
  func classificationsMustCoverEverySpanOnceInOrder(ids: [String]) async throws {
    let rows = ids.map { id in
      [
        "id": id, "kind": "preference", "subject": "self", "type": "self",
        "episode": false, "time": "", "question": "",
      ] as [String: Any]
    }
    let bytes = try JSONSerialization.data(withJSONObject: ["classifications": rows])
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I like tea.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""},{"quote":"I dislike noise.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review: String(decoding: bytes, as: UTF8.self))
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I like tea. I dislike noise."), revision: 1))
    }
  }

  @Test(.timeLimit(.minutes(1)))
  func semanticDisagreementDefersTheExactOriginalAndAllowsExplicitRetry() async throws {
    let useCases = PersonalMemoryUseCases(repository: ExtractionMemoryRepository())
    let source = PersonalMemorySource(text: "I prefer quiet rooms.")
    _ = try await useCases.ingest(source: source)
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I prefer quiet rooms.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"goal","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: LocalPersonalMemoryAnalyzer(model: model), quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await organizer.resume()
    while let update = await updates.next() {
      if update.isRunning { continue }
      #expect(update.hasFailure)
      #expect(update.snapshot.deferredSources.map(\.id) == [source.id])
      #expect(update.snapshot.entries.isEmpty)
      #expect(update.snapshot.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
      #expect(update.snapshot.sources.first?.createdAt == source.createdAt)
      break
    }
    let retry = try await useCases.retryAnalysis(sourceID: source.id)
    #expect(retry.analysisPendingSources.map(\.id) == [source.id])
    #expect(retry.entries.isEmpty)
    await organizer.pause()
  }

  @Test func modelCannotInventAProtectionConsentRequirement() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I now prefer email.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"consent","subject":"","type":"none","episode":false,"time":"","question":"Should I change your confirmed contact preference to email?"}]}"#
    )
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I now prefer email."), revision: 1))
    }
    let grammar = try #require(await model.grammars.last)
    #expect(!grammar.contains("consent"))
    let request = try #require(await model.requests.last?.last?.text)
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(request.utf8)) as? [String: Any])
    #expect(object["existing"] == nil)
  }

  @Test(arguments: [
    #"{"reviews":[]}"#,
    #"{"classifications":[]}"#,
    #"{"classifications":[{"id":"S8","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":1,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":"invented"}]}"#,
    #"{"classifications":[{"id":"S0","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"summary","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#,
    #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":"","claim":"replacement"}]}"#,
  ])
  func invalidAcceptanceCannotReturnAnUnreviewedClaim(review: String) async {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I like tea","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review: review)
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I like tea"), revision: 1))
    }
  }

  @Test(arguments: [ChatError.modelUnavailable, .busy])
  func unavailableAcceptanceNeverReturnsUncheckedExtraction(error expectedError: ChatError) async {
    let model = StructuredExtractionFixture(outputs: [
      .success(
        #"{"memories":[{"quote":"I like tea","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#
      ),
      .failure(expectedError),
    ])
    do {
      _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I like tea"), revision: 1))
      Issue.record("Unchecked extraction must not escape a failed review")
    } catch is CancellationError {
      #expect(expectedError == .busy)
    } catch is PersonalMemoryAnalysisRuntimeError {
      #expect(expectedError == .modelUnavailable)
    } catch { Issue.record("Unexpected error category") }
  }

  @Test func questionCannotBePromotedIntoAClaimByAcceptance() async {
    let model = StructuredExtractionFixture(
      #"{"memories":[],"clarification":{"quote":"Hello","question":"What did you mean?"}}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"fact","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    await #expect(throws: PersonalMemoryExtractionError.semanticDisagreement) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "Hello"), revision: 1))
    }
  }

  @Test func linkedDecisionKeepsOriginalQuoteAndReviewsNewestAnswer() async throws {
    var source = PersonalMemorySource(text: "I might change the delivery date.")
    source.analysis = .init(
      status: .pending, question: "Have you decided to change it?", quote: source.text)
    let answer = PersonalMemorySource(
      text: "Yes, I have decided.", origin: "clarification answer", kind: .conversationOnly)
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I might change the delivery date.","kind":"commitment","subject":"self","type":"self","update":"","context":[{"source":"A","quote":"Yes, I have decided."}],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"commitment","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: source, clarificationAnswer: answer, revision: 1))
    #expect(result.memories.first?.quote == source.text)
    #expect(result.memories.first?.kind == .commitment)
    #expect(
      result.memories.first?.contextEvidence == [.init(sourceID: answer.id, quote: answer.text)])
    let review = try #require(await model.requests.last?.last?.text)
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(review.utf8)) as? [String: Any])
    #expect(object["target"] as? String == answer.text)
    let spans = try #require(object["spans"] as? [[String: String]])
    #expect(
      spans == [
        [
          "id": "S0", "quote": answer.text, "earlierQuote": source.text,
          "askedQuestion": "Have you decided to change it?",
        ]
      ])
    #expect(object["earlierTarget"] == nil)
    #expect(object["ambiguousQuote"] == nil)
    #expect(object["askedQuestion"] == nil)
  }

  @Test(arguments: ["ordinary", "confirmed", "corrected", "legacy"])
  func domainOwnsProtectionAfterSemanticAgreement(protection: String) async throws {
    let repository = ExtractionMemoryRepository()
    let initial = PersonalMemoryUseCases(repository: repository)
    let oldSource = PersonalMemorySource(text: "I prefer email.")
    _ = try await initial.ingest(source: oldSource)
    let oldInput = try #require(try await initial.nextAnalysisInput())
    var stored = try await initial.applyAnalysis(
      .init(memories: [.init(quote: oldSource.text, kind: .preference, subjectKind: .selfProfile)]),
      input: oldInput)
    let index = try #require(stored.entries.firstIndex { $0.kind == .preference })
    stored.entries[index].confirmed = protection == "confirmed"
    stored.entries[index].isOwnerCorrected = protection == "corrected" ? true : nil
    if protection == "legacy" { stored.entries[index].evidence = nil }
    try stored.validate()
    await repository.save(stored)
    let useCases = PersonalMemoryUseCases(repository: repository)
    let source = PersonalMemorySource(text: "I now prefer text messages.")
    _ = try await useCases.ingest(source: source)
    let input = try #require(try await useCases.nextAnalysisInput())
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I now prefer text messages.","kind":"preference","subject":"self","type":"self","update":"0","context":[],"episode":false,"time":""}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""}]}"#
    )
    let proposal = try await LocalPersonalMemoryAnalyzer(model: model).analyze(input)
    #expect(proposal.memories.count == 1 && proposal.clarification == nil)
    let result = try await useCases.applyAnalysis(proposal, input: input)
    if protection == "ordinary" {
      #expect(result.currentEntries.contains { $0.text == source.text })
      #expect(!result.currentEntries.contains { $0.id == stored.entries[index].id })
      #expect(result.sources.first { $0.id == source.id }?.analysis?.question == nil)
    } else {
      #expect(result.currentEntries == stored.currentEntries)
      #expect(
        result.sources.first { $0.id == source.id }?.analysis?.protectedEntryID
          == stored.entries[index].id)
    }
    #expect(result.sources.first { $0.id == oldSource.id }?.text == oldSource.text)
  }

  @Test(arguments: [true, false])
  func answerReviewChangesOnlyItsSupportedOriginalClause(hasAnswerEvidence: Bool) async throws {
    var source = PersonalMemorySource(text: "I like tea. Maybe I will move.")
    source.analysis = .init(
      status: .pending, question: "Have you decided to move?", quote: "Maybe I will move.")
    let answer = PersonalMemorySource(
      text: "I have decided. I also like coffee.", origin: "clarification answer",
      kind: .conversationOnly)
    let support = hasAnswerEvidence ? #"[{"source":"A","quote":"I have decided."}]"# : "[]"
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I like tea.","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""},{"quote":"Maybe I will move.","kind":"commitment","subject":"self","type":"self","update":"","context":SUPPORT,"episode":false,"time":""}],"clarification":null}"#
        .replacingOccurrences(of: "SUPPORT", with: support),
      review:
        #"{"classifications":[{"id":"S0","kind":"preference","subject":"self","type":"self","episode":false,"time":"","question":""},{"id":"S1","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Have you decided to move?"}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: source, clarificationAnswer: answer, revision: 1))
    #expect(result.memories.map(\.quote) == ["I like tea."])
    let text = try #require(await model.requests.last?.last?.text)
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    let spans = try #require(payload["spans"] as? [[String: String]])
    #expect(spans[0] == ["id": "S0", "quote": "I like tea."])
    if hasAnswerEvidence {
      #expect(spans[1]["quote"] == "I have decided.")
      #expect(spans[1]["earlierQuote"] == "Maybe I will move.")
      #expect(spans[1]["askedQuestion"] == "Have you decided to move?")
    } else {
      #expect(spans[1] == ["id": "S1", "quote": "Maybe I will move."])
    }
  }

  @Test func inventedAnswerEvidenceNeverReachesTheReview() async throws {
    var source = PersonalMemorySource(text: "Maybe I will move.")
    source.analysis = .init(status: .pending, question: "Have you decided?", quote: source.text)
    let answer = PersonalMemorySource(
      text: "I am unsure.", origin: "clarification answer", kind: .conversationOnly)
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"Maybe I will move.","kind":"commitment","subject":"self","type":"self","update":"","context":[{"source":"A","quote":"I have decided."}],"episode":false,"time":""}],"clarification":null}"#
    )
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: source, clarificationAnswer: answer, revision: 1))
    }
    #expect(await model.requests.count == 1)
  }

  @Test func emptySemanticResultDoesNotInventClarification() async throws {
    let model = StructuredExtractionFixture(#"{"memories":[],"clarification":null}"#)
    let input = PersonalMemoryAnalysisInput(source: .init(text: "Hi"), revision: 4)
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(input)
    #expect(result.memories.isEmpty)
    #expect(result.clarification == nil)
    #expect(await model.requests.count == 1)
  }

  @Test func priorUserEvidenceAndSpecificQuestionKeepTheirIdentity() async throws {
    let prior = PersonalMemorySource(text: "Sami is my brother", kind: .fact)
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"He lives in Basra","kind":"fact","subject":"Sami","type":"person","update":"","context":[{"source":"C0","quote":"Sami is my brother"}],"episode":false,"time":""}],"clarification":{"quote":"Maybe I should leave","question":"Are you considering leaving or venting?"}}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"fact","subject":"Sami","type":"person","episode":false,"time":"","question":""},{"id":"S1","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering leaving or venting?"}]}"#
    )
    let input = PersonalMemoryAnalysisInput(
      source: .init(text: "He lives in Basra. Maybe I should leave"), context: [prior], revision: 5)
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(input)
    #expect(result.memories.first?.contextEvidence.first?.sourceID == prior.id)
    #expect(result.memories.first?.subjectKind == .person)
    #expect(result.clarification?.question == "Are you considering leaving or venting?")
  }

  @Test(arguments: [
    "not JSON", #"{"memories":[],"clarification":null,"delete_all":true}"#,
    #"{"memories":[{"quote":"tea","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":1,"time":""}],"clarification":null}"#,
    #"{"memories":[{"quote":"tea","kind":"preference","subject":"self","type":"self","update":"","context":[],"episode":false,"time":"2026-11-18"}],"clarification":null}"#,
    #"{"memories":[{"quote":"tea","kind":"summary","subject":"self","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
    #"{"memories":[{"quote":"tea","kind":"fact","subject":"Mira","type":"self","update":"","context":[],"episode":false,"time":""}],"clarification":null}"#,
    #"{"memories":[{"quote":"tea","kind":"fact","subject":"self","type":"self","update":"999","context":[],"episode":false,"time":""}],"clarification":null}"#,
  ])
  func malformedOrUnprovidedActionsAreRefused(output: String) async throws {
    let analyzer = LocalPersonalMemoryAnalyzer(model: StructuredExtractionFixture(output))
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await analyzer.analyze(.init(source: .init(text: "tea"), revision: 1))
    }
  }

  @Test func omittedContextCannotBeGuessedBackIntoResult() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"tea","kind":"fact","subject":"self","type":"self","update":"","context":[{"source":"C0","quote":"hidden"}],"episode":false,"time":""}],"clarification":null}"#
    )
    let input = PersonalMemoryAnalysisInput(
      source: .init(text: "tea"),
      context: [.init(text: String(repeating: "hidden ", count: 200))], revision: 1)
    await #expect(throws: PersonalMemoryExtractionError.invalidOutput) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(input)
    }
  }

  @Test func oversizedOriginalRefusesInferenceWithoutTruncation() async throws {
    let text = String(repeating: "ع", count: 1_300)
    let source = PersonalMemorySource(text: text)
    let model = StructuredExtractionFixture(#"{"memories":[],"clarification":null}"#)
    await #expect(throws: PersonalMemoryExtractionError.inputTooLarge) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: source, revision: 1))
    }
    #expect(await model.requests.isEmpty)
    #expect(source.text == text)
  }

  @Test func datedEpisodeRetainsItsExactTimePhrase() async throws {
    let model = StructuredExtractionFixture(
      #"{"memories":[{"quote":"I met Noor yesterday","kind":"fact","subject":"self","type":"self","update":"","context":[],"episode":true,"time":"yesterday"}],"clarification":null}"#,
      review:
        #"{"classifications":[{"id":"S0","kind":"fact","subject":"self","type":"self","episode":true,"time":"yesterday","question":""}]}"#
    )
    let result = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: .init(text: "I met Noor yesterday"), revision: 1))
    #expect(result.memories.first?.isEpisode == true)
    #expect(result.memories.first?.eventTimeExpression == "yesterday")
    #expect(result.memories.first?.quote == "I met Noor yesterday")
  }

  @Test func unavailableRuntimeRemainsRetryable() async {
    let model = StructuredExtractionFixture(outputs: [.failure(.modelUnavailable)])
    await #expect(throws: PersonalMemoryAnalysisRuntimeError.self) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I enjoy sailing"), revision: 1))
    }
  }

  @Test func foregroundBusyCancelsInsteadOfConsumingOriginal() async {
    let model = StructuredExtractionFixture(outputs: [.failure(.busy)])
    await #expect(throws: CancellationError.self) {
      try await LocalPersonalMemoryAnalyzer(model: model).analyze(
        .init(source: .init(text: "I enjoy sailing"), revision: 1))
    }
  }

  @Test func successiveSourcesKeepTheirOwnSemanticResults() async throws {
    let model = StructuredExtractionFixture(outputs: [
      .success(#"{"memories":[],"clarification":null}"#),
      .success(
        #"{"memories":[],"clarification":{"quote":"I might move","question":"Are you considering a move?"}}"#
      ),
      .success(
        #"{"classifications":[{"id":"S0","kind":"uncertain","subject":"","type":"none","episode":false,"time":"","question":"Are you considering a move?"}]}"#
      ),
    ])
    let analyzer = LocalPersonalMemoryAnalyzer(model: model)
    let first = try await analyzer.analyze(.init(source: .init(text: "Good evening"), revision: 1))
    let second = try await analyzer.analyze(.init(source: .init(text: "I might move"), revision: 2))
    #expect(first.memories.isEmpty)
    #expect(first.clarification == nil)
    #expect(second.clarification?.quote == "I might move")
    #expect(await model.outputs.isEmpty)
  }

  @Test(arguments: ["Are you only venting about leaving?", "Have you decided to leave?"])
  func clarificationAnswerIncludesTheExactQuestionItAnswers(question: String) async throws {
    var source = PersonalMemorySource(text: "I might leave the workshop")
    source.analysis = PersonalMemoryAnalysisState(
      status: .pending, question: question, quote: "I might leave the workshop")
    let answer = PersonalMemorySource(
      text: "yes", origin: "clarification answer", kind: .conversationOnly)
    let model = StructuredExtractionFixture(#"{"memories":[],"clarification":null}"#)
    _ = try await LocalPersonalMemoryAnalyzer(model: model).analyze(
      .init(source: source, clarificationAnswer: answer, revision: 2))
    let request = try #require(await model.requests.last?.last?.text)
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(request.utf8)) as? [String: Any])
    #expect(object["askedQuestion"] as? String == question)
    #expect(object["ambiguousQuote"] as? String == source.text)
    let context = try #require(object["context"] as? [[String: String]])
    #expect(context == [["id": "A", "text": "yes"]])
  }
}
