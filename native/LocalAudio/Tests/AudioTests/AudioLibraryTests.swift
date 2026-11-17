import AudioCore
import AudioPersistence
import Foundation
import Testing

private struct Fixture {
  let root: URL
  let directory: URL
  let source: URL
  let repository: FileAudioRepository
  let library: AudioLibrary

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    directory = root.appendingPathComponent("store")
    source = root.appendingPathComponent("source.wav")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    // Byte preservation fixture. Decoder compatibility is tested by the Apple adapter suite.
    try Data([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4]).write(to: source)
    repository = FileAudioRepository(directory: directory)
    library = AudioLibrary(repository: repository)
  }
  func remove() { try? FileManager.default.removeItem(at: root) }
  func recording() async throws -> AudioRecording {
    try await library.importAudio(from: source, title: "Fictional recording", durationSeconds: 5)
  }
}

@Test func importPreservesBytesAndAssociationsAcrossRestart() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let person = UUID()
  let sourceID = UUID()
  let recording = try await f.library.importAudio(
    from: f.source, title: "علي meeting", durationSeconds: 5,
    personIDs: [person], sourceRecordIDs: [sourceID])
  let localURL = try await f.library.recordingURL(id: recording.id)
  #expect(try Data(contentsOf: localURL) == Data(contentsOf: f.source))
  #expect(recording.sha256?.count == 64)
  #expect(recording.state == .saved)
  let reopened = try await FileAudioRepository(directory: f.directory).snapshot()
  #expect(reopened.recordings == [recording])
  #expect(reopened.recordings[0].personIDs == [person])
  #expect(reopened.recordings[0].sourceRecordIDs == [sourceID])
}

@Test func transcriptCorrectionAndExportRetainOriginalSource() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  let job = try await f.library.beginTranscription(
    recordingID: recording.id, engineID: "whisper.cpp")
  let passage = TranscriptPassage(startSeconds: 0.3, endSeconds: 2.7, text: "علي at Baghdad")
  let transcript = try await f.library.completeTranscription(
    jobID: job.id,
    output: TranscriptionOutput(
      modelID: "tiny-multilingual-pinned", language: "ar", passages: [passage]))
  try await f.library.correctPassage(
    transcriptID: transcript.id, passageID: passage.id,
    text: "علي في بغداد", speaker: "Ali (user label)", uncertain: false)
  let person = UUID()
  let source = UUID()
  try await f.library.updateAssociations(
    recordingID: recording.id, personIDs: [person], sourceRecordIDs: [source])
  let export = try JSONDecoder().decode(
    TranscriptExport.self,
    from: await f.library.exportTranscript(transcriptID: transcript.id))
  #expect(export.formatVersion == 1)
  #expect(export.recording.personIDs == [person])
  #expect(export.recording.sourceRecordIDs == [source])
  #expect(export.recording.sha256 == recording.sha256)
  #expect(export.transcript.passages == [passage])
  #expect(export.transcript.currentPassages[0].text == "علي في بغداد")
  #expect(export.transcript.currentPassages[0].id == passage.id)
  #expect(export.transcript.currentPassages[0].startSeconds == 0.3)
  #expect(export.transcript.currentPassages[0].speaker == "Ali (user label)")
  #expect(export.transcript.corrections.count == 1)
  #expect(
    try Data(contentsOf: await f.library.recordingURL(id: recording.id))
      == Data(contentsOf: f.source))
  #expect(
    try await FileAudioRepository(directory: f.directory).snapshot().transcripts[0]
      == export.transcript)
}

@Test func recoveryRunsOnlyAtOpenAndKeepsInterruptedDraftBytes() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let draft = try await f.library.createDraft(title: "Interrupted recording", fileExtension: "caf")
  let target = try await f.library.recordingURL(id: draft.id)
  try Data([1, 2, 3, 4]).write(to: target)
  try await f.library.setRecordingState(id: draft.id, state: .paused)
  #expect(try await f.library.snapshot().recordings[0].state == .paused)
  let reopened = AudioLibrary(repository: FileAudioRepository(directory: f.directory))
  #expect(try await reopened.snapshot().recordings[0].state == .interrupted)
  #expect(try Data(contentsOf: await reopened.recordingURL(id: draft.id)) == Data([1, 2, 3, 4]))
  let saved = try await reopened.finalizeDraft(id: draft.id, durationSeconds: 1.5)
  #expect(saved.id == draft.id)
  #expect(saved.state == .saved)
  await #expect(throws: AudioError.invalidState) {
    try await reopened.setRecordingState(id: draft.id, state: .recording)
  }
}

