import ChatCore
import ChatPersistence
import ChatPresentation
import Foundation
import Testing

private actor RecordingSpy: ChatMemoryRecording {
  struct Original: Equatable, Sendable {
    let conversationID: UUID
    let messageID: UUID
    let text: String
    let date: Date
  }
  var originals: [Original] = []
  var fails = false
  func setFailure(_ fails: Bool) { self.fails = fails }
  func preserve(conversationID: UUID, messageID: UUID, text: String, createdAt: Date)
    throws
  {
    originals.append(
      Original(conversationID: conversationID, messageID: messageID, text: text, date: createdAt))
    if fails { throw ChatError.storage }
  }
}

private actor PrivacyWriteSpy: ChatRepository {
  var saved: [ChatSnapshot] = []
  var initial: ChatSnapshot
  var fails = false
  func setFailure(_ fails: Bool) { self.fails = fails }
  init(initial: ChatSnapshot = ChatSnapshot()) { self.initial = initial }
  func load() -> ChatSnapshot { saved.last ?? initial }
  func save(_ snapshot: ChatSnapshot) throws {
    if fails { throw ChatError.storage }
    try snapshot.validateDurable()
    saved.append(snapshot)
  }
}

@Test func tentativeMessageStillReachesChatModelAfterOriginalPreservation() async throws {
  let recorder = RecordingSpy()
  let model = TestModel()
  let repository = PrivacyWriteSpy()
  let useCases = ChatUseCases(repository: repository, model: model, recorder: recorder)
  let id = try #require(try await useCases.load().selectedID)
  let state = try await useCases.generate(submittedText: "Maybe I should quit") { _ in }
  #expect(await model.requests.count == 1)
  #expect(state.conversations[0].messages.last?.status == .complete)
  let original = try #require(await recorder.originals.first)
  #expect(original.messageID == state.conversations[0].messages.first?.id)
  #expect(original.conversationID == id)
  #expect(original.text == "Maybe I should quit")
  #expect(await repository.saved.last?.conversations[0].messages.first?.text == original.text)
}

@Test func lastingOriginalSurvivesRecorderFailureAndRetriesWithSameIdentity() async throws {
  let recorder = RecordingSpy()
  await recorder.setFailure(true)
  let repository = PrivacyWriteSpy()
  let model = TestModel()
  let useCases = ChatUseCases(repository: repository, model: model, recorder: recorder)
  _ = try await useCases.load()
  await #expect(throws: ChatError.memoryPreservationFailed) {
    try await useCases.generate(submittedText: "علي e\u{301} source") { _ in }
  }
  let failed = await useCases.state()
  #expect(failed.conversations[0].messages.count == 2)
  #expect(failed.conversations[0].messages.last?.status == .failed)
  #expect(await model.requests.isEmpty)
  let retained = try #require(await repository.saved.last?.conversations[0].messages.first)
  #expect(retained.text.utf8.elementsEqual("علي e\u{301} source".utf8))
  await recorder.setFailure(false)
  let reopened = ChatUseCases(repository: repository, model: model, recorder: recorder)
  _ = try await reopened.load()
  _ = try await reopened.generate(reusingReply: true) { _ in }
  let observed = await recorder.originals
  #expect(observed.count == 2)
  #expect(observed[0].messageID == observed[1].messageID)
  #expect(observed[0].date == observed[1].date)
}

@Test func lastingOriginalSurvivesContextPreflightFailure() async throws {
  let recorder = RecordingSpy()
  let useCases = ChatUseCases(repository: PrivacyWriteSpy(), model: TestModel(), recorder: recorder)
  _ = try await useCases.load()
  let original = String(repeating: "large", count: ChatLimits.promptBytes / 5)
  await #expect(throws: ChatError.contextLimit) {
    try await useCases.generate(submittedText: original) { _ in }
  }
  let state = await useCases.state()
  #expect(state.conversations[0].messages.first?.text == original)
  #expect(await recorder.originals.count == 1)
}

