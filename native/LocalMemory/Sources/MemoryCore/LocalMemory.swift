import Foundation

public enum RecordKind: String, Codable, CaseIterable, Sendable {
  case capture, person, project, idea
}

public struct RecordRevision: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let createdAt: Date

  public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
    self.id = id
    self.text = text
    self.createdAt = createdAt
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.text.utf8.elementsEqual(rhs.text.utf8)
      && lhs.createdAt == rhs.createdAt
  }

}

public struct LocalRecord: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let kind: RecordKind
  public let originalText: String
  public let text: String
  public let createdAt: Date
  public let revisions: [RecordRevision]
  public let deletedAt: Date?

  public init(
    id: UUID = UUID(), kind: RecordKind, originalText: String, text: String,
    createdAt: Date = Date(), revisions: [RecordRevision] = [], deletedAt: Date? = nil
  ) {
    self.id = id
    self.kind = kind
    self.originalText = originalText
    self.text = text
    self.createdAt = createdAt
    self.revisions = revisions
    self.deletedAt = deletedAt
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.kind == rhs.kind
      && lhs.originalText.utf8.elementsEqual(rhs.originalText.utf8)
      && lhs.text.utf8.elementsEqual(rhs.text.utf8)
      && lhs.createdAt == rhs.createdAt && lhs.revisions == rhs.revisions
      && lhs.deletedAt == rhs.deletedAt
  }

}

/// Links are undirected. Storage orders endpoint UUID strings to prevent reversed duplicates.
public struct RecordLink: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let fromID: UUID
  public let toID: UUID

  public init(id: UUID = UUID(), fromID: UUID, toID: UUID) {
    self.id = id
    self.fromID = fromID
    self.toID = toID
  }
}

public struct RecordSnapshot: Codable, Equatable, Sendable {
  public let records: [LocalRecord]
  public let links: [RecordLink]

  public init(records: [LocalRecord] = [], links: [RecordLink] = []) {
    self.records = records
    self.links = links
  }
}

public enum LocalMemoryError: Error, Equatable, Sendable {
  case blankText
  case textTooLarge
  case recordNotFound
  case deletedRecord
  case invalidLink
  case archiveTooLarge
  case invalidArchive
  case unsupportedArchiveVersion
  case conflictingRecord
  case unsupportedSchemaVersion
  case storageFailure
  case limitReached
}

public enum LocalMemoryLimits {
  public static let textUTF8Bytes = 100_000
  public static let archiveBytes = 52_428_800
  public static let records = 10_000
  public static let retainedTextUTF8Bytes = 4_194_304
  public static let totalRevisions = 20_000
  public static let revisionsPerRecord = 1_000
  public static let links = 50_000

  public static func validateText(_ text: String) throws {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw LocalMemoryError.blankText
    }
    guard text.utf8.count <= textUTF8Bytes else { throw LocalMemoryError.textTooLarge }
  }
}

public struct RecordArchive: Codable, Equatable, Sendable {
  public static let currentVersion = 1
  public let formatVersion: Int
  public let snapshot: RecordSnapshot

  public init(formatVersion: Int = currentVersion, snapshot: RecordSnapshot) {
    self.formatVersion = formatVersion
    self.snapshot = snapshot
  }

  public func validate() throws {
    guard formatVersion == Self.currentVersion else {
      throw LocalMemoryError.unsupportedArchiveVersion
    }
    guard snapshot.records.count <= LocalMemoryLimits.records,
      snapshot.links.count <= LocalMemoryLimits.links
    else { throw LocalMemoryError.limitReached }
    let ids = Set(snapshot.records.map(\.id))
    guard ids.count == snapshot.records.count else { throw LocalMemoryError.invalidArchive }
    var revisionIDs = Set<UUID>()
    var retainedTextBytes = 0
    var totalRevisions = 0
    for record in snapshot.records {
      try LocalMemoryLimits.validateText(record.originalText)
      try LocalMemoryLimits.validateText(record.text)
      retainedTextBytes += record.originalText.utf8.count
      totalRevisions += record.revisions.count
      guard retainedTextBytes <= LocalMemoryLimits.retainedTextUTF8Bytes,
        totalRevisions <= LocalMemoryLimits.totalRevisions
      else { throw LocalMemoryError.limitReached }
      guard record.createdAt.timeIntervalSince1970.isFinite,
        record.deletedAt.map({ $0.timeIntervalSince1970.isFinite && $0 >= record.createdAt })
          ?? true,
        record.revisions.count <= LocalMemoryLimits.revisionsPerRecord,
        record.text.utf8.elementsEqual((record.revisions.last?.text ?? record.originalText).utf8)
      else { throw LocalMemoryError.invalidArchive }
      var previousDate = record.createdAt
      for revision in record.revisions {
        try LocalMemoryLimits.validateText(revision.text)
        retainedTextBytes += revision.text.utf8.count
        guard retainedTextBytes <= LocalMemoryLimits.retainedTextUTF8Bytes else {
          throw LocalMemoryError.limitReached
        }
        guard revisionIDs.insert(revision.id).inserted,
          revision.createdAt.timeIntervalSince1970.isFinite,
          revision.createdAt >= previousDate
        else { throw LocalMemoryError.invalidArchive }
        previousDate = revision.createdAt
      }
    }
    var linkIDs = Set<UUID>()
    var pairs = Set<String>()
    for link in snapshot.links {
      let pair = [link.fromID.uuidString, link.toID.uuidString].sorted().joined(separator: ":")
      guard linkIDs.insert(link.id).inserted, pairs.insert(pair).inserted,
        link.fromID != link.toID, ids.contains(link.fromID), ids.contains(link.toID)
      else { throw LocalMemoryError.invalidArchive }
    }
  }

