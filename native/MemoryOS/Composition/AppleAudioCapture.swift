import AVFAudio
import Foundation

/// Owns the app audio session. Interruptions close the CAF file and require an explicit save.
@MainActor
final class AppleAudioCapture: NSObject, AudioCaptureDevice {
  private(set) var snapshot = AudioCaptureSnapshot()
  var onChange: (@MainActor (AudioCaptureSnapshot) -> Void)?
  private var recorder: AVAudioRecorder?
  private var player: AVAudioPlayer?
  private var observationTask: Task<Void, Never>?
  private var clockTask: Task<Void, Never>?
  private var lastCapacityCheck: TimeInterval = 0

  override init() {
    super.init()
    observationTask = Task { @MainActor [weak self] in
      let notifications = NotificationCenter.default.notifications(
        named: AVAudioSession.interruptionNotification)
      for await notification in notifications {
        guard !Task.isCancelled else { break }
        if (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
          == AVAudioSession.InterruptionType.began.rawValue
        {
          self?.interrupt()
        }
      }
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(mediaServicesReset),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil)
  }

  isolated deinit {
    observationTask?.cancel()
    clockTask?.cancel()
    recorder?.stop()
    player?.stop()
    NotificationCenter.default.removeObserver(self)
  }

  func requestPermission() async -> Bool { await AVAudioApplication.requestRecordPermission() }

  func start(to url: URL) throws {
    guard snapshot.state == .idle, url.isFileURL, url.pathExtension.lowercased() == "caf",
      !FileManager.default.fileExists(atPath: url.path)
    else { throw AudioCaptureFailure.invalidState }
    guard AVAudioApplication.shared.recordPermission == .granted else {
      throw AudioCaptureFailure.permissionDenied
    }
    try checkCapacity(at: url.deletingLastPathComponent())
    stopPlayback()
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)
      let next = try AVAudioRecorder(
        url: url,
        settings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: 16_000.0,
          AVNumberOfChannelsKey: 1,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
        ])
      next.delegate = self
      recorder = next
      guard next.prepareToRecord() else { throw AudioCaptureFailure.recordingFailed }
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
      guard next.record(forDuration: AudioCaptureLimits.maximumDurationSeconds - 1) else {
        throw AudioCaptureFailure.recordingFailed
      }
      snapshot = AudioCaptureSnapshot(state: .recording, elapsedSeconds: 0, fileURL: url)
      lastCapacityCheck = 0
      publish()
      startClock()
    } catch {
      recorder?.stop()
      recorder = nil
      deactivateSession()
      // Keep any partial file; the durable draft can recover it after a write failure.
      snapshot = AudioCaptureSnapshot(state: .failed, fileURL: url, failure: .recordingFailed)
      publish()
      throw AudioCaptureFailure.recordingFailed
    }
  }

  func pause() {
    guard snapshot.state == .recording, let recorder else { return }
    snapshot.elapsedSeconds = recorder.currentTime
    recorder.pause()
    snapshot.state = .paused
    publish()
  }

  func resume() throws {
    guard snapshot.state == .paused, let recorder, let url = snapshot.fileURL else {
      throw AudioCaptureFailure.invalidState
    }
    try checkCapacity(at: url.deletingLastPathComponent())
    do {
      try AVAudioSession.sharedInstance().setActive(true)
      guard
        recorder.record(
          forDuration: max(
            0.01, AudioCaptureLimits.maximumDurationSeconds - 1 - recorder.currentTime))
      else { throw AudioCaptureFailure.recordingFailed }
      snapshot.state = .recording
      publish()
    } catch {
      fail(.recordingFailed)
      throw AudioCaptureFailure.recordingFailed
    }
  }

  func finish() throws -> URL {
    guard let url = snapshot.fileURL, snapshot.state != .idle else {
      throw AudioCaptureFailure.invalidState
    }
    stopRecorder()
    snapshot = AudioCaptureSnapshot()
    publish()
    return url
  }

  func interrupt() {
    stopPlayback()
    guard snapshot.state == .recording || snapshot.state == .paused else { return }
    stopRecorder()
    snapshot.state = .interrupted
    publish()
  }

  func play(url: URL, fromSeconds: Double) throws {
    guard snapshot.state != .recording && snapshot.state != .paused,
      url.isFileURL, fromSeconds.isFinite, fromSeconds >= 0
    else { throw AudioCaptureFailure.invalidState }
    stopPlayback()
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio)
      try session.setActive(true)
      let next = try AVAudioPlayer(contentsOf: url)
      guard fromSeconds < next.duration else { throw AudioCaptureFailure.playbackFailed }
      next.currentTime = fromSeconds
      next.delegate = self
      player = next
      guard next.play() else { throw AudioCaptureFailure.playbackFailed }
    } catch {
      stopPlayback()
      throw AudioCaptureFailure.playbackFailed
    }
  }

  func stopPlayback() {
    guard player != nil else { return }
    player?.stop()
    player = nil
    if recorder == nil { deactivateSession() }
  }

  private func startClock() {
    clockTask?.cancel()
    clockTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        self?.tick()
        do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
      }
    }
  }

  private func tick() {
    guard snapshot.state == .recording, let recorder, let url = snapshot.fileURL else { return }
    snapshot.elapsedSeconds = recorder.currentTime
    if snapshot.elapsedSeconds >= AudioCaptureLimits.maximumDurationSeconds {
      fail(.durationTooLong)
      return
    }
    if snapshot.elapsedSeconds - lastCapacityCheck >= 1 {
      do { try checkCapacity(at: url.deletingLastPathComponent()) } catch {
        fail(.lowStorage)
        return
      }
      lastCapacityCheck = snapshot.elapsedSeconds
    }
    publish()
  }

  private func stopRecorder() {
    if let recorder {
      snapshot.elapsedSeconds = max(snapshot.elapsedSeconds, recorder.currentTime)
      recorder.delegate = nil
      recorder.stop()
    }
    recorder = nil
    clockTask?.cancel()
    clockTask = nil
    deactivateSession()
  }

  private func fail(_ failure: AudioCaptureFailure) {
    stopRecorder()
    snapshot.state = .failed
    snapshot.failure = failure
    publish()
  }

  private func checkCapacity(at directory: URL) throws {
    let values = try directory.resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey
    ])
    guard let available = values.volumeAvailableCapacityForImportantUsage,
      available >= AudioCaptureLimits.minimumFreeBytes
    else { throw AudioCaptureFailure.lowStorage }
  }

  private func deactivateSession() {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func publish() { onChange?(snapshot) }

  @objc nonisolated private func routeChanged(_ notification: Notification) {
    let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
    Task { @MainActor [weak self] in self?.interrupt() }
  }

  @objc nonisolated private func mediaServicesReset(_ notification: Notification) {
    Task { @MainActor [weak self] in self?.interrupt() }
  }
}

