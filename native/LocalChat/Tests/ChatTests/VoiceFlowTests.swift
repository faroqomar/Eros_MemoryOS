import ChatCore
import ChatPresentation
import Foundation
import Testing

private actor VoiceStub: VoiceTranscribing {
  var calls = 0
  var failure: VoiceFailure?
  var text: String
  var delay = false
  let transcriptID = UUID()
  let passageID = UUID()
  init(
    text: String = "My fictional name is Mira.", failure: VoiceFailure? = nil, delay: Bool = false
  ) {
    self.text = text
    self.failure = failure
    self.delay = delay
  }
  func setFailure(_ value: VoiceFailure?) { failure = value }
  func transcribe(recordingID: UUID) async throws -> VoiceTranscript {
    calls += 1
    if delay { try await Task.sleep(for: .milliseconds(200)) }
    if let failure { throw failure }
    return VoiceTranscript(
      id: transcriptID, recordingID: recordingID, passageIDs: [passageID], text: text,
      passages: [VoicePassage(id: passageID, startSeconds: 0, endSeconds: 2, text: text)])
  }
}

private func waitForSpeech(_ speech: VoiceStub) async throws {
  for _ in 0..<200 {
    if await speech.calls > 0 { return }
    try await Task.sleep(for: .milliseconds(5))
  }
  Issue.record("Speech did not start")
}

@Test func voiceArchiveDecodesOlderChatAndPreservesPendingAcrossRelaunch() async throws {
  let old = ChatConversation(messages: [
    ChatMessage(role: .user, text: "Old message"), ChatMessage(role: .assistant, text: "Old reply"),
  ])
  let raw = try JSONEncoder().encode(ChatSnapshot(conversations: [old], selectedID: old.id))
  let decoded = try JSONDecoder().decode(ChatSnapshot.self, from: raw)
  try decoded.validate()
  #expect(decoded.conversations[0].pendingVoice == nil)
  #expect(decoded.conversations[0].messages[0].voice == nil)
  let repository = TestRepository(decoded)
  let speech = VoiceStub()
  let cases = ChatUseCases(repository: repository, model: TestModel(), voiceTranscriber: speech)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let selected = try #require(begun.selectedID)
  let pending = try #require(begun.conversations.first { $0.id == selected }?.pendingVoice)
  let reopened = ChatUseCases(repository: repository, model: TestModel(), voiceTranscriber: speech)
  let restored = try await reopened.load()
  #expect(restored.conversations.first { $0.id == selected }?.pendingVoice?.jobID == pending.jobID)
  #expect(restored.conversations.first { $0.id == selected }?.pendingVoice?.status == .interrupted)
  #expect(await speech.calls == 0)
  #expect(restored.conversations.contains(old))
}

@Test func voiceSuccessIsIdempotentAndFollowupsUseTranscript() async throws {
  let repository = TestRepository()
  let model = TestModel()
  let speech = VoiceStub()
  let cases = ChatUseCases(repository: repository, model: model, voiceTranscriber: speech)
  _ = try await cases.load()
  let recordingID = UUID()
  let begun = try await cases.beginVoice(recordingID: recordingID, durationSeconds: 2)
  let conversation = try #require(begun.conversations.first { $0.id == begun.selectedID })
  let pending = try #require(conversation.pendingVoice)
  #expect(await model.requests.isEmpty)
  let final = try await cases.processVoice(conversationID: conversation.id, jobID: pending.jobID) {
    _ in
  }
  let chat = try #require(final.conversations.first { $0.id == conversation.id })
  #expect(chat.pendingVoice == nil)
  #expect(chat.messages.count == 2)
  #expect(chat.messages.first?.voice?.recordingID == recordingID)
  #expect(chat.messages.first?.voice?.passages.first?.endSeconds == 2)
  #expect(chat.messages.first?.voice?.transcriptID == speech.transcriptID)
  let reopened = try await cases.beginVoice(recordingID: recordingID, durationSeconds: 2)
  #expect(reopened.selectedID == conversation.id)
  #expect(reopened.conversations == final.conversations)
  #expect(await speech.calls == 1)
  _ = try await cases.generate(submittedText: "What is my name?") { _ in }
  #expect(
    await model.requests.last?.filter { $0.role == .user }.map(\.text) == [
      "My fictional name is Mira.", "What is my name?",
    ])
}

