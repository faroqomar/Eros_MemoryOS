import CSQLite
import Foundation
import MemoryCore
import MemorySQLite
import Testing

private struct Fixture {
  let directory: URL
  let url: URL
  let repository: SQLiteRecordRepository

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    url = directory.appendingPathComponent("records.sqlite")
    repository = try SQLiteRecordRepository(url: url)
  }

  func remove() { try? FileManager.default.removeItem(at: directory) }
}

private func executeSQL(_ sql: String, at url: URL) throws {
  var database: OpaquePointer?
  guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
    throw LocalMemoryError.storageFailure
  }
  defer { sqlite3_close(database) }
  guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
    throw LocalMemoryError.storageFailure
  }
}

struct LocalMemoryTests {
  @Test(arguments: [
    "  فكرة عن مشروع Reading room\n ", "O'Brien'); DROP TABLE records; -- 🧠\u{0}next",
  ])
  func typedOriginalSurvivesReopeningExactly(text: String) async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = try await fixture.repository.create(kind: .capture, text: text)
    let reopened = try SQLiteRecordRepository(url: fixture.url)
    let snapshot = try await reopened.snapshot()
    #expect(snapshot.records == [record])
    #expect(snapshot.records.first?.originalText == text)
    #expect(snapshot.records.first?.text == text)
  }

  @Test func correctionPreservesOriginalAndEveryRevision() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let useCases = LocalMemoryUseCases(repository: fixture.repository)
    let original = try await useCases.create(kind: .person, text: "  علي Hassan  ")
    try await useCases.correct(id: original.id, text: "علي حسن")
    try await useCases.correct(id: original.id, text: "Ali Hassan / علي حسن")
    try await useCases.correct(id: original.id, text: "Ali Hassan / علي حسن")
    await #expect(throws: LocalMemoryError.blankText) {
      try await useCases.correct(id: original.id, text: "  \n")
    }
    let record = try #require(try await useCases.snapshot().records.first)
    #expect(record.id == original.id)
    #expect(record.originalText == original.originalText)
    #expect(record.text == "Ali Hassan / علي حسن")
    #expect(record.revisions.map(\.text) == ["علي حسن", "Ali Hassan / علي حسن"])
    #expect(Set(record.revisions.map(\.id)).count == 2)
    #expect(record.createdAt == original.createdAt)
  }

  @Test func allKindsHaveStableUndirectedLinksAndTrashRestoresThem() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    var records: [LocalRecord] = []
    for kind in RecordKind.allCases {
      records.append(try await fixture.repository.create(kind: kind, text: kind.rawValue))
    }
    for record in records.dropFirst() {
      try await fixture.repository.link(from: records[0].id, to: record.id)
      try await fixture.repository.link(from: record.id, to: records[0].id)
    }
    let before = try await fixture.repository.snapshot()
    #expect(before.links.count == 3)
    try await fixture.repository.setDeleted(id: records[0].id, deleted: true)
    let trashed = try await fixture.repository.snapshot()
    #expect(trashed.records.first { $0.id == records[0].id }?.deletedAt != nil)
    #expect(trashed.links == before.links)
    await #expect(throws: LocalMemoryError.deletedRecord) {
      try await fixture.repository.correct(id: records[0].id, text: "edit while deleted")
    }
    await #expect(throws: LocalMemoryError.deletedRecord) {
      try await fixture.repository.link(from: records[0].id, to: records[1].id)
    }
    let reopened = try SQLiteRecordRepository(url: fixture.url)
    try await reopened.setDeleted(id: records[0].id, deleted: false)
    #expect(try await reopened.snapshot() == before)
  }

  @Test func missingAndSelfLinksLeaveDatabaseUnchanged() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = try await fixture.repository.create(kind: .idea, text: "A possible idea")
    let before = try await fixture.repository.snapshot()
    await #expect(throws: LocalMemoryError.invalidLink) {
      try await fixture.repository.link(from: record.id, to: record.id)
    }
    await #expect(throws: LocalMemoryError.recordNotFound) {
      try await fixture.repository.link(from: record.id, to: UUID())
    }
    await #expect(throws: LocalMemoryError.recordNotFound) {
      try await fixture.repository.correct(id: UUID(), text: "missing")
    }
    await #expect(throws: LocalMemoryError.recordNotFound) {
      try await fixture.repository.setDeleted(id: UUID(), deleted: true)
    }
    #expect(try await fixture.repository.snapshot() == before)
  }

  @Test func portableBackupRoundTripsOriginalsRevisionsLinksAndTrashIdempotently() async throws {
    let source = try Fixture()
    let target = try Fixture()
    defer {
      source.remove()
      target.remove()
    }
    let capture = try await source.repository.create(kind: .capture, text: "  Original\nأصل  ")
    let project = try await source.repository.create(kind: .project, text: "A future possibility")
    try await source.repository.correct(id: capture.id, text: "Correction / تصحيح")
    try await source.repository.link(from: project.id, to: capture.id)
    try await source.repository.setDeleted(id: capture.id, deleted: true)
    let archive = try await source.repository.exportArchive()
    try await target.repository.restoreArchive(archive)
    let first = try await target.repository.snapshot()
    #expect(first == (try await source.repository.snapshot()))
    try await target.repository.restoreArchive(archive)
    let reopened = try SQLiteRecordRepository(url: target.url)
    #expect(try await reopened.snapshot() == first)
    #expect(try await reopened.exportArchive() == archive)
  }

  @Test func restoreMergesMissingRecordsWithoutReplacingExistingRecords() async throws {
    let source = try Fixture()
    let target = try Fixture()
    defer {
      source.remove()
      target.remove()
    }
    let sourceRecord = try await source.repository.create(kind: .capture, text: "incoming")
    let targetRecord = try await target.repository.create(kind: .capture, text: "keep me")
    try await target.repository.restoreArchive(source.repository.exportArchive())
    #expect(
      Set(try await target.repository.snapshot().records.map(\.id)) == [
        sourceRecord.id, targetRecord.id,
      ])
  }

  @Test func differingExistingRecordRejectsEntireRestoreAndDoesNotResurrectTrash() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let old = try await fixture.repository.create(kind: .capture, text: "Original")
    let archiveBeforeDelete = try await fixture.repository.exportArchive()
    try await fixture.repository.setDeleted(id: old.id, deleted: true)
    let before = try await fixture.repository.snapshot()
    await #expect(throws: LocalMemoryError.conflictingRecord) {
      try await fixture.repository.restoreArchive(archiveBeforeDelete)
    }
    let incoming = LocalRecord(kind: .idea, originalText: "new", text: "new")
    let archive = try RecordArchive(snapshot: RecordSnapshot(records: [incoming, old])).encoded()
    await #expect(throws: LocalMemoryError.conflictingRecord) {
      try await fixture.repository.restoreArchive(archive)
    }
    #expect(try await fixture.repository.snapshot() == before)
  }

  @Test func writeFailureRollsBackEarlierRecordsFromSameRestore() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    _ = try await fixture.repository.create(kind: .capture, text: "Existing")
    let before = try await fixture.repository.snapshot()
    let first = LocalRecord(kind: .capture, originalText: "first", text: "first")
    let second = LocalRecord(kind: .person, originalText: "second", text: "second")
    try executeSQL(
      """
      CREATE TRIGGER reject_incoming BEFORE INSERT ON records
      WHEN NEW.id = '\(second.id.uuidString)'
      BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END;
      """, at: fixture.url)
    let archive = try RecordArchive(snapshot: RecordSnapshot(records: [first, second])).encoded()
    await #expect(throws: LocalMemoryError.storageFailure) {
      try await fixture.repository.restoreArchive(archive)
    }
    #expect(try await fixture.repository.snapshot() == before)
  }

  @Test func invalidAndFutureArchivesLeaveExistingDataUnchanged() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = try await fixture.repository.create(kind: .capture, text: "Keep original")
    let before = try await fixture.repository.snapshot()
    let encoder = JSONEncoder()
    let duplicate = RecordArchive(snapshot: RecordSnapshot(records: [record, record]))
    let dangling = RecordArchive(
      snapshot: RecordSnapshot(
        records: [record], links: [RecordLink(fromID: record.id, toID: UUID())]))
    let mismatch = LocalRecord(
      id: UUID(), kind: .idea, originalText: "source", text: "untracked edit")
    for invalid in [
      duplicate, dangling, RecordArchive(snapshot: RecordSnapshot(records: [mismatch])),
    ] {
      let data = try encoder.encode(invalid)
      await #expect(throws: LocalMemoryError.invalidArchive) {
        try await fixture.repository.restoreArchive(data)
      }
    }
    await #expect(throws: LocalMemoryError.invalidArchive) {
      try await fixture.repository.restoreArchive(Data("not JSON".utf8))
    }
    let future = try encoder.encode(RecordArchive(formatVersion: 2, snapshot: before))
    await #expect(throws: LocalMemoryError.unsupportedArchiveVersion) {
      try await fixture.repository.restoreArchive(future)
    }
    #expect(try await fixture.repository.snapshot() == before)
  }

  @Test func textLimitsAndBlankValidationDoNotCreateRecords() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let useCases = LocalMemoryUseCases(repository: fixture.repository)
    await #expect(throws: LocalMemoryError.blankText) {
      try await useCases.create(kind: .capture, text: " \n \t")
    }
    await #expect(throws: LocalMemoryError.textTooLarge) {
      try await useCases.create(kind: .capture, text: String(repeating: "ع", count: 50_001))
    }
    await #expect(throws: LocalMemoryError.archiveTooLarge) {
      try await useCases.restoreArchive(Data(count: LocalMemoryLimits.archiveBytes + 1))
    }
    #expect(try await fixture.repository.snapshot().records.isEmpty)
    _ = try await useCases.create(kind: .capture, text: String(repeating: "ع", count: 50_000))
    #expect(try await fixture.repository.snapshot().records.count == 1)
  }

  @Test func schemaUpgradeRefusesNewerVersionWithoutResettingData() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = try await fixture.repository.create(kind: .capture, text: "Do not reset")
    try executeSQL("PRAGMA user_version = 2", at: fixture.url)
    #expect(throws: LocalMemoryError.unsupportedSchemaVersion) {
      try SQLiteRecordRepository(url: fixture.url)
    }
    await #expect(throws: LocalMemoryError.unsupportedSchemaVersion) {
      try await fixture.repository.snapshot()
    }
    try executeSQL("PRAGMA user_version = 1", at: fixture.url)
    #expect(try await fixture.repository.snapshot().records == [record])
  }

  @Test func unversionedForeignDatabaseAndUnavailableDirectoryRemainUntouched() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let foreign = fixture.directory.appendingPathComponent("foreign.sqlite")
    try executeSQL(
      "CREATE TABLE unrelated (value TEXT); INSERT INTO unrelated VALUES ('keep')", at: foreign)
    #expect(throws: LocalMemoryError.unsupportedSchemaVersion) {
      try SQLiteRecordRepository(url: foreign)
    }
    // A second raw access proves no replacement/reset occurred.
    try executeSQL("UPDATE unrelated SET value = 'still present'", at: foreign)
    let missing = fixture.directory.appendingPathComponent("missing/sub/records.sqlite")
    #expect(throws: LocalMemoryError.storageFailure) { try SQLiteRecordRepository(url: missing) }
  }

  @Test func concurrentCapturesDoNotLoseWrites() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<32 {
        group.addTask {
          _ = try await fixture.repository.create(kind: .capture, text: "Thought \(index)")
        }
      }
      try await group.waitForAll()
    }
    let snapshot = try await fixture.repository.snapshot()
    #expect(snapshot.records.count == 32)
    #expect(Set(snapshot.records.map(\.id)).count == 32)
    #expect(Set(snapshot.records.map(\.originalText)).count == 32)
  }
}