@Test func temporarySessionReadsExistingMemoryAndNeverSavesItsContent() async throws {
  let repository = PrivacyWriteSpy()
  let recorder = RecordingSpy()
  let evidence = ChatEvidence(id: UUID(), text: "Ali likes tea")
  let memory = TestMemory([evidence])
  let model = TestModel()
  await model.setReply("PRIVATE REPLY")
  let useCases = ChatUseCases(
    repository: repository, model: model, memory: memory, recorder: recorder)
  let normalID = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateHomeDraft("NORMAL HOME INPUT")
  let tempID = try #require(try await useCases.startTemporary().selectedID)
  _ = try await useCases.updateDraft(
    "PRIVATE DRAFT", memoryMode: true, conversationID: tempID, homeDraft: "PRIVATE HOME LEAK")
  _ = try await useCases.rename(tempID, title: "PRIVATE TITLE")
  let replied = try await useCases.generate { _ in }
  #expect(replied.conversations.first(where: \.isTemporary)?.messages.last?.text == "PRIVATE REPLY")
  #expect(await memory.queries == ["PRIVATE DRAFT"])
  #expect(await recorder.originals.isEmpty)
  let writes = await repository.saved
  for write in writes {
    let bytes = try JSONEncoder().encode(write)
    let text = String(decoding: bytes, as: UTF8.self)
    #expect(!text.contains("PRIVATE"))
    #expect(write.selectedID == normalID)
    #expect(!write.conversations.contains(where: { $0.isTemporary }))
    #expect(write.homeDraft == nil || write.homeDraft == "NORMAL HOME INPUT")
  }
  let restarted = ChatUseCases(repository: repository, model: TestModel(), recorder: recorder)
  let reopened = try await restarted.load()
  #expect(reopened.selectedID == normalID)
  #expect(reopened.conversations.count == 1)
  #expect(!reopened.conversations.contains(where: { $0.isTemporary }))
  #expect(reopened.homeDraft == "NORMAL HOME INPUT")
}

@Test func temporaryEndRestoresNormalDraftAndDoesNotPersistPrivateVoice() async throws {
  let useCases = ChatUseCases(repository: PrivacyWriteSpy(), model: TestModel())
  let normalID = try #require(try await useCases.load().selectedID)
  _ = try await useCases.updateDraft(
    "normal saved draft", memoryMode: false, conversationID: normalID)
  let tempID = try #require(try await useCases.startTemporary().selectedID)
  _ = try await useCases.updateDraft(
    "private ephemeral draft", memoryMode: false, conversationID: tempID)
  await #expect(throws: ChatError.temporaryVoiceUnavailable) {
    try await useCases.beginVoice(recordingID: UUID(), durationSeconds: 1)
  }
  let ended = try await useCases.endTemporary()
  #expect(ended.selectedID == normalID)
  #expect(ended.conversations.count == 1)
  #expect(ended.conversations[0].draft == "normal saved draft")
}

@Test func persistenceRejectsPrivateArchivesAndOldArchivesRemainReadable() async throws {
  let url = URL.temporaryDirectory.appending(path: "private-archive-test-\(UUID())/chat.json")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let repository = FileChatRepository(url: url)
  let temp = ChatConversation(title: "temporary", temporary: true)
  let state = ChatSnapshot(conversations: [temp], selectedID: temp.id)
  await #expect(throws: ChatError.invalidArchive) { try await repository.save(state) }
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try JSONEncoder().encode(state).write(to: url)
  await #expect(throws: ChatError.invalidArchive) { try await repository.load() }
  let normal = ChatConversation()
  let legacy = ChatSnapshot(conversations: [normal], selectedID: normal.id)
  try JSONEncoder().encode(legacy).write(to: url)
  #expect(try await repository.load().conversations.first?.isTemporary == false)
}

@Test @MainActor func appSwitchingKeepsPrivateSessionButExplicitEndDiscardsIt() async throws {
  let repository = PrivacyWriteSpy()
  let model = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel()))
  await model.load()
  let normalID = model.currentConversation?.id
  model.draft = "normal"
  await model.startTemporary()
  #expect(model.isTemporary)
  model.draft = "private across app switch"
  await model.interrupt()
  #expect(model.isTemporary)
  #expect(model.draft == "private across app switch")
  #expect(model.currentConversation?.draft == "private across app switch")
  #expect(model.conversations.allSatisfy { !$0.isTemporary })
  await model.endTemporary()
  #expect(!model.isTemporary)
  #expect(!model.hasTemporarySession)
  #expect(model.currentConversation?.id == normalID)
  #expect(model.draft == "normal")
}

