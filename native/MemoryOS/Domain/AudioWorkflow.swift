import AudioCore
import Foundation

protocol AudioModelPreparing: Sendable {
  func directory(engine: String) async throws -> URL
  func install(folder: URL, engine: String) async throws
}

enum AudioWorkflowError: Error {
  case modelMissing, invalidModel, unknownEngine, busy, transcriptionTooLong
}

/// Coordinates product actions through app-owned interfaces. No SDK or file-system calls.
@MainActor
final class AudioWorkflow {
  let library: AudioLibrary
  let capture: AudioCaptureUseCases
  let engines: [String]
  private let providers: [String: any TranscriptionProvider]
  private let models: any AudioModelPreparing
  private var lifecycleGeneration = 0
  private var captureStarting = false
  private var transcribing = false
  private(set) var draftID: UUID?

  init(
    library: AudioLibrary, capture: AudioCaptureUseCases,
    providers: [any TranscriptionProvider], models: any AudioModelPreparing
  ) {
    self.library = library
    self.capture = capture
    self.models = models
    self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
    engines = providers.map(\.id)
  }

  func start(title: String) async throws {
    guard draftID == nil, !captureStarting, !transcribing else { throw AudioWorkflowError.busy }
    captureStarting = true
    defer { captureStarting = false }
    let generation = lifecycleGeneration
    guard await capture.requestPermission() else { throw AudioCaptureFailure.permissionDenied }
    try Task.checkCancellation()
    guard generation == lifecycleGeneration else { throw CancellationError() }
    let draft = try await library.createDraft(title: title, fileExtension: "caf")
    draftID = draft.id
    do {
      try Task.checkCancellation()
      guard generation == lifecycleGeneration else { throw CancellationError() }
      let url = try await library.recordingURL(id: draft.id)
      try Task.checkCancellation()
      guard generation == lifecycleGeneration else { throw CancellationError() }
      try await capture.start(to: url)
    } catch {
      // Stop and detach this session before inspecting its bytes. Delayed platform
      // callbacks must not mistake the failed attempt for a later recording.
      draftID = nil
      do {
        capture.interrupt()
        if capture.snapshot.state != .idle { _ = try capture.finish() }
        try await library.setRecordingState(id: draft.id, state: .interrupted)
        if try await !library.discardEmptyDraft(id: draft.id) { draftID = draft.id }
      } catch {
        // A failed metadata write is recoverable after space/access returns.
        draftID = draft.id
        throw error
      }
      throw error
    }
  }

  func pause() async throws {
    capture.pause()
    if let draftID { try await library.setRecordingState(id: draftID, state: .paused) }
  }

  func resume() async throws {
    try capture.resume()
    if let draftID { try await library.setRecordingState(id: draftID, state: .recording) }
  }

  func save() async throws {
    guard let draftID else { throw AudioError.invalidState }
    if capture.snapshot.state != .idle { _ = try capture.finish() }
    try await recover(id: draftID)
    self.draftID = nil
  }

  func keepForLater() async throws {
    capture.interrupt()
    if capture.snapshot.state != .idle { _ = try capture.finish() }
    if let draftID { try await library.setRecordingState(id: draftID, state: .interrupted) }
    draftID = nil
  }

  func recover(id: UUID) async throws {
    if draftID == id, capture.snapshot.state == .idle {
      try await library.setRecordingState(id: id, state: .interrupted)
    }
    if try await library.discardEmptyDraft(id: id) {
      if draftID == id { draftID = nil }
      return
    }
    let url = try await library.recordingURL(id: id)
    let details = try await capture.inspect(url: url)
    _ = try await library.finalizeDraft(id: id, durationSeconds: details.durationSeconds)
    if draftID == id { draftID = nil }
  }

  func interrupt() async throws {
    lifecycleGeneration += 1
    capture.interrupt()
    capture.stopPlayback()
    if let draftID { try await library.setRecordingState(id: draftID, state: .interrupted) }
  }

  func importAudio(url: URL) async throws {
    // The platform adapter manages the security-scoped grant across inspection and copy.
    try await capture.withSelectedFile(url: url) { selected in
      let details = try await self.capture.inspect(url: selected)
      _ = try await self.library.importAudio(
        from: selected,
        title: selected.deletingPathExtension().lastPathComponent,
        durationSeconds: details.durationSeconds)
    }
  }

  func play(id: UUID, seconds: Double) async throws {
    let url = try await library.recordingURL(id: id)
    try capture.play(url: url, fromSeconds: seconds)
  }

  func transcribe(id: UUID, engine: String) async throws {
    _ = try await transcribeRecording(id: id, engine: engine, reuseExisting: false)
  }

  /// A failed chat commit can retry without repeating a completed speech job.
  func transcriptForChat(id: UUID) async throws -> AudioTranscript {
    try await transcribeRecording(id: id, engine: "whisper.cpp", reuseExisting: true)
  }

  private func transcribeRecording(id: UUID, engine: String, reuseExisting: Bool) async throws
    -> AudioTranscript
  {
    guard !transcribing, !captureStarting, draftID == nil else { throw AudioWorkflowError.busy }
    transcribing = true
    defer { transcribing = false }
    try Task.checkCancellation()
    let snapshot = try await library.snapshot()
    guard let recording = snapshot.recordings.first(where: { $0.id == id }),
      recording.state == .saved
    else { throw AudioError.recordingNotFound }
    if reuseExisting,
      let transcript = snapshot.transcripts.filter({ $0.recordingID == id })
        .max(by: { $0.createdAt < $1.createdAt })
    {
      // Reusing text still requires the original recording to exist and match its saved digest.
      _ = try await library.recordingURL(id: id)
      return transcript
    }
    guard let provider = providers[engine] else { throw AudioWorkflowError.unknownEngine }
    guard (recording.durationSeconds ?? 0) <= 900 else {
      throw AudioWorkflowError.transcriptionTooLong
    }
    let directory = try await models.directory(engine: engine)
    return try await library.transcribe(
      recordingID: id, provider: NonemptySpeechProvider(base: provider), modelDirectory: directory)
  }

  func installModel(folder: URL, engine: String) async throws {
    try await models.install(folder: folder, engine: engine)
  }
}

/// Empty output is recoverable silence, not an invalid archive to persist.
enum AudioChatInputError: Error { case noSpeech }

private struct NonemptySpeechProvider: TranscriptionProvider {
  let base: any TranscriptionProvider
  var id: String { base.id }
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    let output = try await base.transcribe(audioURL: audioURL, modelDirectory: modelDirectory)
    guard
      output.passages.contains(where: {
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      })
    else { throw AudioChatInputError.noSpeech }
    return output
  }
}
