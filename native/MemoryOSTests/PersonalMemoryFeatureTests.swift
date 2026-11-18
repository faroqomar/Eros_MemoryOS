import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor FeatureMemoryRepository: PersonalMemoryRepository {
  var value = PersonalMemorySnapshot()
  var fail = false
  func setFailure(_ flag: Bool) { fail = flag }
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) throws {
    if fail { throw PersonalMemoryError.storage }
    try snapshot.validate()
    value = snapshot
  }
}

private struct NoImageReader: PersonalImageReading {
  func readImage(at url: URL) async throws -> Data { throw PersonalImageError.invalidImage }
}

private actor GreetingChatRepository: ChatRepository {
  var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ snapshot: ChatSnapshot) { value = snapshot }
}

private actor GreetingChatModel: ChatModel {
  var requests: [[ChatTurn]] = []
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    requests.append(turns)
    onText("A normal model reply")
  }
  func unload() {}
}

private actor FeatureMemoryAnalyzer: PersonalMemoryAnalyzing {
  let result: PersonalMemoryAnalysis
  private(set) var inputs: [PersonalMemoryAnalysisInput] = []

  init(result: PersonalMemoryAnalysis = PersonalMemoryAnalysis()) { self.result = result }

  func analyze(_ input: PersonalMemoryAnalysisInput) -> PersonalMemoryAnalysis {
    inputs.append(input)
    return result
  }
}

private actor UnqualifiedModelSpy: StructuredChatModel {
  private(set) var calls = 0
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    calls += 1
    return #"{"memories":[],"clarification":null}"#
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) { calls += 1 }
  func unload() {}
}

private func processedSource(
  _ sourceID: UUID,
  updates: inout AsyncStream<PersonalMemoryProcessingUpdate>.Iterator
) async throws -> PersonalMemorySnapshot {
  while let update = await updates.next() {
    if update.snapshot.sources.first(where: { $0.id == sourceID })?.analysis?.status == .processed {
      return update.snapshot
    }
  }
  throw CancellationError()
}

@MainActor struct PersonalMemoryFeatureTests {
  @Test(.timeLimit(.minutes(1)), arguments: [false, true])
  func productionCompositionDoesNotAnalyzeHistoryWithAnUnqualifiedModel(deferred: Bool) async throws
  {
    let useCases = PersonalMemoryUseCases(repository: FeatureMemoryRepository())
    let conversationID = UUID()
    let source = PersonalMemorySource(
      conversationID: conversationID, text: "I prefer quiet mornings")
    _ = try await useCases.ingest(source: source)
    if deferred { _ = try await useCases.deferAnalysis(sourceID: source.id) }
    let before = try await useCases.snapshot()
    let model = UnqualifiedModelSpy()
    let organizer = PersonalMemoryComposition.makeOrganizer(useCases, model: model)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await PersonalChatRecorder(useCases: useCases, organizer: organizer).didFinish(
      conversationID: conversationID)
    while let update = await updates.next() {
      if !update.isRunning { break }
    }
    #expect(try await useCases.snapshot() == before)
    #expect(await model.calls == 0)
    #expect(!PersonalMemoryComposition.automaticMemoryQualified)
    let viewModel = PersonalMemoryComposition.makeViewModel(useCases, organizer: organizer)
    #expect(viewModel.automaticMemoryUnavailable)
    await viewModel.load()
    await viewModel.retryOrganization()
    #expect(try await useCases.snapshot() == before)
    await organizer.pause()
  }

  @Test(.timeLimit(.minutes(1)), arguments: ["Hi", "هلا", "Could you explain Swift?"])
  func conversationalMessageReachesModelThroughRealRecorder(text: String) async throws {
    let personal = PersonalMemoryUseCases(repository: FeatureMemoryRepository())
    let analyzer = FeatureMemoryAnalyzer()
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: personal, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    let model = GreetingChatModel()
    let chat = ChatUseCases(
      repository: GreetingChatRepository(), model: model,
      recorder: PersonalChatRecorder(useCases: personal, organizer: organizer))
    _ = try await chat.load()
    let reply = try await chat.generate(submittedText: text) { _ in }
    #expect(reply.conversations.first?.messages.last?.text == "A normal model reply")
    #expect(await model.requests.count == 1)
    let source = try #require(try await personal.snapshot().sources.first)
    let state = try await processedSource(source.id, updates: &updates)
    #expect(state.sources.first?.text == text)
    #expect(state.entries.isEmpty)
    #expect(state.pendingSources.isEmpty)
    #expect(state.analysisPendingSources.isEmpty)
    #expect(await analyzer.inputs.map(\.source.id) == [source.id])
    await organizer.pause()
  }

