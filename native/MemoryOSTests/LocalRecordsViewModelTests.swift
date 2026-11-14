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
    #expect(!model.canSave)
    await model.load()
    model.draft = " \n "
    #expect(!model.canSave)
    model.draft = "  فكرة عن Reading room\n "
    #expect(await model.saveCapture())
    #expect(model.draft.isEmpty)
    #expect(model.records.first?.originalText == "  فكرة عن Reading room\n ")
  }

  @Test func storageFailureKeepsDraftAndReloadCanRecover() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    await model.load()
    model.draft = "Keep this thought"
    await repository.setFailure(true)
    #expect(!(await model.saveCapture()))
    #expect(model.failure)
    #expect(model.draft == "Keep this thought")
    #expect(!model.isBusy)
    await repository.setFailure(false)
    await model.load()
    #expect(await model.saveCapture())
    #expect(model.records.count == 1)
  }

  @Test func pendingSaveRejectsDuplicateAndPreservesNewTyping() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    await model.load()
    await repository.pauseSave()
    model.draft = "First thought"
    let first = Task { await model.saveCapture() }
    while !(await repository.isWaiting()) { await Task.yield() }
    #expect(model.isBusy)
    model.draft = "Next thought"
    #expect(!(await model.saveCapture()))
    await repository.releaseSave()
    #expect(await first.value)
    #expect(model.draft == "Next thought")
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
    model.draft = "Retain current"
    #expect(await model.saveCapture())
    #expect(!(await model.importArchive(from: URL(filePath: "/fictional-backup.json"))))
    #expect(model.failure)
    #expect(model.records.first?.text == "Retain current")
    #expect(!(await model.correct(id: try #require(model.records.first?.id), text: "new")))
    #expect(model.records.first?.originalText == "Retain current")
  }

  @Test func committedCreateIsNotRetriedAfterRefreshFailure() async {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    await model.load()
    await repository.failRereadAfterCreate()
    model.draft = "Commit once"
    #expect(await model.saveCapture())
    #expect(model.draft.isEmpty)
    #expect(model.failure)
    #expect(await repository.createCount == 1)
    await repository.setFailure(false)
    await model.load()
    #expect(model.records.first?.text == "Commit once")
  }

  @Test func equivalentNewDraftBytesSurvivePendingSave() async throws {
    let repository = ControlledRecords()
    let model = LocalRecordsViewModel(useCases: LocalMemoryUseCases(repository: repository))
    await model.load()
    await repository.pauseSave()
    model.draft = "\u{e9}"
    let pending = Task { await model.saveCapture() }
    while !(await repository.isWaiting()) { await Task.yield() }
    model.draft = "e\u{301}"
    await repository.releaseSave()
    #expect(await pending.value)
    #expect(Array(model.draft.utf8) == [101, 204, 129])
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
    model.draft = "Keep my unsaved thought"
    await model.load()
    #expect(model.error == .storageFailure)
    #expect(!model.canSave)
    #expect(model.draft == "Keep my unsaved thought")
    await model.load()
    #expect(model.error == nil)
    #expect(model.canSave)
    #expect(await model.saveCapture())
    #expect(model.records.first?.originalText == "Keep my unsaved thought")
    #expect(await provider.attempts == 2)
  }

  @Test func unavailableStorageDoesNotAllowEphemeralSave() async {
    let model = LocalRecordsViewModel(useCases: nil)
    model.draft = "Unsaved"
    await model.load()
    #expect(!model.canSave)
    #expect(!(await model.saveCapture()))
    #expect(model.failure)
    #expect(model.draft == "Unsaved")
  }
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
