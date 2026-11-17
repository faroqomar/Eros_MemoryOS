import AudioCore
import AudioPersistence
import ChatCore
import Foundation
import Testing

@testable import MemoryOS

@MainActor
private final class WorkflowCapture: AudioCaptureDevice {
  var snapshot = AudioCaptureSnapshot()
  var onChange: (@MainActor (AudioCaptureSnapshot) -> Void)?
  var granted = true
  var heldPermission: CheckedContinuation<Bool, Never>?
  var holdPermission = false
  var starts = 0
  var finishes = 0
  var failureBeforeBytes: AudioCaptureFailure?
  var failureAfterBytes: AudioCaptureFailure?
  func requestPermission() async -> Bool {
    if holdPermission { return await withCheckedContinuation { heldPermission = $0 } }
    return granted
  }
  func start(to url: URL) throws {
    starts += 1
    if let failureBeforeBytes { throw failureBeforeBytes }
    try Data("fictional recorded bytes".utf8).write(to: url)
    snapshot = AudioCaptureSnapshot(state: .recording, elapsedSeconds: 2, fileURL: url)
    onChange?(snapshot)
    if let failureAfterBytes {
      snapshot.state = .failed
      snapshot.failure = failureAfterBytes
      onChange?(snapshot)
      throw failureAfterBytes
    }
  }
  func pause() {
    snapshot.state = .paused
    onChange?(snapshot)
  }
  func resume() throws {
    snapshot.state = .recording
    onChange?(snapshot)
  }
  func finish() throws -> URL {
    guard let url = snapshot.fileURL else { throw AudioCaptureFailure.invalidState }
    finishes += 1
    snapshot = AudioCaptureSnapshot()
    onChange?(snapshot)
    return url
  }
  func interrupt() {
    guard snapshot.fileURL != nil else { return }
    snapshot.state = .interrupted
    onChange?(snapshot)
  }
  func play(url: URL, fromSeconds: Double) throws {}
  func stopPlayback() {}
}

private actor WorkflowInspector: AudioFileInspecting {
  var fails = false
  func setFailure(_ value: Bool) { fails = value }
  func inspect(url: URL) throws -> AudioFileDetails {
    if fails { throw AudioCaptureFailure.damagedFile }
    return AudioFileDetails(durationSeconds: 2, byteCount: 24, format: "caf")
  }
  func withSelectedFile(url: URL, operation: @MainActor @Sendable (URL) async throws -> Void)
    async throws
  {
    try await operation(url)
  }
}

private actor WorkflowModels: AudioModelPreparing {
  let url: URL
  var installed = false
  init(url: URL) { self.url = url }
  func directory(engine: String) throws -> URL {
    guard installed else { throw AudioWorkflowError.modelMissing }
    return url
  }
  func install(folder: URL, engine: String) { installed = true }
}

private actor WorkflowTranscriber: TranscriptionProvider {
  nonisolated let id: String
  var text = "موعد زينب غداً"
  init(id: String = "controlled") { self.id = id }
  func setText(_ value: String) { text = value }
  var calls = 0
  var waits = false
  func setWait(_ value: Bool) { waits = value }
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    calls += 1
    if waits { try await Task.sleep(for: .seconds(60)) }
    return TranscriptionOutput(
      modelID: "fictional-test", language: "ar",
      passages: [
        TranscriptPassage(startSeconds: 0, endSeconds: 1.5, text: text, uncertain: true)
      ])
  }
}