@Test @MainActor func explicitEndCancelsAndJoinsPrivateGeneration() async throws {
  let repository = PrivacyWriteSpy()
  let model = ChatViewModel(useCases: ChatUseCases(repository: repository, model: TestModel(.slow)))
  await model.load()
  await model.startTemporary()
  model.draft = "private running"
  let send = Task { await model.send() }
  for _ in 0..<200 {
    if model.currentConversation?.messages.last?.text == "Hello" { break }
    try await Task.sleep(for: .milliseconds(5))
  }
  try #require(model.isGenerating)
  try #require(model.currentConversation?.messages.last?.text == "Hello")
  await model.endTemporary()
  await send.value
  #expect(!model.isGenerating)
  #expect(!model.isTemporary)
  #expect(!model.hasTemporarySession)
  let saved = await repository.saved
  #expect(saved.allSatisfy { !$0.conversations.contains(where: { $0.isTemporary }) })
}

private struct LastingVoiceStub: VoiceTranscribing {
  func transcribe(recordingID: UUID) async throws -> VoiceTranscript {
    let passage = VoicePassage(
      id: UUID(), startSeconds: 0, endSeconds: 1, text: "Maybe move the project")
    return VoiceTranscript(
      id: UUID(), recordingID: recordingID, passageIDs: [passage.id], text: passage.text,
      passages: [passage])
  }
}

@Test func voiceTranscriptIsPreservedAndStillReachesChatModel() async throws {
  let recorder = RecordingSpy()
  let model = TestModel()
  let cases = ChatUseCases(
    repository: PrivacyWriteSpy(), model: model, voiceTranscriber: LastingVoiceStub(),
    recorder: recorder)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 1)
  let conversation = try #require(begun.conversations.first { $0.id == begun.selectedID })
  let job = try #require(conversation.pendingVoice)
  let final = try await cases.processVoice(conversationID: conversation.id, jobID: job.jobID) { _ in
  }
  #expect(final.conversations.first?.messages.last?.status == .complete)
  #expect(await recorder.originals.first?.text == "Maybe move the project")
  #expect(await model.requests.count == 1)
}

@Test func privateUpdatesAndExplicitEndRequireNoNewDiskWrites() async throws {
  let repository = PrivacyWriteSpy()
  let cases = ChatUseCases(repository: repository, model: TestModel())
  _ = try await cases.load()
  let before = await repository.saved.count
  await repository.setFailure(true)
  let temporaryID = try #require(try await cases.startTemporary().selectedID)
  _ = try await cases.updateDraft("private draft", memoryMode: false, conversationID: temporaryID)
  _ = try await cases.generate { _ in }
  _ = try await cases.endTemporary()
  #expect(await repository.saved.count == before)
  #expect(await cases.state().conversations.allSatisfy { !$0.isTemporary })
}

@Test @MainActor func endingSideSessionPreservesCurrentNormalInput() async throws {
  let model = ChatViewModel(
    useCases: ChatUseCases(repository: PrivacyWriteSpy(), model: TestModel()))
  await model.load()
  let normalID = try #require(model.currentConversation?.id)
  await model.startTemporary()
  await model.open(normalID)
  model.draft = "normal input edited while private session remains open"
  await model.endTemporary()
  #expect(!model.hasTemporarySession)
  #expect(model.draft == "normal input edited while private session remains open")
  #expect(model.currentConversation?.draft == model.draft)
}

@Test @MainActor func homeVoiceUsesNormalTargetAndKeepsPrivateSessionInMemory() async throws {
  let repository = PrivacyWriteSpy()
  let cases = ChatUseCases(repository: repository, model: TestModel())
  let model = ChatViewModel(useCases: cases)
  await model.load()
  await model.startTemporary()
  let privateID = try #require(model.currentConversation?.id)
  model.draft = "fictional private draft"
  let recording = UUID()
  #expect(!(await model.prepareVoiceChat(recordingID: recording, durationSeconds: 2)))
  #expect(model.error == .temporaryVoiceUnavailable)
  #expect(model.isTemporary)
  #expect(
    await model.prepareVoiceChat(
      recordingID: recording, durationSeconds: 2, asNormalCapture: true))
  #expect(!model.isTemporary)
  #expect(model.currentConversation?.pendingVoice?.recordingID == recording)
  #expect(model.hasTemporarySession)
  #expect(
    model.snapshot.conversations.first { $0.id == privateID }?.draft == "fictional private draft")
  let durable = try #require(await repository.saved.last)
  #expect(durable.conversations.allSatisfy { !$0.isTemporary })
  #expect(!durable.conversations.contains { $0.id == privateID })
  await model.startTemporary()
  #expect(model.currentConversation?.id == privateID)
  #expect(model.draft == "fictional private draft")
}
