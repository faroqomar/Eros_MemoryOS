import ChatCore
import ChatPersistence
import ChatPresentation
import Foundation
import Testing

actor TestRepository: ChatRepository {
  var snapshot: ChatSnapshot
  var fails = false
  init(_ snapshot: ChatSnapshot = ChatSnapshot()) { self.snapshot = snapshot }
  func load() -> ChatSnapshot { snapshot }
  func save(_ snapshot: ChatSnapshot) throws {
    if fails { throw ChatError.storage }
    self.snapshot = snapshot
  }
  func setFailure(_ value: Bool) { fails = value }
}

actor TestModel: ChatModel {
  var requests: [[ChatTurn]] = []
  var mode: Mode
  var reply: String?
  enum Mode: Sendable {
    case success, failure, slow, capped, unavailableBeforeText, slowBeforeText, whitespaceFailure,
      whitespaceSlow
  }
  init(_ mode: Mode = .success) { self.mode = mode }
  func setMode(_ mode: Mode) { self.mode = mode }
  func setReply(_ text: String) { reply = text }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    requests.append(turns)
    if mode == .unavailableBeforeText { throw ChatError.modelUnavailable }
    if mode == .slowBeforeText { try await Task.sleep(for: .seconds(2)) }
    if mode == .whitespaceFailure || mode == .whitespaceSlow {
      onText("\n \t")
      if mode == .whitespaceSlow { try await Task.sleep(for: .seconds(2)) }
      throw ChatError.generationFailed
    }
    onText("Hello")
    switch mode {
    case .success: onText(reply ?? "Hello مرحباً")
    case .failure: throw ChatError.modelUnavailable
    case .capped: throw ChatError.outputLimit
    case .unavailableBeforeText, .slowBeforeText, .whitespaceFailure, .whitespaceSlow:
      onText("Hello مرحباً")
    case .slow:
      for _ in 0..<200 { try await Task.sleep(for: .milliseconds(10)) }
      onText("Hello مرحباً")
    }
  }
  func unload() {}
}

actor TestMemory: ChatMemoryRetrieving {
  var records: [ChatEvidence]
  var queries: [String] = []
  var earlierQuestions: [[String]] = []
  init(_ records: [ChatEvidence]) { self.records = records }
  func replace(_ records: [ChatEvidence]) { self.records = records }
  func retrieve(query: String) async throws -> [ChatEvidence] {
    queries.append(query)
    return records
  }
  func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence] {
    queries.append(query)
    earlierQuestions.append(previousQuestions)
    return records
  }
}

private func repositoryURL() -> URL {
  URL.temporaryDirectory.appending(path: "chat-tests-\(UUID())").appending(path: "chat.json")
}

@Test func durableConversationAndDraftRoundTrip() async throws {
  let url = repositoryURL()
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let useCases = ChatUseCases(repository: FileChatRepository(url: url), model: TestModel())
  let initial = try await useCases.load()
  let id = try #require(initial.selectedID)
  let text = "علي e\u{301}\nIraqi شلونك؟\u{200F}"
  _ = try await useCases.updateDraft(text, memoryMode: true, conversationID: id)
  let reopened = ChatUseCases(repository: FileChatRepository(url: url), model: TestModel())
  let state = try await reopened.load()
  #expect(state.selectedID == id)
  #expect(state.conversations[0].draft.utf8.elementsEqual(text.utf8))
  #expect(state.conversations[0].memoryMode)
}

@Test func conversationLifecycleDoesNotAffectOtherChats() async throws {
  let useCases = ChatUseCases(repository: TestRepository(), model: TestModel())
  let first = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft(
    "Keep this first draft", memoryMode: false, conversationID: first)
  let second = try #require(try await useCases.newConversation().selectedID)
  _ = try await useCases.rename(first, title: "Arabic العربية")
  let open = try await useCases.open(first)
  #expect(open.conversations.first(where: { $0.id == first })?.title == "Arabic العربية")
  let removed = try await useCases.delete(second)
  #expect(removed.conversations.map(\.id) == [first])
  let empty = try await useCases.delete(first)
  #expect(empty.conversations.count == 1)
  #expect(empty.selectedID != first)
}

