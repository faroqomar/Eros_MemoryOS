import AudioCore
import Foundation
import Observation

@MainActor
@Observable
final class AudioViewModel {
  private let workflow: AudioWorkflow
  private var processing: Task<Void, Never>?
  private var chatProcessing = false
  private var startingCapture = false
  private(set) var snapshot = AudioSnapshot()
  private(set) var busy = false
  private(set) var processingID: UUID?
  private(set) var captureState: AudioCaptureSnapshot
  private(set) var failure: Error?
  private(set) var hasLoaded = false
  var title = ""
  var engine: String
  var exportData: Data?
  var modelInstalled = false
  var engines: [String] { workflow.engines }
  var draftID: UUID? { workflow.draftID }
  var recordings: [AudioRecording] { snapshot.recordings.sorted { $0.createdAt > $1.createdAt } }
  var canStart: Bool { hasLoaded && !busy && draftID == nil && !isProcessing }
  var isProcessing: Bool { processing != nil || chatProcessing }

  init(workflow: AudioWorkflow) {
    self.workflow = workflow
    engine = workflow.engines.first ?? ""
    captureState = workflow.capture.snapshot
    workflow.capture.onChange = { [weak self] value in
      guard let self else { return }
      self.captureState = value
      if let failure = value.failure { self.failure = failure }
      if value.state == .interrupted || value.state == .failed, let id = self.draftID {
        Task { [weak self] in await self?.persistInterruption(id: id, fileURL: value.fileURL) }
      }
    }
  }

  func load() async {
    guard !busy else { return }
    await perform { try await self.refresh() }
  }

  func start(defaultTitle: String) async {
    guard canStart else { return }
    startingCapture = true
    defer { startingCapture = false }
    await perform {
      try await self.workflow.start(title: self.title.isEmpty ? defaultTitle : self.title)
      try await self.refresh()
    }
  }

  func pause() async {
    await perform {
      try await self.workflow.pause()
      try await self.refresh()
    }
  }
  func resume() async {
    await perform {
      try await self.workflow.resume()
      try await self.refresh()
    }
  }
  func save() async {
    await perform {
      try await self.workflow.save()
      self.title = ""
      try await self.refresh()
    }
  }
  /// Returns only finalized audio; chat failure cannot remove this original recording.
  func saveForChat() async -> AudioRecording? {
    guard let id = draftID, !isProcessing else { return nil }
    let saved = await perform {
      try await self.workflow.save()
      self.title = ""
      try await self.refresh()
    }
    guard saved else { return nil }
    return snapshot.recordings.first { $0.id == id && $0.state == .saved }
  }

  func voiceProcessingChanged(_ processing: Bool) async {
    chatProcessing = processing
    if !processing {
      do { try await refresh() } catch { failure = error }
    }
  }

  func keepForLater() async {
    await perform {
      try await self.workflow.keepForLater()
      try await self.refresh()
    }
  }
  func recover(id: UUID) async {
    await perform {
      try await self.workflow.recover(id: id)
      try await self.refresh()
    }
  }
  func importAudio(_ result: Result<URL, Error>) async {
    do {
      let url = try result.get()
      await perform {
        try await self.workflow.importAudio(url: url)
        try await self.refresh()
      }
    } catch { failure = error }
  }
  func installModel(_ result: Result<URL, Error>) async {
    do {
      let folder = try result.get()
      await perform {
        try await self.workflow.installModel(folder: folder, engine: self.engine)
        self.modelInstalled = true
      }
    } catch { failure = error }
  }

  func transcribe(id: UUID) {
    guard !busy, !isProcessing, draftID == nil else { return }
    failure = nil
    processingID = id
    let chosenEngine = engine
    processing = Task { [weak self] in
      guard let self else { return }
      defer {
        self.processing = nil
        self.processingID = nil
      }
      do { try await self.workflow.transcribe(id: id, engine: chosenEngine) } catch {
        self.failure = error
      }
      do { try await self.refresh() } catch { self.failure = error }
    }
  }

  func cancelProcessing() { processing?.cancel() }

  /// Leaving a capture surface stops the microphone, including a pending permission request.
  /// A saved recording handed to chat owns its processing independently of that surface.
  func leaveCapture() async {
    guard draftID != nil || startingCapture else { return }
    await interrupt()
  }

  func interrupt() async {
    processing?.cancel()
    do {
      try await workflow.interrupt()
      try await refresh()
    } catch { failure = error }
  }

  private func persistInterruption(id: UUID, fileURL: URL?) async {
    guard draftID == id, captureState.fileURL == fileURL,
      captureState.state == .interrupted || captureState.state == .failed
    else { return }
    do {
      try await workflow.library.setRecordingState(id: id, state: .interrupted)
      try await refresh()
    } catch {
      // A completed save supersedes an already queued platform interruption.
      if let stored = try? await workflow.library.snapshot(),
        stored.recordings.contains(where: { $0.id == id && $0.state == .saved })
      {
        return
      }
      failure = error
    }
  }

  func play(id: UUID, seconds: Double = 0) async {
    await perform { try await self.workflow.play(id: id, seconds: seconds) }
  }
  func stopPlayback() { workflow.capture.stopPlayback() }

  func correct(
    transcriptID: UUID, passage: TranscriptPassage, text: String,
    speaker: String, uncertain: Bool
  ) async -> Bool {
    await perform {
      try await self.workflow.library.correctPassage(
        transcriptID: transcriptID,
        passageID: passage.id, text: text, speaker: speaker.isEmpty ? nil : speaker,
        uncertain: uncertain)
      try await self.refresh()
    }
  }

  func toggleAssociation(recordingID: UUID, linkedID: UUID, isPerson: Bool) async {
    guard let recording = snapshot.recordings.first(where: { $0.id == recordingID }) else { return }
    var people = recording.personIDs
    var sources = recording.sourceRecordIDs
    if isPerson {
      if people.contains(linkedID) {
        people.removeAll { $0 == linkedID }
      } else {
        people.append(linkedID)
      }
    } else {
      if sources.contains(linkedID) {
        sources.removeAll { $0 == linkedID }
      } else {
        sources.append(linkedID)
      }
    }
    await associate(id: recordingID, personIDs: people, sourceIDs: sources)
  }

  func associate(id: UUID, personIDs: [UUID], sourceIDs: [UUID]) async {
    await perform {
      try await self.workflow.library.updateAssociations(
        recordingID: id,
        personIDs: personIDs, sourceRecordIDs: sourceIDs)
      try await self.refresh()
    }
  }

  func export(id: UUID) async -> Bool {
    exportData = nil
    return await perform {
      self.exportData = try await self.workflow.library.exportTranscript(transcriptID: id)
    }
  }

  func report(_ error: Error) { failure = error }
  func dismissFailure() { failure = nil }

  @discardableResult
  private func perform(_ operation: () async throws -> Void) async -> Bool {
    guard !busy else { return false }
    busy = true
    defer { busy = false }
    do {
      try await operation()
      failure = captureState.failure
      return true
    } catch {
      failure = error
      return false
    }
  }

  private func refresh() async throws {
    snapshot = try await workflow.library.snapshot()
    hasLoaded = true
  }
}