@Test func voiceFailureRetryKeepsOneConversationAndOnePair() async throws {
  let repository = TestRepository()
  let speech = VoiceStub(failure: .modelUnavailable)
  let model = TestModel()
  let cases = ChatUseCases(repository: repository, model: model, voiceTranscriber: speech)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first { $0.id == begun.selectedID })
  let job = try #require(c.pendingVoice)
  await #expect(throws: VoiceFailure.modelUnavailable) {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  let failed = await cases.state()
  #expect(failed.conversations.first?.pendingVoice?.failure == .modelUnavailable)
  #expect(failed.conversations.first?.messages.isEmpty == true)
  #expect(await model.requests.isEmpty)
  await speech.setFailure(nil)
  let final = try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  #expect(final.conversations.count == begun.conversations.count)
  #expect(final.conversations.first?.messages.count == 2)
}

@Test func voiceSilenceNeverGeneratesPlaceholder() async throws {
  let model = TestModel()
  let cases = ChatUseCases(
    repository: TestRepository(), model: model, voiceTranscriber: VoiceStub(text: " \n "))
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  await #expect(throws: VoiceFailure.noSpeech) {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  #expect(await model.requests.isEmpty)
  #expect(await cases.state().conversations.first?.pendingVoice?.failure == .noSpeech)
}

@Test func voiceCompletionUsesCapturedConversationAndExcludesConcurrentTextInference() async throws
{
  let speech = VoiceStub(delay: true)
  let model = TestModel()
  let cases = ChatUseCases(repository: TestRepository(), model: model, voiceTranscriber: speech)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  let processing = Task {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  try await waitForSpeech(speech)
  let other = try await cases.newConversation(draft: "Another topic")
  await #expect(throws: ChatError.busy) {
    try await cases.generate(submittedText: "Do not generate") { _ in }
  }
  let result = try await processing.value
  #expect(result.selectedID == other.selectedID)
  #expect(result.conversations.first { $0.id == c.id }?.messages.count == 2)
  #expect(result.conversations.first { $0.id == other.selectedID }?.messages.isEmpty == true)
  #expect(await model.requests.count == 1)
}