  @Test(.timeLimit(.minutes(1)))
  func personalStatementGetsNormalChatReplyThenSourceBackedMemory() async throws {
    let text = "Quiet mornings help me think"
    let personal = PersonalMemoryUseCases(repository: FeatureMemoryRepository())
    let analyzer = FeatureMemoryAnalyzer(
      result: PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(quote: text, kind: .preference, subjectKind: .selfProfile)
      ]))
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: personal, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    let model = GreetingChatModel()
    let chat = ChatUseCases(
      repository: GreetingChatRepository(), model: model,
      recorder: PersonalChatRecorder(useCases: personal, organizer: organizer))
    _ = try await chat.load()
    let reply = try await chat.generate(submittedText: text) { _ in }
    let conversation = try #require(reply.conversations.first)
    let message = try #require(conversation.messages.first)
    #expect(conversation.messages.last?.text == "A normal model reply")
    #expect(await model.requests.count == 1)
    let result = try await processedSource(message.id, updates: &updates)
    let memory = try #require(result.currentEntries.first { $0.kind == .preference })
    #expect(memory.text == text)
    #expect(memory.confirmed == false)
    #expect(memory.profileIDs == [result.selfProfileID])
    #expect(memory.evidence == [PersonalMemoryEvidence(sourceID: message.id, quote: text)])
    #expect(result.pendingSources.isEmpty)
    #expect(result.sources.first?.conversationID == conversation.id)
    await organizer.pause()
  }

  @Test func temporaryChatUsesTheModelWithoutCreatingPersonalSourcesOrJobs() async throws {
    let personal = PersonalMemoryUseCases(repository: FeatureMemoryRepository())
    let before = try await personal.snapshot()
    let analyzer = FeatureMemoryAnalyzer()
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: personal, analyzer: analyzer, quietDelay: .zero)
    let repository = GreetingChatRepository()
    let model = GreetingChatModel()
    let chat = ChatUseCases(
      repository: repository, model: model,
      recorder: PersonalChatRecorder(useCases: personal, organizer: organizer))
    _ = try await chat.load()
    _ = try await chat.startTemporary()
    let reply = try await chat.generate(submittedText: "I am considering a private move") { _ in }
    #expect(reply.conversations.contains { $0.isTemporary })
    #expect(await model.requests.count == 1)
    #expect(try await personal.snapshot() == before)
    #expect(await analyzer.inputs.isEmpty)
    #expect(await repository.value.conversations.allSatisfy { !$0.isTemporary })
    _ = try await chat.endTemporary()
    #expect(try await personal.snapshot() == before)
    #expect(await analyzer.inputs.isEmpty)
    #expect(await chat.state().conversations.allSatisfy { !$0.isTemporary })
    await organizer.pause()
  }

  @Test func profileAnswerAndUndoRetainOriginalWithoutDerivedEntry() async throws {
    let repository = FeatureMemoryRepository()
    let useCases = PersonalMemoryUseCases(repository: repository)
    let model = PersonalMemoryViewModel(
      useCases: useCases, imageImport: ImportPersonalImage(reader: NoImageReader()))
    await model.load()
    #expect(
      await model.addReport(
        text: "Quiet mornings", kind: .preference, profileID: model.snapshot.selfProfileID,
        question: "Which preference matters?"))
    #expect(model.snapshot.entries.count == 1)
    #expect(model.snapshot.entries.first?.text == "Quiet mornings")
    #expect(model.snapshot.entries.first?.profileIDs == [model.snapshot.selfProfileID])
    await model.undo()
    #expect(model.snapshot.entries.isEmpty)
    #expect(model.snapshot.sources.first?.text == "Which preference matters?\nQuiet mornings")
  }

  @Test func recorderQueuesOriginalWithoutGenericClarificationThenExplicitResolution() async throws
  {
    let repository = FeatureMemoryRepository()
    let useCases = PersonalMemoryUseCases(repository: repository)
    let recorder = PersonalChatRecorder(useCases: useCases)
    let source = UUID()
    try await recorder.preserve(
      conversationID: UUID(), messageID: source,
      text: "Maybe Cedar should close", createdAt: Date())
    let before = try await useCases.snapshot()
    #expect(before.entries.isEmpty)
    #expect(before.pendingSources.isEmpty)
    #expect(before.analysisPendingSources.map(\.id) == [source])
    let resolved = try await useCases.resolve(sourceID: source, kind: .idea)
    #expect(resolved.entries.first?.kind == .idea)
    #expect(resolved.sources.first?.text == "Maybe Cedar should close")
  }

  @Test func confirmedCorrectionFailureDoesNotChangeVisibleState() async throws {
    let repository = FeatureMemoryRepository()
    let useCases = PersonalMemoryUseCases(repository: repository)
    let model = PersonalMemoryViewModel(
      useCases: useCases, imageImport: ImportPersonalImage(reader: NoImageReader()))
    await model.load()
    #expect(await model.addReport(text: "Mira's date is May 12", kind: .fact, profileID: nil))
    let entry = try #require(model.snapshot.entries.first)
    #expect(entry.confirmed)
    #expect(!(await model.correct(entry.id, text: "May 13", confirmedChange: false)))
    #expect(model.snapshot.entries.first?.text == "Mira's date is May 12")
    await repository.setFailure(true)
    #expect(!(await model.correct(entry.id, text: "May 13", confirmedChange: true)))
    await repository.setFailure(false)
    #expect(await model.correct(entry.id, text: "May 13", confirmedChange: true))
    #expect(model.snapshot.entries.first?.text == "May 13")
    #expect(model.snapshot.sources.first?.text.contains("May 12") == true)
  }

  @Test func importedPhotoFailureKeepsProfileAndReportsRecoverableError() async throws {
    let useCases = PersonalMemoryUseCases(repository: FeatureMemoryRepository())
    let model = PersonalMemoryViewModel(
      useCases: useCases, imageImport: ImportPersonalImage(reader: NoImageReader()))
    await model.load()
    #expect(
      !(await model.photo(
        profile: model.snapshot.selfProfileID, url: URL(filePath: "/missing.jpg"), origin: .imported
      )))
    #expect(model.failure == .invalidImage)
    #expect(model.snapshot.photos.isEmpty)
    #expect(model.snapshot.sources.isEmpty)
  }
}

