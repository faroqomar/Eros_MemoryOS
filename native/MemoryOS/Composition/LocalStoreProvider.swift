import Foundation
import MemoryCore
import MemorySQLite

/// Filesystem policy and concrete SQLite construction stay in the integration layer.
actor LocalStoreProvider: LocalMemorySessionProvider {
  private let directory: URL
  private var session: LocalMemorySession?

  init(directory: URL) { self.directory = directory }

  func open() throws -> LocalMemorySession {
    if let session { return session }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    var base = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try base.setResourceValues(values)
    let repository = try SQLiteRecordRepository(url: directory.appending(path: "records.sqlite"))
    for file in try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    {
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
    }
    let useCases = LocalMemoryUseCases(repository: repository)
    let result = LocalMemorySession(
      useCases: useCases,
      archiveRestore: RestoreArchiveFromFile(useCases: useCases, reader: LocalArchiveFileReader()))
    session = result
    return result
  }
}