@MainActor
struct AudioWorkflowTests {
  @Test func deniedPermissionCreatesNoDraft() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    capture.granted = false
    let workflow = make(root, capture: capture)
    await #expect(throws: AudioCaptureFailure.permissionDenied) {
      try await workflow.start(title: "Note")
    }
    #expect(try await workflow.library.snapshot().recordings.isEmpty)
    #expect(capture.starts == 0)
  }

  @Test func permissionGrantedAfterBackgroundDoesNotCreateDraftOrStartMicrophone() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    capture.holdPermission = true
    let workflow = make(root, capture: capture)
    let task = Task { try await workflow.start(title: "Note") }
    while capture.heldPermission == nil { await Task.yield() }
    try await workflow.interrupt()
    capture.heldPermission?.resume(returning: true)
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try await workflow.library.snapshot().recordings.isEmpty)
    #expect(capture.starts == 0)
  }

  @Test func leavingCaptureDuringPermissionDoesNotStartHiddenRecording() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    capture.holdPermission = true
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    let start = Task { await model.start(defaultTitle: "Fictional note") }
    while capture.heldPermission == nil { await Task.yield() }
    #expect(model.busy)
    #expect(model.draftID == nil)
    await model.leaveCapture()
    capture.heldPermission?.resume(returning: true)
    await start.value
    #expect(capture.starts == 0)
    #expect(model.draftID == nil)
    #expect(model.recordings.isEmpty)
  }

  @Test(arguments: [false, true])
  func leavingRecordingSurfaceRetainsAudioAndStopsActiveOrPausedCapture(paused: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "Fictional navigation test")
    let id = try #require(model.draftID)
    let original = try await workflow.library.recordingURL(id: id)
    let bytes = try Data(contentsOf: original)
    if paused { await model.pause() }
    await model.leaveCapture()
    #expect(model.captureState.state == .interrupted)
    #expect(model.draftID == id)
    #expect(model.recordings.first?.state == .interrupted)
    #expect(try Data(contentsOf: original) == bytes)
    await model.save()
    #expect(model.draftID == nil)
    #expect(model.captureState.state == .idle)
    #expect(model.recordings.first?.state == .saved)
    #expect(try Data(contentsOf: original) == bytes)
    await model.start(defaultTitle: "Next fictional recording")
    #expect(model.captureState.state == .recording)
    #expect(model.draftID != id)
    #expect(capture.starts == 2)
  }

  @Test func saveCanRetryAfterRecorderClosedAndInspectionFailed() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let inspector = WorkflowInspector()
    let workflow = make(root, capture: capture, inspector: inspector)
    try await workflow.start(title: "Keep original")
    let id = try #require(workflow.draftID)
    await inspector.setFailure(true)
    await #expect(throws: AudioCaptureFailure.damagedFile) { try await workflow.save() }
    #expect(workflow.draftID == id)
    #expect(capture.finishes == 1)
    await inspector.setFailure(false)
    try await workflow.save()
    #expect(workflow.draftID == nil)
    #expect(capture.finishes == 1)
    #expect(try await workflow.library.snapshot().recordings.first?.state == .saved)
  }

  @Test func viewModelKeepsInterruptedDraftThenRecoversWithoutReopeningMicrophone() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "Fictional recording")
    let id = try #require(model.draftID)
    await model.pause()
    #expect(model.captureState.state == .paused)
    await model.resume()
    #expect(model.captureState.state == .recording)
    await model.keepForLater()
    #expect(model.draftID == nil)
    await model.recover(id: id)
    #expect(model.snapshot.recordings.first?.state == .saved)
    #expect(capture.starts == 1)
  }

  @Test func runtimeLowStorageFailureRemainsVisibleWithRecoverableDraft() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "Retain partial audio")
    let id = try #require(model.draftID)
    capture.snapshot.state = .failed
    capture.snapshot.failure = .lowStorage
    capture.onChange?(capture.snapshot)
    #expect(model.failure as? AudioCaptureFailure == .lowStorage)
    await model.load()
    #expect(model.failure as? AudioCaptureFailure == .lowStorage)
    #expect(model.draftID == id)
    await model.save()
    #expect(model.snapshot.recordings.first?.state == .saved)
    #expect(model.failure == nil)
  }

  @Test func missingModelsDoNotCallEngineAndCancellationRetainsOriginal() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let models = WorkflowModels(url: root)
    let provider = WorkflowTranscriber()
    let workflow = make(root, capture: capture, models: models, provider: provider)
    try await workflow.start(title: "Note")
    let id = try #require(workflow.draftID)
    try await workflow.save()
    await #expect(throws: AudioWorkflowError.self) {
      try await workflow.transcribe(id: id, engine: provider.id)
    }
    #expect(await provider.calls == 0)
    await models.install(folder: root, engine: provider.id)
    await provider.setWait(true)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    let hash = model.recordings.first?.sha256
    model.transcribe(id: id)
    while await provider.calls == 0 { await Task.yield() }
    model.cancelProcessing()
    while model.isProcessing { await Task.yield() }
    #expect(model.recordings.first?.sha256 == hash)
    #expect(model.snapshot.jobs.last?.state == .interrupted)
    #expect(model.snapshot.transcripts.isEmpty)
  }

  @Test func startLowStorageBeforeBytesRollsBackDraftAndAllowsRetry() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    capture.failureBeforeBytes = .lowStorage
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "No bytes")
    #expect(model.failure as? AudioCaptureFailure == .lowStorage)
    #expect(model.draftID == nil)
    #expect(model.canStart)
    #expect(try await workflow.library.snapshot().recordings.isEmpty)
    capture.failureBeforeBytes = nil
    await model.start(defaultTitle: "Retry")
    #expect(model.draftID != nil)
    #expect(capture.snapshot.state == .recording)
    await model.save()
    #expect(model.snapshot.recordings.count == 1)
    #expect(model.snapshot.recordings.first?.state == .saved)
    #expect(capture.starts == 2)
  }

  @Test func startFailureAfterBytesRetainsRecoverableAudioAndOriginalFailure() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    capture.failureAfterBytes = .recordingFailed
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "Partial audio")
    let id = try #require(model.draftID)
    #expect(capture.snapshot.state == .idle)
    #expect(model.failure as? AudioCaptureFailure == .recordingFailed)
    let url = try await workflow.library.recordingURL(id: id)
    #expect(try Data(contentsOf: url) == Data("fictional recorded bytes".utf8))
    #expect(try await workflow.library.snapshot().recordings.first?.state == .interrupted)
    await model.save()
    #expect(model.draftID == nil)
    #expect(model.snapshot.recordings.first?.state == .saved)
    #expect(try Data(contentsOf: url) == Data("fictional recorded bytes".utf8))
    #expect(capture.starts == 1)
  }

  @Test func restartRecoveryClearsOldEmptyDraftAndRetainsPartialDraft() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let oldLibrary = AudioLibrary(repository: FileAudioRepository(directory: root))
    let empty = try await oldLibrary.createDraft(title: "No audio", fileExtension: "caf")
    let partial = try await oldLibrary.createDraft(title: "Audio written", fileExtension: "caf")
    let url = try await oldLibrary.recordingURL(id: partial.id)
    try Data("fictional recorded bytes".utf8).write(to: url)
    let capture = WorkflowCapture()
    let workflow = make(root, capture: capture)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    #expect(model.recordings.count == 2)
    await model.recover(id: empty.id)
    #expect(model.recordings.map(\.id) == [partial.id])
    await model.recover(id: partial.id)
    #expect(model.recordings.first?.state == .saved)
    #expect(try Data(contentsOf: url) == Data("fictional recorded bytes".utf8))
    #expect(capture.starts == 0)
    #expect(model.canStart)
  }

  @Test func finishForChatReturnsFinalizedOriginalWithoutStartingTranscription() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = WorkflowCapture()
    let inspector = WorkflowInspector()
    let provider = WorkflowTranscriber(id: "whisper.cpp")
    let workflow = make(root, capture: capture, inspector: inspector, provider: provider)
    let model = AudioViewModel(workflow: workflow)
    await model.load()
    await model.start(defaultTitle: "Fictional voice chat")
    let id = try #require(model.draftID)
    await inspector.setFailure(true)
    #expect(await model.saveForChat() == nil)
    #expect(model.draftID == id)
    await inspector.setFailure(false)
    let recording = try #require(await model.saveForChat())
    #expect(recording.id == id)
    #expect(recording.state == .saved)
    #expect(recording.durationSeconds == 2)
    #expect(recording.sha256 != nil)
    #expect(capture.finishes == 1)
    #expect(await provider.calls == 0)
    #expect(await model.saveForChat() == nil)
    #expect(model.recordings.count == 1)
  }

  @Test func voiceBridgeReusesCanonicalTranscriptAndRetainsPassageLinks() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let models = WorkflowModels(url: root)
    await models.install(folder: root, engine: "whisper.cpp")
    let provider = WorkflowTranscriber(id: "whisper.cpp")
    let workflow = make(root, capture: WorkflowCapture(), models: models, provider: provider)
    let feature = AudioComposition.makeFeature(workflow: workflow)
    let model = feature.viewModel
    await model.load()
    await model.start(defaultTitle: "Fictional voice")
    let recording = try #require(await model.saveForChat())
    let bridge = feature.voiceTranscriber
    let first = try await bridge.transcribe(recordingID: recording.id)
    let second = try await bridge.transcribe(recordingID: recording.id)
    #expect(first == second)
    #expect(await provider.calls == 1)
    #expect(model.snapshot.transcripts.count == 1)
    #expect(first.id == model.snapshot.transcripts.first?.id)
    #expect(first.passageIDs == first.passages.map(\.id))
    #expect(first.passages.first?.startSeconds == 0)
    #expect(first.passages.first?.endSeconds == 1.5)
    #expect(first.text == "موعد زينب غداً")
    #expect(model.recordings.first?.sha256 == recording.sha256)
    #expect(!model.isProcessing)
    let url = try await workflow.library.recordingURL(id: recording.id)
    try Data("changed bytes".utf8).write(to: url)
    await #expect(throws: VoiceFailure.recordingUnavailable) {
      try await bridge.transcribe(recordingID: recording.id)
    }
  }

  @Test func voiceBridgeReportsMissingModelAndEmptySpeechWithoutLosingAudio() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let models = WorkflowModels(url: root)
    let provider = WorkflowTranscriber(id: "whisper.cpp")
    let workflow = make(root, capture: WorkflowCapture(), models: models, provider: provider)
    try await workflow.start(title: "Silent fixture")
    let id = try #require(workflow.draftID)
    try await workflow.save()
    let bridge = AudioChatTranscriber(workflow: workflow)
    await #expect(throws: VoiceFailure.modelUnavailable) {
      try await bridge.transcribe(recordingID: id)
    }
    #expect(await provider.calls == 0)
    await models.install(folder: root, engine: "whisper.cpp")
    await provider.setText("   ")
    await #expect(throws: VoiceFailure.noSpeech) { try await bridge.transcribe(recordingID: id) }
    await #expect(throws: VoiceFailure.noSpeech) { try await bridge.transcribe(recordingID: id) }
    #expect(await provider.calls == 2)
    #expect(try await workflow.library.snapshot().recordings.first?.state == .saved)
  }

  @Test func voiceBridgeCancellationRetainsOriginalAndReleasesCapture() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let models = WorkflowModels(url: root)
    await models.install(folder: root, engine: "whisper.cpp")
    let provider = WorkflowTranscriber(id: "whisper.cpp")
    await provider.setWait(true)
    let workflow = make(root, capture: WorkflowCapture(), models: models, provider: provider)
    let feature = AudioComposition.makeFeature(workflow: workflow)
    let model = feature.viewModel
    await model.load()
    await model.start(defaultTitle: "Fictional interruption")
    let recording = try #require(await model.saveForChat())
    let bridge = feature.voiceTranscriber
    let task = Task { try await bridge.transcribe(recordingID: recording.id) }
    while await provider.calls == 0 { await Task.yield() }
    #expect(model.isProcessing)
    #expect(!model.canStart)
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(!model.isProcessing)
    #expect(model.canStart)
    #expect(model.recordings.first?.sha256 == recording.sha256)
    #expect(model.snapshot.jobs.last?.state == .interrupted)
  }

  private func make(
    _ root: URL, capture: WorkflowCapture,
    inspector: WorkflowInspector = WorkflowInspector(),
    models: WorkflowModels? = nil, provider: WorkflowTranscriber = WorkflowTranscriber()
  ) -> AudioWorkflow {
    AudioWorkflow(
      library: AudioLibrary(repository: FileAudioRepository(directory: root)),
      capture: AudioCaptureUseCases(device: capture, inspector: inspector),
      providers: [provider], models: models ?? WorkflowModels(url: root))
  }
}