extension PersonalMemoryFeatureTests {
  @Test func imageAdapterKeepsOriginalBytesAndRejectsCorruptOrOversizedFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = try #require(
      Data(
        base64Encoded:
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      ))
    let url = directory.appending(path: "fictional.png")
    try image.write(to: url)
    let reader = PersonalImageReader()
    #expect(try await reader.readImage(at: url) == image)
    try Data("not an image".utf8).write(to: url)
    await #expect(throws: PersonalImageError.invalidImage) { try await reader.readImage(at: url) }
    try Data(count: 2 * 1024 * 1024 + 1).write(to: url)
    await #expect(throws: PersonalImageError.tooLarge) { try await reader.readImage(at: url) }
  }

  @Test func promptMeaningDoesNotDependOnDisplayLanguage() {
    #expect(PersonalProfileQuestion.communication.kind == .interpretation)
    #expect(PersonalProfileQuestion.priority.kind == .goal)
    #expect(PersonalProfileQuestion.preference.kind == .preference)
    #expect(PersonalProfileQuestion.relationship.kind == .fact)
  }
}

extension PersonalMemoryFeatureTests {
  @Test func fileFailuresKeepExportForRetryAndCancellationIsNeutral() async throws {
    let model = PersonalMemoryViewModel(
      useCases: PersonalMemoryUseCases(repository: FeatureMemoryRepository()),
      imageImport: ImportPersonalImage(reader: NoImageReader()))
    await model.load()
    #expect(await model.exportArchive())
    let archive = try #require(model.exportedArchive)
    model.finishExport(.failure(CocoaError(.fileWriteOutOfSpace)))
    #expect(model.failure == .storage)
    #expect(model.exportedArchive == archive)
    model.dismissFailure()
    model.fileOperationFailed(CocoaError(.userCancelled))
    #expect(model.failure == nil)
    model.fileOperationFailed(CocoaError(.fileReadNoPermission))
    #expect(model.failure == .storage)
    #expect(model.snapshot.sources.isEmpty)
    model.finishExport(.success(URL(filePath: "/fictional-backup.json")))
    #expect(model.exportedArchive == nil)
    #expect(model.failure == nil)
  }
}
