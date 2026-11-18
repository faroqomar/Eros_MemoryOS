import Foundation
import MemoryCore
import MemorySQLite
import Testing

private actor PersonalMemoryTestRepository: PersonalMemoryRepository {
  var state = PersonalMemorySnapshot()
  var failure = false
  var writes = 0
  func load() -> PersonalMemorySnapshot { state }
  func save(_ next: PersonalMemorySnapshot) throws {
    if failure { throw PersonalMemoryError.storage }
    state = next
    writes += 1
  }
  func failWrites(_ fail: Bool) { failure = fail }
}

struct PersonalMemoryTests {
  @Test(arguments: [
    "Hi", "  Hi! 👋  ", "Hello", "Thanks!", "OK", "How are you?",
    "What is Swift", "Could you explain Swift?", "Tell me a story", "Please summarize this",
    "Could you explain how to save a file?", "Please explain why people remember dreams",
    "Hi! How are you?", "How are you? What is Swift?",
    "هلا", "مرحبا", "شكراً", "شلونك؟", "شنو معنى هذا", "ممكن تشرح هذا؟",
  ])
  func ordinaryConversationPreservesOriginalWithoutClarificationOrProfileMemory(text: String)
    async throws
  {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let result = try await useCases.ingest(source: PersonalMemorySource(text: text))
    let state = try await useCases.snapshot()
    #expect(!result.needsClarification)
    #expect(state.pendingSources.isEmpty)
    #expect(state.sources.first?.text.utf8.elementsEqual(text.utf8) == true)
    #expect(state.entries.isEmpty)
    #expect(state.profiles.count == 1)
  }

  @Test func oldUnansweredGreetingStopsPromptingWithoutRewritingOrDeriving() async throws {
    let store = PersonalMemoryTestRepository()
    var seed = PersonalMemorySnapshot()
    let source = PersonalMemorySource(text: "Hi")
    seed.sources = [source]
    try await store.save(seed)
    let useCases = PersonalMemoryUseCases(repository: store)
    let loaded = try await useCases.snapshot()
    #expect(loaded == seed)
    #expect(loaded.sources.first?.kind == nil)
    #expect(loaded.sources.first?.effectiveKind == nil)
    #expect(loaded.pendingSources.isEmpty)
    #expect(loaded.entries.isEmpty)
    #expect(await store.writes == 1)
    let retry = try await useCases.ingest(source: source)
    #expect(!retry.needsClarification)
    #expect(try await useCases.snapshot() == seed)
    #expect(await store.writes == 1)
    let confirmed = try await useCases.resolve(sourceID: source.id, kind: .fact)
    #expect(confirmed.sources.first?.effectiveKind == .fact)
    #expect(confirmed.entries.first?.confirmed == true)
  }

