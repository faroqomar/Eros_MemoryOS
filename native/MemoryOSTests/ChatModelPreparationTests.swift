import Foundation
import Testing

@testable import MemoryOS

private let preparationAsset = ChatModelAsset(
  name: "Fictional fixture", filename: "fixture.gguf",
  sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  byteCount: 3)

private actor PreparationGate: ChatModelPreparing {
  private var continuation: CheckedContinuation<Void, Never>?
  private var observers: [CheckedContinuation<Void, Never>] = []
  private(set) var calls = 0
  func prepare(from url: URL) async throws {
    calls += 1
    for observer in observers { observer.resume() }
    observers = []
    await withCheckedContinuation { continuation = $0 }
    try Task.checkCancellation()
  }
  func waitUntilEntered() async {
    if calls > 0 { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    continuation?.resume()
    continuation = nil
  }
}

private struct PreparationFailure: ChatModelPreparing {
  let error: ChatModelPreparationFailure
  func prepare(from url: URL) throws { throw error }
}

@Suite struct ChatModelPreparationTests {
  private func workspace() throws -> URL {
    let root = URL.temporaryDirectory.appending(path: "model-import-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  @Test func verifiedImportAndReplacementPreserveSource() async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "chosen.gguf")
    let directory = root.appending(path: "prepared")
    try Data("abc".utf8).write(to: source)
    let importer = ChatModelImporter(asset: preparationAsset, directory: directory)
    try await importer.prepare(from: source)
    let destination = directory.appending(path: preparationAsset.filename)
    #expect(try Data(contentsOf: destination) == Data("abc".utf8))
    #expect(try Data(contentsOf: source) == Data("abc".utf8))
    try Data("old model".utf8).write(to: destination)
    try await importer.prepare(from: source)
    #expect(try Data(contentsOf: destination) == Data("abc".utf8))
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: directory.path) == [
        preparationAsset.filename
      ])
    // The Simulator does not expose iOS file-protection metadata. Phone verification
    // remains a separate check; it is not implied by the copy/replace assertions.
    #if !targetEnvironment(simulator)
      let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
      #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
    #endif
    #expect(
      try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
    )
  }

  @Test func retryRemovesOnlyAbandonedOwnedStagingAndKeepsChosenSource() async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "prepared")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let source = directory.appending(path: UUID().uuidString + ".importing")
    let orphan = directory.appending(path: UUID().uuidString + ".importing")
    let unknown = directory.appending(path: "notes.importing")
    let folder = directory.appending(path: UUID().uuidString + ".importing")
    let link = directory.appending(path: UUID().uuidString + ".importing")
    let outside = root.appending(path: "keep.gguf")
    try Data("abc".utf8).write(to: source)
    try Data("partial".utf8).write(to: orphan)
    try Data("notes".utf8).write(to: unknown)
    try Data("outside".utf8).write(to: outside)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    let importer = ChatModelImporter(asset: preparationAsset, directory: directory)
    try await importer.prepare(from: source)
    #expect(!FileManager.default.fileExists(atPath: orphan.path))
    #expect(try Data(contentsOf: source) == Data("abc".utf8))
    #expect(try Data(contentsOf: unknown) == Data("notes".utf8))
    #expect(try Data(contentsOf: outside) == Data("outside".utf8))
    #expect(try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
    #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    #expect(
      try Data(contentsOf: directory.appending(path: preparationAsset.filename)) == Data("abc".utf8)
    )
  }

  @Test(arguments: ["abd", "ab", "abcd"])
  func rejectedModelPreservesPreviousAssetAndRemovesStaging(contents: String) async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "chosen.gguf")
    let directory = root.appending(path: "prepared")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appending(path: preparationAsset.filename)
    try Data("previous".utf8).write(to: destination)
    try Data(contents.utf8).write(to: source)
    let importer = ChatModelImporter(asset: preparationAsset, directory: directory)
    await #expect(throws: ChatModelPreparationFailure.differentModel) {
      try await importer.prepare(from: source)
    }
    #expect(try Data(contentsOf: destination) == Data("previous".utf8))
    #expect(try Data(contentsOf: source) == Data(contents.utf8))
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: directory.path) == [
        preparationAsset.filename
      ])
  }

  @Test func nonFileMissingAndDirectoryInputsAreRecoverable() async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "prepared")
    let importer = ChatModelImporter(asset: preparationAsset, directory: directory)
    let remote = try #require(URL(string: "https://example.invalid/model.gguf"))
    for source in [remote, root.appending(path: "missing.gguf"), root] {
      await #expect(throws: ChatModelPreparationFailure.unreadableFile) {
        try await importer.prepare(from: source)
      }
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
  }

  @Test func unwritableDestinationDoesNotChangeChosenFile() async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "chosen.gguf")
    let directory = root.appending(path: "not-a-directory")
    try Data("abc".utf8).write(to: source)
    try Data("keep".utf8).write(to: directory)
    let importer = ChatModelImporter(asset: preparationAsset, directory: directory)
    await #expect(throws: ChatModelPreparationFailure.couldNotSave) {
      try await importer.prepare(from: source)
    }
    #expect(try Data(contentsOf: source) == Data("abc".utf8))
    #expect(try Data(contentsOf: directory) == Data("keep".utf8))
  }

  @Test(.timeLimit(.minutes(1)))
  func cancelledRealCopyPreservesPreviousModelAndReleasesDirectoryLease() async throws {
    let root = try workspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "sparse-fixture.gguf")
    let directory = root.appending(path: "prepared")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appending(path: preparationAsset.filename)
    try Data("previous".utf8).write(to: destination)
    FileManager.default.createFile(atPath: source.path, contents: nil)
    let handle = try FileHandle(forWritingTo: source)
    // Sparse source uses no model download or large fixture buffer. Cancel after the
    // first staged bytes appear, long before it could validate or replace anything.
    let byteCount: Int64 = 3_000_000_000
    try handle.truncate(atOffset: UInt64(byteCount))
    try handle.close()
    let sparseAsset = ChatModelAsset(
      name: "Sparse cancellation fixture", filename: preparationAsset.filename,
      sha256: String(repeating: "0", count: 64), byteCount: byteCount)
    let importer = ChatModelImporter(asset: sparseAsset, directory: directory)
    let copying = Task { try await importer.prepare(from: source) }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(10))
    var sawPartialCopy = false
    do {
      while clock.now < deadline {
        let staged = try FileManager.default.contentsOfDirectory(
          at: directory, includingPropertiesForKeys: [.fileSizeKey]
        )
        .filter { $0.pathExtension == "importing" }
        if let file = staged.first,
          (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) == true
        {
          sawPartialCopy = true
          break
        }
        try await Task.sleep(for: .milliseconds(1))
      }
      // A second importer instance cannot erase the active staging file as an orphan.
      if sawPartialCopy {
        let other = ChatModelImporter(asset: sparseAsset, directory: directory)
        await #expect(throws: ChatModelPreparationFailure.busy) {
          try await other.prepare(from: source)
        }
      }
    } catch {
      copying.cancel()
      _ = await copying.result
      throw error
    }
    copying.cancel()
    await #expect(throws: CancellationError.self) { try await copying.value }
    #expect(sawPartialCopy)
    #expect(try Data(contentsOf: destination) == Data("previous".utf8))
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: directory.path) == [
        preparationAsset.filename
      ])
    let valid = root.appending(path: "valid.gguf")
    try Data("abc".utf8).write(to: valid)
    try await ChatModelImporter(asset: preparationAsset, directory: directory).prepare(from: valid)
    #expect(try Data(contentsOf: destination) == Data("abc".utf8))
  }

  @MainActor @Test(arguments: [false, true])
  func cancellationJoinsBeforeRetryAndDoesNotReportFailure(cancelCaller: Bool) async {
    let gate = PreparationGate()
    let model = ChatModelPreparationViewModel(
      useCase: .init(asset: preparationAsset, importer: gate))
    let source = URL.temporaryDirectory.appending(path: "fictional.gguf")
    let request = Task { await model.prepare(source) }
    await gate.waitUntilEntered()
    if cancelCaller { request.cancel() } else { model.cancel() }
    #expect(model.isPreparing)
    if !cancelCaller { #expect(model.isCancelling) }
    await model.prepare(source)
    #expect(await gate.calls == 1)
    await gate.release()
    await request.value
    #expect(!model.isPreparing && !model.isCancelling)
    #expect(model.result == nil && model.failure == nil)
    #expect(model.asset == preparationAsset)
  }

  @MainActor @Test func pickerCancellationPreservesStateAndFailuresExplainRecovery() async {
    let model = ChatModelPreparationViewModel(
      useCase: .init(asset: preparationAsset, importer: PreparationFailure(error: .differentModel)))
    model.selectionFailed(CocoaError(.userCancelled))
    #expect(model.result == nil && model.failure == nil)
    model.selectionFailed(CocoaError(.fileReadNoPermission))
    #expect(model.result == false && model.failure == .unreadableFile)
    await model.prepare(URL.temporaryDirectory.appending(path: "fictional.gguf"))
    #expect(model.result == false && model.failure == .differentModel)
    model.selectionFailed(CocoaError(.userCancelled))
    #expect(model.result == false && model.failure == .differentModel)
  }
}
