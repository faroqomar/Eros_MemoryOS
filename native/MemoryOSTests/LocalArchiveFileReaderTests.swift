import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

struct LocalArchiveFileReaderTests {
  @Test func readsExactLocalArchiveBytes() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "backup.json")
    let data = try RecordArchive(snapshot: RecordSnapshot()).encoded()
    try data.write(to: url)
    #expect(try await LocalArchiveFileReader().readArchive(at: url) == data)
  }

  @Test func rejectsOversizedFileBeforeReadingItsContents() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "oversized.json")
    try Data().write(to: url)
    let file = try FileHandle(forWritingTo: url)
    try file.truncate(atOffset: UInt64(LocalMemoryLimits.archiveBytes + 1))
    try file.close()
    await #expect(throws: LocalMemoryError.archiveTooLarge) {
      try await LocalArchiveFileReader().readArchive(at: url)
    }
  }
}