struct CapacityTests {
  @Test func aggregateTextLimitRejectsCreateCorrectionAndMergedRestoreWithoutChangingRecords()
    async throws
  {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let fullText = String(repeating: "x", count: LocalMemoryLimits.textUTF8Bytes)
    let remainder = LocalMemoryLimits.retainedTextUTF8Bytes % LocalMemoryLimits.textUTF8Bytes
    var records = (0..<(LocalMemoryLimits.retainedTextUTF8Bytes / LocalMemoryLimits.textUTF8Bytes))
      .map { _ in
        LocalRecord(kind: .capture, originalText: fullText, text: fullText)
      }
    records.append(
      LocalRecord(
        kind: .capture, originalText: String(repeating: "y", count: remainder),
        text: String(repeating: "y", count: remainder)))
    let fullArchive = try RecordArchive(snapshot: RecordSnapshot(records: records)).encoded()
    try await fixture.repository.restoreArchive(fullArchive)
    let before = try await fixture.repository.snapshot()
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.create(kind: .capture, text: "one byte too many")
    }
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.correct(
        id: records[0].id, text: "correction also consumes retained space")
    }
    let incoming = LocalRecord(kind: .idea, originalText: "new", text: "new")
    let incomingArchive = try RecordArchive(snapshot: RecordSnapshot(records: [incoming])).encoded()
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.restoreArchive(incomingArchive)
    }
    #expect(try await fixture.repository.snapshot() == before)
    #expect(throws: LocalMemoryError.limitReached) {
      try RecordArchive(snapshot: RecordSnapshot(records: records + [incoming])).validate()
    }
  }

  @Test func aggregateCorrectionCountRejectsNewHistoryAndCombinedRestore() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let date = Date(timeIntervalSinceReferenceDate: 1)
    var records: [LocalRecord] = []
    for _ in 0..<(LocalMemoryLimits.totalRevisions / LocalMemoryLimits.revisionsPerRecord) {
      let revisions = (0..<LocalMemoryLimits.revisionsPerRecord).map { _ in
        RecordRevision(text: "corrected", createdAt: date)
      }
      records.append(
        LocalRecord(
          kind: .capture, originalText: "source", text: "corrected", createdAt: date,
          revisions: revisions))
    }
    let editable = LocalRecord(
      kind: .capture, originalText: "editable", text: "editable", createdAt: date)
    records.append(editable)
    let archive = try RecordArchive(snapshot: RecordSnapshot(records: records)).encoded()
    try await fixture.repository.restoreArchive(archive)
    let before = try await fixture.repository.snapshot()
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.correct(id: editable.id, text: "one correction too many")
    }
    let incoming = LocalRecord(
      kind: .idea, originalText: "source", text: "new correction", createdAt: date,
      revisions: [RecordRevision(text: "new correction", createdAt: date)])
    let incomingArchive = try RecordArchive(snapshot: RecordSnapshot(records: [incoming])).encoded()
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.restoreArchive(incomingArchive)
    }
    #expect(try await fixture.repository.snapshot() == before)
    #expect(throws: LocalMemoryError.limitReached) {
      try RecordArchive(snapshot: RecordSnapshot(records: records + [incoming])).validate()
    }
  }

  @Test func oversizedExternalTextFailsSqlPreflightBeforeTextDecoding() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = try await fixture.repository.create(kind: .capture, text: "small")
    // Embedded NUL bytes make SQLite text length zero. The byte limit must count the BLOB length.
    try executeSQL(
      "UPDATE records SET original_text = CAST(zeroblob(\(LocalMemoryLimits.retainedTextUTF8Bytes + 1)) AS TEXT) WHERE id = '\(record.id.uuidString)'",
      at: fixture.url)
    await #expect(throws: LocalMemoryError.limitReached) { try await fixture.repository.snapshot() }
    await #expect(throws: LocalMemoryError.limitReached) {
      try await fixture.repository.exportArchive()
    }
    #expect(throws: LocalMemoryError.limitReached) { try SQLiteRecordRepository(url: fixture.url) }
  }

  @Test func oversizedExternalCorrectionCountFailsBeforeRevisionDecoding() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    try executeSQL(
      """
      WITH RECURSIVE numbers(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM numbers WHERE n < 20)
      INSERT INTO records(id,kind,original_text,created_at)
      SELECT printf('10000000-0000-0000-0000-%012d', n), 'capture', 'source', 1 FROM numbers;
      WITH RECURSIVE numbers(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM numbers WHERE n < \(LocalMemoryLimits.totalRevisions))
      INSERT INTO revisions(id,record_id,sequence,text,created_at)
      SELECT printf('20000000-0000-0000-0000-%012d', n),
        printf('10000000-0000-0000-0000-%012d', n / 1000), n % 1000, 'x', 1 FROM numbers;
      """, at: fixture.url)
    await #expect(throws: LocalMemoryError.limitReached) { try await fixture.repository.snapshot() }
    #expect(throws: LocalMemoryError.limitReached) { try SQLiteRecordRepository(url: fixture.url) }
  }
}

