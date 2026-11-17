import AVFoundation
import AudioCore
import ChatCore
import Foundation

/// Connects app-owned audio and chat contracts without exposing files or provider SDK types.
@MainActor
final class AudioChatTranscriber: VoiceTranscribing {
  private let workflow: AudioWorkflow
  private let signalCheck: @Sendable (URL) async throws -> Bool
  private let onProcessing: @MainActor @Sendable (Bool) async -> Void

  init(
    workflow: AudioWorkflow,
    signalCheck: @escaping @Sendable (URL) async throws -> Bool = { _ in true },
    onProcessing: @escaping @MainActor @Sendable (Bool) async -> Void = { _ in }
  ) {
    self.workflow = workflow
    self.signalCheck = signalCheck
    self.onProcessing = onProcessing
  }

  func transcribe(recordingID: UUID) async throws -> VoiceTranscript {
    await onProcessing(true)
    do {
      let url = try await workflow.library.recordingURL(id: recordingID)
      guard try await signalCheck(url) else { throw VoiceFailure.noSpeech }
      let transcript = try await workflow.transcriptForChat(id: recordingID)
      try Task.checkCancellation()
      let passages = transcript.currentPassages
      let text = passages.map(\.text).joined(separator: "\n")
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw VoiceFailure.noSpeech
      }
      let result = VoiceTranscript(
        id: transcript.id, recordingID: transcript.recordingID,
        passageIDs: passages.map(\.id), text: text,
        passages: passages.map {
          VoicePassage(
            id: $0.id, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds,
            text: $0.text, uncertain: $0.uncertain)
        })
      await onProcessing(false)
      return result
    } catch {
      await onProcessing(false)
      throw Self.failure(error)
    }
  }

  private static func failure(_ error: Error) -> Error {
    if error is CancellationError { return CancellationError() }
    if let failure = error as? VoiceFailure { return failure }
    if error is AudioChatInputError { return VoiceFailure.noSpeech }
    if let error = error as? AudioWorkflowError {
      switch error {
      case .modelMissing, .invalidModel: return VoiceFailure.modelUnavailable
      case .busy: return VoiceFailure.interrupted
      case .unknownEngine, .transcriptionTooLong: return VoiceFailure.transcriptionFailed
      }
    }
    if let error = error as? AudioError {
      switch error {
      case .recordingNotFound, .originalChanged, .damagedAudio:
        return VoiceFailure.recordingUnavailable
      case .storageFailure, .insufficientStorage: return VoiceFailure.storage
      default: return VoiceFailure.transcriptionFailed
      }
    }
    return VoiceFailure.transcriptionFailed
  }
}

/// Rejects effectively digital silence. This is not speaker detection or a general noise filter.
actor AudioSignalInspector {
  func hasSignal(url: URL) throws -> Bool {
    try Task.checkCancellation()
    let file: AVAudioFile
    do {
      file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
    } catch { throw AudioError.damagedAudio }
    let format = file.processingFormat
    guard format.sampleRate > 0, file.length > 0 else { return false }
    guard Double(file.length) / format.sampleRate <= 900 else {
      throw AudioWorkflowError.transcriptionTooLong
    }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
      throw AudioError.damagedAudio
    }
    while file.framePosition < file.length {
      try Task.checkCancellation()
      try file.read(into: buffer)
      guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { return false }
      for channel in 0..<Int(format.channelCount) {
        for frame in 0..<Int(buffer.frameLength) {
          let sample = channels[channel][frame]
          guard sample.isFinite else { throw AudioError.damagedAudio }
          if abs(sample) > 0.00001 { return true }
        }
      }
    }
    return false
  }
}
