import Foundation
import MemoryCore
import MemorySQLite
import Testing

private actor AnalysisRepository: PersonalMemoryRepository {
  var state = PersonalMemorySnapshot()
  var writes = 0
  var fails = false
  func load() -> PersonalMemorySnapshot { state }
  func save(_ value: PersonalMemorySnapshot) throws {
    if fails { throw PersonalMemoryError.storage }
    state = value
    writes += 1
  }
  func fail(_ value: Bool) { fails = value }
}

struct PersonalMemoryAnalysisTests {

  @Test(arguments: [0, 1, 2, 3])
  func disputedRemainderSurvivesAnswerOrSkipReopenAndExplicitRetry(path: Int) async throws {
    let folder = URL.temporaryDirectory.appending(path: "partial-analysis-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let input = try await capture("I like tea. Maybe move. Perhaps leave.", in: cases)
    let preference = PersonalMemoryProposal(
      quote: "I like tea.", kind: .preference, subjectKind: .selfProfile)
    _ = try await cases.applyAnalysis(
      .init(
        memories: [preference],
        clarification: .init(
          quote: "Maybe move.", question: "Are you considering a move?"),
        deferredQuotes: ["Perhaps leave."]), input: input)
    if path > 0 {
      _ = try await cases.answerClarification(sourceID: input.source.id, answer: "Only venting.")
      let answered = try #require(try await cases.nextAnalysisInput())
      if path >= 2 {
        _ = try await cases.applyAnalysis(
          .init(
            clarification: .init(
              quote: "Maybe move.", question: "Was that only venting?")), input: answered)
        if path == 3 {
          let exported = try await cases.exportArchive()
          var json = try #require(
            JSONSerialization.jsonObject(with: exported) as? [String: Any])
          var sources = try #require(json["sources"] as? [[String: Any]])
          for index in sources.indices {
            sources[index].removeValue(forKey: "clarificationContext")
          }
          json["sources"] = sources
          let legacy = try JSONDecoder().decode(
            PersonalMemorySnapshot.self, from: JSONSerialization.data(withJSONObject: json))
          try legacy.validate()
          try await FilePersonalMemoryRepository(url: file).save(legacy)
          let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
          _ = try await reopened.skipClarification(sourceID: input.source.id)
        } else {
          _ = try await cases.skipClarification(sourceID: input.source.id)
        }
      } else {
        let result = try await cases.applyAnalysis(.init(), input: answered)
        #expect(result.deferredSources.first?.analysis?.hasDeferredRemainder == true)
        #expect(result.deferredSources.first?.analysis?.question == "Are you considering a move?")
      }
    } else {
      _ = try await cases.skipClarification(sourceID: input.source.id)
    }
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let saved = try await reopened.snapshot()
    let memories = saved.entries.filter { $0.excerptConversationID == nil }
    #expect(memories.count == 1 && memories.first?.text == "I like tea.")
    #expect(saved.deferredSources.map(\.id) == [input.source.id])
    #expect(saved.sources.first?.analysis?.hasDeferredRemainder == true)
    #expect(try await reopened.nextAnalysisInput() == nil)
    let archive = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: await reopened.exportArchive())
    try archive.validate()
    _ = try await reopened.retryAnalysis(sourceID: input.source.id)
    _ = try await reopened.deferAnalysis(sourceID: input.source.id)
    #expect(try await reopened.snapshot().deferredSources.map(\.id) == [input.source.id])
    _ = try await reopened.retryAnalysis(sourceID: input.source.id)
    let retry = try #require(try await reopened.nextAnalysisInput())
    let complete = try await reopened.applyAnalysis(.init(memories: [preference]), input: retry)
    #expect(complete.entries.filter { $0.excerptConversationID == nil }.count == 1)
    #expect(complete.deferredSources.isEmpty)
    #expect(complete.sources.first?.text.utf8.elementsEqual(input.source.text.utf8) == true)
    #expect(complete.sources.first?.createdAt == input.source.createdAt)
  }

  @Test(arguments: ["I like tea.", "not in source"])
  func deferredEvidenceCannotOverlapAnAcceptedClaimOrInventSource(quote: String) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("I like tea. Maybe move.", in: cases)
    let before = try await cases.snapshot()
    await #expect(throws: (any Error).self) {
      try await cases.applyAnalysis(
        .init(
          memories: [
            .init(quote: "I like tea.", kind: .preference, subjectKind: .selfProfile)
          ], deferredQuotes: [quote]), input: input)
    }
    #expect(try await cases.snapshot() == before)
  }

  @Test func legacyAnalysisStateDecodesWithoutARemainderMarker() throws {
    let data = Data(#"{"status":"processed","version":1}"#.utf8)
    let old = try JSONDecoder().decode(PersonalMemoryAnalysisState.self, from: data)
    #expect(old.hasDeferredRemainder == nil)
    #expect(old == PersonalMemoryAnalysisState(status: .processed))
    #expect(old != PersonalMemoryAnalysisState(status: .processed, hasDeferredRemainder: false))
  }
  private func capture(
    _ text: String, in cases: PersonalMemoryUseCases, conversation: UUID = UUID(),
    date: Date = Date()
  ) async throws -> PersonalMemoryAnalysisInput {
    _ = try await cases.ingest(
      source: PersonalMemorySource(conversationID: conversation, text: text, createdAt: date))
    return try #require(try await cases.nextAnalysisInput(conversationID: conversation))
  }

  @Test(arguments: [true, false])
  func protectedChangeQuestionUsesSourceLanguageAndIdentifiesTheChange(arabic: Bool) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let oldText = arabic ? "أفضل التذكير بالبريد الإلكتروني." : "I prefer email reminders."
    let newText = arabic ? "أفضل الآن التذكير برسالة نصية." : "I now prefer SMS reminders for علي."
    let prior = try await capture(oldText, in: cases)
    let confirmed = try await cases.resolve(
      sourceID: prior.source.id, kind: .preference, profileIDs: [PersonalMemorySnapshot.ownerID])
    let original = try #require(confirmed.currentEntries.first { $0.excerptConversationID == nil })
    let input = try await capture(newText, in: cases)
    let result = try await cases.applyAnalysis(
      .init(memories: [
        .init(
          quote: newText, kind: .preference, subjectKind: .selfProfile,
          replacesEntryID: original.id)
      ]), input: input)
    let pending = try #require(result.pendingSources.first { $0.id == input.source.id })
    let question = try #require(pending.analysis?.question)
    #expect(question.contains(newText))
    #expect(arabic ? question.contains("هل تريد") : question.contains("confirmed"))
    #expect(arabic || !question.contains("هل تريد"))
    #expect(pending.analysis?.quote == newText)
    #expect(pending.analysis?.protectedEntryID == original.id)
    #expect(result.currentEntries.filter { $0.excerptConversationID == nil } == [original])
    #expect(result.sources.first { $0.id == prior.source.id }?.text == oldText)
  }

  @Test func ambiguousArabicIdentityAsksInArabicWithoutMergingPeople() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    _ = try await cases.createProfile(kind: .person, name: "سامي الأول", aliases: ["سامي"])
    _ = try await cases.createProfile(kind: .person, name: "سامي الثاني", aliases: ["سامي"])
    let input = try await capture("سامي يسكن في البصرة", in: cases)
    let result = try await cases.applyAnalysis(
      .init(memories: [
        .init(quote: input.source.text, kind: .fact, subjectName: "سامي", subjectKind: .person)
      ]), input: input)
    let question = try #require(result.pendingSources.first?.analysis?.question)
    #expect(question.contains("أي شخص") && question.contains("سامي"))
    #expect(result.profiles.count == 3 && result.profiles.allSatisfy { $0.mergedIntoID == nil })
    #expect(result.entries.isEmpty)
    #expect(result.pendingSources.first?.analysis?.quote == input.source.text)
  }

  @Test(arguments: [false, true])
  func longConfirmationShowsTruncationAndPreservesTheFullChangedQuote(combining: Bool) async throws
  {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let prior = try await capture("أفضل تذكيراً قصيراً", in: cases)
    let confirmed = try await cases.resolve(
      sourceID: prior.source.id, kind: .preference, profileIDs: [PersonalMemorySnapshot.ownerID])
    let original = try #require(confirmed.currentEntries.first { $0.excerptConversationID == nil })
    let text =
      combining
      ? "أفضل ت" + String(repeating: "\u{0651}", count: 1_000) + "ذكيراً هادئاً"
      : "أفضل تذكيراً هادئاً " + String(repeating: "للعمل اليومي ", count: 80)
    let input = try await capture(text, in: cases)
    let result = try await cases.applyAnalysis(
      .init(memories: [
        .init(
          quote: text, kind: .preference, subjectKind: .selfProfile,
          replacesEntryID: original.id)
      ]), input: input)
    let pending = try #require(result.pendingSources.first)
    let question = try #require(pending.analysis?.question)
    #expect(question.utf8.count <= 1_000 && question.contains("…"))
    #expect(!question.contains("\u{FFFD}"))
    #expect(pending.text.utf8.elementsEqual(text.utf8))
    #expect(pending.analysis?.quote?.utf8.elementsEqual(text.utf8) == true)
    #expect(result.currentEntries.filter { $0.excerptConversationID == nil } == [original])
  }

  @Test func semanticProposalCreatesUnconfirmedQuotedMemoryAndRetryWritesNothing() async throws {
    let store = AnalysisRepository()
    let cases = PersonalMemoryUseCases(repository: store)
    let input = try await capture("Tea helps me relax after work", in: cases)
    #expect(try await cases.snapshot().entries.isEmpty)
    #expect(try await cases.snapshot().pendingSources.isEmpty)
    let result = PersonalMemoryAnalysis(memories: [
      PersonalMemoryProposal(
        quote: input.source.text, kind: .preference, subjectKind: .selfProfile)
    ])
    let applied = try await cases.applyAnalysis(result, input: input)
    let primary = try #require(applied.entries.first { $0.kind == .preference })
    #expect(primary.text == input.source.text)
    #expect(
      primary.evidence == [
        PersonalMemoryEvidence(sourceID: input.source.id, quote: input.source.text)
      ])
    #expect(!primary.confirmed)
    #expect(primary.profileIDs == [applied.selfProfileID])
    let count = await store.writes
    #expect(try await cases.applyAnalysis(result, input: input) == applied)
    #expect(await store.writes == count)
  }

  @Test func emptyAnalysisIsAProcessedConversationNotAnInventedProfile() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("Hello, how are you?", in: cases)
    let result = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: input)
    #expect(result.sources.first?.text == input.source.text)
    #expect(result.sources.first?.kind == .conversationOnly)
    #expect(result.sources.first?.analysis?.status == .processed)
    #expect(result.entries.isEmpty && result.profiles.count == 1)
    #expect(try await cases.nextAnalysisInput() == nil)
  }

  @Test func mixedCaptureDerivesOnlyTheResolvedQuote() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("I work at Cedar. Maybe I should leave.", in: cases)
    let result = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        memories: [PersonalMemoryProposal(quote: "I work at Cedar.", kind: .fact)],
        clarification: PersonalMemoryClarification(
          quote: "Maybe I should leave.", question: "Are you considering a change, or venting?")),
      input: input)
    #expect(
      result.entries.filter { $0.excerptConversationID == nil }.map(\.text) == ["I work at Cedar."])
    #expect(result.pendingSources.first?.analysis?.quote == "Maybe I should leave.")
    #expect(result.sources.first?.text == input.source.text)
    _ = try await cases.answerClarification(sourceID: input.source.id, answer: "Just venting")
    let answered = try #require(try await cases.nextAnalysisInput())
    let finished = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: answered)
    #expect(finished.pendingSources.isEmpty)
    #expect(
      finished.entries.filter { $0.excerptConversationID == nil }.map(\.text) == [
        "I work at Cedar."
      ])
  }

  @Test func skipClarificationPreservesClearClauseAndUndoRestoresOnlyTheQuestion() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("I work at Cedar. Maybe I should leave.", in: cases)
    let before = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        memories: [PersonalMemoryProposal(quote: "I work at Cedar.", kind: .fact)],
        clarification: PersonalMemoryClarification(
          quote: "Maybe I should leave.", question: "Are you considering leaving, or venting?")),
      input: input)
    let skipped = try await cases.skipClarification(sourceID: input.source.id)
    #expect(skipped.entries == before.entries)
    #expect(skipped.sources.first?.text == input.source.text)
    #expect(skipped.sources.first?.analysis?.status == .ignored)
    #expect(skipped.pendingSources.isEmpty && skipped.analysisPendingSources.isEmpty)
    let restored = try await cases.undo()
    #expect(restored.entries == before.entries)
    #expect(restored.pendingSources.first?.analysis?.quote == "Maybe I should leave.")
    #expect(try await cases.nextAnalysisInput() == nil)
  }

  @Test(arguments: ["assistant", "private", "imported"])
  func onlyNormalChatIsAutomaticallyAnalyzed(origin: String) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let conversation = UUID()
    let excluded = PersonalMemorySource(
      conversationID: conversation, text: "Sami lives in Basra", origin: origin, kind: .fact)
    _ = try await cases.ingest(source: excluded)
    let target = try await capture("He prefers tea", in: cases, conversation: conversation)
    #expect(!target.context.contains { $0.id == excluded.id })
    let forged = PersonalMemoryAnalysisInput(
      source: target.source, context: [excluded], profiles: target.profiles,
      entries: target.entries, revision: target.revision)
    let before = try await cases.snapshot()
    await #expect(throws: PersonalMemoryError.invalidAnalysis) {
      try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: target.source.text, kind: .preference, subjectName: "Sami", subjectKind: .person,
            contextEvidence: [PersonalMemoryEvidence(sourceID: excluded.id, quote: excluded.text)])
        ]),
        input: forged)
    }
    #expect(try await cases.snapshot() == before)
    let other = PersonalMemoryUseCases(repository: AnalysisRepository())
    _ = try await other.ingest(
      source: PersonalMemorySource(text: "Only an excluded original", origin: origin))
    #expect(try await other.nextAnalysisInput() == nil)
  }

  @Test func ambiguousAliasesAskWithoutMergingAndInventedNameSpellingIsRejected() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    _ = try await cases.createProfile(kind: .person, name: "Sami A", aliases: ["Sami"])
    _ = try await cases.createProfile(kind: .person, name: "Sami B", aliases: ["Sami"])
    let input = try await capture("Sami lives in Basra", in: cases)
    let result = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: input.source.text, kind: .fact, subjectName: "Sami", subjectKind: .person)
      ]), input: input)
    #expect(result.entries.isEmpty)
    #expect(result.pendingSources.count == 1)
    #expect(result.profiles.count == 3 && result.profiles.allSatisfy { $0.mergedIntoID == nil })
    let unicode = try await capture("José lives in Basra", in: cases)
    let before = try await cases.snapshot()
    await #expect(throws: PersonalMemoryError.invalidAnalysis) {
      try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: unicode.source.text, kind: .fact, subjectName: "Jose", subjectKind: .person)
        ]), input: unicode)
    }
    #expect(try await cases.snapshot() == before)
    let exact = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: unicode.source.text, kind: .fact, subjectName: "José", subjectKind: .person)
      ]), input: unicode)
    #expect(exact.profiles.contains { $0.name == "José" && $0.isSuggested == true })
  }

  @Test func canonicallyEquivalentEvidenceCannotReplaceOriginalBytes() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("I prefer cafe\u{301}", in: cases)
    let before = try await cases.snapshot()
    await #expect(throws: PersonalMemoryError.invalidAnalysis) {
      try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(quote: "I prefer café", kind: .preference)
        ]),
        input: input)
    }
    #expect(try await cases.snapshot() == before)
  }

  @Test func archivedUnresolvedEvidenceAndUnknownAnalysisPoolsAreRejected() async throws {
    let folder = URL.temporaryDirectory.appending(path: "analysis-tamper-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let input = try await capture("I work at Cedar", in: cases)
    let result = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(quote: input.source.text, kind: .fact)
      ]),
      input: input)
    var corrupt = result
    corrupt.sources[0].analysis = PersonalMemoryAnalysisState(
      status: .needsClarification, question: "Is this a plan?", quote: input.source.text)
    #expect(throws: PersonalMemoryError.invalidArchive) { try corrupt.validate() }
    let validBytes = try Data(contentsOf: file)
    var object = try #require(JSONSerialization.jsonObject(with: validBytes) as? [String: Any])
    var events = try #require(object["events"] as? [[String: Any]])
    var before = try #require(events.last?["before"] as? [String: Any])
    before["analyses"] = [99_999]
    events[events.count - 1]["before"] = before
    object["events"] = events
    let badBytes = try JSONSerialization.data(withJSONObject: object)
    try badBytes.write(to: file)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    await #expect(throws: (any Error).self) { try await reopened.snapshot() }
    #expect(try Data(contentsOf: file) == badBytes)
  }

  @Test func olderReportsCannotSupersedeCurrentMemoryAndCorrectionCanRestoreHistory() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let present = try await capture(
      "I live in Basra", in: cases, date: Date(timeIntervalSince1970: 2_000))
    let initial = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: present.source.text, kind: .fact, subjectKind: .selfProfile)
      ]), input: present)
    let entry = try #require(initial.entries.first)
    let past = try await capture(
      "I lived in Mosul", in: cases, date: Date(timeIntervalSince1970: 1_000))
    let imported = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: past.source.text, kind: .fact, subjectKind: .selfProfile, replacesEntryID: entry.id
        )
      ]),
      input: past)
    #expect(imported.entries.first { $0.id == entry.id }?.supersededByID == nil)
    let latest = try await capture(
      "I live in Baghdad now", in: cases, date: Date(timeIntervalSince1970: 3_000))
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: latest.source.text, kind: .fact, subjectKind: .selfProfile,
          replacesEntryID: entry.id)
      ]),
      input: latest)
    let corrected = try await cases.updateEntry(id: entry.id, text: "Basra remains my home")
    #expect(corrected.entries.first { $0.id == entry.id }?.supersededByID == nil)
    #expect(corrected.entries.first { $0.id == entry.id }?.isOwnerCorrected == true)
  }

  @Test(arguments: [
    "not-in-source", "overlapping-ambiguity", "unsupported-subject", "unknown-update",
  ])
  func invalidModelClaimsDoNotMutateSourcesOrGraph(mutation: String) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("Sami lives in Basra", in: cases)
    let before = try await cases.snapshot()
    let proposal = PersonalMemoryProposal(
      quote: mutation == "not-in-source" ? "Sami lives in Baghdad" : input.source.text,
      kind: .fact,
      subjectName: mutation == "unsupported-subject" ? "Mira" : nil,
      subjectKind: mutation == "unsupported-subject" ? .person : nil,
      replacesEntryID: mutation == "unknown-update" ? UUID() : nil)
    do {
      _ = try await cases.applyAnalysis(
        PersonalMemoryAnalysis(
          memories: [proposal],
          clarification: mutation == "overlapping-ambiguity"
            ? PersonalMemoryClarification(quote: input.source.text, question: "Is this certain?")
            : nil),
        input: input)
      Issue.record("An unsupported or unresolved model claim was accepted")
    } catch {}
    #expect(try await cases.snapshot() == before)
  }

  @Test func crossTurnPersonEvidenceUsesBothOriginalsAndCreatesProvisionalIdentity() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let conversation = UUID()
    let first = try await capture("My brother is Sami", in: cases, conversation: conversation)
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: first.source.text, kind: .fact, subjectName: "Sami", subjectKind: .person)
      ]), input: first)
    let second = try await capture("He lives in Basra", in: cases, conversation: conversation)
    let result = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: second.source.text, kind: .fact, subjectName: "Sami", subjectKind: .person,
          contextEvidence: [
            PersonalMemoryEvidence(sourceID: first.source.id, quote: first.source.text)
          ])
      ]),
      input: second)
    let person = try #require(result.profiles.first { $0.name == "Sami" })
    #expect(person.isSuggested == true)
    let memory = try #require(result.entries.first { $0.text == second.source.text })
    #expect(Set(memory.sourceIDs) == [first.source.id, second.source.id])
    #expect(memory.profileIDs == [person.id])
    #expect(memory.evidence?.count == 2)
  }

  @Test func processedConversationContextCanGroundANameWithoutBecomingItsOwnMemory() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let conversation = UUID()
    let first = try await capture(
      "What about my brother Sami?", in: cases, conversation: conversation)
    _ = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: first)
    #expect(try await cases.snapshot().entries.isEmpty)
    let next = try await capture("He prefers tea", in: cases, conversation: conversation)
    #expect(next.context.map(\.id) == [first.source.id])
    let organized = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: next.source.text, kind: .preference, subjectName: "Sami", subjectKind: .person,
          contextEvidence: [
            PersonalMemoryEvidence(sourceID: first.source.id, quote: first.source.text)
          ])
      ]),
      input: next)
    let memory = try #require(organized.entries.first { $0.excerptConversationID == nil })
    #expect(memory.text == next.source.text && memory.evidence?.count == 2)
    #expect(!organized.entries.contains { $0.text == first.source.text })
    let summary = try #require(organized.entries.first { $0.excerptConversationID == conversation })
    #expect(summary.sourceIDs == [next.source.id])
    let data = try await cases.exportArchive()
    #expect(try JSONDecoder().decode(PersonalMemorySnapshot.self, from: data) == organized)
  }

  @Test(arguments: [PersonalMemoryKind.venting, .rolePlay])
  func discardedConversationMeaningCannotGroundLaterMemory(kind: PersonalMemoryKind) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let conversation = UUID()
    let excluded = PersonalMemorySource(
      conversationID: conversation, text: "Sami lives in Basra", kind: kind)
    _ = try await cases.ingest(source: excluded)
    let next = try await capture("He prefers tea", in: cases, conversation: conversation)
    #expect(next.context.isEmpty)
    let forged = PersonalMemoryAnalysisInput(
      source: next.source, context: [excluded], profiles: next.profiles,
      entries: next.entries, revision: next.revision)
    await #expect(throws: PersonalMemoryError.invalidAnalysis) {
      try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: next.source.text, kind: .preference, subjectName: "Sami", subjectKind: .person,
            contextEvidence: [PersonalMemoryEvidence(sourceID: excluded.id, quote: excluded.text)])
        ]),
        input: forged)
    }
  }

  @Test func duplicateClaimAddsEvidenceButIdenticalEpisodesRemainDistinct() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    for _ in 0..<2 {
      let input = try await capture("Tea is my favorite drink", in: cases)
      _ = try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: input.source.text, kind: .preference, subjectKind: .selfProfile)
        ]), input: input)
    }
    let duplicate = try await cases.snapshot()
    #expect(duplicate.entries.filter { $0.kind == .preference }.count == 1)
    #expect(duplicate.entries.first { $0.kind == .preference }?.sourceIDs.count == 2)
    for _ in 0..<2 {
      let input = try await capture("Visited the library today", in: cases)
      _ = try await cases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: input.source.text, kind: .fact, isEpisode: true, eventTimeExpression: "today")
        ]), input: input)
    }
    #expect(try await cases.snapshot().entries.filter { $0.isEpisode == true }.count == 2)
  }

  @Test func replacementPreservesOldVersionAndOwnerCorrectionBlocksAutomaticReplacement()
    async throws
  {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let first = try await capture("I drink coffee", in: cases)
    let initial = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: first.source.text, kind: .preference, subjectKind: .selfProfile)
      ]), input: first)
    let old = try #require(initial.entries.first { $0.kind == .preference })
    let next = try await capture("I drink tea now", in: cases)
    let updated = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: next.source.text, kind: .preference, subjectKind: .selfProfile,
          replacesEntryID: old.id)
      ]), input: next)
    let current = try #require(updated.entries.first { $0.text == next.source.text })
    #expect(updated.entries.first { $0.id == old.id }?.supersededByID == current.id)
    #expect(!updated.currentEntries.contains { $0.id == old.id })
    _ = try await cases.updateEntry(id: current.id, text: "I prefer green tea")
    let third = try await capture("I prefer black tea now", in: cases)
    let protected = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: third.source.text, kind: .preference, subjectKind: .selfProfile,
          replacesEntryID: current.id)
      ]), input: third)
    #expect(protected.entries.first { $0.id == current.id }?.text == "I prefer green tea")
    #expect(protected.pendingSources.first?.analysis?.protectedEntryID == current.id)
    #expect(!protected.entries.contains { $0.text == third.source.text })
  }

  @Test func naturalAnswerRetainsNewOriginalAndMakesOnlyItsQuestionRetryable() async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let input = try await capture("Maybe I should leave", in: cases)
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        clarification: PersonalMemoryClarification(
          quote: input.source.text, question: "A plan, or venting?")), input: input)
    let answered = try await cases.answerClarification(
      sourceID: input.source.id, answer: "Just venting")
    let retry = try #require(try await cases.nextAnalysisInput())
    #expect(retry.clarificationAnswer?.text == "Just venting")
    #expect(retry.source.analysis?.question == "A plan, or venting?")
    #expect(retry.source.analysis?.quote == input.source.text)
    #expect(answered.sources.count == 2)
    #expect(answered.pendingSources.isEmpty)
    _ = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: retry)
    #expect(try await cases.snapshot().entries.isEmpty)
  }

  @Test(arguments: ["Are you venting about leaving?", "Have you decided to leave?"])
  func shortAnswerRetainsTheExactQuestionAcrossRetryReopenAndExport(question: String) async throws {
    let folder = URL.temporaryDirectory.appending(path: "answer-context-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let input = try await capture("Maybe I should leave", in: cases)
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        clarification: PersonalMemoryClarification(
          quote: input.source.text, question: question)), input: input)
    let answered = try await cases.answerClarification(sourceID: input.source.id, answer: "yes")
    #expect(answered.pendingSources.isEmpty)
    #expect(answered.sources.first?.analysis?.status == .pending)
    _ = try await cases.deferAnalysis(sourceID: input.source.id)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let deferred = try await reopened.snapshot()
    #expect(deferred.deferredSources.first?.analysis?.question == question)
    #expect(deferred.deferredSources.first?.analysis?.quote == input.source.text)
    #expect(deferred.pendingSources.isEmpty)
    _ = try await reopened.retryAnalysis(sourceID: input.source.id)
    let again = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let retry = try #require(try await again.nextAnalysisInput())
    #expect(retry.source.text == "Maybe I should leave")
    #expect(retry.source.analysis?.question == question)
    #expect(retry.source.analysis?.quote == input.source.text)
    #expect(retry.clarificationAnswer?.text == "yes")
    #expect(retry.clarificationAnswer?.id == retry.source.analysis?.answerSourceID)
    let exported = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: await again.exportArchive())
    try exported.validate()
    #expect(exported.sources.first?.analysis?.question == question)
    #expect(exported.sources.first?.analysis?.quote == input.source.text)
  }

  @Test func staleOrFailedAnalysisCannotOverwriteNewerStateAndOriginalRemainsRetryable()
    async throws
  {
    let store = AnalysisRepository()
    let cases = PersonalMemoryUseCases(repository: store)
    let input = try await capture("I work at Cedar", in: cases)
    _ = try await cases.createProfile(kind: .person, name: "Mira")
    await #expect(throws: PersonalMemoryError.staleAnalysis) {
      try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: input)
    }
    let retry = try #require(try await cases.nextAnalysisInput())
    let before = try await cases.snapshot()
    await store.fail(true)
    await #expect(throws: PersonalMemoryError.storage) {
      try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: retry)
    }
    #expect(try await cases.snapshot() == before)
    await store.fail(false)
    _ = try await cases.deferAnalysis(sourceID: input.source.id)
    #expect(try await cases.snapshot().deferredSources.count == 1)
    #expect(try await cases.nextAnalysisInput() == nil)
    _ = try await cases.retryAnalysis()
    #expect(try await cases.nextAnalysisInput()?.source.id == input.source.id)
  }

  @Test func everyAnswerKeepsItsAskedQuestionAfterProcessingAndHistoryRolloff() async throws {
    let folder = URL.temporaryDirectory.appending(path: "answer-provenance-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let input = try await capture("Maybe I should leave", in: cases)
    let questions = ["Are you venting about leaving?", "Have you decided to leave?"]
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        clarification: PersonalMemoryClarification(
          quote: input.source.text, question: questions[0])), input: input)
    _ = try await cases.answerClarification(sourceID: input.source.id, answer: "yes")
    let firstAnswer = try #require(try await cases.nextAnalysisInput())
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(
        clarification: PersonalMemoryClarification(
          quote: input.source.text, question: questions[1])), input: firstAnswer)
    _ = try await cases.answerClarification(sourceID: input.source.id, answer: "yes")
    let secondAnswer = try #require(try await cases.nextAnalysisInput())
    let processed = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: secondAnswer)
    #expect(processed.sources.first?.analysis?.status == .processed)
    #expect(processed.sources.first?.analysis?.question == questions[1])
    #expect(processed.sources.first?.analysis?.quote == input.source.text)
    for index in 0..<55 {
      _ = try await cases.createProfile(kind: .project, name: "Fictional history project \(index)")
    }
    let rolled = try await cases.snapshot()
    #expect(rolled.events.count == 50)
    #expect(
      !rolled.events.contains { $0.summary == "Answered memory clarification; originals retained" })
    let answers = rolled.sources.filter { $0.origin == "clarification answer" }
    #expect(answers.map(\.text) == ["yes", "yes"])
    #expect(answers.map { $0.clarificationContext?.question } == questions.map(Optional.some))
    #expect(
      answers.allSatisfy {
        $0.clarificationContext?.quote == input.source.text
          && $0.clarificationContext?.parentSourceID == input.source.id
      })
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    #expect(try await reopened.snapshot() == rolled)
    let exported = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: await reopened.exportArchive())
    try exported.validate()
    #expect(exported == rolled)
    #expect(exported.sources.first?.analysis?.question == questions[1])
  }

  @Test(arguments: ["unknown-parent", "invented-quote", "empty-question", "other-conversation"])
  func invalidAnswerProvenanceFailsWithoutPersistingTheAnswer(mutation: String) async throws {
    let cases = PersonalMemoryUseCases(repository: AnalysisRepository())
    let parent = PersonalMemorySource(
      conversationID: UUID(), text: "Maybe I should leave", kind: .conversationOnly)
    _ = try await cases.ingest(source: parent)
    let before = try await cases.snapshot()
    let answer = PersonalMemorySource(
      conversationID: mutation == "other-conversation" ? UUID() : parent.conversationID,
      text: "yes", origin: "clarification answer", kind: .conversationOnly,
      clarificationContext: PersonalMemoryClarificationContext(
        parentSourceID: mutation == "unknown-parent" ? UUID() : parent.id,
        question: mutation == "empty-question" ? "" : "Are you venting?",
        quote: mutation == "invented-quote" ? "I decided to leave" : parent.text))
    await #expect(throws: (any Error).self) { try await cases.ingest(source: answer) }
    #expect(try await cases.snapshot() == before)
  }

  @Test func analyzedArchiveAndUndoMetadataReopenWithoutRecreatingUndoneMemory() async throws {
    let folder = URL.temporaryDirectory.appending(path: "analysis-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let input = try await capture("Coffee is my favorite drink", in: cases)
    _ = try await cases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: input.source.text, kind: .preference, subjectKind: .selfProfile)
      ]), input: input)
    let before = try await cases.snapshot()
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    #expect(try await reopened.snapshot() == before)
    let undone = try await reopened.undo()
    #expect(undone.entries.isEmpty)
    #expect(undone.sources.first?.text == input.source.text)
    #expect(undone.sources.first?.analysis?.status == .ignored)
    #expect(try await reopened.nextAnalysisInput() == nil)
    let again = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    #expect(try await again.snapshot() == undone)
    let exported = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: await again.exportArchive())
    #expect(exported == undone)
  }

  @Test func diskArchivePoolsIndividualSourceStatesAndReadsVersionOneWithoutRewrite() async throws {
    let folder = URL.temporaryDirectory.appending(path: "analysis-pool-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "memory.json")
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    for index in 0..<12 {
      let input = try await capture("A fictional exchange \(index)", in: cases)
      _ = try await cases.applyAnalysis(PersonalMemoryAnalysis(), input: input)
    }
    let bytes = try Data(contentsOf: file)
    let root = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let pool = try #require(root["analysisStates"] as? [[String: Any]])
    #expect(pool.count <= 24)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    #expect(try await reopened.snapshot() == cases.snapshot())

    let oldFile = folder.appending(path: "version-one.json")
    let legacy = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: oldFile))
    _ = try await legacy.ingest(
      source: PersonalMemorySource(text: "A saved preference", kind: .preference))
    let before = try await legacy.snapshot()
    var oldRoot = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: oldFile)) as? [String: Any])
    oldRoot["storageVersion"] = 1
    #expect(oldRoot["analysisStates"] == nil)
    let oldBytes = try JSONSerialization.data(withJSONObject: oldRoot)
    try oldBytes.write(to: oldFile)
    let oldReader = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: oldFile))
    #expect(try await oldReader.snapshot() == before)
    #expect(try Data(contentsOf: oldFile) == oldBytes)
  }
}