private actor StubArchiveReader: ArchiveDataReader {
  let result: Result<Data, LocalMemoryError>
  var receivedURLs: [URL] = []

  init(result: Result<Data, LocalMemoryError>) { self.result = result }

  func readArchive(at url: URL) throws -> Data {
    receivedURLs.append(url)
    return try result.get()
  }
}

struct RestoreFileTests {
  @Test func injectedFileReaderRestoresThroughUseCasesAndPropagatesReadFailure() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let record = LocalRecord(kind: .capture, originalText: "portable", text: "portable")
    let data = try RecordArchive(snapshot: RecordSnapshot(records: [record])).encoded()
    let reader = StubArchiveReader(result: .success(data))
    let url = URL(fileURLWithPath: "/fictional/backup.json")
    let useCases = LocalMemoryUseCases(repository: fixture.repository)
    try await RestoreArchiveFromFile(useCases: useCases, reader: reader).execute(url)
    #expect(await reader.receivedURLs == [url])
    let before = try await fixture.repository.snapshot()
    #expect(before.records == [record])
    let failingReader = StubArchiveReader(result: .failure(.storageFailure))
    await #expect(throws: LocalMemoryError.storageFailure) {
      try await RestoreArchiveFromFile(useCases: useCases, reader: failingReader).execute(url)
    }
    #expect(try await fixture.repository.snapshot() == before)
  }
}