  @Test(arguments: [
    "Hi, maybe I should quit", "Thanks but I might leave", "هلا يمكن أترك المشروع",
    "Please remember I might leave", "Could you remember that I might quit",
    "How are you? Maybe I should quit", "Could you explain Swift? I might leave my job",
    "How are you? I prefer tea", "Tell me a story, I might leave my job",
    "شنو معنى هذا؟ يمكن أترك المشروع", "Could you explain Swift and I might quit",
    "Explain Swift but maybe I should quit", "اشرح سويفت بس يمكن أترك المشروع",
    "اشرح سويفت، أَنَا يمكن أترك المشروع",
  ])
  func unclassifiedCaptureDoesNotDeriveBeforeSemanticAnalysis(text: String) async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let result = try await useCases.ingest(source: PersonalMemorySource(text: text))
    #expect(!result.needsClarification)
    #expect(try await useCases.snapshot().analysisPendingSources.count == 1)
    #expect(try await useCases.snapshot().entries.isEmpty)
  }

  @Test(arguments: [
    "Maybe I should leave the project", "I prefer coffee but maybe tea tomorrow",
    "Pretend I decided to quit", "I prefer tea. Maybe I should quit",
    "يمكن أترك المشروع", "هذا فضفضة عن الدوام", "A statement with no clear intent",
  ])
  func ambiguityKeepsOriginalWithoutDerivedMemory(text: String) async throws {
    let store = PersonalMemoryTestRepository()
    let useCases = PersonalMemoryUseCases(repository: store)
    let source = PersonalMemorySource(text: text)
    let result = try await useCases.ingest(source: source)
    let state = try await useCases.snapshot()
    #expect(!result.needsClarification)
    #expect(state.analysisPendingSources.map(\.id) == [source.id])
    let input = try #require(try await useCases.nextAnalysisInput())
    _ = try await useCases.applyAnalysis(
      PersonalMemoryAnalysis(
        clarification: PersonalMemoryClarification(
          quote: text, question: "Is this a plan or just a thought?")), input: input)
    let clarified = try await useCases.snapshot()
    #expect(state.sources.first?.text.utf8.elementsEqual(text.utf8) == true)
    #expect(state.entries.isEmpty)
    #expect(clarified.pendingSources.map(\.id) == [source.id])
    await #expect(throws: PersonalMemoryError.unresolvedSource) {
      try await useCases.addEntry(text: "Invented fact", kind: .fact, sourceIDs: [source.id])
    }
  }

  @Test func clearStatedPreferencesAndGoalsBuildSelfProfileWithoutClaimingConfirmation()
    async throws
  {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let examples: [(String, PersonalMemoryKind)] = [
      ("I prefer tea", .preference), ("My goal is learning Swift", .goal),
      ("أفضل القهوة", .preference), ("هدفي تعلم البرمجة", .goal),
    ]
    for (text, kind) in examples {
      _ = try await useCases.ingest(source: PersonalMemorySource(text: text))
      let input = try #require(try await useCases.nextAnalysisInput())
      _ = try await useCases.applyAnalysis(
        PersonalMemoryAnalysis(memories: [
          PersonalMemoryProposal(
            quote: text, kind: kind, subjectKind: .selfProfile)
        ]), input: input)
    }
    let state = try await useCases.snapshot()
    #expect(state.entries.map(\.kind) == [.preference, .goal, .preference, .goal])
    #expect(state.entries.allSatisfy { $0.profileIDs == [state.selfProfileID] && !$0.confirmed })
  }

  @Test func idempotentIngestionAndConflictingOriginalAreDistinct() async throws {
    let store = PersonalMemoryTestRepository()
    let useCases = PersonalMemoryUseCases(repository: store)
    let source = PersonalMemorySource(text: "  Ali writes e\u{301}\nعلي  ")
    _ = try await useCases.ingest(source: source)
    let before = try await useCases.snapshot()
    _ = try await useCases.ingest(source: source)
    #expect(try await useCases.snapshot() == before)
    #expect(await store.writes == 1)
    await #expect(throws: PersonalMemoryError.conflictingSource) {
      try await useCases.ingest(
        source: PersonalMemorySource(
          id: source.id, text: "Ali writes é",
          createdAt: source.createdAt))
    }
    #expect(try await useCases.snapshot() == before)
  }

  @Test func clarifyingVentingAndRoleplayNeverDerivesFacts() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    for kind in [PersonalMemoryKind.venting, .rolePlay, .conversationOnly] {
      let source = PersonalMemorySource(text: "Pretend I leave")
      _ = try await useCases.ingest(source: source)
      let state = try await useCases.resolve(sourceID: source.id, kind: kind)
      #expect(state.entries.isEmpty)
      #expect(!state.pendingSources.contains { $0.id == source.id })
    }
  }

  @Test func explicitFactCorrectionRequiresConfirmationAndUndoRetainsOriginal() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let source = PersonalMemorySource(text: "Ali starts work in June")
    _ = try await useCases.ingest(source: source)
    let resolved = try await useCases.resolve(sourceID: source.id, kind: .fact)
    let entry = try #require(resolved.entries.first)
    #expect(entry.confirmed)
    await #expect(throws: PersonalMemoryError.confirmationRequired) {
      try await useCases.updateEntry(id: entry.id, text: "Ali starts work in July")
    }
    _ = try await useCases.updateEntry(
      id: entry.id, text: "Ali starts work in July", confirmedChange: true)
    #expect(try await useCases.snapshot().sources.first?.text == source.text)
    let undo = try await useCases.undo()
    #expect(undo.entries.first?.text == source.text)
    await #expect(throws: PersonalMemoryError.confirmationRequired) {
      try await useCases.resolve(sourceID: source.id, kind: .idea)
    }
  }

  @Test func sourceResolutionUndoReturnsToAnalysisBacklogWithoutDeletingOriginal() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let source = PersonalMemorySource(text: "Maybe launch a reading group")
    _ = try await useCases.ingest(source: source)
    _ = try await useCases.resolve(sourceID: source.id, kind: .idea)
    let state = try await useCases.undo()
    #expect(state.sources.count == 1)
    #expect(state.analysisPendingSources.first?.text == source.text)
    #expect(state.entries.isEmpty)
  }

  @Test func profileProjectKindsOrganizationAndInterpretationsStaySourceLinked() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.createProfile(kind: .project, name: "Reading room")
    let initial = try await useCases.snapshot()
    let project = try #require(initial.profiles.first { $0.kind == .project })
    for kind in [PersonalMemoryKind.plan, .workflow, .fact, .idea, .commitment, .interpretation] {
      let source = PersonalMemorySource(text: "Project update \(kind.rawValue)", kind: kind)
      _ = try await useCases.ingest(source: source)
      _ = try await useCases.resolve(sourceID: source.id, kind: kind, profileIDs: [project.id])
    }
    let state = try await useCases.snapshot()
    let entry = try #require(state.entries.first)
    _ = try await useCases.organize(
      entryID: entry.id, categories: ["Current", "Reading"], profileIDs: [project.id])
    _ = try await useCases.addEntry(
      text: "The project has tentative and committed work", kind: .summary,
      sourceIDs: state.entries.map { $0.sourceIDs[0] }, profileIDs: [project.id])
    let interpreted = try await useCases.addEntry(
      text: "Work discussion may suggest pressure", kind: .interpretation,
      sourceIDs: entry.sourceIDs, profileIDs: [project.id], confirmed: true)
    #expect(interpreted.entries.last?.confirmed == false)
    #expect(interpreted.entries.last?.kind == .interpretation)
    #expect(interpreted.entries.last?.sourceIDs == entry.sourceIDs)
    _ = try await useCases.undo()
    _ = try await useCases.undo()
    let undone = try await useCases.undo()
    #expect(undone.entries.first?.categories == ["plan"])
    #expect(undone.sources.count == 6)
  }

  @Test func identitySuggestionsDoNotMergeAndExplicitMergeCanUndo() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.createProfile(kind: .person, name: "أحمد حسن", aliases: ["Ahmad", "Mo"])
    _ = try await useCases.createProfile(kind: .person, name: "Ahmed Hassan", aliases: ["Mo"])
    let initial = try await useCases.snapshot()
    let people = initial.profiles.filter { $0.kind == .person }
    #expect(try await useCases.suggestPeople(name: "MO").count == 2)
    #expect(try await useCases.suggestPeople(name: "احمد").first?.name == "أحمد حسن")
    #expect(try await useCases.snapshot() == initial)
    await #expect(throws: PersonalMemoryError.confirmationRequired) {
      try await useCases.mergePeople(from: people[0].id, into: people[1].id, confirmed: false)
    }
    let merged = try await useCases.mergePeople(
      from: people[0].id, into: people[1].id, confirmed: true)
    #expect(merged.profiles.first { $0.id == people[0].id }?.mergedIntoID == people[1].id)
    let undone = try await useCases.undo()
    #expect(undone.profiles == initial.profiles)
  }

  @Test func optionalProfileAnswerAndImageOriginsHaveReversibleVisibleProvenance() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let initial = try await useCases.snapshot()
    #expect(initial.sources.isEmpty)
    _ = try await useCases.answerProfileQuestion(
      profileID: initial.selfProfileID,
      question: "What matters to you?", answer: "Learning Arabic", kind: .goal)
    let answered = try await useCases.snapshot()
    #expect(answered.sources.first?.origin == "profile answer")
    #expect(answered.entries.first?.profileIDs == [initial.selfProfileID])
    _ = try await useCases.setPhoto(
      profileID: initial.selfProfileID, data: Data([1, 2]), origin: .supplied)
    let supplied = try await useCases.snapshot()
    _ = try await useCases.setPhoto(
      profileID: initial.selfProfileID, data: Data([3, 4]), origin: .generated)
    let generated = try await useCases.snapshot()
    #expect(generated.photos.last?.origin == .generated)
    let undone = try await useCases.undo()
    #expect(undone.profiles.first?.photoID == supplied.profiles.first?.photoID)
    await #expect(throws: PersonalMemoryError.invalidPhoto) {
      try await useCases.setPhoto(
        profileID: initial.selfProfileID, data: Data([5]), origin: .imported)
    }
    let imported = try await useCases.setPhoto(
      profileID: initial.selfProfileID, data: Data([5]),
      origin: .imported, sourceID: try #require(answered.sources.first?.id))
    #expect(imported.photos.last?.sourceID == answered.sources.first?.id)
  }

  @Test func failedTransactionKeepsStateAndCanRetry() async throws {
    let store = PersonalMemoryTestRepository()
    let useCases = PersonalMemoryUseCases(repository: store)
    let before = try await useCases.snapshot()
    await store.failWrites(true)
    await #expect(throws: PersonalMemoryError.storage) {
      try await useCases.ingest(
        source: PersonalMemorySource(text: "I prefer tea", kind: .preference))
    }
    #expect(try await useCases.snapshot() == before)
    await store.failWrites(false)
    _ = try await useCases.ingest(
      source: PersonalMemorySource(text: "I prefer tea", kind: .preference))
    #expect(try await useCases.snapshot().entries.count == 1)
  }

  @Test func parallelTransactionsDoNotLoseSources() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<24 {
        group.addTask {
          _ = try await useCases.ingest(source: PersonalMemorySource(text: "Capture \(index)"))
        }
      }
      try await group.waitForAll()
    }
    #expect(try await useCases.snapshot().sources.count == 24)
  }

  @Test func fileReopenBackupRestoreAndConflictRefusalPreserveSourcesAndHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("personal.json")
    let useCases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    _ = try await useCases.ingest(
      source: PersonalMemorySource(text: "I prefer tea", kind: .preference))
    _ = try await useCases.createProfile(kind: .person, name: "Ali")
    let expected = try await useCases.snapshot()
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    #expect(try await reopened.snapshot() == expected)
    let backup = try await useCases.exportArchive()
    let restored = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let result = try await restored.restoreArchive(backup)
    #expect(result.sources == expected.sources)
    #expect(result.events == expected.events)
    await #expect(throws: PersonalMemoryError.conflictingSource) {
      try await restored.restoreArchive(backup)
    }
    var malformed = expected
    malformed.formatVersion = 2
    let malformedData = try JSONEncoder().encode(malformed)
    await #expect(throws: PersonalMemoryError.unsupportedVersion) {
      try await restored.restoreArchive(malformedData)
    }
  }

  @Test func canonicallyEquivalentCorrectionRetainsDistinctBytesInVisibleHistory() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let source = PersonalMemorySource(text: "I prefer cafe\u{301}", kind: .preference)
    _ = try await useCases.ingest(source: source)
    let before = try await useCases.snapshot()
    let entry = try #require(before.entries.first)
    let corrected = try await useCases.updateEntry(id: entry.id, text: "I prefer café")
    #expect(corrected.entries.first?.text.utf8.elementsEqual("I prefer café".utf8) == true)
    #expect(
      corrected.events.last?.previousEntries.first?.text.utf8.elementsEqual(source.text.utf8)
        == true)
    #expect(corrected.sources.first?.text.utf8.elementsEqual(source.text.utf8) == true)
    let undo = try await useCases.undo()
    #expect(undo.entries.first?.text.utf8.elementsEqual(source.text.utf8) == true)
  }

  @Test func reclassifyingConfirmedFactToVentingRemovesDerivedSummariesAndLinks() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let source = PersonalMemorySource(text: "Ali plans a workshop")
    _ = try await useCases.ingest(source: source)
    let resolved = try await useCases.resolve(sourceID: source.id, kind: .fact)
    let entry = try #require(resolved.entries.first)
    _ = try await useCases.addEntry(
      text: "Workshop is planned", kind: .summary, sourceIDs: [source.id])
    _ = try await useCases.addLink(from: entry.id, to: source.id, label: "Evidence")
    let updated = try await useCases.resolve(
      sourceID: source.id, kind: .venting, confirmedChange: true)
    #expect(updated.entries.isEmpty)
    #expect(updated.links.isEmpty)
    #expect(updated.sources.count == 1)
    let undone = try await useCases.undo()
    #expect(undone.entries.count == 2)
    #expect(undone.links.count == 1)
  }

  @Test func oversizedImagesAndInvalidProfileLinksRollbackAllMutation() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.ingest(
      source: PersonalMemorySource(text: "I prefer tea", kind: .preference))
    let initial = try await useCases.snapshot()
    let entry = try #require(initial.entries.first)
    await #expect(throws: PersonalMemoryError.invalidPhoto) {
      try await useCases.setPhoto(
        profileID: initial.selfProfileID,
        data: Data(repeating: 0, count: PersonalMemoryLimits.imageBytes + 1), origin: .supplied)
    }
    await #expect(throws: PersonalMemoryError.invalidArchive) {
      try await useCases.organize(entryID: entry.id, categories: [], profileIDs: [UUID()])
    }
    #expect(try await useCases.snapshot() == initial)
  }
}

