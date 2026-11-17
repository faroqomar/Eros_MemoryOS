import Foundation
import Testing

@testable import MemoryOS

struct AudioModelStoreTests {
  @Test func modelUpgradeDoesNotReuseOrDeleteLegacyImport() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let selected = root.appending(path: "selected")
    let bundled = root.appending(path: "bundled")
    for folder in [selected, bundled] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    try Data("legacy fixture".utf8).write(to: selected.appending(path: "ggml-tiny.bin"))
    try Data("upgrade fixture".utf8).write(to: bundled.appending(path: "ggml-small-q5_1.bin"))
    let owned = root.appending(path: "owned")
    let legacy = FileAudioModelStore(directory: owned) { _, _ in }
    try await legacy.install(folder: selected, engine: "whisper.cpp")
    let oldFolder = try await legacy.directory(engine: "whisper.cpp")
    let upgraded = FileAudioModelStore(
      directory: owned, bundledDirectory: bundled, cppModel: .smallQ5
    ) { folder, _ in
      let bytes = try Data(contentsOf: folder.appending(path: "ggml-small-q5_1.bin"))
      #expect(bytes == Data("upgrade fixture".utf8))
    }
    #expect(try await upgraded.directory(engine: "whisper.cpp") == bundled)
    #expect(try await legacy.directory(engine: "whisper.cpp") == oldFolder)
    #expect(
      try Data(contentsOf: oldFolder.appending(path: "ggml-tiny.bin"))
        == Data("legacy fixture".utf8))
    await #expect(throws: AudioWorkflowError.modelMissing) {
      try await upgraded.install(folder: selected, engine: "whisper.cpp")
    }
    try await upgraded.install(folder: bundled, engine: "whisper.cpp")
    #expect(try await upgraded.directory(engine: "whisper.cpp") != bundled)
    #expect(try await legacy.directory(engine: "whisper.cpp") == oldFolder)
  }

  @Test func invalidReplacementKeepsPreparedFolder() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "selected")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    // A small content validator isolates the install transaction from large external assets.
    try Data("fictional model fixture".utf8).write(to: source.appending(path: "ggml-tiny.bin"))
    let store = FileAudioModelStore(directory: root.appending(path: "owned")) { folder, _ in
      guard
        try Data(contentsOf: folder.appending(path: "ggml-tiny.bin"))
          == Data("fictional model fixture".utf8)
      else { throw AudioWorkflowError.invalidModel }
    }
    try await store.install(folder: source, engine: "whisper.cpp")
    let first = try await store.directory(engine: "whisper.cpp")
    let invalid = root.appending(path: "invalid")
    try FileManager.default.createDirectory(at: invalid, withIntermediateDirectories: true)
    try Data("damaged replacement".utf8).write(to: invalid.appending(path: "ggml-tiny.bin"))
    await #expect(throws: (any Error).self) {
      try await store.install(folder: invalid, engine: "whisper.cpp")
    }
    #expect(try await store.directory(engine: "whisper.cpp") == first)
    #expect(
      try Data(contentsOf: first.appending(path: "ggml-tiny.bin"))
        == Data("fictional model fixture".utf8))
    #expect(FileManager.default.fileExists(atPath: source.appending(path: "ggml-tiny.bin").path))
  }

  @Test(arguments: ["whisperkit", "whisper.cpp"])
  func productionValidatorRejectsMatchingNamesWithDamagedBytes(engine: String) async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "selected")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let names =
      engine == "whisperkit"
      ? [
        "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc",
        "tokenizer.json", "tokenizer_config.json",
      ] : ["ggml-tiny.bin"]
    for name in names { try Data("damaged".utf8).write(to: source.appending(path: name)) }
    let store = FileAudioModelStore(directory: root.appending(path: "owned"))
    await #expect(throws: AudioWorkflowError.invalidModel) {
      try await store.install(folder: source, engine: engine)
    }
    await #expect(throws: AudioWorkflowError.modelMissing) {
      try await store.directory(engine: engine)
    }
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "owned").path)
        .isEmpty)
  }

  @Test func bundledSpeechModelIsValidatedAndImportedModelTakesPrecedence() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let bundled = root.appending(path: "bundled")
    let selected = root.appending(path: "selected")
    for folder in [bundled, selected] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try Data("valid fixture".utf8).write(to: folder.appending(path: "ggml-tiny.bin"))
    }
    let store = FileAudioModelStore(
      directory: root.appending(path: "owned"), bundledDirectory: bundled
    ) {
      folder, _ in
      guard
        try Data(contentsOf: folder.appending(path: "ggml-tiny.bin")) == Data("valid fixture".utf8)
      else { throw AudioWorkflowError.invalidModel }
    }
    #expect(try await store.directory(engine: "whisper.cpp") == bundled)
    await #expect(throws: AudioWorkflowError.modelMissing) {
      try await store.directory(engine: "whisperkit")
    }
    try Data("damaged".utf8).write(to: bundled.appending(path: "ggml-tiny.bin"))
    await #expect(throws: AudioWorkflowError.invalidModel) {
      try await store.directory(engine: "whisper.cpp")
    }
    try await store.install(folder: selected, engine: "whisper.cpp")
    let installed = try await store.directory(engine: "whisper.cpp")
    #expect(installed != bundled)
    #expect(
      try Data(contentsOf: installed.appending(path: "ggml-tiny.bin")) == Data("valid fixture".utf8)
    )
  }

  @Test func modelSymlinkCannotImportExternalFiles() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "selected")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let external = root.appending(path: "outside.bin")
    try Data("outside".utf8).write(to: external)
    try FileManager.default.createSymbolicLink(
      at: source.appending(path: "ggml-tiny.bin"), withDestinationURL: external)
    let store = FileAudioModelStore(directory: root.appending(path: "owned"))
    await #expect(throws: AudioWorkflowError.self) {
      try await store.install(folder: source, engine: "whisper.cpp")
    }
    await #expect(throws: AudioWorkflowError.self) {
      try await store.directory(engine: "whisper.cpp")
    }
    #expect(try Data(contentsOf: external) == Data("outside".utf8))
  }
}