@Test func followupPreservesEarlierTurnsAndStableReplyOnRegeneration() async throws {
  let repository = TestRepository()
  let model = TestModel()
  let useCases = ChatUseCases(repository: repository, model: model)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("My name is Ali", memoryMode: false, conversationID: id)
  let first = try await useCases.generate { _ in }
  let replyID = first.conversations[0].messages.last?.id
  let again = try await useCases.generate(reusingReply: true) { _ in }
  #expect(again.conversations[0].messages.count == 2)
  #expect(again.conversations[0].messages.last?.id == replyID)
  _ = try await useCases.updateDraft("What is my name?", memoryMode: false, conversationID: id)
  _ = try await useCases.generate { _ in }
  let requests = await model.requests
  #expect(
    requests.last?.filter { $0.role == .user }.map(\.text) == [
      "My name is Ali", "What is my name?",
    ])
  #expect(
    requests.last?.contains(where: { $0.role == .assistant && $0.text == "Hello مرحباً" }) == true)
}

@Test func failureAndRetryPreserveOneUserAndOneAssistant() async throws {
  let model = TestModel(.failure)
  let useCases = ChatUseCases(repository: TestRepository(), model: model)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Hello", memoryMode: false, conversationID: id)
  await #expect(throws: ChatError.modelUnavailable) { try await useCases.generate { _ in } }
  let failed = await useCases.state()
  #expect(failed.conversations[0].messages.last?.text == "Hello")
  #expect(failed.conversations[0].messages.last?.status == .failed)
  let assistantID = failed.conversations[0].messages.last?.id
  await model.setMode(.success)
  let retried = try await useCases.generate(reusingReply: true) { _ in }
  #expect(retried.conversations[0].messages.count == 2)
  #expect(retried.conversations[0].messages.last?.id == assistantID)
  #expect(retried.conversations[0].messages.last?.status == .complete)
}

@Test func contextLimitRefusesWithoutDroppingHistory() async throws {
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model)
  let id = try #require(try await useCases.load().selectedID)
  let oversized = String(repeating: "A", count: ChatLimits.promptBytes)
  _ = try await useCases.updateDraft(oversized, memoryMode: false, conversationID: id)
  await #expect(throws: ChatError.contextLimit) { try await useCases.generate { _ in } }
  let state = await useCases.state()
  #expect(state.conversations[0].draft == oversized)
  #expect(state.conversations[0].messages.isEmpty)
  #expect(await model.requests.isEmpty)
}

@Test func currentSourcesReplaceOldCorrectionsAndDeletionOnFollowup() async throws {
  let recordID = UUID()
  let model = TestModel()
  let memory = TestMemory([ChatEvidence(id: recordID, text: "Ali birthday May 12")])
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  let id = try #require(try await useCases.load().selectedID)
  await model.setReply("Ali birthday May 12")
  _ = try await useCases.updateDraft("Ali birthday?", memoryMode: true, conversationID: id)
  _ = try await useCases.generate { _ in }
  await memory.replace([ChatEvidence(id: recordID, text: "Ali birthday June 14")])
  _ = try await useCases.updateDraft("What else?", memoryMode: true, conversationID: id)
  let corrected = try await useCases.generate { _ in }
  let request = try #require(await model.requests.last)
  #expect(request[0].text.contains("June 14"))
  #expect(!request.map(\.text).joined().contains("May 12"))
  #expect(
    request.contains(where: {
      $0.role == .assistant && $0.text.contains("Earlier AI interpretation withheld")
    }))
  #expect(corrected.conversations[0].messages.last?.sources.first?.id == recordID)
  #expect(await memory.queries.last == "What else?")
  #expect(await memory.earlierQuestions.last == ["Ali birthday?"])
  await memory.replace([])
  _ = try await useCases.updateDraft("And now?", memoryMode: true, conversationID: id)
  let countBeforeMissing = await model.requests.count
  await #expect(throws: ChatError.noEvidence) { try await useCases.generate { _ in } }
  let removed = await useCases.state()
  #expect(removed.conversations[0].messages.count == 4)
  #expect(removed.conversations[0].draft == "And now?")
  #expect(await model.requests.count == countBeforeMissing)
}

