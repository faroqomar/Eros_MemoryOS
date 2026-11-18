import Foundation
import MemoryCore

/// Files access is explicit, bounded and replaceable. The picker only supplies a URL.
actor LocalArchiveFileReader: ArchiveDataReader {
  private let maximumBytes: Int
  init(maximumBytes: Int = LocalMemoryLimits.archiveBytes) { self.maximumBytes = maximumBytes }

  func readArchive(at url: URL) throws -> Data {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size <= maximumBytes else { throw LocalMemoryError.archiveTooLarge }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var data = Data()
    while let chunk = try handle.read(
      upToCount: min(65_536, maximumBytes - data.count + 1)), !chunk.isEmpty
    {
      data.append(chunk)
      guard data.count <= maximumBytes else {
        throw LocalMemoryError.archiveTooLarge
      }
    }
    return data
  }
}
