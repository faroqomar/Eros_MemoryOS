import Foundation
import OrganizationCore

public actor FileOrganizationRepository: OrganizationRepository {
  private let url: URL
  public init(url: URL) { self.url = url }
  public func load() throws -> OrganizationSnapshot {
    guard url.isFileURL else { throw OrganizationError.storage }
    guard FileManager.default.fileExists(atPath: url.path) else { return OrganizationSnapshot() }
    do {
      let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard metadata.isRegularFile == true,
        (metadata.fileSize ?? Int.max) <= OrganizationSnapshot.maximumArchiveBytes
      else {
        throw OrganizationError.limitReached
      }
      let data = try Data(contentsOf: url)
      guard data.count <= OrganizationSnapshot.maximumArchiveBytes else {
        throw OrganizationError.limitReached
      }
      return try JSONDecoder().decode(OrganizationSnapshot.self, from: data)
        .upgradedToCurrentFormat()
    } catch let error as OrganizationError { throw error } catch { throw OrganizationError.storage }
  }
  public func save(_ value: OrganizationSnapshot) throws {
    guard url.isFileURL else { throw OrganizationError.storage }
    try value.validate()
    do {
      let data = try JSONEncoder().encode(value)
      guard data.count <= OrganizationSnapshot.maximumArchiveBytes else {
        throw OrganizationError.limitReached
      }
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var folder = directory
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try folder.setResourceValues(values)
      #if os(iOS)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
      #else
        try data.write(to: url, options: .atomic)
      #endif
    } catch let error as OrganizationError { throw error } catch { throw OrganizationError.storage }
  }
}