extension PersonalMemoryTests {
  @Test func automaticCategoriesUniqueAliasLinksAndExcerptsExcludePendingParts() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.createProfile(kind: .person, name: "Mira Noor", aliases: ["Mimi"])
    _ = try await useCases.createProfile(kind: .project, name: "Cedar")
    let conversation = UUID()
    let clear = PersonalMemorySource(
      conversationID: conversation, text: "My goal is share Cedar with Mimi", kind: .goal)
    _ = try await useCases.ingest(source: clear)
    let pending = PersonalMemorySource(
      conversationID: conversation, text: "Maybe I should abandon Cedar")
    _ = try await useCases.ingest(source: pending)
    var state = try await useCases.snapshot()
    let entry = try #require(state.entries.first { $0.kind == .goal })
    #expect(entry.categories == ["goal"])
    #expect(Set(entry.profileIDs) == Set(state.profiles.map(\.id)))
    #expect(state.entries.filter { $0.kind == .summary }.count == 1)
    #expect(state.entries.last?.text.contains("Maybe") == false)
    #expect(state.entries.last?.sourceIDs == [clear.id])
    _ = try await useCases.updateEntry(id: entry.id, text: "Share Cedar next month")
    state = try await useCases.snapshot()
    #expect(state.entries.last?.text.contains("Share Cedar next month") == true)
    #expect(state.sources.first?.text == "My goal is share Cedar with Mimi")
    _ = try await useCases.resolve(sourceID: pending.id, kind: .idea)
    state = try await useCases.snapshot()
    #expect(state.entries.last?.text.contains("Maybe I should abandon Cedar") == true)
    #expect(Set(state.entries.last!.sourceIDs) == [clear.id, pending.id])
  }

  @Test func sharedNicknameDoesNotSilentlyLinkEitherPerson() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.createProfile(kind: .person, name: "Mira Noor", aliases: ["M"])
    _ = try await useCases.createProfile(kind: .person, name: "Mona Noor", aliases: ["M"])
    _ = try await useCases.ingest(
      source: PersonalMemorySource(text: "My goal is ask M", kind: .goal))
    let state = try await useCases.snapshot()
    #expect(state.entries.first?.profileIDs == [state.selfProfileID])
  }

  @Test func photoAndProvenanceCommitTogetherOrBothRollback() async throws {
    let repository = PersonalMemoryTestRepository()
    let useCases = PersonalMemoryUseCases(repository: repository)
    let state = try await useCases.snapshot()
    let source = PersonalMemorySource(
      text: "Owner supplied image", origin: "image import", kind: .conversationOnly)
    await repository.failWrites(true)
    await #expect(throws: PersonalMemoryError.storage) {
      try await useCases.setPhoto(
        profileID: state.selfProfileID, data: Data([1, 2]), origin: .imported, source: source)
    }
    let failed = try await useCases.snapshot()
    #expect(failed.sources.isEmpty && failed.photos.isEmpty)
    await repository.failWrites(false)
    let saved = try await useCases.setPhoto(
      profileID: state.selfProfileID, data: Data([1, 2]), origin: .imported, source: source)
    #expect(saved.sources.count == 1 && saved.photos.count == 1)
    #expect(saved.photos.first?.sourceID == source.id)
  }
}

