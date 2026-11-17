import AudioCore
import ChatCore
import Foundation

/// One lease covers every speech/text adapter, including manual library transcription.
actor LocalInferenceCoordinator: ChatModel {
  private let model: any ChatModel
  private var occupied = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(model: any ChatModel) { self.model = model }

  private func acquire() async {
    if !occupied {
      occupied = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty { occupied = false } else { waiters.removeFirst().resume() }
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    try await model.generate(turns: turns, onText: onText)
  }

  func unload() async {
    await acquire()
    defer { release() }
    await model.unload()
  }

  func transcribe(provider: any TranscriptionProvider, audioURL: URL, modelDirectory: URL)
    async throws -> TranscriptionOutput
  {
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    await model.unload()
    try Task.checkCancellation()
    return try await provider.transcribe(audioURL: audioURL, modelDirectory: modelDirectory)
  }
}

struct CoordinatedTranscriber: TranscriptionProvider {
  let base: any TranscriptionProvider
  let coordinator: LocalInferenceCoordinator
  var id: String { base.id }
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    try await coordinator.transcribe(
      provider: base, audioURL: audioURL, modelDirectory: modelDirectory)
  }
}
