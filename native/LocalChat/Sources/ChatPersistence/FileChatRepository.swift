import ChatCore
import Foundation

/// One injected instance owns this app-private file. Atomic replacement preserves the last
/// valid archive if a write fails. Lasting-memory records use a separate repository.
public actor FileChatRepository: ChatRepository {
  private let url: URL
  private var newestRevision: UInt64?

  public init(url: URL) { self.url = url }

  public func load() throws -> ChatSnapshot {
    guard url.isFileURL else { throw ChatError.storage }
    guard FileManager.default.fileExists(atPath: url.path) else {
      newestRevision = 0
      return ChatSnapshot()
    }
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= ChatLimits.archiveBytes
      else {
        throw ChatError.invalidArchive
      }
      let data = try Data(contentsOf: url)
      guard data.count <= ChatLimits.archiveBytes else { throw ChatError.invalidArchive }
      let snapshot = try JSONDecoder().decode(ChatSnapshot.self, from: data)
      try snapshot.validateDurable()
      newestRevision = snapshot.revision
      return snapshot
    } catch let error as ChatError { throw error } catch { throw ChatError.storage }
  }

  public func save(_ snapshot: ChatSnapshot) throws {
    guard url.isFileURL else { throw ChatError.storage }
    try snapshot.validateDurable()
    if let newestRevision, snapshot.revision < newestRevision { return }
    do {
      let data = try JSONEncoder().encode(snapshot)
      guard data.count <= ChatLimits.archiveBytes else { throw ChatError.messageTooLong }
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      #if os(iOS)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete],
          ofItemAtPath: directory.path)
      #endif
      var base = directory
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try base.setResourceValues(values)
      #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
      #else
        try data.write(to: url, options: .atomic)
      #endif
      newestRevision = snapshot.revision
    } catch let error as ChatError { throw error } catch { throw ChatError.storage }
  }
}
