import CryptoKit
import Foundation

actor ChatModelImporter: ChatModelPreparing {
  private static let leases = ChatModelImportLeases()
  private let asset: ChatModelAsset
  private let directory: URL

  init(
    asset: ChatModelAsset,
    directory: URL = .documentsDirectory.appending(path: "ChatModels")
  ) {
    self.asset = asset
    self.directory = directory
  }

  func prepare(from url: URL) throws {
    try Task.checkCancellation()
    guard url.isFileURL else { throw ChatModelPreparationFailure.unreadableFile }
    let lease = directory.standardizedFileURL.resolvingSymlinksInPath().path
    guard Self.leases.acquire(lease) else { throw ChatModelPreparationFailure.busy }
    defer { Self.leases.release(lease) }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let temporary = directory.appending(path: UUID().uuidString + ".importing")
    defer { try? FileManager.default.removeItem(at: temporary) }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
      var excluded = directory
      var resources = URLResourceValues()
      resources.isExcludedFromBackup = true
      try excluded.setResourceValues(resources)
      try removeAbandonedImports(excluding: url)
    } catch { throw writeFailure(error) }

    // Coordinate Files-provider reads. Stream once, hash while copying, and keep the old
    // asset until validation succeeds. Cancellation never commits a partial replacement.
    var coordinationError: NSError?
    var copyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      source in
      do { try copyReviewedAsset(from: source, to: temporary) } catch { copyError = error }
    }
    if let copyError { throw copyError }
    if coordinationError != nil { throw ChatModelPreparationFailure.unreadableFile }
    try Task.checkCancellation()
    let destination = directory.appending(path: asset.filename)
    do {
      if FileManager.default.fileExists(atPath: destination.path) {
        _ = try FileManager.default.replaceItemAt(
          destination, withItemAt: temporary, options: .usingNewMetadataOnly)
      } else {
        try FileManager.default.moveItem(at: temporary, to: destination)
      }
    } catch { throw writeFailure(error) }
  }

  private func copyReviewedAsset(from source: URL, to temporary: URL) throws {
    try Task.checkCancellation()
    let resources: URLResourceValues
    let input: FileHandle
    do {
      resources = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard resources.isRegularFile == true else {
        throw ChatModelPreparationFailure.unreadableFile
      }
      guard resources.fileSize.map(Int64.init) == asset.byteCount else {
        throw ChatModelPreparationFailure.differentModel
      }
      input = try FileHandle(forReadingFrom: source)
    } catch let failure as ChatModelPreparationFailure { throw failure } catch {
      throw ChatModelPreparationFailure.unreadableFile
    }
    defer { try? input.close() }
    guard
      FileManager.default.createFile(
        atPath: temporary.path, contents: nil,
        attributes: [.protectionKey: FileProtectionType.complete])
    else { throw ChatModelPreparationFailure.couldNotSave }
    let output: FileHandle
    do { output = try FileHandle(forWritingTo: temporary) } catch { throw writeFailure(error) }
    defer { try? output.close() }
    var hash = SHA256()
    var copied: Int64 = 0
    while true {
      try Task.checkCancellation()
      let data: Data
      do { data = try input.read(upToCount: 65_536) ?? Data() } catch {
        throw ChatModelPreparationFailure.unreadableFile
      }
      if data.isEmpty { break }
      copied += Int64(data.count)
      guard copied <= asset.byteCount else { throw ChatModelPreparationFailure.differentModel }
      hash.update(data: data)
      do { try output.write(contentsOf: data) } catch { throw writeFailure(error) }
    }
    guard copied == asset.byteCount,
      hash.finalize().map({ String(format: "%02x", $0) }).joined() == asset.sha256
    else { throw ChatModelPreparationFailure.differentModel }
    do {
      try output.synchronize()
      try output.close()
    } catch { throw writeFailure(error) }
  }

  private func writeFailure(_ error: Error) -> ChatModelPreparationFailure {
    (error as? CocoaError)?.code == .fileWriteOutOfSpace ? .notEnoughSpace : .couldNotSave
  }

  private func removeAbandonedImports(excluding source: URL) throws {
    // The process-wide directory lease excludes another live importer. A new process
    // may remove only the UUID staging files this importer owns, never the model or
    // unknown files, directories, and links a user may have placed beside it.
    for file in try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    where file.pathExtension == "importing"
      && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil
    {
      guard
        file.standardizedFileURL.resolvingSymlinksInPath()
          != source.standardizedFileURL.resolvingSymlinksInPath()
      else { continue }
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
      try FileManager.default.removeItem(at: file)
    }
  }
}

/// All access to the directory set is under the lock; no importer or file handle escapes.
private final class ChatModelImportLeases: @unchecked Sendable {
  private let lock = NSLock()
  private var directories: Set<String> = []
  func acquire(_ directory: String) -> Bool {
    lock.withLock { directories.insert(directory).inserted }
  }
  func release(_ directory: String) {
    lock.withLock { _ = directories.remove(directory) }
  }
}