@Test func interruptedTranscriptionCanRetryWithoutLosingOlderResult() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  let firstJob = try await f.library.beginTranscription(
    recordingID: recording.id, engineID: "WhisperKit")
  let original = try await f.library.completeTranscription(
    jobID: firstJob.id,
    output: TranscriptionOutput(
      modelID: "tiny", language: "en",
      passages: [
        TranscriptPassage(startSeconds: 0, endSeconds: 3, text: "Original result")
      ]))
  let running = try await f.library.beginTranscription(
    recordingID: recording.id, engineID: "whisper.cpp")
  let reopened = AudioLibrary(repository: FileAudioRepository(directory: f.directory))
  let snapshot = try await reopened.snapshot()
  #expect(snapshot.transcripts == [original])
  #expect(snapshot.jobs.first(where: { $0.id == running.id })?.state == .interrupted)
  await #expect(throws: AudioError.invalidState) {
    try await reopened.completeTranscription(
      jobID: running.id,
      output: TranscriptionOutput(modelID: "tiny", language: nil, passages: []))
  }
  let retry = try await reopened.beginTranscription(
    recordingID: recording.id, engineID: "whisper.cpp")
  #expect(retry.id != running.id)
  #expect(try await reopened.snapshot().transcripts == [original])
}

@Test(arguments: [Double.nan, -Double.infinity, -1.0, 0.0, 7_201.0])
func invalidDurationDoesNotImport(_ duration: Double) async throws {
  let f = try Fixture()
  defer { f.remove() }
  await #expect(throws: AudioError.invalidDuration) {
    try await f.library.importAudio(from: f.source, title: "Invalid", durationSeconds: duration)
  }
  #expect(try await f.library.snapshot().recordings.isEmpty)
}

@Test(arguments: [
  TranscriptPassage(startSeconds: -1, endSeconds: 2, text: "Invalid"),
  TranscriptPassage(startSeconds: 2, endSeconds: 1, text: "Invalid"),
  TranscriptPassage(startSeconds: 0, endSeconds: 40, text: "Invalid"),
  TranscriptPassage(startSeconds: .nan, endSeconds: 1, text: "Invalid"),
  TranscriptPassage(startSeconds: 0, endSeconds: 1, text: "  "),
])
func malformedProviderOutputDoesNotChangeDurableResult(_ passage: TranscriptPassage) async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  let job = try await f.library.beginTranscription(recordingID: recording.id, engineID: "test")
  await #expect(throws: AudioError.invalidTranscript) {
    try await f.library.completeTranscription(
      jobID: job.id,
      output: TranscriptionOutput(modelID: "test", language: nil, passages: [passage]))
  }
  #expect(try await f.library.snapshot().transcripts.isEmpty)
  #expect(try await f.library.snapshot().jobs[0].state == .running)
}

@Test func saveFailurePreservesPreviousStateAndImportedSource() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let first = try await f.recording()
  let archive = f.directory.appendingPathComponent("library.json")
  let preserved = f.directory.appendingPathComponent("preserved.json")
  try FileManager.default.moveItem(at: archive, to: preserved)
  try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false)
  await #expect(throws: (any Error).self) {
    try await f.library.importAudio(from: f.source, title: "Second", durationSeconds: 1)
  }
  #expect(try await f.library.snapshot().recordings == [first])
  #expect(FileManager.default.fileExists(atPath: f.source.path))
  #expect(
    try FileManager.default.contentsOfDirectory(
      atPath: f.directory.appendingPathComponent("originals").path
    ).count == 1)
  try FileManager.default.removeItem(at: archive)
  try FileManager.default.moveItem(at: preserved, to: archive)
  #expect(try await FileAudioRepository(directory: f.directory).snapshot().recordings == [first])
}

@Test func changedOriginalRejectsPlaybackTranscriptionAndExport() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  let job = try await f.library.beginTranscription(recordingID: recording.id, engineID: "test")
  let transcript = try await f.library.completeTranscription(
    jobID: job.id,
    output: TranscriptionOutput(modelID: "tiny", language: nil, passages: []))
  let url = try await f.library.recordingURL(id: recording.id)
  try Data([9, 8, 7, 6]).write(to: url)
  await #expect(throws: AudioError.originalChanged) {
    try await f.library.recordingURL(id: recording.id)
  }
  await #expect(throws: AudioError.originalChanged) {
    try await f.library.beginTranscription(recordingID: recording.id, engineID: "test")
  }
  await #expect(throws: AudioError.originalChanged) {
    try await f.library.exportTranscript(transcriptID: transcript.id)
  }
}

