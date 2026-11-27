import ChatCore
import ChatPresentation
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor ControlledRecords: RecordRepository {
  var current = RecordSnapshot()
  var shouldFail = false
  var holdSave = false
  var failAfterCreate = false
  var continuation: CheckedContinuation<Void, Never>?
  var createCount = 0

  func setFailure(_ value: Bool) { shouldFail = value }
  func failRereadAfterCreate() { failAfterCreate = true }
  func pauseSave() { holdSave = true }
  func isWaiting() -> Bool { continuation != nil }
  func releaseSave() {
    continuation?.resume()
    continuation = nil
  }
  func snapshot() throws -> RecordSnapshot {
    if shouldFail { throw LocalMemoryError.storageFailure }
    return current
  }
  func create(kind: RecordKind, text: String) async throws -> LocalRecord {
    createCount += 1
    if holdSave { await withCheckedContinuation { continuation = $0 } }
    if shouldFail { throw LocalMemoryError.storageFailure }
    let record = LocalRecord(kind: kind, originalText: text, text: text)
    current = RecordSnapshot(records: current.records + [record], links: current.links)
    if failAfterCreate { shouldFail = true }
    return record
  }
  func correct(id: UUID, text: String) throws { throw LocalMemoryError.storageFailure }
  func setDeleted(id: UUID, deleted: Bool) throws { throw LocalMemoryError.storageFailure }
  func link(from: UUID, to: UUID) throws { throw LocalMemoryError.storageFailure }
  func exportArchive() throws -> Data { try RecordArchive(snapshot: current).encoded() }
  func restoreArchive(_ data: Data) throws { current = try RecordArchive.decode(data).snapshot }
}