@Test func cancelledVoiceRetainsRecoverableAudioReferenceWithoutMessages() async throws {
  let speech = VoiceStub(delay: true)
  let cases = ChatUseCases(
    repository: TestRepository(), model: TestModel(), voiceTranscriber: speech)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  let processing = Task {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  try await waitForSpeech(speech)
  processing.cancel()
  await #expect(throws: CancellationError.self) { try await processing.value }
  let state = await cases.state()
  #expect(state.conversations.first?.pendingVoice?.recordingID == job.recordingID)
  #expect(state.conversations.first?.pendingVoice?.status == .interrupted)
  #expect(state.conversations.first?.messages.isEmpty == true)
}

@Test @MainActor func voiceViewModelPreservesBothDraftsAndDoesNotReplayCommittedAudio() async throws
{
  let speech = VoiceStub()
  let model = TestModel()
  let vm = ChatViewModel(
    useCases: ChatUseCases(repository: TestRepository(), model: model, voiceTranscriber: speech))
  await vm.load()
  let original = try #require(vm.currentConversation?.id)
  vm.draft = "Unsent followup"
  vm.homeDraft = "Unsent Home"
  let recording = UUID()
  #expect(await vm.prepareVoiceChat(recordingID: recording, durationSeconds: 2))
  #expect(vm.currentConversation?.pendingVoice != nil)
  #expect(vm.homeDraft == "Unsent Home")
  #expect(vm.conversations.first { $0.id == original }?.draft == "Unsent followup")
  await vm.processVoice()
  #expect(vm.currentConversation?.messages.count == 2)
  #expect(!vm.isTranscribing && !vm.isGenerating)
  await vm.startVoiceChat(recordingID: recording, durationSeconds: 2)
  #expect(await speech.calls == 1)
  #expect(await model.requests.count == 1)
  #expect(vm.currentConversation?.messages.count == 2)
}

@Test func oversizedVoiceTranscriptRemainsExpandableWithoutPromptTruncation() async throws {
  let text = String(repeating: "word ", count: 7_000)
  let model = TestModel()
  let cases = ChatUseCases(
    repository: TestRepository(), model: model, voiceTranscriber: VoiceStub(text: text))
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  await #expect(throws: ChatError.messageTooLong) {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  #expect(await cases.state().conversations.first?.pendingVoice?.transcript?.text == text)
  #expect(await model.requests.isEmpty)
}

@Test @MainActor func voiceTimingDoesNotReuseEarlierTypedReplyMeasurements() async throws {
  let model = TestModel(.slow)
  let speech = VoiceStub(delay: true)
  let vm = ChatViewModel(
    useCases: ChatUseCases(repository: TestRepository(), model: model, voiceTranscriber: speech))
  await vm.load()
  vm.draft = "A fictional typed request"
  let typed = Task { await vm.send() }
  for _ in 0..<200 where vm.firstUsableTextSeconds == nil {
    try await Task.sleep(for: .milliseconds(5))
  }
  vm.stop()
  await typed.value
  #expect(vm.firstUsableTextSeconds != nil)
  #expect(vm.lastCancellationSeconds != nil)

  #expect(await vm.prepareVoiceChat(recordingID: UUID(), durationSeconds: 2))
  let voice = Task { await vm.processVoice() }
  try await waitForSpeech(speech)
  #expect(vm.firstUsableTextSeconds == nil)
  #expect(vm.lastCancellationSeconds == nil)
  for _ in 0..<200 where !vm.isGenerating || vm.firstUsableTextSeconds == nil {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(vm.isGenerating)
  #expect(vm.firstUsableTextSeconds != nil)
  vm.stop()
  await voice.value
  #expect(vm.lastCancellationSeconds != nil)
  #expect(vm.currentConversation?.messages.last?.status == .stopped)
}

private actor VoiceOrder {
  var events: [String] = []
  func record(_ event: String) { events.append(event) }
}
private struct OrderedModel: ChatModel {
  let order: VoiceOrder
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    await order.record("reply")
    onText("A fictional reply")
  }
  func unload() async { await order.record("unload") }
}
private struct OrderedVoice: VoiceTranscribing {
  let order: VoiceOrder
  func transcribe(recordingID: UUID) async throws -> VoiceTranscript {
    await order.record("speech")
    return VoiceTranscript(
      id: UUID(), recordingID: recordingID, passageIDs: [], text: "A fictional question")
  }
}

@Test func voicePipelineUnloadsTextWeightsBeforeSpeechThenGenerates() async throws {
  let order = VoiceOrder()
  let cases = ChatUseCases(
    repository: TestRepository(), model: OrderedModel(order: order),
    voiceTranscriber: OrderedVoice(order: order))
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  _ = try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  #expect(await order.events == ["unload", "speech", "reply"])
}

private actor VoiceFailingRepository: ChatRepository {
  var snapshot = ChatSnapshot()
  var writes = 0
  func load() -> ChatSnapshot { snapshot }
  func save(_ value: ChatSnapshot) throws {
    writes += 1
    // load, begin, transcribing, retained transcript, atomic pair commit.
    if writes == 5 { throw ChatError.storage }
    snapshot = value
  }
}

@Test func voicePairSaveFailureRetainsTranscriptAndRetryDoesNotRepeatSpeech() async throws {
  let speech = VoiceStub()
  let repository = VoiceFailingRepository()
  let model = TestModel()
  let cases = ChatUseCases(repository: repository, model: model, voiceTranscriber: speech)
  _ = try await cases.load()
  let begun = try await cases.beginVoice(recordingID: UUID(), durationSeconds: 2)
  let c = try #require(begun.conversations.first)
  let job = try #require(c.pendingVoice)
  await #expect(throws: ChatError.storage) {
    try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  }
  let retained = await cases.state()
  #expect(retained.conversations.first?.messages.isEmpty == true)
  #expect(
    retained.conversations.first?.pendingVoice?.transcript?.text == "My fictional name is Mira.")
  #expect(await model.requests.isEmpty)
  let final = try await cases.processVoice(conversationID: c.id, jobID: job.jobID) { _ in }
  #expect(final.conversations.first?.pendingVoice == nil)
  #expect(final.conversations.first?.messages.count == 2)
  #expect(await speech.calls == 1)
  #expect(await model.requests.count == 1)
}