@Test func unsupportedAndSymlinkInputsDoNotCreateRecords() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let link = f.root.appendingPathComponent("link.wav")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: f.source)
  await #expect(throws: AudioError.damagedAudio) {
    try await f.library.importAudio(from: link, title: "Link", durationSeconds: 1)
  }
  await #expect(throws: AudioError.unsupportedFormat) {
    try await f.library.createDraft(title: "Traversal", fileExtension: "../wav")
  }
  #expect(try await f.library.snapshot().recordings.isEmpty)
}

@Test func unsupportedArchiveVersionLeavesSourceUntouched() async throws {
  let f = try Fixture()
  defer { f.remove() }
  _ = try await f.library.snapshot()
  let archive = f.directory.appendingPathComponent("library.json")
  let data = try JSONEncoder().encode(AudioSnapshot(version: 2))
  try data.write(to: archive)
  await #expect(throws: AudioError.unsupportedVersion) {
    try await FileAudioRepository(directory: f.directory).snapshot()
  }
  #expect(try Data(contentsOf: archive) == data)
}

@Test func twoEnginesKeepIndependentResultsAndOriginalWordEvidence() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  let word = TranscriptWord(text: "Zainab", startSeconds: 0.2, endSeconds: 1, uncertain: true)
  let passage = TranscriptPassage(
    startSeconds: 0, endSeconds: 2, text: "Zainab came",
    words: [word])
  let first = try await f.library.beginTranscription(
    recordingID: recording.id, engineID: "WhisperKit")
  let a = try await f.library.completeTranscription(
    jobID: first.id,
    output: TranscriptionOutput(modelID: "tiny", language: "en", passages: [passage]))
  let second = try await f.library.beginTranscription(
    recordingID: recording.id, engineID: "whisper.cpp")
  let b = try await f.library.completeTranscription(
    jobID: second.id,
    output: TranscriptionOutput(
      modelID: "tiny", language: "en",
      passages: [
        TranscriptPassage(startSeconds: 0, endSeconds: 2, text: "Zaynab came")
      ]))
  try await f.library.correctPassage(
    transcriptID: a.id, passageID: passage.id, text: passage.text, speaker: "Fictional speaker",
    uncertain: true)
  let speakerOnly = try await f.library.snapshot().transcripts.first { $0.id == a.id }
  #expect(speakerOnly?.currentPassages[0].words == [word])
  #expect(speakerOnly?.currentPassages[0].speaker == "Fictional speaker")
  try await f.library.correctPassage(
    transcriptID: a.id, passageID: passage.id, text: "زينب came", uncertain: false)
  let snapshot = try await f.library.snapshot()
  #expect(snapshot.transcripts.count == 2)
  #expect(snapshot.transcripts.first(where: { $0.id == b.id }) == b)
  let corrected = try #require(snapshot.transcripts.first(where: { $0.id == a.id }))
  #expect(corrected.passages[0].words == [word])
  #expect(corrected.currentPassages[0].words.isEmpty)
  #expect(corrected.passages[0].speaker == nil)
}

private struct CancelledProvider: TranscriptionProvider {
  let id = "cancelled-test"
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    throw CancellationError()
  }
}

@Test func cancellationPersistsInterruptedJobAndKeepsAudio() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let recording = try await f.recording()
  await #expect(throws: CancellationError.self) {
    try await f.library.transcribe(
      recordingID: recording.id, provider: CancelledProvider(), modelDirectory: f.root)
  }
  let snapshot = try await f.library.snapshot()
  #expect(snapshot.jobs.count == 1)
  #expect(snapshot.jobs[0].state == .interrupted)
  #expect(snapshot.jobs[0].failure == .cancelled)
  #expect(snapshot.transcripts.isEmpty)
  #expect(snapshot.recordings == [recording])
}