extension PersonalMemoryTests {
  @Test func editedExcerptKeepsItsOriginalSourcesBeyondRollingWindow() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    let conversation = UUID()
    let first = PersonalMemorySource(
      conversationID: conversation, text: "My goal is study Cedar", kind: .goal)
    _ = try await useCases.ingest(source: first)
    let initial = try await useCases.snapshot()
    let summary = try #require(initial.entries.first { $0.kind == .summary })
    _ = try await useCases.updateEntry(id: summary.id, text: "Owner correction about Cedar")
    for number in 1...6 {
      _ = try await useCases.ingest(
        source: PersonalMemorySource(
          conversationID: conversation,
          text: "My goal is exercise day \(number)", kind: .goal))
    }
    let state = try await useCases.snapshot()
    let edited = try #require(state.entries.first { $0.id == summary.id })
    #expect(edited.text == "Owner correction about Cedar")
    #expect(edited.sourceIDs == [first.id])
  }

  @Test func organizingExcerptDoesNotFreezeCorrectedPrimaryText() async throws {
    let useCases = PersonalMemoryUseCases(repository: PersonalMemoryTestRepository())
    _ = try await useCases.ingest(
      source: PersonalMemorySource(conversationID: UUID(), text: "I prefer tea", kind: .preference))
    let initial = try await useCases.snapshot()
    let primary = try #require(initial.entries.first { $0.kind == .preference })
    let summary = try #require(initial.entries.first { $0.kind == .summary })
    _ = try await useCases.organize(entryID: summary.id, categories: ["Drinks"], profileIDs: [])
    _ = try await useCases.updateEntry(id: primary.id, text: "I prefer coffee")
    let state = try await useCases.snapshot()
    let organized = try #require(state.entries.first { $0.id == summary.id })
    #expect(organized.text.contains("I prefer coffee"))
    #expect(!organized.text.contains("I prefer tea"))
    #expect(organized.categories == ["Drinks"])
    #expect(organized.profileIDs.isEmpty)
  }
}
