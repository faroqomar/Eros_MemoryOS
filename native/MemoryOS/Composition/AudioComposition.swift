import AudioCore
import AudioPersistence
import ChatCore
import Foundation
import WhisperCppTranscription
import WhisperKitTranscription

@MainActor
enum AudioComposition {
  static let speechModel: WhisperCppTranscriber.Model = {
    guard
      let url = Bundle.main.url(
        forResource: "model-kind", withExtension: "txt", subdirectory: "SpeechModels"),
      let value = try? String(contentsOf: url, encoding: .utf8)
    else { return .smallQ5 }
    return WhisperCppTranscriber.Model(
      rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines))
      ?? .smallQ5
  }()

  struct Feature {
    let viewModel: AudioViewModel
    let voiceTranscriber: any VoiceTranscribing
  }

  static func makeFeature(inference: LocalInferenceCoordinator) -> Feature {
    let base = URL.applicationSupportDirectory.appending(path: "AudioLibrary")
    let library = AudioLibrary(repository: FileAudioRepository(directory: base))
    let capture = AudioCaptureUseCases(
      device: AppleAudioCapture(), inspector: AppleAudioFileInspector())
    let models = FileAudioModelStore(
      directory: URL.applicationSupportDirectory.appending(path: "SpeechModels"),
      bundledDirectory: Bundle.main.resourceURL?.appending(path: "SpeechModels"),
      cppModel: speechModel)
    let signal = AudioSignalInspector()
    return makeFeature(
      workflow: AudioWorkflow(
        library: library, capture: capture,
        providers: [
          CoordinatedTranscriber(
            base: WhisperCppTranscriber(model: speechModel), coordinator: inference),
          CoordinatedTranscriber(base: WhisperKitTranscriber(), coordinator: inference),
        ], models: models),
      signalCheck: { try await signal.hasSignal(url: $0) })
  }

  static func makeFeature(
    workflow: AudioWorkflow,
    signalCheck: @escaping @Sendable (URL) async throws -> Bool = { _ in true }
  ) -> Feature {
    let viewModel = AudioViewModel(workflow: workflow)
    let transcriber = AudioChatTranscriber(workflow: workflow, signalCheck: signalCheck) {
      [weak viewModel] processing in
      await viewModel?.voiceProcessingChanged(processing)
    }
    return Feature(viewModel: viewModel, voiceTranscriber: transcriber)
  }
}

/// A model import commits a small pointer only after a complete copy. Existing models survive failure.
actor FileAudioModelStore: AudioModelPreparing {
  private let directory: URL
  private let bundledDirectory: URL?
  private let cppModel: WhisperCppTranscriber.Model
  private let validateContent: @Sendable (URL, String) throws -> Void

  init(
    directory: URL,
    bundledDirectory: URL? = nil,
    cppModel: WhisperCppTranscriber.Model = .tiny,
    validateContent: (@Sendable (URL, String) throws -> Void)? = nil
  ) {
    self.directory = directory
    self.bundledDirectory = bundledDirectory
    self.cppModel = cppModel
    self.validateContent =
      validateContent ?? { folder, engine in
        do {
          if engine == "whisperkit" {
            try WhisperKitTranscriber.validateModel(directory: folder)
          } else {
            try WhisperCppTranscriber.validateModel(directory: folder, model: cppModel)
          }
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          throw AudioWorkflowError.invalidModel
        }
      }
  }

  func directory(engine: String) throws -> URL {
    guard ["whisperkit", "whisper.cpp"].contains(engine) else {
      throw AudioWorkflowError.unknownEngine
    }
    let index = directory.appending(path: key(engine) + ".json")
    if !FileManager.default.fileExists(atPath: index.path), engine == "whisper.cpp",
      let bundledDirectory
    {
      try validate(bundledDirectory, engine: engine)
      try validateContent(bundledDirectory, engine)
      return bundledDirectory
    }
    guard let data = try? Data(contentsOf: index),
      let folder = try? JSONDecoder().decode(UUID.self, from: data)
    else { throw AudioWorkflowError.modelMissing }
    let result = directory.appending(path: folder.uuidString, directoryHint: .isDirectory)
    try validate(result, engine: engine)
    return result
  }

  func install(folder: URL, engine: String) throws {
    guard ["whisperkit", "whisper.cpp"].contains(engine) else {
      throw AudioWorkflowError.unknownEngine
    }
    let granted = folder.startAccessingSecurityScopedResource()
    defer { if granted { folder.stopAccessingSecurityScopedResource() } }
    try validate(folder, engine: engine)
    let manager = FileManager.default
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    var excluded = URLResourceValues()
    excluded.isExcludedFromBackup = true
    var root = directory
    try root.setResourceValues(excluded)
    try manager.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    // Bound selected trees and reject aliases/links before copying. No network loader is invoked.
    let keys: [URLResourceKey] = [
      .isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey,
    ]
    guard let files = manager.enumerator(at: folder, includingPropertiesForKeys: keys) else {
      throw AudioWorkflowError.modelMissing
    }
    var count = 0
    var bytes: Int64 = 0
    for case let file as URL in files {
      try Task.checkCancellation()
      let values = try file.resourceValues(forKeys: Set(keys))
      guard values.isSymbolicLink != true,
        values.isDirectory == true || values.isRegularFile == true
      else { throw AudioWorkflowError.modelMissing }
      count += 1
      bytes += Int64(values.fileSize ?? 0)
      guard count <= 10_000, bytes <= 2_147_483_648 else { throw AudioError.audioTooLarge }
    }
    let space = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]
    )
    if let available = space.volumeAvailableCapacityForImportantUsage,
      available < bytes + 33_554_432
    {
      throw AudioError.insufficientStorage
    }
    let identifier = UUID()
    let destination = directory.appending(path: identifier.uuidString)
    let index = directory.appending(path: key(engine) + ".json")
    let oldID = (try? Data(contentsOf: index)).flatMap {
      try? JSONDecoder().decode(UUID.self, from: $0)
    }
    do {
      try manager.copyItem(at: folder, to: destination)
      try Task.checkCancellation()
      try validate(destination, engine: engine)
      try validateContent(destination, engine)
      try Task.checkCancellation()
      try JSONEncoder().encode(identifier).write(
        to: index, options: [.atomic, .completeFileProtection])
    } catch {
      try? manager.removeItem(at: destination)
      throw error
    }
    if let oldID { try? manager.removeItem(at: directory.appending(path: oldID.uuidString)) }
  }

  private func key(_ engine: String) -> String {
    if engine == "whisperkit" { return "whisperkit" }
    // Retain old imports without allowing their pointer to shadow a model upgrade.
    return cppModel == .tiny ? "whisper-cpp" : "whisper-cpp-\(cppModel.rawValue)"
  }
  private func validate(_ folder: URL, engine: String) throws {
    guard folder.isFileURL else { throw AudioWorkflowError.modelMissing }
    let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
      throw AudioWorkflowError.modelMissing
    }
    let expected =
      engine == "whisperkit"
      ? [
        "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc",
        "tokenizer.json", "tokenizer_config.json",
      ]
      : [cppModel.filename]
    guard
      expected.allSatisfy({
        FileManager.default.fileExists(atPath: folder.appending(path: $0).path)
      })
    else {
      throw AudioWorkflowError.modelMissing
    }
  }
}