struct ExactTextTests {
  @Test(arguments: ["caf\u{e9}", "\u{623}"])
  func canonicallyEquivalentCorrectionKeepsDistinctBytesAndHistory(composed: String) async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let decomposed = composed.decomposedStringWithCanonicalMapping
    let original = try await fixture.repository.create(kind: .capture, text: composed)
    try await fixture.repository.correct(id: original.id, text: decomposed)
    let reopened = try SQLiteRecordRepository(url: fixture.url)
    let record = try #require(try await reopened.snapshot().records.first)
    #expect(Array(record.originalText.utf8) == Array(composed.utf8))
    #expect(Array(record.text.utf8) == Array(decomposed.utf8))
    #expect(record.revisions.count == 1)
    #expect(Array(try #require(record.revisions.first).text.utf8) == Array(decomposed.utf8))
    try await reopened.correct(id: original.id, text: decomposed)
    #expect(try await reopened.snapshot().records.first?.revisions.count == 1)
  }

  @Test func archiveRejectsEquivalentTextWithDifferentSourceBytes() throws {
    let invalid = LocalRecord(kind: .capture, originalText: "\u{e9}", text: "e\u{301}")
    #expect(throws: LocalMemoryError.invalidArchive) {
      try RecordArchive(snapshot: RecordSnapshot(records: [invalid])).validate()
    }
  }

  @Test func restoreRejectsSameIDWithEquivalentButDifferentOriginalBytes() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let original = try await fixture.repository.create(kind: .capture, text: "\u{e9}")
    let replacement = LocalRecord(
      id: original.id, kind: original.kind,
      originalText: "e\u{301}", text: "e\u{301}", createdAt: original.createdAt)
    let archive = try RecordArchive(snapshot: RecordSnapshot(records: [replacement])).encoded()
    await #expect(throws: LocalMemoryError.conflictingRecord) {
      try await fixture.repository.restoreArchive(archive)
    }
    let stored = try #require(try await fixture.repository.snapshot().records.first)
    #expect(Array(stored.originalText.utf8) == Array(original.originalText.utf8))
  }
}
