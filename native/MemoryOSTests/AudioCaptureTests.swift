import Foundation
import Testing

@testable import MemoryOS

@MainActor
private final class ControlledAudioCapture: AudioCaptureDevice {
  var snapshot = AudioCaptureSnapshot()
  var onChange: (@MainActor (AudioCaptureSnapshot) -> Void)?
  var permission = true
  var holdPermission = false
  var permissionContinuation: CheckedContinuation<Bool, Never>?
  var starts = 0
  var lastPlaybackOffset: Double?

  func requestPermission() async -> Bool {
    if holdPermission {
      return await withCheckedContinuation { permissionContinuation = $0 }
    }
    return permission
  }
  func start(to url: URL) throws {
    starts += 1
    snapshot = AudioCaptureSnapshot(state: .recording, fileURL: url)
    onChange?(snapshot)
  }
  func pause() {
    snapshot.state = .paused
    onChange?(snapshot)
  }
  func resume() throws {
    guard snapshot.state == .paused else { throw AudioCaptureFailure.invalidState }
    snapshot.state = .recording
    onChange?(snapshot)
  }
  func finish() throws -> URL {
    guard let url = snapshot.fileURL else { throw AudioCaptureFailure.invalidState }
    snapshot = AudioCaptureSnapshot()
    onChange?(snapshot)
    return url
  }
  func interrupt() {
    guard snapshot.fileURL != nil else { return }
    snapshot.state = .interrupted
    onChange?(snapshot)
  }
  func play(url: URL, fromSeconds: Double) throws { lastPlaybackOffset = fromSeconds }
  func stopPlayback() { lastPlaybackOffset = nil }
}

private struct ControlledAudioInspector: AudioFileInspecting {
  func inspect(url: URL) async throws -> AudioFileDetails {
    AudioFileDetails(durationSeconds: 3, byteCount: 96_000, format: "caf")
  }
  func withSelectedFile(
    url: URL, operation: @MainActor @Sendable (URL) async throws -> Void
  ) async throws { try await operation(url) }
}

@MainActor
struct AudioCaptureTests {
  private let url = URL(fileURLWithPath: "/tmp/fictional-capture.caf")

  @Test func deniedPermissionNeverStartsMicrophone() async {
    let device = ControlledAudioCapture()
    device.permission = false
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    await #expect(throws: AudioCaptureFailure.permissionDenied) {
      try await useCases.start(to: url)
    }
    #expect(device.starts == 0)
    #expect(useCases.snapshot.state == .idle)
  }

  @Test func interruptedPermissionRequestCannotStartRecordingLater() async throws {
    let device = ControlledAudioCapture()
    device.holdPermission = true
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    let start = Task { try await useCases.start(to: url) }
    while device.permissionContinuation == nil { await Task.yield() }
    useCases.interrupt()
    device.permissionContinuation?.resume(returning: true)
    await #expect(throws: CancellationError.self) { try await start.value }
    #expect(device.starts == 0)
  }

  @Test func overlappingStartDoesNotCreateSecondRecording() async throws {
    let device = ControlledAudioCapture()
    device.holdPermission = true
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    let first = Task { try await useCases.start(to: url) }
    while device.permissionContinuation == nil { await Task.yield() }
    await #expect(throws: AudioCaptureFailure.invalidState) {
      try await useCases.start(to: url.appendingPathExtension("second"))
    }
    device.permissionContinuation?.resume(returning: true)
    try await first.value
    #expect(device.starts == 1)
    #expect(useCases.snapshot.fileURL == url)
  }

  @Test func cancelledPermissionRequestCannotStartMicrophone() async throws {
    let device = ControlledAudioCapture()
    device.holdPermission = true
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    let start = Task { try await useCases.start(to: url) }
    while device.permissionContinuation == nil { await Task.yield() }
    start.cancel()
    device.permissionContinuation?.resume(returning: true)
    await #expect(throws: CancellationError.self) { try await start.value }
    #expect(device.starts == 0)
  }

  @Test func pauseResumeAndInterruptionKeepOriginalURL() async throws {
    let device = ControlledAudioCapture()
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    var states: [AudioCaptureState] = []
    useCases.onChange = { states.append($0.state) }
    try await useCases.start(to: url)
    useCases.pause()
    try useCases.resume()
    useCases.interrupt()
    #expect(throws: AudioCaptureFailure.invalidState) { try useCases.resume() }
    #expect(try useCases.finish() == url)
    #expect(states == [.recording, .paused, .recording, .interrupted, .idle])
    #expect(device.starts == 1)
  }

  @Test(arguments: [Double.nan, Double.infinity, -1])
  func invalidTimestampDoesNotReachPlayback(offset: Double) {
    let device = ControlledAudioCapture()
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    #expect(throws: AudioCaptureFailure.playbackFailed) {
      try useCases.play(url: url, fromSeconds: offset)
    }
    #expect(device.lastPlaybackOffset == nil)
  }

  @Test func timestampPlaybackKeepsRequestedOffset() throws {
    let device = ControlledAudioCapture()
    let useCases = AudioCaptureUseCases(device: device, inspector: ControlledAudioInspector())
    try useCases.play(url: url, fromSeconds: 12.75)
    #expect(device.lastPlaybackOffset == 12.75)
    useCases.stopPlayback()
    #expect(device.lastPlaybackOffset == nil)
  }
}

#if os(iOS)
  struct AppleAudioFileInspectorTests {
    @Test func unsupportedAndDamagedFilesReportDifferentFailures() async throws {
      let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let unsupported = directory.appending(path: "fixture.ogg")
      let damaged = directory.appending(path: "fixture.wav")
      try Data("fictional non-audio bytes".utf8).write(to: damaged)
      let inspector = AppleAudioFileInspector()
      await #expect(throws: AudioCaptureFailure.unsupportedFormat) {
        try await inspector.inspect(url: unsupported)
      }
      await #expect(throws: AudioCaptureFailure.damagedFile) {
        try await inspector.inspect(url: damaged)
      }
    }

    @Test func realDecoderInspectsFictionalPCMWithoutMicrophone() async throws {
      let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".wav")
      defer { try? FileManager.default.removeItem(at: url) }
      let frames: UInt32 = 16_000
      var data = Data()
      func text(_ value: String) { data.append(contentsOf: value.utf8) }
      func little<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
      }
      text("RIFF")
      little(UInt32(36 + frames * 2))
      text("WAVEfmt ")
      little(UInt32(16))
      little(UInt16(1))
      little(UInt16(1))
      little(UInt32(16_000))
      little(UInt32(32_000))
      little(UInt16(2))
      little(UInt16(16))
      text("data")
      little(frames * 2)
      data.append(Data(repeating: 0, count: Int(frames * 2)))
      try data.write(to: url)
      let details = try await AppleAudioFileInspector().inspect(url: url)
      #expect(details.durationSeconds == 1)
      #expect(details.byteCount == Int64(data.count))
      #expect(details.format == "wav")
    }
  }
#endif