extension AppleAudioCapture: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
  nonisolated func audioRecorderDidFinishRecording(
    _ recorder: AVAudioRecorder, successfully flag: Bool
  ) {
    let identifier = ObjectIdentifier(recorder)
    Task { @MainActor [weak self] in
      guard let self, let current = self.recorder, ObjectIdentifier(current) == identifier else {
        return
      }
      if flag { self.interrupt() } else { self.fail(.recordingFailed) }
    }
  }

  nonisolated func audioRecorderEncodeErrorDidOccur(
    _ recorder: AVAudioRecorder, error: (any Error)?
  ) {
    let identifier = ObjectIdentifier(recorder)
    Task { @MainActor [weak self] in
      guard let self, let current = self.recorder, ObjectIdentifier(current) == identifier else {
        return
      }
      self.fail(.recordingFailed)
    }
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    let identifier = ObjectIdentifier(player)
    Task { @MainActor [weak self] in
      guard let self, let current = self.player, ObjectIdentifier(current) == identifier else {
        return
      }
      self.stopPlayback()
    }
  }

  nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
    let identifier = ObjectIdentifier(player)
    Task { @MainActor [weak self] in
      guard let self, let current = self.player, ObjectIdentifier(current) == identifier else {
        return
      }
      self.stopPlayback()
    }
  }
}

/// Full streaming decode finds truncated/corrupt input without loading the whole recording into RAM.
actor AppleAudioFileInspector: AudioFileInspecting {
  func withSelectedFile(
    url: URL, operation: @MainActor @Sendable (URL) async throws -> Void
  ) async throws {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    try await operation(url)
  }

  func inspect(url: URL) throws -> AudioFileDetails {
    try Task.checkCancellation()
    let fileExtension = url.pathExtension.lowercased()
    guard url.isFileURL, AudioCaptureLimits.supportedExtensions.contains(fileExtension) else {
      throw AudioCaptureFailure.unsupportedFormat
    }
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile == true, let bytes = values.fileSize, bytes > 0 else {
        throw AudioCaptureFailure.damagedFile
      }
      guard bytes <= AudioCaptureLimits.maximumBytes else { throw AudioCaptureFailure.fileTooLarge }
      let audio = try AVAudioFile(forReading: url)
      let format = audio.processingFormat
      guard format.sampleRate.isFinite, format.sampleRate > 0, format.channelCount > 0,
        format.channelCount <= 8, audio.length > 0
      else { throw AudioCaptureFailure.damagedFile }
      let duration = Double(audio.length) / format.sampleRate
      guard duration.isFinite, duration <= AudioCaptureLimits.maximumDurationSeconds else {
        throw AudioCaptureFailure.durationTooLong
      }
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
        throw AudioCaptureFailure.damagedFile
      }
      var frames: AVAudioFramePosition = 0
      while frames < audio.length {
        try Task.checkCancellation()
        try audio.read(
          into: buffer, frameCount: AVAudioFrameCount(min(16_384, audio.length - frames)))
        guard buffer.frameLength > 0 else { throw AudioCaptureFailure.damagedFile }
        frames += AVAudioFramePosition(buffer.frameLength)
      }
      return AudioFileDetails(
        durationSeconds: duration, byteCount: Int64(bytes), format: fileExtension)
    } catch let failure as AudioCaptureFailure {
      throw failure
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw AudioCaptureFailure.damagedFile
    }
  }
}