@Test func interruptedArchiveRecoversPartialReply() async throws {
  let reply = ChatMessage(role: .assistant, text: "partial جزئي", status: .generating)
  let chat = ChatConversation(
    messages: [ChatMessage(role: .user, text: "Hi"), reply], draft: "next draft")
  let repository = TestRepository(
    ChatSnapshot(conversations: [chat], selectedID: chat.id, revision: 10))
  let useCases = ChatUseCases(repository: repository, model: TestModel())
  let recovered = try await useCases.load()
  #expect(recovered.conversations[0].messages.last?.id == reply.id)
  #expect(recovered.conversations[0].messages.last?.text == "partial جزئي")
  #expect(recovered.conversations[0].messages.last?.status == .interrupted)
  #expect(recovered.conversations[0].draft == "next draft")
  #expect(recovered.revision == 11)
}

@Test func unknownArchiveIsNotOverwritten() async throws {
  let url = repositoryURL()
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  let data = try JSONEncoder().encode(ChatSnapshot(formatVersion: 99))
  try data.write(to: url)
  let useCases = ChatUseCases(repository: FileChatRepository(url: url), model: TestModel())
  await #expect(throws: ChatError.unsupportedVersion) { try await useCases.load() }
  #expect(try Data(contentsOf: url) == data)
}

@Test func cappedOutputPreservesPartialAndReportsLimit() async throws {
  let useCases = ChatUseCases(repository: TestRepository(), model: TestModel(.capped))
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Hello", memoryMode: false, conversationID: id)
  await #expect(throws: ChatError.outputLimit) { try await useCases.generate { _ in } }
  #expect(await useCases.state().conversations[0].messages.last?.text == "Hello")
}

