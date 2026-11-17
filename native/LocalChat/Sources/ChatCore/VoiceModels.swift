import Foundation

/// Speech is replaceable; the chat domain knows identifiers and text, never files or SDKs.
public protocol VoiceTranscribing: Sendable {
  func transcribe(recordingID: UUID) async throws -> VoiceTranscript
}

public struct UnavailableVoiceTranscriber: VoiceTranscribing {
  public init() {}
  public func transcribe(recordingID: UUID) async throws -> VoiceTranscript {
    throw VoiceFailure.modelUnavailable
  }
}

public enum VoiceFailure: String, Error, Codable, Sendable {
  case modelUnavailable, recordingUnavailable, noSpeech, transcriptionFailed, interrupted, storage
}

public enum VoiceStatus: String, Codable, Sendable {
  case queued, transcribing, failed, interrupted
}

public struct VoicePassage: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let startSeconds: Double
  public let endSeconds: Double
  public let text: String
  public let uncertain: Bool

  public init(
    id: UUID, startSeconds: Double, endSeconds: Double, text: String, uncertain: Bool = true
  ) {
    self.id = id
    self.startSeconds = startSeconds
    self.endSeconds = endSeconds
    self.text = text
    self.uncertain = uncertain
  }
}

public struct VoiceTranscript: Codable, Equatable, Sendable {
  public let id: UUID
  public let recordingID: UUID
  public let passageIDs: [UUID]
  public let text: String
  public let passages: [VoicePassage]

  public init(
    id: UUID, recordingID: UUID, passageIDs: [UUID], text: String, passages: [VoicePassage] = []
  ) {
    self.id = id
    self.recordingID = recordingID
    self.passageIDs = passageIDs
    self.text = text
    self.passages = passages
  }
}

public struct PendingVoice: Codable, Equatable, Sendable {
  public let jobID: UUID
  public let recordingID: UUID
  public let durationSeconds: Double
  public var status: VoiceStatus
  public var failure: VoiceFailure?
  public var transcript: VoiceTranscript?

  public init(
    jobID: UUID = UUID(), recordingID: UUID, durationSeconds: Double,
    status: VoiceStatus = .queued, failure: VoiceFailure? = nil, transcript: VoiceTranscript? = nil
  ) {
    self.jobID = jobID
    self.recordingID = recordingID
    self.durationSeconds = durationSeconds
    self.status = status
    self.failure = failure
    self.transcript = transcript
  }
}

public struct ChatVoiceAttachment: Codable, Equatable, Sendable {
  public let recordingID: UUID
  public let transcriptID: UUID
  public let passageIDs: [UUID]
  public let durationSeconds: Double
  public let passages: [VoicePassage]

  public init(
    recordingID: UUID, transcriptID: UUID, passageIDs: [UUID], durationSeconds: Double,
    passages: [VoicePassage] = []
  ) {
    self.recordingID = recordingID
    self.transcriptID = transcriptID
    self.passageIDs = passageIDs
    self.durationSeconds = durationSeconds
    self.passages = passages
  }

  func validate(textByteLimit: Int = ChatLimits.draftBytes) throws {
    guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= 7_200,
      passageIDs.count <= 20_000, Set(passageIDs).count == passageIDs.count,
      passages.isEmpty || passages.map(\.id) == passageIDs,
      passages.allSatisfy({
        $0.startSeconds.isFinite && $0.endSeconds.isFinite && $0.startSeconds >= 0
          && $0.endSeconds >= $0.startSeconds && $0.endSeconds <= durationSeconds + 1
          && $0.text.utf8.count <= textByteLimit
      }), passages.reduce(0, { $0 + $1.text.utf8.count }) <= textByteLimit
    else { throw ChatError.invalidArchive }
  }
}
