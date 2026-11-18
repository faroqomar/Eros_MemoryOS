import Foundation

/// App-owned current source values. Providers never own the canonical history.
public struct MemorySearchRecord: Equatable, Sendable {
  public let id: String
  public let text: String
  public init(id: String, text: String) {
    self.id = id
    self.text = text
  }
}
public struct MemorySearchHit: Equatable, Sendable {
  public let sourceID: String
  public let score: Double
  public let matchedText: String?
  public init(sourceID: String, score: Double, matchedText: String? = nil) {
    self.sourceID = sourceID
    self.score = score
    self.matchedText = matchedText
  }
}
public protocol MemorySearching: Sendable {
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
}
public protocol RecallIndex: Sendable {
  func rebuild(records: [MemorySearchRecord]) async throws
  func search(query: String, limit: Int) async throws -> [MemorySearchHit]
  func close() async throws
}
public enum RetrievalError: Error, Equatable, Sendable {
  case invalidInput(String)
  case invalidResult(String)
  case unavailable(String)
  case busy
}

/// Files are disposable caches. Exclude them from backup and protect new child files on iOS.
public enum RecallDirectory {
  public static func prepare(_ directory: URL) throws {
    guard directory.isFileURL else {
      throw RetrievalError.invalidInput("Recall requires local directories.")
    }
    #if os(iOS)
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.complete])
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    #else
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    #endif
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var url = directory
    try url.setResourceValues(values)
  }
}
