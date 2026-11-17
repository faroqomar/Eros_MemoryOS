import Foundation

public enum AudioError: Error, Equatable, Sendable {
  case invalidTitle, unsupportedFormat, damagedAudio, invalidDuration, audioTooLarge
  case recordingNotFound, transcriptNotFound, passageNotFound, jobNotFound
  case invalidState, invalidTranscript, invalidArchive, unsupportedVersion
  case storageFailure, insufficientStorage, originalChanged, limitReached
}

public enum RecordingState: String, Codable, Sendable {
  case recording, paused, interrupted, saved
}

public enum TranscriptionJobState: String, Codable, Sendable {
  case running, completed, interrupted, failed
}

public enum AudioFailureCode: String, Codable, Sendable {
  case interrupted, cancelled, modelUnavailable, damagedAudio, processingFailed, storageFailure
}

public enum AudioLimits {
  public static let audioBytes = 262_144_000
  public static let durationSeconds: Double = 7_200
  public static let recordings = 1_000
  public static let metadataBytes = 16_777_216
  public static let passages = 20_000
  public static let transcriptBytes = 1_048_576
  public static let supportedExtensions: Set<String> = [
    "m4a", "wav", "mp3", "aiff", "aif", "caf", "flac",
  ]
}

public struct AudioRecording: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let title: String
  public let createdAt: Date
  public let durationSeconds: Double?
  public let fileName: String
  public let sha256: String?
  public let byteCount: Int
  public let personIDs: [UUID]
  public let sourceRecordIDs: [UUID]
  public let state: RecordingState

  public init(
    id: UUID = UUID(), title: String, createdAt: Date = Date(),
    durationSeconds: Double? = nil, fileName: String, sha256: String? = nil,
    byteCount: Int = 0, personIDs: [UUID] = [], sourceRecordIDs: [UUID] = [],
    state: RecordingState = .recording
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.durationSeconds = durationSeconds
    self.fileName = fileName
    self.sha256 = sha256
    self.byteCount = byteCount
    self.personIDs = personIDs
    self.sourceRecordIDs = sourceRecordIDs
    self.state = state
  }
}

public struct TranscriptWord: Codable, Equatable, Sendable {
  public let text: String
  public let startSeconds: Double
  public let endSeconds: Double
  public let uncertain: Bool

  public init(text: String, startSeconds: Double, endSeconds: Double, uncertain: Bool) {
    self.text = text
    self.startSeconds = startSeconds
    self.endSeconds = endSeconds
    self.uncertain = uncertain
  }
}

public struct TranscriptPassage: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let startSeconds: Double
  public let endSeconds: Double
  public let text: String
  public let uncertain: Bool
  public let words: [TranscriptWord]
  /// A user-supplied label, not biometric speaker identification. Nil means unknown.
  public let speaker: String?

  public init(
    id: UUID = UUID(), startSeconds: Double, endSeconds: Double, text: String,
    uncertain: Bool = true, speaker: String? = nil, words: [TranscriptWord] = []
  ) {
    self.id = id
    self.startSeconds = startSeconds
    self.endSeconds = endSeconds
    self.text = text
    self.uncertain = uncertain
    self.speaker = speaker
    self.words = words
  }
}

public struct TranscriptionOutput: Sendable {
  public let modelID: String
  public let language: String?
  public let passages: [TranscriptPassage]

  public init(modelID: String, language: String?, passages: [TranscriptPassage]) {
    self.modelID = modelID
    self.language = language
    self.passages = passages
  }
}

public protocol TranscriptionProvider: Sendable {
  var id: String { get }
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput
}

public struct TranscriptCorrection: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let passageID: UUID
  public let text: String
  public let speaker: String?
  public let uncertain: Bool
  public let createdAt: Date

  public init(
    id: UUID = UUID(), passageID: UUID, text: String, speaker: String?,
    uncertain: Bool, createdAt: Date = Date()
  ) {
    self.id = id
    self.passageID = passageID
    self.text = text
    self.speaker = speaker
    self.uncertain = uncertain
    self.createdAt = createdAt
  }
}

public struct AudioTranscript: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let recordingID: UUID
  public let engineID: String
  public let modelID: String
  public let language: String?
  public let createdAt: Date
  public let passages: [TranscriptPassage]
  public let corrections: [TranscriptCorrection]

  public init(
    id: UUID = UUID(), recordingID: UUID, engineID: String, modelID: String,
    language: String?, createdAt: Date = Date(), passages: [TranscriptPassage],
    corrections: [TranscriptCorrection] = []
  ) {
    self.id = id
    self.recordingID = recordingID
    self.engineID = engineID
    self.modelID = modelID
    self.language = language
    self.createdAt = createdAt
    self.passages = passages
    self.corrections = corrections
  }

  public var currentPassages: [TranscriptPassage] {
    let latest = Dictionary(
      corrections.map { ($0.passageID, $0) }, uniquingKeysWith: { _, new in new })
    return passages.map { passage in
      guard let correction = latest[passage.id] else { return passage }
      return TranscriptPassage(
        id: passage.id, startSeconds: passage.startSeconds,
        endSeconds: passage.endSeconds, text: correction.text, uncertain: correction.uncertain,
        speaker: correction.speaker,
        words: correction.text.utf8.elementsEqual(passage.text.utf8) ? passage.words : [])
    }
  }
}

public struct TranscriptionJob: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let recordingID: UUID
  public let engineID: String
  public let createdAt: Date
  public let state: TranscriptionJobState
  public let failure: AudioFailureCode?
  public let transcriptID: UUID?

  public init(
    id: UUID = UUID(), recordingID: UUID, engineID: String, createdAt: Date = Date(),
    state: TranscriptionJobState = .running, failure: AudioFailureCode? = nil,
    transcriptID: UUID? = nil
  ) {
    self.id = id
    self.recordingID = recordingID
    self.engineID = engineID
    self.createdAt = createdAt
    self.state = state
    self.failure = failure
    self.transcriptID = transcriptID
  }
}

public struct AudioSnapshot: Codable, Equatable, Sendable {
  public let version: Int
  public let recordings: [AudioRecording]
  public let transcripts: [AudioTranscript]
  public let jobs: [TranscriptionJob]

  public init(
    version: Int = 1, recordings: [AudioRecording] = [],
    transcripts: [AudioTranscript] = [], jobs: [TranscriptionJob] = []
  ) {
    self.version = version
    self.recordings = recordings
    self.transcripts = transcripts
    self.jobs = jobs
  }
}

/// Export retains the immutable engine text, correction history, original hash and stable associations.
/// The recording itself stays local; this is a transcript export, not an audio backup.
public struct TranscriptExport: Codable, Equatable, Sendable {
  public let formatVersion: Int
  public let recording: AudioRecording
  public let transcript: AudioTranscript

  public init(recording: AudioRecording, transcript: AudioTranscript) {
    formatVersion = 1
    self.recording = recording
    self.transcript = transcript
  }
}
