import CSQLite
import Foundation
import MemoryCore

/// One actor owns operations. Each synchronous operation owns and closes its connection.
/// No SQLite pointer crosses an isolation boundary or survives an await.
public actor SQLiteRecordRepository: RecordRepository {
  private let url: URL

  public init(url: URL) throws {
    guard url.isFileURL else { throw LocalMemoryError.storageFailure }
    self.url = url
    let database = try Database(url: url, allowUninitialized: true)
    try database.prepareSchema()
    try database.validateCapacity()
  }

  public func snapshot() throws -> RecordSnapshot {
    let database = try Database(url: url)
    return try database.transaction(write: false) { try database.snapshot() }
  }

  public func create(kind: RecordKind, text: String) throws -> LocalRecord {
    try LocalMemoryLimits.validateText(text)
    let database = try Database(url: url)
    return try database.transaction {
      guard try database.count("records") < LocalMemoryLimits.records else {
        throw LocalMemoryError.limitReached
      }
      let record = LocalRecord(kind: kind, originalText: text, text: text)
      try database.insert(record)
      try database.validateCapacity()
      return record
    }
  }

  public func correct(id: UUID, text: String) throws {
    try LocalMemoryLimits.validateText(text)
    let database = try Database(url: url)
    try database.transaction {
      let record = try database.record(id)
      guard let revision = try LocalRecordRules.correction(for: record, text: text) else { return }
      try database.insert(revision, recordID: id, sequence: record.revisions.count)
      try database.validateCapacity()
    }
  }

  public func setDeleted(id: UUID, deleted: Bool) throws {
    let database = try Database(url: url)
    try database.transaction {
      let record = try database.record(id)
      let date = LocalRecordRules.deletionDate(for: record, deleted: deleted)
      guard date != record.deletedAt else { return }
      try database.execute(
        "UPDATE records SET deleted_at = ? WHERE id = ?",
        [date.map { .number($0.timeIntervalSinceReferenceDate) } ?? .null, .text(id.uuidString)])
    }
  }

  public func link(from: UUID, to: UUID) throws {
    guard from != to else { throw LocalMemoryError.invalidLink }
    let database = try Database(url: url)
    try database.transaction {
      let first = try database.record(from)
      let second = try database.record(to)
      try LocalRecordRules.validateLink(from: first, to: second)
      let endpoints = [from.uuidString, to.uuidString].sorted()
      let existing = try database.query(
        "SELECT id FROM links WHERE from_id = ? AND to_id = ?",
        endpoints.map(SQLValue.text))
      guard existing.isEmpty else { return }
      guard try database.count("links") < LocalMemoryLimits.links else {
        throw LocalMemoryError.limitReached
      }
      try database.insert(RecordLink(fromID: from, toID: to))
    }
  }

  public func exportArchive() throws -> Data {
    try RecordArchive(snapshot: snapshot()).encoded()
  }

  public func restoreArchive(_ data: Data) throws {
    let archive = try RecordArchive.decode(data)
    let database = try Database(url: url)
    try database.transaction {
      let existing = try database.snapshot()
      let recordsByID = Dictionary(uniqueKeysWithValues: existing.records.map { ($0.id, $0) })
      let linksByID = Dictionary(uniqueKeysWithValues: existing.links.map { ($0.id, $0) })
      let newRecords = archive.snapshot.records.filter { recordsByID[$0.id] == nil }
      let newLinks = archive.snapshot.links.filter { linksByID[$0.id] == nil }
      guard existing.records.count + newRecords.count <= LocalMemoryLimits.records,
        existing.links.count + newLinks.count <= LocalMemoryLimits.links
      else { throw LocalMemoryError.limitReached }
      for record in archive.snapshot.records {
        if let old = recordsByID[record.id] {
          guard old == record else { throw LocalMemoryError.conflictingRecord }
        } else {
          try database.insert(record)
          for (sequence, revision) in record.revisions.enumerated() {
            try database.insert(revision, recordID: record.id, sequence: sequence)
          }
        }
      }
      for link in archive.snapshot.links {
        let endpoints = [link.fromID.uuidString, link.toID.uuidString].sorted()
        if let old = linksByID[link.id] {
          guard Set([old.fromID, old.toID]) == Set([link.fromID, link.toID]) else {
            throw LocalMemoryError.conflictingRecord
          }
        } else {
          let existingPair = try database.query(
            "SELECT id FROM links WHERE from_id = ? AND to_id = ?", endpoints.map(SQLValue.text))
          guard existingPair.isEmpty else { throw LocalMemoryError.conflictingRecord }
          try database.insert(link)
        }
      }
      try database.validateCapacity()
    }
  }
}

private enum SQLValue {
  case text(String)
  case number(Double)
  case null
}

private final class Database {
  private let handle: OpaquePointer