  public func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    guard data.count <= LocalMemoryLimits.archiveBytes else {
      throw LocalMemoryError.archiveTooLarge
    }
    return data
  }

  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= LocalMemoryLimits.archiveBytes else {
      throw LocalMemoryError.archiveTooLarge
    }
    let result: Self
    do { result = try JSONDecoder().decode(Self.self, from: data) } catch {
      throw LocalMemoryError.invalidArchive
    }
    try result.validate()
    return result
  }
}

public protocol RecordRepository: Sendable {
  func snapshot() async throws -> RecordSnapshot
  func create(kind: RecordKind, text: String) async throws -> LocalRecord
  func correct(id: UUID, text: String) async throws
  func setDeleted(id: UUID, deleted: Bool) async throws
  func link(from: UUID, to: UUID) async throws
  func exportArchive() async throws -> Data
  func restoreArchive(_ data: Data) async throws
}

/// Feature coordination calls this app-owned interface; storage stays replaceable.
public struct LocalMemoryUseCases: Sendable {
  private let repository: any RecordRepository

  public init(repository: any RecordRepository) { self.repository = repository }

  public func snapshot() async throws -> RecordSnapshot { try await repository.snapshot() }

  public func create(kind: RecordKind, text: String) async throws -> LocalRecord {
    try LocalMemoryLimits.validateText(text)
    return try await repository.create(kind: kind, text: text)
  }

  public func correct(id: UUID, text: String) async throws {
    try LocalMemoryLimits.validateText(text)
    try await repository.correct(id: id, text: text)
  }

  public func setDeleted(id: UUID, deleted: Bool) async throws {
    try await repository.setDeleted(id: id, deleted: deleted)
  }

  public func link(from: UUID, to: UUID) async throws {
    guard from != to else { throw LocalMemoryError.invalidLink }
    try await repository.link(from: from, to: to)
  }

  public func exportArchive() async throws -> Data { try await repository.exportArchive() }

  public func restoreArchive(_ data: Data) async throws {
    _ = try RecordArchive.decode(data)
    try await repository.restoreArchive(data)
  }
}

/// Pure record rules shared by storage implementations. These do not import a database or UI framework.
public enum LocalRecordRules {
  public static func correction(
    for record: LocalRecord, text: String, at date: Date = Date()
  ) throws -> RecordRevision? {
    try LocalMemoryLimits.validateText(text)
    guard record.deletedAt == nil else { throw LocalMemoryError.deletedRecord }
    guard !record.text.utf8.elementsEqual(text.utf8) else { return nil }
    guard record.revisions.count < LocalMemoryLimits.revisionsPerRecord else {
      throw LocalMemoryError.limitReached
    }
    return RecordRevision(
      text: text, createdAt: max(date, record.revisions.last?.createdAt ?? record.createdAt))
  }

  public static func validateLink(from: LocalRecord, to: LocalRecord) throws {
    guard from.id != to.id else { throw LocalMemoryError.invalidLink }
    guard from.deletedAt == nil, to.deletedAt == nil else { throw LocalMemoryError.deletedRecord }
  }

  public static func deletionDate(
    for record: LocalRecord, deleted: Bool, at date: Date = Date()
  ) -> Date? {
    guard deleted else { return nil }
    return record.deletedAt ?? max(date, record.revisions.last?.createdAt ?? record.createdAt)
  }
}