@Test @MainActor func viewModelStopPreservesPartialAndNextDraft() async throws {
  let model = TestModel(.slow)
  let repository = TestRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await vm.load()
  vm.draft = "Hello"
  let generation = Task { await vm.send() }
  for _ in 0..<100 where vm.currentConversation?.messages.last?.text != "Hello" {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(vm.isGenerating)
  vm.draft = "Next thought\nفكرة ثانية"
  vm.stop()
  await generation.value
  #expect(!vm.isGenerating)
  #expect(vm.lastCancellationSeconds != nil)
  #expect(vm.firstUsableTextSeconds != nil)
  #expect(vm.currentConversation?.messages.last?.text == "Hello")
  #expect(vm.currentConversation?.messages.last?.status == .stopped)
  #expect(vm.draft == "Next thought\nفكرة ثانية")
  await vm.flushDraft()
  let reopened = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await reopened.load()
  #expect(reopened.draft == "Next thought\nفكرة ثانية")
}

@Test @MainActor func diskFailurePreservesDraftAndPreventsModelInvocation() async throws {
  let repository = TestRepository()
  let model = TestModel()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await vm.load()
  vm.draft = "Do not lose this"
  await repository.setFailure(true)
  await vm.send()
  #expect(vm.draft == "Do not lose this")
  #expect(vm.error == .storage)
  #expect(vm.currentConversation?.messages.isEmpty == true)
  #expect(await model.requests.isEmpty)
}

@Test func submittedDraftCannotRaceWithNextDraft() async throws {
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Submitted", memoryMode: false, conversationID: id)
  // A newer draft may finish saving before the queued generation starts.
  _ = try await useCases.updateDraft("Next message", memoryMode: false, conversationID: id)
  let result = try await useCases.generate(submittedText: "Submitted") { _ in }
  #expect(result.conversations[0].messages.first?.text == "Submitted")
  #expect(result.conversations[0].draft == "Next message")
  #expect(await model.requests.last?.last?.text == "Submitted")
}

@Test func unicodeAutomaticTitleRespectsByteLimitWithoutRejectingMessage() async throws {
  let useCases = ChatUseCases(repository: TestRepository(), model: TestModel())
  let id = try #require(try await useCases.load().selectedID)
  let emoji = String(repeating: "👩🏽‍💻", count: 40)
  _ = try await useCases.updateDraft(emoji, memoryMode: false, conversationID: id)
  let result = try await useCases.generate { _ in }
  #expect(result.conversations[0].messages.first?.text == emoji)
  #expect(result.conversations[0].title.utf8.count <= ChatLimits.titleBytes)
  #expect(!result.conversations[0].title.isEmpty)
}

@Test func staleRepositorySnapshotDoesNotOverwriteNewerData() async throws {
  let url = repositoryURL()
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let repository = FileChatRepository(url: url)
  let chat = ChatConversation(title: "Latest", draft: "Keep this")
  let recent = ChatSnapshot(conversations: [chat], selectedID: chat.id, revision: 5)
  try await repository.save(recent)
  try await repository.save(ChatSnapshot(revision: 4))
  #expect(try await repository.load() == recent)
}

@Test @MainActor func renameDeleteAndReopenUseCaseResultsReachViewModel() async throws {
  let vm = ChatViewModel(useCases: ChatUseCases(repository: TestRepository(), model: TestModel()))
  await vm.load()
  let first = try #require(vm.currentConversation?.id)
  vm.draft = "Unsent first draft"
  await vm.newConversation()
  let second = try #require(vm.currentConversation?.id)
  await vm.rename(first, title: "First renamed")
  await vm.open(first)
  #expect(vm.draft == "Unsent first draft")
  #expect(vm.currentConversation?.title == "First renamed")
  await vm.delete(second)
  #expect(vm.conversations.count == 1)
}

@Test func missingEvidenceCanRetryAfterAnOriginalIsSaved() async throws {
  let model = TestModel()
  let memory = TestMemory([])
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("What about Ali?", memoryMode: true, conversationID: id)
  await #expect(throws: ChatError.noEvidence) { try await useCases.generate { _ in } }
  let failed = await useCases.state()
  #expect(failed.conversations[0].draft == "What about Ali?")
  #expect(failed.conversations[0].messages.isEmpty)
  #expect(await model.requests.isEmpty)
  let record = ChatEvidence(id: UUID(), text: "Ali likes coffee")
  await memory.replace([record])
  let retried = try await useCases.generate { _ in }
  #expect(retried.conversations[0].messages.count == 2)
  #expect(retried.conversations[0].messages.last?.sources == [record])
}

@Test func midGenerationStorageFailureRetainsVisibleReplyForRecovery() async throws {
  let repository = TestRepository()
  let useCases = ChatUseCases(repository: repository, model: TestModel())
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Hi", memoryMode: false, conversationID: id)
  await #expect(throws: ChatError.storage) {
    try await useCases.generate { state in
      if state.conversations[0].messages.last?.text == "Hello" {
        await repository.setFailure(true)
      }
    }
  }
  let unsaved = await useCases.state()
  #expect(unsaved.conversations[0].messages.last?.text == "Hello مرحباً")
  #expect(unsaved.conversations[0].messages.last?.status == .failed)
  await repository.setFailure(false)
  _ = try await useCases.updateDraft("Next", memoryMode: false, conversationID: id)
  let reopened = ChatUseCases(repository: repository, model: TestModel())
  #expect(try await reopened.load().conversations[0].messages.last?.text == "Hello مرحباً")
}

@Test func invalidRoleOrderAndRevisionOverflowAreRejected() throws {
  let chat = ChatConversation(messages: [ChatMessage(role: .assistant, text: "Invalid")])
  #expect(throws: ChatError.invalidArchive) {
    try ChatSnapshot(conversations: [chat], selectedID: chat.id).validate()
  }
  #expect(throws: ChatError.invalidArchive) { try ChatSnapshot(revision: .max).validate() }
}

