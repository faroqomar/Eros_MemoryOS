import AudioCore
import ChatCore
import Foundation

/// One lease covers every speech/text adapter, including manual library transcription.
actor LocalInferenceCoordinator: StructuredChatModel {
  private let model: any ChatModel
  private var occupied = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var background: (id: UUID, task: Task<String, Error>)?

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
    background?.task.cancel()
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    try await model.generate(turns: turns, onText: onText)
  }

  func unload() async {
    background?.task.cancel()
    await acquire()
    defer { release() }
    await model.unload()
  }

  /// One foreground lease covers candidate verification and the verifier's unload.
  func selectRelevant(
    using filter: any MemoryEvidenceFiltering, query: String, candidates: [ChatEvidence]
  ) async throws -> Set<UUID> {
    guard !candidates.isEmpty else { return [] }
    background?.task.cancel()
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    await model.unload()
    try Task.checkCancellation()
    return try await filter.selectRelevant(query: query, candidates: candidates)
  }

  func transcribe(provider: any TranscriptionProvider, audioURL: URL, modelDirectory: URL)
    async throws -> TranscriptionOutput
  {
    background?.task.cancel()
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    await model.unload()
    try Task.checkCancellation()
    return try await provider.transcribe(audioURL: audioURL, modelDirectory: modelDirectory)
  }

  /// One cancellable background job shares the same model and lease as chat and speech.
  func generateJSON(
    turns: [ChatTurn], grammar: String, maximumOutputTokens: Int
  ) async throws -> String {
    try Task.checkCancellation()
    guard background == nil else { throw ChatError.busy }
    guard let structured = model as? any StructuredChatModel else {
      throw ChatError.modelUnavailable
    }
    let id = UUID()
    let operation = Task { [self] in
      try await runStructured(
        model: structured, turns: turns, grammar: grammar,
        maximumOutputTokens: maximumOutputTokens)
    }
    background = (id, operation)
    defer { if background?.id == id { background = nil } }
    let output = try await withTaskCancellationHandler {
      try await operation.value
    } onCancel: {
      operation.cancel()
    }
    try Task.checkCancellation()
    return output
  }

  private func runStructured(
    model: any StructuredChatModel, turns: [ChatTurn], grammar: String,
    maximumOutputTokens: Int
  ) async throws -> String {
    try Task.checkCancellation()
    await acquire()
    defer { release() }
    try Task.checkCancellation()
    let output = try await model.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    try Task.checkCancellation()
    return output
  }
}

struct CoordinatedEvidenceFilter: MemoryEvidenceFiltering {
  let base: any MemoryEvidenceFiltering
  let coordinator: LocalInferenceCoordinator
  func selectRelevant(query: String, candidates: [ChatEvidence]) async throws -> Set<UUID> {
    try await coordinator.selectRelevant(using: base, query: query, candidates: candidates)
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
