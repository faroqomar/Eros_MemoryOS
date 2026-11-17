import AudioCore
import CryptoKit
import Foundation

/// Inject one instance for this app-private directory. The actor owns the metadata transaction;
/// provider SDKs and the recorder never mutate the archive. Original saved files are immutable.
public actor FileAudioRepository: AudioRepository {
  private let directory: URL
  private var cached: AudioSnapshot?
  private var discardedEmptyDraftIDs: Set<UUID> = []
  private var metadataURL: URL { directory.appendingPathComponent("library.json") }
  private var originalsURL: URL { directory.appendingPathComponent("originals", isDirectory: true) }

  public init(directory: URL) { self.directory = directory }

  public func snapshot() throws -> AudioSnapshot { try load() }

  public func createDraft(
    title: String, fileExtension: String, personIDs: [UUID], sourceRecordIDs: [UUID]
  ) throws -> AudioRecording {
    let current = try load()
    try validateNew(
      title: title, fileExtension: fileExtension, personIDs: personIDs,
      sourceRecordIDs: sourceRecordIDs)
    guard current.recordings.count < AudioLimits.recordings else { throw AudioError.limitReached }
    try capacity(required: 5_242_880)
    let id = UUID()
    let recording = AudioRecording(
      id: id, title: title, fileName: id.uuidString + "." + fileExtension.lowercased(),
      personIDs: personIDs, sourceRecordIDs: sourceRecordIDs)
    try commit(
      AudioSnapshot(
        recordings: current.recordings + [recording], transcripts: current.transcripts,
        jobs: current.jobs))
    return recording
  }

  public func recordingURL(id: UUID) throws -> URL {
    let recording = try findRecording(id, in: load())
    let url = originalsURL.appendingPathComponent(recording.fileName)
    if recording.state == .saved {
      let actual = try inspect(url)
      guard actual.hash == recording.sha256, actual.bytes == recording.byteCount else {
        throw AudioError.originalChanged
      }
    } else if FileManager.default.fileExists(atPath: url.path) {
      try regularFile(url)
    }
    return url
  }

  public func finalizeDraft(id: UUID, durationSeconds: Double) throws -> AudioRecording {
    let current = try load()
    let old = try findRecording(id, in: current)
    guard old.state != .saved else { throw AudioError.invalidState }
    try AudioValidation.duration(durationSeconds)
    let url = originalsURL.appendingPathComponent(old.fileName)
    let actual = try inspect(url)
    try protect(url)
    let saved = AudioRecording(
      id: old.id, title: old.title, createdAt: old.createdAt,
      durationSeconds: durationSeconds, fileName: old.fileName, sha256: actual.hash,
      byteCount: actual.bytes, personIDs: old.personIDs, sourceRecordIDs: old.sourceRecordIDs,
      state: .saved)
    try replace(saved, in: current)
    return saved
  }

  public func setRecordingState(id: UUID, state: RecordingState) throws {
    let current = try load()
    // A queued interruption can arrive after an empty draft was rolled back.
    if state == .interrupted, discardedEmptyDraftIDs.contains(id) { return }
    let old = try findRecording(id, in: current)
    guard old.state != .saved, state != .saved else { throw AudioError.invalidState }
    try replace(copy(old, state: state), in: current)
  }

  public func discardEmptyDraft(id: UUID) throws -> Bool {
    let current = try load()
    guard let draft = current.recordings.first(where: { $0.id == id }) else { return true }
    guard draft.state == .interrupted else { return false }
    let url = originalsURL.appendingPathComponent(draft.fileName)
    do {
      let values = try url.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard values.isRegularFile == true, values.isSymbolicLink != true else {
        throw AudioError.damagedAudio
      }
      guard values.fileSize == 0 else { return false }
    } catch {
      let cocoa = error as NSError
      guard cocoa.domain == NSCocoaErrorDomain, cocoa.code == NSFileReadNoSuchFileError else {
        throw map(error)
      }
    }
    // Do not unlink files here. Even an empty file remains untouched; this operation
    // only rolls back metadata after the workflow has closed its recording session.
    try commit(
      AudioSnapshot(
        recordings: current.recordings.filter { $0.id != id },
        transcripts: current.transcripts, jobs: current.jobs))
    discardedEmptyDraftIDs.insert(id)
    return true
  }

  /// The caller validates decoder support and duration before import. The repository copies the
  /// original bytes without conversion; transcription may create its own disposable decode buffer.
  public func importAudio(
    from source: URL, title: String, durationSeconds: Double, personIDs: [UUID],
    sourceRecordIDs: [UUID]
  ) throws -> AudioRecording {
    let current = try load()
    let ext = source.pathExtension.lowercased()
    try validateNew(
      title: title, fileExtension: ext, personIDs: personIDs, sourceRecordIDs: sourceRecordIDs)
    try AudioValidation.duration(durationSeconds)
    guard current.recordings.count < AudioLimits.recordings else { throw AudioError.limitReached }
    let original = try inspect(source)
    try capacity(required: Int64(original.bytes) + 5_242_880)
    let id = UUID()
    let name = id.uuidString + "." + ext
    let target = originalsURL.appendingPathComponent(name)
    do {
      try FileManager.default.copyItem(at: source, to: target)
      try protect(target)
      let copied = try inspect(target)
      guard copied.hash == original.hash, copied.bytes == original.bytes else {
        throw AudioError.originalChanged
      }
      let saved = AudioRecording(
        id: id, title: title, durationSeconds: durationSeconds,
        fileName: name, sha256: copied.hash, byteCount: copied.bytes,
        personIDs: personIDs, sourceRecordIDs: sourceRecordIDs, state: .saved)
      try commit(
        AudioSnapshot(
          recordings: current.recordings + [saved], transcripts: current.transcripts,
          jobs: current.jobs))
      return saved
    } catch {
      // Only the uncommitted copy belongs to this failed transaction. Never remove the input.
      try? FileManager.default.removeItem(at: target)
      throw map(error)
    }
  }

  public func beginTranscription(recordingID: UUID, engineID: String) throws -> TranscriptionJob {
    let current = try load()
    let recording = try findRecording(recordingID, in: current)
    guard recording.state == .saved,
      !engineID.isEmpty, engineID.utf8.count <= 200,
      !current.jobs.contains(where: { $0.recordingID == recordingID && $0.state == .running })
    else { throw AudioError.invalidState }
    _ = try recordingURL(id: recordingID)
    guard current.jobs.count < 10_000 else { throw AudioError.limitReached }
    let job = TranscriptionJob(recordingID: recordingID, engineID: engineID)
    try commit(
      AudioSnapshot(
        recordings: current.recordings, transcripts: current.transcripts, jobs: current.jobs + [job]
      ))
    return job
  }

  public func completeTranscription(jobID: UUID, output: TranscriptionOutput) throws
    -> AudioTranscript
  {
    let current = try load()
    guard let job = current.jobs.first(where: { $0.id == jobID }) else {
      throw AudioError.jobNotFound
    }
    guard job.state == .running else { throw AudioError.invalidState }
    let recording = try findRecording(job.recordingID, in: current)
    guard let duration = recording.durationSeconds else { throw AudioError.invalidState }
    try AudioValidation.passages(output.passages, duration: duration)
    guard !output.modelID.isEmpty, output.modelID.utf8.count <= 1_000,
      (output.language?.utf8.count ?? 0) <= 100
    else { throw AudioError.invalidTranscript }
    _ = try recordingURL(id: recording.id)
    let transcript = AudioTranscript(
      recordingID: recording.id, engineID: job.engineID,
      modelID: output.modelID, language: output.language, passages: output.passages)
    let completed = TranscriptionJob(
      id: job.id, recordingID: job.recordingID, engineID: job.engineID,
      createdAt: job.createdAt, state: .completed, transcriptID: transcript.id)
    try commit(
      AudioSnapshot(
        recordings: current.recordings, transcripts: current.transcripts + [transcript],
        jobs: current.jobs.map { $0.id == job.id ? completed : $0 }))
    return transcript
  }

  public func interruptTranscription(jobID: UUID, failure: AudioFailureCode) throws {
    let current = try load()
    guard let job = current.jobs.first(where: { $0.id == jobID }) else {
      throw AudioError.jobNotFound
    }
    guard job.state == .running else { return }
    let state: TranscriptionJobState =
      [.interrupted, .cancelled].contains(failure) ? .interrupted : .failed
    let changed = TranscriptionJob(
      id: job.id, recordingID: job.recordingID, engineID: job.engineID,
      createdAt: job.createdAt, state: state, failure: failure)
    try commit(
      AudioSnapshot(
        recordings: current.recordings, transcripts: current.transcripts,
        jobs: current.jobs.map { $0.id == job.id ? changed : $0 }))
  }

  public func correctPassage(
    transcriptID: UUID, passageID: UUID, text: String, speaker: String?, uncertain: Bool
  ) throws {
    let current = try load()
    guard let old = current.transcripts.first(where: { $0.id == transcriptID }) else {
      throw AudioError.transcriptNotFound
    }
    guard old.passages.contains(where: { $0.id == passageID }) else {
      throw AudioError.passageNotFound
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      text.utf8.count <= AudioLimits.transcriptBytes, (speaker?.utf8.count ?? 0) <= 200,
      old.corrections.count < 20_000
    else { throw AudioError.invalidTranscript }
    let correction = TranscriptCorrection(
      passageID: passageID, text: text, speaker: speaker, uncertain: uncertain)
    let changed = AudioTranscript(
      id: old.id, recordingID: old.recordingID, engineID: old.engineID,
      modelID: old.modelID, language: old.language, createdAt: old.createdAt,
      passages: old.passages,
      corrections: old.corrections + [correction])
    try commit(
      AudioSnapshot(
        recordings: current.recordings,
        transcripts: current.transcripts.map { $0.id == old.id ? changed : $0 }, jobs: current.jobs)
    )
  }

  public func updateAssociations(recordingID: UUID, personIDs: [UUID], sourceRecordIDs: [UUID])
    throws
  {
    let current = try load()
    let old = try findRecording(recordingID, in: current)
    try AudioValidation.associations(personIDs)
    try AudioValidation.associations(sourceRecordIDs)
    let changed = AudioRecording(
      id: old.id, title: old.title, createdAt: old.createdAt,
      durationSeconds: old.durationSeconds, fileName: old.fileName, sha256: old.sha256,
      byteCount: old.byteCount,
      personIDs: personIDs, sourceRecordIDs: sourceRecordIDs, state: old.state)
    try replace(changed, in: current)
  }

  public func exportTranscript(transcriptID: UUID) throws -> Data {
    let current = try load()
    guard let transcript = current.transcripts.first(where: { $0.id == transcriptID }) else {
      throw AudioError.transcriptNotFound
    }
    let recording = try findRecording(transcript.recordingID, in: current)
    _ = try recordingURL(id: recording.id)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(TranscriptExport(recording: recording, transcript: transcript))
  }

  private func load() throws -> AudioSnapshot {
    if let cached { return cached }
    do {
      try prepareDirectory()
      guard FileManager.default.fileExists(atPath: metadataURL.path) else {
        let empty = AudioSnapshot()
        cached = empty
        return empty
      }
      try regularFile(metadataURL)
      let size = try metadataURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
      guard size <= AudioLimits.metadataBytes else { throw AudioError.invalidArchive }
      let data = try Data(contentsOf: metadataURL)
      guard data.count <= AudioLimits.metadataBytes else { throw AudioError.invalidArchive }
      let decoded = try JSONDecoder().decode(AudioSnapshot.self, from: data)
      try validate(decoded)
      let recovered = AudioSnapshot(
        recordings: decoded.recordings.map {
          [.recording, .paused].contains($0.state) ? copy($0, state: .interrupted) : $0
        }, transcripts: decoded.transcripts,
        jobs: decoded.jobs.map {
          $0.state == .running
            ? TranscriptionJob(
              id: $0.id, recordingID: $0.recordingID, engineID: $0.engineID,
              createdAt: $0.createdAt, state: .interrupted, failure: .interrupted) : $0
        })
      if recovered != decoded { try commit(recovered) } else { cached = decoded }
      return recovered
    } catch { throw map(error) }
  }

  private func commit(_ snapshot: AudioSnapshot) throws {
    do {
      try validate(snapshot)
      let data = try JSONEncoder().encode(snapshot)
      guard data.count <= AudioLimits.metadataBytes else { throw AudioError.limitReached }
      try prepareDirectory()
      if FileManager.default.fileExists(atPath: metadataURL.path) { try regularFile(metadataURL) }
      #if os(iOS)
        try data.write(to: metadataURL, options: [.atomic, .completeFileProtection])
      #else
        try data.write(to: metadataURL, options: .atomic)
      #endif
      cached = snapshot
    } catch { throw map(error) }
  }

  private func validate(_ value: AudioSnapshot) throws {
    guard value.version == 1 else { throw AudioError.unsupportedVersion }
    guard value.recordings.count <= AudioLimits.recordings, value.jobs.count <= 10_000,
      value.transcripts.count <= 10_000,
      Set(value.recordings.map(\.id)).count == value.recordings.count,
      Set(value.transcripts.map(\.id)).count == value.transcripts.count,
      Set(value.jobs.map(\.id)).count == value.jobs.count
    else { throw AudioError.invalidArchive }
    let records = Dictionary(uniqueKeysWithValues: value.recordings.map { ($0.id, $0) })
    for recording in value.recordings {
      try AudioValidation.title(recording.title)
      try AudioValidation.associations(recording.personIDs)
      try AudioValidation.associations(recording.sourceRecordIDs)
      let ext = (recording.fileName as NSString).pathExtension
      guard AudioLimits.supportedExtensions.contains(ext),
        recording.fileName == recording.id.uuidString + "." + ext,
        recording.byteCount >= 0, recording.byteCount <= AudioLimits.audioBytes
      else { throw AudioError.invalidArchive }
      if recording.state == .saved {
        guard let duration = recording.durationSeconds, let hash = recording.sha256,
          hash.count == 64, hash.allSatisfy({ $0.isHexDigit }), recording.byteCount > 0
        else { throw AudioError.invalidArchive }
        try AudioValidation.duration(duration)
      }
    }
    for transcript in value.transcripts {
      guard let recording = records[transcript.recordingID], recording.state == .saved,
        let duration = recording.durationSeconds, !transcript.modelID.isEmpty,
        transcript.modelID.utf8.count <= 1_000,
        !transcript.engineID.isEmpty, transcript.engineID.utf8.count <= 200,
        (transcript.language?.utf8.count ?? 0) <= 100, transcript.corrections.count <= 20_000,
        Set(transcript.corrections.map(\.id)).count == transcript.corrections.count
      else { throw AudioError.invalidArchive }
      try AudioValidation.passages(transcript.passages, duration: duration)
      let passageIDs = Set(transcript.passages.map(\.id))
      for correction in transcript.corrections {
        guard passageIDs.contains(correction.passageID),
          !correction.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          correction.text.utf8.count <= AudioLimits.transcriptBytes,
          (correction.speaker?.utf8.count ?? 0) <= 200
        else { throw AudioError.invalidArchive }
      }
    }
    let transcriptByID = Dictionary(uniqueKeysWithValues: value.transcripts.map { ($0.id, $0) })
    for job in value.jobs {
      guard records[job.recordingID]?.state == .saved, !job.engineID.isEmpty,
        job.engineID.utf8.count <= 200
      else { throw AudioError.invalidArchive }
      if job.state == .completed {
        guard let id = job.transcriptID, let transcript = transcriptByID[id],
          transcript.recordingID == job.recordingID, transcript.engineID == job.engineID
        else { throw AudioError.invalidArchive }
      } else if job.transcriptID != nil {
        throw AudioError.invalidArchive
      }
    }
  }

  private func validateNew(
    title: String, fileExtension: String, personIDs: [UUID], sourceRecordIDs: [UUID]
  ) throws {
    try AudioValidation.title(title)
    guard AudioLimits.supportedExtensions.contains(fileExtension.lowercased()) else {
      throw AudioError.unsupportedFormat
    }
    try AudioValidation.associations(personIDs)
    try AudioValidation.associations(sourceRecordIDs)
  }
  private func findRecording(_ id: UUID, in value: AudioSnapshot) throws -> AudioRecording {
    guard let recording = value.recordings.first(where: { $0.id == id }) else {
      throw AudioError.recordingNotFound
    }
    return recording
  }
  private func replace(_ recording: AudioRecording, in current: AudioSnapshot) throws {
    try commit(
      AudioSnapshot(
        recordings: current.recordings.map { $0.id == recording.id ? recording : $0 },
        transcripts: current.transcripts, jobs: current.jobs))
  }
  private func copy(_ old: AudioRecording, state: RecordingState) -> AudioRecording {
    AudioRecording(
      id: old.id, title: old.title, createdAt: old.createdAt, durationSeconds: old.durationSeconds,
      fileName: old.fileName, sha256: old.sha256, byteCount: old.byteCount,
      personIDs: old.personIDs,
      sourceRecordIDs: old.sourceRecordIDs, state: state)
  }
  private func prepareDirectory() throws {
    guard directory.isFileURL else { throw AudioError.storageFailure }
    for folder in [directory, originalsURL] {
      if FileManager.default.fileExists(atPath: folder.path) {
        let values = try folder.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
          throw AudioError.storageFailure
        }
      }
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try protect(folder)
      var base = folder
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try base.setResourceValues(values)
    }
  }
  private func protect(_ url: URL) throws {
    #if os(iOS)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    #endif
  }
  private func regularFile(_ url: URL) throws {
    guard url.isFileURL else { throw AudioError.damagedAudio }
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw AudioError.damagedAudio
    }
  }
  private func inspect(_ url: URL) throws -> (hash: String, bytes: Int) {
    do {
      try regularFile(url)
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
      guard size > 0 else { throw AudioError.damagedAudio }
      guard size <= AudioLimits.audioBytes else { throw AudioError.audioTooLarge }
      let file = try FileHandle(forReadingFrom: url)
      defer { try? file.close() }
      var digest = SHA256()
      var bytes = 0
      while let chunk = try file.read(upToCount: 1_048_576), !chunk.isEmpty {
        bytes += chunk.count
        guard bytes <= AudioLimits.audioBytes else { throw AudioError.audioTooLarge }
        digest.update(data: chunk)
      }
      guard bytes == size else { throw AudioError.originalChanged }
      return (digest.finalize().map { String(format: "%02x", $0) }.joined(), bytes)
    } catch { throw map(error) }
  }
  private func capacity(required: Int64) throws {
    let values = try directory.resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey
    ])
    if let available = values.volumeAvailableCapacityForImportantUsage, available < required {
      throw AudioError.insufficientStorage
    }
  }
  private func map(_ error: any Error) -> any Error {
    if let error = error as? AudioError { return error }
    if (error as NSError).domain == NSCocoaErrorDomain,
      (error as NSError).code == NSFileWriteOutOfSpaceError
    {
      return AudioError.insufficientStorage
    }
    return AudioError.storageFailure
  }
}