@Test func failedRegenerationBeforeFirstPrefixPreservesSavedAnswerAndSources() async throws {
  let oldEvidence = ChatEvidence(id: UUID(), text: "Original evidence")
  let memory = TestMemory([oldEvidence])
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Saved memory?", memoryMode: true, conversationID: id)
  let complete = try await useCases.generate { _ in }
  let originalReply = try #require(complete.conversations[0].messages.last)
  await memory.replace([ChatEvidence(id: UUID(), text: "Changed evidence")])
  await model.setMode(.unavailableBeforeText)
  await #expect(throws: ChatError.modelUnavailable) {
    try await useCases.generate(reusingReply: true) { _ in }
  }
  let retained = await useCases.state()
  #expect(retained.conversations[0].messages.count == 2)
  #expect(retained.conversations[0].messages.last == originalReply)
}

@Test func cancelledRegenerationBeforeFirstPrefixPreservesSavedAnswer() async throws {
  let model = TestModel()
  let useCases = ChatUseCases(repository: TestRepository(), model: model)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Hello", memoryMode: false, conversationID: id)
  let complete = try await useCases.generate { _ in }
  let originalReply = try #require(complete.conversations[0].messages.last)
  await model.setMode(.slowBeforeText)
  let regeneration = Task { try await useCases.generate(reusingReply: true) { _ in } }
  for _ in 0..<100 where await model.requests.count < 2 {
    try await Task.sleep(for: .milliseconds(10))
  }
  regeneration.cancel()
  do {
    _ = try await regeneration.value
    Issue.record("Expected cancellation")
  } catch is CancellationError {}
  #expect(await useCases.state().conversations[0].messages.last == originalReply)
}

