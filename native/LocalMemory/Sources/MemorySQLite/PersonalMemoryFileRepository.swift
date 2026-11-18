import Foundation
import MemoryCore

/// Independent app-owned graph archive; it leaves the earlier record database untouched.
public actor FilePersonalMemoryRepository: PersonalMemoryRepository {
  private let url: URL
  private var newestRevision: UInt64?

  public init(url: URL) { self.url = url }

  public func load() throws -> PersonalMemorySnapshot {
    guard url.isFileURL else { throw PersonalMemoryError.storage }
    guard FileManager.default.fileExists(atPath: url.path) else {
      newestRevision = 0
      return PersonalMemorySnapshot()
    }
    do {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values.isRegularFile == true,
        (values.fileSize ?? Int.max) <= PersonalMemoryLimits.archiveBytes
      else {
        throw PersonalMemoryError.invalidArchive
      }
      let data = try Data(contentsOf: url)
      guard data.count <= PersonalMemoryLimits.archiveBytes else {
        throw PersonalMemoryError.limitReached
      }
      let result = try JSONDecoder().decode(PersonalMemoryStorageArchive.self, from: data)
        .expanded()
      try result.validate()
      newestRevision = result.revision
      return result
    } catch let error as PersonalMemoryError { throw error } catch {
      throw PersonalMemoryError.storage
    }
  }

  public func save(_ snapshot: PersonalMemorySnapshot) throws {
    guard url.isFileURL else { throw PersonalMemoryError.storage }
    try snapshot.validate()
    guard newestRevision.map({ snapshot.revision >= $0 }) ?? true else {
      throw PersonalMemoryError.storage
    }
    do {
      let data = try JSONEncoder().encode(PersonalMemoryStorageArchive(snapshot))
      guard data.count <= PersonalMemoryLimits.archiveBytes else {
        throw PersonalMemoryError.limitReached
      }
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      #if os(iOS)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
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
    } catch let error as PersonalMemoryError { throw error } catch {
      throw PersonalMemoryError.storage
    }
  }
}
