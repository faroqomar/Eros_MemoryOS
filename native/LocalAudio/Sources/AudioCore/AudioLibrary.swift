import Foundation

public protocol AudioRepository: Sendable {
  func snapshot() async throws -> AudioSnapshot
  func createDraft(title: String, fileExtension: String, personIDs: [UUID], sourceRecordIDs: [UUID])
    async throws -> AudioRecording
  func recordingURL(id: UUID) async throws -> URL
  func finalizeDraft(id: UUID, durationSeconds: Double) async throws -> AudioRecording
  func setRecordingState(id: UUID, state: RecordingState) async throws
  /// Call after closing the recorder. Removes only interrupted metadata with no audio bytes.
  func discardEmptyDraft(id: UUID) async throws -> Bool
  func importAudio(
    from: URL, title: String, durationSeconds: Double, personIDs: [UUID], sourceRecordIDs: [UUID]
  ) async throws -> AudioRecording
  func beginTranscription(recordingID: UUID, engineID: String) async throws -> TranscriptionJob
  func completeTranscription(jobID: UUID, output: TranscriptionOutput) async throws
    -> AudioTranscript
  func interruptTranscription(jobID: UUID, failure: AudioFailureCode) async throws
  func correctPassage(
    transcriptID: UUID, passageID: UUID, text: String, speaker: String?, uncertain: Bool)
    async throws
  func updateAssociations(recordingID: UUID, personIDs: [UUID], sourceRecordIDs: [UUID])
    async throws
  func exportTranscript(transcriptID: UUID) async throws -> Data
}

public struct AudioLibrary: Sendable {
  private let repository: any AudioRepository
  public init(repository: any AudioRepository) { self.repository = repository }
  public func snapshot() async throws -> AudioSnapshot { try await repository.snapshot() }
  public func createDraft(
    title: String, fileExtension: String = "m4a", personIDs: [UUID] = [],
    sourceRecordIDs: [UUID] = []
  ) async throws -> AudioRecording {
    try await repository.createDraft(
      title: title, fileExtension: fileExtension, personIDs: personIDs,
      sourceRecordIDs: sourceRecordIDs)
  }
  public func recordingURL(id: UUID) async throws -> URL {
    try await repository.recordingURL(id: id)
  }
  public func finalizeDraft(id: UUID, durationSeconds: Double) async throws -> AudioRecording {
    try await repository.finalizeDraft(id: id, durationSeconds: durationSeconds)
  }
  public func setRecordingState(id: UUID, state: RecordingState) async throws {
    try await repository.setRecordingState(id: id, state: state)
  }
  public func discardEmptyDraft(id: UUID) async throws -> Bool {
    try await repository.discardEmptyDraft(id: id)
  }
  public func importAudio(
    from: URL, title: String, durationSeconds: Double, personIDs: [UUID] = [],
    sourceRecordIDs: [UUID] = []
  ) async throws -> AudioRecording {
    try await repository.importAudio(
      from: from, title: title, durationSeconds: durationSeconds, personIDs: personIDs,
      sourceRecordIDs: sourceRecordIDs)
  }
  public func beginTranscription(recordingID: UUID, engineID: String) async throws
    -> TranscriptionJob
  {
    try await repository.beginTranscription(recordingID: recordingID, engineID: engineID)
  }
  public func completeTranscription(jobID: UUID, output: TranscriptionOutput) async throws
    -> AudioTranscript
  {
    try await repository.completeTranscription(jobID: jobID, output: output)
  }
  public func interruptTranscription(jobID: UUID, failure: AudioFailureCode = .interrupted)
    async throws
  {
    try await repository.interruptTranscription(jobID: jobID, failure: failure)
  }
  public func correctPassage(
    transcriptID: UUID, passageID: UUID, text: String, speaker: String? = nil,
    uncertain: Bool = true
  ) async throws {
    try await repository.correctPassage(
      transcriptID: transcriptID, passageID: passageID, text: text, speaker: speaker,
      uncertain: uncertain)
  }
  public func updateAssociations(recordingID: UUID, personIDs: [UUID], sourceRecordIDs: [UUID])
    async throws
  {
    try await repository.updateAssociations(
      recordingID: recordingID, personIDs: personIDs, sourceRecordIDs: sourceRecordIDs)
  }
  public func exportTranscript(transcriptID: UUID) async throws -> Data {
    try await repository.exportTranscript(transcriptID: transcriptID)
  }

  public func transcribe(
    recordingID: UUID, provider: any TranscriptionProvider, modelDirectory: URL
  ) async throws -> AudioTranscript {
    try Task.checkCancellation()
    let job = try await beginTranscription(recordingID: recordingID, engineID: provider.id)
    do {
      let audioURL = try await recordingURL(id: recordingID)
      let output = try await provider.transcribe(audioURL: audioURL, modelDirectory: modelDirectory)
      try Task.checkCancellation()
      return try await completeTranscription(jobID: job.id, output: output)
    } catch {
      // Failure of metadata persistence must remain visible to the caller too.
      try await interruptTranscription(
        jobID: job.id, failure: error is CancellationError ? .cancelled : .processingFailed)
      throw error
    }
  }
}

public enum AudioValidation {
  public static func title(_ value: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf8.count <= 1_000
    else { throw AudioError.invalidTitle }
  }
  public static func duration(_ value: Double) throws {
    guard value.isFinite, value > 0, value <= AudioLimits.durationSeconds else {
      throw AudioError.invalidDuration
    }
  }
  public static func associations(_ ids: [UUID]) throws {
    guard ids.count <= 1_000, Set(ids).count == ids.count else { throw AudioError.invalidArchive }
  }
  public static func passages(_ values: [TranscriptPassage], duration: Double) throws {
    guard values.count <= AudioLimits.passages, Set(values.map(\.id)).count == values.count,
      values.reduce(0, { $0 + $1.text.utf8.count }) <= AudioLimits.transcriptBytes
    else { throw AudioError.invalidTranscript }
    var previous: Double = 0
    for passage in values {
      guard passage.startSeconds.isFinite, passage.endSeconds.isFinite,
        passage.startSeconds >= previous, passage.endSeconds >= passage.startSeconds,
        passage.endSeconds <= duration + 1,
        !passage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        (passage.speaker?.utf8.count ?? 0) <= 200
      else { throw AudioError.invalidTranscript }
      guard passage.words.count <= 20_000 else { throw AudioError.invalidTranscript }
      var previousWord = passage.startSeconds
      for word in passage.words {
        guard word.startSeconds.isFinite, word.endSeconds.isFinite,
          word.startSeconds >= previousWord, word.endSeconds >= word.startSeconds,
          word.endSeconds <= passage.endSeconds + 0.05, !word.text.isEmpty,
          word.text.utf8.count <= 10_000
        else { throw AudioError.invalidTranscript }
        previousWord = word.startSeconds
      }
      previous = passage.startSeconds
    }
  }
}