@Test(arguments: [TestModel.Mode.whitespaceFailure, .whitespaceSlow])
func whitespaceOnlyRegenerationPreservesPriorAnswer(mode: TestModel.Mode) async throws {
  let model = TestModel()
  let repository = TestRepository()
  let useCases = ChatUseCases(repository: repository, model: model)
  let id = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft("Hello", memoryMode: false, conversationID: id)
  let complete = try await useCases.generate { _ in }
  let original = try #require(complete.conversations[0].messages.last)
  await model.setMode(mode)
  let task = Task { try await useCases.generate(reusingReply: true) { _ in } }
  if mode == .whitespaceSlow {
    for _ in 0..<100 where await model.requests.count < 2 {
      try await Task.sleep(for: .milliseconds(10))
    }
    task.cancel()
  }
  do {
    _ = try await task.value
    Issue.record("Expected an incomplete regeneration")
  } catch { #expect(error is CancellationError || error as? ChatError == .generationFailed) }
  #expect(await useCases.state().conversations[0].messages.last == original)
  #expect(await repository.load().conversations[0].messages.last == original)
}

actor DelayedRepository: ChatRepository {
  private var snapshot = ChatSnapshot()
  private var delayNext = false
  func load() -> ChatSnapshot { snapshot }
  func save(_ next: ChatSnapshot) async throws {
    if delayNext {
      delayNext = false
      try await Task.sleep(for: .milliseconds(200))
    }
    snapshot = next
  }
  func delayOneSave() { delayNext = true }
}

@Test @MainActor func navigationDisablesInputUntilOutgoingDraftCommits() async throws {
  let repository = DelayedRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  await vm.load()
  let first = try #require(vm.currentConversation?.id)
  vm.draft = "Outgoing draft"
  await repository.delayOneSave()
  let navigation = Task { await vm.newConversation() }
  for _ in 0..<100 where !vm.isTransitioning {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(vm.isTransitioning)
  #expect(!vm.canSend)
  // The UI disables editing with this state; stale binding writes cannot target the next chat.
  vm.draft = "Late binding write"
  vm.memoryMode = true
  #expect(vm.draft == "Outgoing draft")
  #expect(!vm.memoryMode)
  await vm.send()
  await navigation.value
  #expect(!vm.isTransitioning)
  #expect(vm.currentConversation?.id != first)
  #expect(vm.draft.isEmpty)
  await vm.open(first)
  #expect(vm.draft == "Outgoing draft")
  #expect(vm.currentConversation?.messages.isEmpty == true)
}

@Test @MainActor func successfulSaveRetryClearsOnlyStorageError() async throws {
  let repository = TestRepository()
  let model = TestModel(.unavailableBeforeText)
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await vm.load()
  vm.draft = "Preserve my draft"
  await repository.setFailure(true)
  #expect(await vm.flushDraft() == false)
  #expect(vm.error == .storage)
  await repository.setFailure(false)
  #expect(await vm.flushDraft())
  #expect(await repository.snapshot.conversations.first?.draft == "Preserve my draft")
  #expect(vm.error == nil)
  await vm.send()
  #expect(vm.error == .modelUnavailable)
  #expect(await vm.flushDraft())
  #expect(vm.error == .modelUnavailable)
}

@Test @MainActor func failedDeletePreservesChatForRetry() async throws {
  let repository = TestRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  await vm.load()
  let id = try #require(vm.currentConversation?.id)
  vm.draft = "Keep until deletion commits"
  #expect(await vm.flushDraft())
  await repository.setFailure(true)
  await vm.delete(id)
  #expect(vm.error == .storage)
  #expect(vm.conversations.contains { $0.id == id })
  await repository.setFailure(false)
  await vm.delete(id)
  #expect(vm.error == nil)
  #expect(!vm.conversations.contains { $0.id == id })
}

@Test @MainActor func homeStartsSeparateChatsWhileFollowupsAndHistoryStayTogether() async throws {
  let repository = TestRepository()
  let model = TestModel()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await vm.load()
  #expect(await vm.prepareNewConversation(draft: "Plan a fictional garden"))
  let first = try #require(vm.currentConversation?.id)
  await vm.send()
  vm.draft = "Include shade plants"
  await vm.send()
  #expect(vm.currentConversation?.id == first)
  #expect(vm.currentConversation?.messages.filter { $0.role == .user }.count == 2)

  #expect(await vm.prepareNewConversation(draft: "Describe a fictional telescope"))
  let second = try #require(vm.currentConversation?.id)
  #expect(second != first)
  await vm.send()
  #expect(
    await model.requests.last?.filter { $0.role == .user }.map(\.text) == [
      "Describe a fictional telescope"
    ])
  await vm.open(first)
  vm.draft = "Add a walking path"
  await vm.send()
  #expect(vm.currentConversation?.id == first)
  #expect(vm.conversations.first?.id == first)
  #expect(
    await model.requests.last?.filter { $0.role == .user }.map(\.text) == [
      "Plan a fictional garden", "Include shade plants", "Add a walking path",
    ])
  let reloaded = ChatViewModel(useCases: ChatUseCases(repository: repository, model: model))
  await reloaded.load()
  #expect(reloaded.conversations.count == 2)
  #expect(reloaded.conversations.first { $0.id == second }?.messages.count == 2)
}

@Test @MainActor func preparingHomeChatPreservesOutgoingDraftAndDoesNotInheritMemoryMode()
  async throws
{
  let repository = TestRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  await vm.load()
  let oldID = try #require(vm.currentConversation?.id)
  let oldDraft = "Unsent e\u{301}\nفكرة أخرى"
  vm.draft = oldDraft
  vm.memoryMode = true
  #expect(await vm.prepareNewConversation(draft: "New Home message"))
  #expect(vm.currentConversation?.id != oldID)
  #expect(vm.draft == "New Home message")
  #expect(!vm.memoryMode)
  #expect(vm.currentConversation?.messages.isEmpty == true)
  await vm.open(oldID)
  #expect(vm.draft.utf8.elementsEqual(oldDraft.utf8))
  #expect(vm.memoryMode)
}

