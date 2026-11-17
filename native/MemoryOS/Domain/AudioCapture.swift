import Foundation

enum AudioCaptureFailure: String, Error, Equatable, Sendable {
  case permissionDenied, invalidState, recordingFailed, lowStorage
  case unsupportedFormat, damagedFile, fileTooLarge, durationTooLong, playbackFailed
}

enum AudioCaptureState: String, Equatable, Sendable {
  case idle, recording, paused, interrupted, failed
}

struct AudioCaptureSnapshot: Equatable, Sendable {
  var state: AudioCaptureState = .idle
  var elapsedSeconds: Double = 0
  var fileURL: URL?
  var failure: AudioCaptureFailure?
}

struct AudioFileDetails: Equatable, Sendable {
  let durationSeconds: Double
  let byteCount: Int64
  let format: String
}

enum AudioCaptureLimits {
  static let supportedExtensions: Set<String> = ["wav", "m4a", "mp3", "aif", "aiff", "caf", "flac"]
  static let maximumBytes: Int64 = 262_144_000
  static let maximumDurationSeconds: Double = 7_200
  static let minimumFreeBytes: Int64 = 32 * 1_024 * 1_024
}

/// The platform session and its callbacks have one main-actor owner.
@MainActor
protocol AudioCaptureDevice: AnyObject {
  var snapshot: AudioCaptureSnapshot { get }
  var onChange: (@MainActor (AudioCaptureSnapshot) -> Void)? { get set }
  func requestPermission() async -> Bool
  func start(to url: URL) throws
  func pause()
  func resume() throws
  func finish() throws -> URL
  func interrupt()
  func play(url: URL, fromSeconds: Double) throws
  func stopPlayback()
}

protocol AudioFileInspecting: Sendable {
  func inspect(url: URL) async throws -> AudioFileDetails
  func withSelectedFile(
    url: URL, operation: @MainActor @Sendable (URL) async throws -> Void
  ) async throws
}

/// Presentation calls this boundary; AVFAudio remains in the injected adapter.
@MainActor
final class AudioCaptureUseCases {
  private let device: any AudioCaptureDevice
  private let inspector: any AudioFileInspecting
  private var permissionRequestInProgress = false
  private var requestGeneration = 0

  init(device: any AudioCaptureDevice, inspector: any AudioFileInspecting) {
    self.device = device
    self.inspector = inspector
  }

  var snapshot: AudioCaptureSnapshot { device.snapshot }
  var onChange: (@MainActor (AudioCaptureSnapshot) -> Void)? {
    get { device.onChange }
    set { device.onChange = newValue }
  }

  func requestPermission() async -> Bool { await device.requestPermission() }

  /// Call only after a durable draft identifies `url`. The adapter never overwrites it.
  func start(to url: URL) async throws {
    guard !permissionRequestInProgress, device.snapshot.state == .idle else {
      throw AudioCaptureFailure.invalidState
    }
    permissionRequestInProgress = true
    let generation = requestGeneration
    defer { permissionRequestInProgress = false }
    guard await device.requestPermission() else { throw AudioCaptureFailure.permissionDenied }
    try Task.checkCancellation()
    guard generation == requestGeneration else { throw CancellationError() }
    try device.start(to: url)
  }

  func pause() { device.pause() }
  func resume() throws { try device.resume() }
  func finish() throws -> URL { try device.finish() }
  func interrupt() {
    requestGeneration += 1
    device.interrupt()
  }
  func inspect(url: URL) async throws -> AudioFileDetails { try await inspector.inspect(url: url) }
  func withSelectedFile(
    url: URL, operation: @MainActor @Sendable (URL) async throws -> Void
  ) async throws {
    try await inspector.withSelectedFile(url: url, operation: operation)
  }
  func play(url: URL, fromSeconds: Double = 0) throws {
    guard fromSeconds.isFinite, fromSeconds >= 0 else { throw AudioCaptureFailure.playbackFailed }
    try device.play(url: url, fromSeconds: fromSeconds)
  }
  func stopPlayback() { device.stopPlayback() }
}