@Test func traversalInStoredMetadataFailsWithoutReadingOutsideDirectory() async throws {
  let f = try Fixture()
  defer { f.remove() }
  _ = try await f.library.snapshot()
  let recording = AudioRecording(title: "Tampered", fileName: "../source.wav")
  let archive = f.directory.appendingPathComponent("library.json")
  let data = try JSONEncoder().encode(AudioSnapshot(recordings: [recording]))
  try data.write(to: archive)
  await #expect(throws: AudioError.invalidArchive) {
    try await FileAudioRepository(directory: f.directory).snapshot()
  }
  #expect(try Data(contentsOf: archive) == data)
  #expect(FileManager.default.fileExists(atPath: f.source.path))
}

@Test(arguments: [false, true])
func emptyInterruptedDraftCanBeDiscardedAfterRestart(zeroByteFile: Bool) async throws {
  let f = try Fixture()
  defer { f.remove() }
  let draft = try await f.library.createDraft(title: "Start failed", fileExtension: "caf")
  let url = try await f.library.recordingURL(id: draft.id)
  if zeroByteFile { try Data().write(to: url) }
  // A fresh repository recovers an unfinished previous session as interrupted.
  let reopened = AudioLibrary(repository: FileAudioRepository(directory: f.directory))
  #expect(try await reopened.snapshot().recordings.first?.state == .interrupted)
  #expect(try await reopened.discardEmptyDraft(id: draft.id))
  #expect(try await reopened.snapshot().recordings.isEmpty)
  #expect(try await FileAudioRepository(directory: f.directory).snapshot().recordings.isEmpty)
  // A delayed platform event cannot recreate the discarded draft or report a spurious failure.
  try await reopened.setRecordingState(id: draft.id, state: .interrupted)
  #expect(try await reopened.snapshot().recordings.isEmpty)
  await #expect(throws: AudioError.recordingNotFound) {
    try await reopened.setRecordingState(id: UUID(), state: .interrupted)
  }
  await #expect(throws: AudioError.recordingNotFound) {
    try await reopened.setRecordingState(id: draft.id, state: .recording)
  }
}

@Test func emptyDraftRollbackPreservesPartialBytesAndSavedAudio() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let draft = try await f.library.createDraft(title: "Keep captured bytes", fileExtension: "caf")
  let url = try await f.library.recordingURL(id: draft.id)
  let bytes = Data([1, 2, 3])
  try bytes.write(to: url)
  try await f.library.setRecordingState(id: draft.id, state: .interrupted)
  #expect(try await !f.library.discardEmptyDraft(id: draft.id))
  #expect(try await f.library.snapshot().recordings.first?.id == draft.id)
  #expect(try Data(contentsOf: url) == bytes)
  _ = try await f.library.finalizeDraft(id: draft.id, durationSeconds: 1)
  #expect(try await !f.library.discardEmptyDraft(id: draft.id))
  #expect(try Data(contentsOf: url) == bytes)
}

@Test func emptyDraftRollbackDoesNotDiscardLiveDraftOrSymlink() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let draft = try await f.library.createDraft(title: "Keep active", fileExtension: "caf")
  #expect(try await !f.library.discardEmptyDraft(id: draft.id))
  let url = try await f.library.recordingURL(id: draft.id)
  try FileManager.default.createSymbolicLink(at: url, withDestinationURL: f.source)
  try await f.library.setRecordingState(id: draft.id, state: .interrupted)
  await #expect(throws: AudioError.damagedAudio) {
    try await f.library.discardEmptyDraft(id: draft.id)
  }
  #expect(try await f.library.snapshot().recordings.first?.id == draft.id)
  #expect(try Data(contentsOf: f.source) == Data([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4]))
}

@Test func emptyDraftRollbackWriteFailureRetainsMetadataForRetry() async throws {
  let f = try Fixture()
  defer { f.remove() }
  let draft = try await f.library.createDraft(title: "Retry later", fileExtension: "caf")
  try await f.library.setRecordingState(id: draft.id, state: .interrupted)
  let archive = f.directory.appendingPathComponent("library.json")
  let preserved = f.directory.appendingPathComponent("preserved.json")
  try FileManager.default.moveItem(at: archive, to: preserved)
  try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false)
  await #expect(throws: (any Error).self) { try await f.library.discardEmptyDraft(id: draft.id) }
  #expect(try await f.library.snapshot().recordings.first?.id == draft.id)
  try FileManager.default.removeItem(at: archive)
  try FileManager.default.moveItem(at: preserved, to: archive)
  #expect(
    try await FileAudioRepository(directory: f.directory).snapshot().recordings.first?.id
      == draft.id)
  #expect(try await f.library.discardEmptyDraft(id: draft.id))
}