@Test func repeatedNewChatReusesOnlyUntouchedPlaceholders() async throws {
  let named = ChatConversation(title: "Reserved subject")
  let whitespace = ChatConversation(draft: " \n")
  let configured = ChatConversation(memoryMode: true)
  let repository = TestRepository(
    ChatSnapshot(
      conversations: [named, whitespace, configured], selectedID: named.id))
  let useCases = ChatUseCases(repository: repository, model: TestModel())
  _ = try await useCases.load()
  let first = try await useCases.newConversation()
  let again = try await useCases.newConversation()
  #expect(first.selectedID == again.selectedID)
  #expect(again.conversations.count == 4)
  #expect(again.conversations.contains(named))
  #expect(again.conversations.contains(whitespace))
  #expect(again.conversations.contains(configured))
  let prepared = try await useCases.newConversation(draft: "Independent question")
  #expect(prepared.selectedID == first.selectedID)
  #expect(prepared.conversations.first?.draft == "Independent question")
}

@Test func failedFreshChatCommitLeavesSelectionAndArchiveUnchanged() async throws {
  let old = ChatConversation(draft: "Saved draft")
  let repository = TestRepository(ChatSnapshot(conversations: [old], selectedID: old.id))
  let useCases = ChatUseCases(repository: repository, model: TestModel())
  let before = try await useCases.load()
  await repository.setFailure(true)
  await #expect(throws: ChatError.storage) {
    try await useCases.newConversation(draft: "Keep on Home for retry")
  }
  #expect(await useCases.state() == before)
  #expect(await repository.snapshot == before)
}

@Test @MainActor func failedHomePreparationRetainsSelectedInputAndReturnsFalse() async throws {
  let repository = TestRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  #expect(await vm.prepareNewConversation(draft: "Before loading") == false)
  await vm.load()
  let oldID = vm.currentConversation?.id
  vm.draft = "Existing unsent text"
  await repository.setFailure(true)
  #expect(await vm.prepareNewConversation(draft: "Independent Home input") == false)
  #expect(vm.error == .storage)
  #expect(vm.currentConversation?.id == oldID)
  #expect(vm.draft == "Existing unsent text")
  #expect(!vm.isTransitioning)
  await repository.setFailure(false)
  #expect(await vm.prepareNewConversation(draft: "Independent Home input"))
  #expect(vm.currentConversation?.id != oldID)
  #expect(vm.conversations.first { $0.id == oldID }?.draft == "Existing unsent text")
}

@Test func legacyArchiveWithoutHomeDraftDecodesWithoutMovingConversationInput() throws {
  let old = ChatConversation(draft: "Existing conversation draft")
  let legacy = ChatSnapshot(conversations: [old], selectedID: old.id)
  let data = try JSONEncoder().encode(legacy)
  let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  #expect(object["homeDraft"] == nil)
  let decoded = try JSONDecoder().decode(ChatSnapshot.self, from: data)
  try decoded.validate()
  #expect(decoded.homeDraft == nil)
  #expect(decoded.conversations == [old])
  #expect(decoded.selectedID == old.id)
}

@Test @MainActor func independentHomeDraftSurvivesBackgroundAndRelaunch() async throws {
  let url = repositoryURL()
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let vm = ChatViewModel(
    useCases: ChatUseCases(
      repository: FileChatRepository(url: url), model: TestModel()))
  await vm.load()
  let oldID = try #require(vm.currentConversation?.id)
  vm.draft = "Conversation follow-up"
  let home = "Independent e\u{301}\nفكرة من الرئيسية"
  vm.homeDraft = home
  await vm.interrupt()
  let restored = ChatViewModel(
    useCases: ChatUseCases(
      repository: FileChatRepository(url: url), model: TestModel()))
  await restored.load()
  #expect(restored.homeDraft.utf8.elementsEqual(home.utf8))
  #expect(restored.draft == "Conversation follow-up")
  await restored.newConversation()
  #expect(restored.homeDraft.utf8.elementsEqual(home.utf8))
  #expect(await restored.prepareHomeConversation())
  #expect(restored.homeDraft.isEmpty)
  #expect(restored.draft.utf8.elementsEqual(home.utf8))
  #expect(restored.currentConversation?.id != oldID)
  await restored.open(oldID)
  #expect(restored.draft == "Conversation follow-up")
  let saved = try await FileChatRepository(url: url).load()
  #expect(saved.homeDraft == "")
  #expect(saved.conversations.contains { $0.draft.utf8.elementsEqual(home.utf8) })
}