@MainActor
struct LocalRecordsViewModelTests {
  @Test func savingPreservesExactTextAndClearsOnlyAfterSuccess() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    let chat = await captureChat()
    #expect(!(await model.create(kind: .capture, text: "Before storage loads")))
    await model.load()
    #expect(!(await model.create(kind: .capture, text: " \n ")))
    #expect(model.error == .blankText)
    chat.homeDraft = "  فكرة عن Reading room\n "
    let submitted = chat.homeDraft
    let saved = await model.create(kind: .capture, text: submitted)
    if saved { chat.clearSavedHomeDraft(submitted) }
    #expect(saved)
    #expect(chat.homeDraft.isEmpty)
    #expect(model.records.first?.originalText.utf8.elementsEqual(submitted.utf8) == true)
  }

  @Test func storageFailureKeepsDraftAndReloadCanRecover() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    let chat = await captureChat()
    await model.load()
    chat.homeDraft = "Keep this thought"
    let submitted = chat.homeDraft
    await repository.setFailure(true)
    let failed = await model.create(kind: .capture, text: submitted)
    if failed { chat.clearSavedHomeDraft(submitted) }
    #expect(!failed)
    #expect(model.failure)
    #expect(chat.homeDraft == submitted)
    #expect(!model.isBusy)
    await repository.setFailure(false)
    await model.load()
    let saved = await model.create(kind: .capture, text: submitted)
    if saved { chat.clearSavedHomeDraft(submitted) }
    #expect(saved)
    #expect(chat.homeDraft.isEmpty)
    #expect(model.records.count == 1)
  }

  @Test func pendingSaveRejectsDuplicateAndPreservesNewTyping() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    let chat = await captureChat()
    await model.load()
    await repository.pauseSave()
    chat.homeDraft = "First thought"
    let submitted = chat.homeDraft
    let first = Task {
      let saved = await model.create(kind: .capture, text: submitted)
      if saved { chat.clearSavedHomeDraft(submitted) }
      return saved
    }
    while !(await repository.isWaiting()) { await Task.yield() }
    #expect(model.isBusy)
    chat.homeDraft = "Next thought"
    #expect(!(await model.create(kind: .capture, text: chat.homeDraft)))
    await repository.releaseSave()
    #expect(await first.value)
    #expect(chat.homeDraft == "Next thought")
    #expect(model.records.first?.text == "First thought")
    #expect(await repository.createCount == 1)
  }

  @Test func unsupportedRestoreKeepsVisibleRecordsAndReportsFailure() async throws {
    let repository = ControlledRecords()
    let useCases = LocalMemoryUseCases(repository: repository)
    let model = LocalRecordsViewModel(
      useCases: useCases,
      archiveRestore: RestoreArchiveFromFile(
        useCases: useCases,
        reader: ControlledArchiveReader(data: Data("not a backup".utf8))))
    await model.load()
    #expect(await model.create(kind: .capture, text: "Retain current"))
    #expect(!(await model.importArchive(from: URL(filePath: "/fictional-backup.json"))))
    #expect(model.failure)
    #expect(model.records.first?.text == "Retain current")
    #expect(!(await model.correct(id: try #require(model.records.first?.id), text: "new")))
    #expect(model.records.first?.originalText == "Retain current")
  }

  @Test func committedCreateIsNotRetriedAfterRefreshFailure() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    let chat = await captureChat()
    await model.load()
    await repository.failRereadAfterCreate()
    chat.homeDraft = "Commit once"
    let submitted = chat.homeDraft
    let saved = await model.create(kind: .capture, text: submitted)
    if saved { chat.clearSavedHomeDraft(submitted) }
    #expect(saved)
    #expect(chat.homeDraft.isEmpty)
    #expect(model.failure)
    #expect(await repository.createCount == 1)
    await repository.setFailure(false)
    await model.load()
    #expect(model.records.first?.text == "Commit once")
  }

  @Test func equivalentNewDraftBytesSurvivePendingSave() async throws {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    let chat = await captureChat()
    await model.load()
    await repository.pauseSave()
    chat.homeDraft = "\u{e9}"
    let submitted = chat.homeDraft
    let pending = Task {
      let saved = await model.create(kind: .capture, text: submitted)
      if saved { chat.clearSavedHomeDraft(submitted) }
      return saved
    }
    while !(await repository.isWaiting()) { await Task.yield() }
    chat.homeDraft = "e\u{301}"
    await repository.releaseSave()
    #expect(await pending.value)
    #expect(Array(chat.homeDraft.utf8) == [101, 204, 129])
    #expect(Array(try #require(model.records.first).originalText.utf8) == [195, 169])
  }

  @Test func transientConnectionFailureRetriesWithoutLosingDraft() async {
    let repository = ControlledRecords()
    let useCases = LocalMemoryUseCases(repository: repository)
    let provider = ControlledSessionProvider(
      session: LocalMemorySession(
        useCases: useCases,
        archiveRestore: RestoreArchiveFromFile(
          useCases: useCases,
          reader: ControlledArchiveReader(data: Data()))))
    let model = LocalRecordsViewModel(provider: provider)
    let chat = await captureChat()
    chat.homeDraft = "Keep my unsaved thought"
    await model.load()
    #expect(model.error == .storageFailure)
    #expect(!model.hasLoaded)
    #expect(chat.homeDraft == "Keep my unsaved thought")
    await model.load()
    #expect(model.error == nil)
    #expect(model.hasLoaded)
    #expect(await model.create(kind: .capture, text: chat.homeDraft))
    #expect(model.records.first?.originalText == "Keep my unsaved thought")
    #expect(await provider.attempts == 2)
  }

  @Test func unavailableStorageDoesNotAllowEphemeralSave() async {
    let model = LocalRecordsViewModel(useCases: nil)
    let chat = await captureChat()
    chat.homeDraft = "Unsaved"
    await model.load()
    #expect(!model.hasLoaded)
    let saved = await model.create(kind: .capture, text: chat.homeDraft)
    if saved { chat.clearSavedHomeDraft("Unsaved") }
    #expect(!saved)
    #expect(model.failure)
    #expect(chat.homeDraft == "Unsaved")
  }

  private func captureChat() async -> ChatViewModel {
    let model = ChatViewModel(
      useCases: ChatUseCases(repository: CaptureChatRepository(), model: CaptureChatModel()))
    await model.load()
    return model
  }
}

private actor CaptureChatRepository: ChatRepository {
  private var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ snapshot: ChatSnapshot) { value = snapshot }
}

private struct CaptureChatModel: ChatModel {
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    throw ChatError.modelUnavailable
  }
  func unload() async {}
}

private struct ControlledArchiveReader: ArchiveDataReader {
  let data: Data
  func readArchive(at url: URL) async throws -> Data { data }
}

private actor ControlledSessionProvider: LocalMemorySessionProvider {
  let session: LocalMemorySession
  private(set) var attempts = 0
  init(session: LocalMemorySession) { self.session = session }
  func open() throws -> LocalMemorySession {
    attempts += 1
    if attempts == 1 { throw LocalMemoryError.storageFailure }
    return session
  }
}
