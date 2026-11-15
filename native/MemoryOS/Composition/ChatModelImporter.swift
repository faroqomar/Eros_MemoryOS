import CryptoKit
import Foundation

actor ChatModelImporter: ChatModelPreparing {
  func prepare(from url: URL) throws {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
    let directory = URL.documentsDirectory.appending(path: "ChatModels")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    var excluded = directory
    var resources = URLResourceValues()
    resources.isExcludedFromBackup = true
    try excluded.setResourceValues(resources)
    let temporary = directory.appending(path: UUID().uuidString + ".importing")
    defer { try? FileManager.default.removeItem(at: temporary) }
    // Coordinated copy supports Files providers and avoids changing a previously prepared model on failure.
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var copyError: Error?
    coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
      do { try FileManager.default.copyItem(at: source, to: temporary) } catch { copyError = error }
    }
    if let error = coordinationError ?? (copyError as NSError?) { throw error }
    guard let stream = InputStream(url: temporary) else { throw CocoaError(.fileReadUnknown) }
    stream.open()
    defer { stream.close() }
    var hash = SHA256()
    var bytes = [UInt8](repeating: 0, count: 65_536)
    while true {
      try Task.checkCancellation()
      let count = stream.read(&bytes, maxLength: bytes.count)
      guard count >= 0 else { throw CocoaError(.fileReadUnknown) }
      if count == 0 { break }
      hash.update(data: Data(bytes.prefix(count)))
    }
    guard
      hash.finalize().map({ String(format: "%02x", $0) }).joined()
        == "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: temporary.path)
    let destination = directory.appending(path: "Qwen3-0.6B-Q4_K_M.gguf")
    if FileManager.default.fileExists(atPath: destination.path) {
      _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
    } else {
      try FileManager.default.moveItem(at: temporary, to: destination)
    }
  }
}