@Test func failedHomeTransferPreservesHomeDraftAndConversationSelection() async throws {
  let old = ChatConversation(draft: "Old follow-up")
  let repository = TestRepository(
    ChatSnapshot(
      conversations: [old], selectedID: old.id, homeDraft: "Unsent Home text"))
  let useCases = ChatUseCases(repository: repository, model: TestModel())
  let before = try await useCases.load()
  await repository.setFailure(true)
  await #expect(throws: ChatError.storage) { try await useCases.prepareHomeConversation() }
  #expect(await useCases.state() == before)
  #expect(await repository.snapshot == before)
  await repository.setFailure(false)
  let transferred = try await useCases.prepareHomeConversation()
  #expect(transferred.homeDraft == "")
  #expect(transferred.selectedID != old.id)
  #expect(transferred.conversations.first?.draft == "Unsent Home text")
  #expect(transferred.conversations.contains(old))
}

@Test @MainActor func homeTransferFailureLeavesEditableInputForRetry() async throws {
  let repository = TestRepository()
  let vm = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  await vm.load()
  vm.homeDraft = "Keep Home input"
  await repository.setFailure(true)
  #expect(await vm.prepareHomeConversation() == false)
  #expect(vm.homeDraft == "Keep Home input")
  #expect(vm.error == .storage)
  #expect(!vm.isTransitioning)
  await repository.setFailure(false)
  #expect(await vm.prepareHomeConversation())
  #expect(vm.homeDraft.isEmpty)
  #expect(vm.draft == "Keep Home input")
  #expect(await vm.flushDraft())
  #expect(await repository.snapshot.homeDraft == "")
}

@Test func oversizedHomeDraftIsRejectedWithoutArchiveMutation() async throws {
  let useCases = ChatUseCases(repository: TestRepository(), model: TestModel())
  let before = try await useCases.load()
  await #expect(throws: ChatError.messageTooLong) {
    try await useCases.updateHomeDraft(String(repeating: "a", count: ChatLimits.draftBytes + 1))
  }
  #expect(await useCases.state() == before)
  var invalid = before
  invalid.homeDraft = String(repeating: "a", count: ChatLimits.draftBytes + 1)
  #expect(throws: ChatError.invalidArchive) { try invalid.validate() }
}

@Test func ordinaryFollowupRetainsAssistantContextOnlyWhileCitationsStayCurrent() async throws {
  let sourceID = UUID()
  let model = TestModel()
  let memory = TestMemory([ChatEvidence(id: sourceID, text: "Fictional appointment Monday")])
  let useCases = ChatUseCases(repository: TestRepository(), model: model, memory: memory)
  _ = try await useCases.load()
  await model.setReply("I suggest preparing on Sunday.")
  _ = try await useCases.generate(submittedText: "When should I prepare?") { _ in }
  _ = try await useCases.generate(submittedText: "Why did you suggest that?") { _ in }
  let unchanged = try #require(await model.requests.last)
  #expect(
    unchanged.contains { $0.role == .assistant && $0.text == "I suggest preparing on Sunday." })
  await memory.replace([ChatEvidence(id: sourceID, text: "Fictional appointment Thursday")])
  _ = try await useCases.generate(submittedText: "Is that still right?") { _ in }
  let changed = try #require(await model.requests.last)
  #expect(!changed.contains { $0.role == .assistant && $0.text.contains("Sunday") })
  #expect(changed.first?.text.contains("Thursday") == true)
}