  init(url: URL, allowUninitialized: Bool = false) throws {
    var pointer: OpaquePointer?
    let result = sqlite3_open_v2(
      url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
    guard result == SQLITE_OK, let pointer else {
      if let pointer { sqlite3_close(pointer) }
      throw LocalMemoryError.storageFailure
    }
    handle = pointer
    guard sqlite3_busy_timeout(handle, 2_000) == SQLITE_OK else {
      throw LocalMemoryError.storageFailure
    }
    try execute("PRAGMA foreign_keys = ON")
    try execute("PRAGMA synchronous = FULL")
    let version = try schemaVersion()
    guard version == 1 || (allowUninitialized && version == 0) else {
      throw LocalMemoryError.unsupportedSchemaVersion
    }
  }

  deinit { sqlite3_close(handle) }

  func prepareSchema() throws {
    try transaction {
      let version = try schemaVersion()
      guard version == 0 else { return }
      let tables = try query(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
      guard tables.isEmpty else { throw LocalMemoryError.unsupportedSchemaVersion }
      try execute(
        """
        CREATE TABLE records (
          id TEXT PRIMARY KEY NOT NULL,
          kind TEXT NOT NULL CHECK(kind IN ('capture','person','project','idea')),
          original_text TEXT NOT NULL,
          created_at REAL NOT NULL,
          deleted_at REAL
        )
        """)
      try execute(
        """
        CREATE TABLE revisions (
          id TEXT PRIMARY KEY NOT NULL,
          record_id TEXT NOT NULL REFERENCES records(id),
          sequence INTEGER NOT NULL CHECK(sequence >= 0),
          text TEXT NOT NULL,
          created_at REAL NOT NULL,
          UNIQUE(record_id, sequence)
        )
        """)
      try execute(
        """
        CREATE TABLE links (
          id TEXT PRIMARY KEY NOT NULL,
          from_id TEXT NOT NULL REFERENCES records(id),
          to_id TEXT NOT NULL REFERENCES records(id),
          CHECK(from_id < to_id),
          UNIQUE(from_id, to_id)
        )
        """)
      try execute("CREATE INDEX revisions_record ON revisions(record_id, sequence)")
      try execute("CREATE INDEX links_to ON links(to_id)")
      try execute("PRAGMA user_version = 1")
    }
  }

  func schemaVersion() throws -> Int {
    guard let value = try query("PRAGMA user_version").first?.first,
      case .number(let number) = value
    else { throw LocalMemoryError.storageFailure }
    return Int(number)
  }

  func count(_ table: String) throws -> Int {
    // Callers pass fixed internal table names, never user input.
    guard table == "records" || table == "links",
      let value = try query("SELECT COUNT(*) FROM \(table)").first?.first,
      case .number(let number) = value
    else { throw LocalMemoryError.storageFailure }
    return Int(number)
  }

  func transaction<T>(write: Bool = true, _ body: () throws -> T) throws -> T {
    try execute(write ? "BEGIN IMMEDIATE" : "BEGIN")
    do {
      let value = try body()
      try execute("COMMIT")
      return value
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  /// Check counts and byte sizes inside SQLite before Swift materializes record content.
  /// Deleted records remain in these totals because backups retain their originals and history.
  func validateCapacity() throws {
    let rows = try query(
      """
      SELECT
        (SELECT COUNT(*) FROM records),
        (SELECT COUNT(*) FROM revisions),
        (SELECT COUNT(*) FROM links),
        (SELECT COALESCE(SUM(length(CAST(original_text AS BLOB))), 0) FROM records)
          + (SELECT COALESCE(SUM(length(CAST(text AS BLOB))), 0) FROM revisions),
        (SELECT COALESCE(MAX(revision_count), 0) FROM
          (SELECT COUNT(*) AS revision_count FROM revisions GROUP BY record_id))
      """)
    guard let row = rows.first, row.count == 5 else { throw LocalMemoryError.storageFailure }
    let totals = try row.map { value -> Double in
      guard case .number(let number) = value, number.isFinite, number >= 0 else {
        throw LocalMemoryError.storageFailure
      }
      return number
    }
    guard totals[0] <= Double(LocalMemoryLimits.records),
      totals[1] <= Double(LocalMemoryLimits.totalRevisions),
      totals[2] <= Double(LocalMemoryLimits.links),
      totals[3] <= Double(LocalMemoryLimits.retainedTextUTF8Bytes),
      totals[4] <= Double(LocalMemoryLimits.revisionsPerRecord)
    else { throw LocalMemoryError.limitReached }
  }

  func insert(_ record: LocalRecord) throws {
    try execute(
      "INSERT INTO records(id,kind,original_text,created_at,deleted_at) VALUES(?,?,?,?,?)",
      [
        .text(record.id.uuidString), .text(record.kind.rawValue), .text(record.originalText),
        .number(record.createdAt.timeIntervalSinceReferenceDate),
        record.deletedAt.map { .number($0.timeIntervalSinceReferenceDate) } ?? .null,
      ])
  }

  func insert(_ revision: RecordRevision, recordID: UUID, sequence: Int) throws {
    try execute(
      "INSERT INTO revisions(id,record_id,sequence,text,created_at) VALUES(?,?,?,?,?)",
      [
        .text(revision.id.uuidString), .text(recordID.uuidString), .number(Double(sequence)),
        .text(revision.text), .number(revision.createdAt.timeIntervalSinceReferenceDate),
      ])
  }

  func insert(_ link: RecordLink) throws {
    let endpoints = [link.fromID.uuidString, link.toID.uuidString].sorted()
    try execute(
      "INSERT INTO links(id,from_id,to_id) VALUES(?,?,?)",
      [.text(link.id.uuidString), .text(endpoints[0]), .text(endpoints[1])])
  }

  func record(_ id: UUID) throws -> LocalRecord {
    try validateCapacity()
    let rows = try query(
      "SELECT id,kind,original_text,created_at,deleted_at FROM records WHERE id = ?",
      [.text(id.uuidString)])
    guard let row = rows.first else { throw LocalMemoryError.recordNotFound }
    return try decodeRecord(row)
  }

  func snapshot() throws -> RecordSnapshot {
    try validateCapacity()
    let records = try query(
      "SELECT id,kind,original_text,created_at,deleted_at FROM records ORDER BY created_at DESC,id"
    )
    .map(decodeRecord)
    let links = try query("SELECT id,from_id,to_id FROM links ORDER BY id").map { row in
      RecordLink(id: try uuid(row[0]), fromID: try uuid(row[1]), toID: try uuid(row[2]))
    }
    let snapshot = RecordSnapshot(records: records, links: links)
    try RecordArchive(snapshot: snapshot).validate()
    return snapshot
  }

  private func decodeRecord(_ row: [SQLValue]) throws -> LocalRecord {
    let id = try uuid(row[0])
    guard let kind = RecordKind(rawValue: try string(row[1])) else {
      throw LocalMemoryError.storageFailure
    }
    let originalText = try string(row[2])
    let revisions = try query(
      "SELECT id,text,created_at FROM revisions WHERE record_id = ? ORDER BY sequence",
      [.text(id.uuidString)]
    ).map { revision in
      RecordRevision(
        id: try uuid(revision[0]), text: try string(revision[1]),
        createdAt: try date(revision[2]))
    }
    let deletedAt: Date?
    if case .null = row[4] { deletedAt = nil } else { deletedAt = try date(row[4]) }
    return LocalRecord(
      id: id, kind: kind, originalText: originalText,
      text: revisions.last?.text ?? originalText, createdAt: try date(row[3]),
      revisions: revisions, deletedAt: deletedAt)
  }

  private func string(_ value: SQLValue) throws -> String {
    guard case .text(let text) = value else { throw LocalMemoryError.storageFailure }
    return text
  }

  private func uuid(_ value: SQLValue) throws -> UUID {
    guard let id = UUID(uuidString: try string(value)) else {
      throw LocalMemoryError.storageFailure
    }
    return id
  }

  private func date(_ value: SQLValue) throws -> Date {
    guard case .number(let number) = value, number.isFinite else {
      throw LocalMemoryError.storageFailure
    }
    return Date(timeIntervalSinceReferenceDate: number)
  }

  func execute(_ sql: String, _ bindings: [SQLValue] = []) throws {
    _ = try query(sql, bindings)
  }

  func query(_ sql: String, _ bindings: [SQLValue] = []) throws -> [[SQLValue]] {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw LocalMemoryError.storageFailure
    }
    defer { sqlite3_finalize(statement) }
    for (offset, value) in bindings.enumerated() {
      let index = Int32(offset + 1)
      let result: Int32
      switch value {
      case .text(let text):
        result = text.withCString {
          sqlite3_bind_text(
            statement, index, $0, Int32(text.utf8.count),
            unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
      case .number(let number): result = sqlite3_bind_double(statement, index, number)
      case .null: result = sqlite3_bind_null(statement, index)
      }
      guard result == SQLITE_OK else { throw LocalMemoryError.storageFailure }
    }
    var rows: [[SQLValue]] = []
    while true {
      let step = sqlite3_step(statement)
      if step == SQLITE_DONE { return rows }
      guard step == SQLITE_ROW else { throw LocalMemoryError.storageFailure }
      var row: [SQLValue] = []
      for index in 0..<sqlite3_column_count(statement) {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_NULL: row.append(.null)
        case SQLITE_INTEGER, SQLITE_FLOAT:
          row.append(.number(sqlite3_column_double(statement, index)))
        case SQLITE_TEXT:
          guard let pointer = sqlite3_column_text(statement, index) else {
            throw LocalMemoryError.storageFailure
          }
          let buffer = UnsafeBufferPointer(
            start: pointer, count: Int(sqlite3_column_bytes(statement, index)))
          guard let text = String(bytes: buffer, encoding: .utf8) else {
            throw LocalMemoryError.storageFailure
          }
          row.append(.text(text))
        default: throw LocalMemoryError.storageFailure
        }
      }
      rows.append(row)
    }
  }
}
