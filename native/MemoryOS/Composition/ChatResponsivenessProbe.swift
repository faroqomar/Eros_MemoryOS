import Foundation
import QuartzCore
import UIKit

/// Local builder measurements. No prompt, reply, record or conversation identifier is retained.
@MainActor
final class ChatResponsivenessProbe: NSObject, ChatScrollMeasuring {
  private var heartbeat: Timer?
  private var lastHeartbeat = 0.0
  private var memorySampleCount = 0
  private var expectedFrameInterval: Double?
  private var displayLink: CADisplayLink?
  private var lastFrame: CFTimeInterval?
  private var frameGaps: [Double] = []
  private var scrollingFrameGaps: [Double] = []
  private var generating = false
  private var completion: (cancellation: Double?, firstText: Double?) = (nil, nil)
  private var startedAt: Date?
  private var scrolling = false
  private var scrollingOnly = false
  private var maximumHeartbeatDelay = 0.0
  private var peakResidentBytes: UInt64 = 0
  private var started: ContinuousClock.Instant?

  private let record: @MainActor (ChatUIResponsiveness) -> Void

  init(
    record: @escaping @MainActor (ChatUIResponsiveness) -> Void = { sample in
      Task { await ChatUIResponsivenessStore.shared.append(sample) }
    }
  ) {
    self.record = record
  }

  func start() {
    guard !generating else { return }
    generating = true
    beginIfNeeded()
    scrollingOnly = false
    completion = (nil, nil)
  }

  private func beginIfNeeded() {
    guard started == nil else { return }
    started = .now
    startedAt = Date()
    completion = (nil, nil)
    frameGaps = []
    scrollingFrameGaps = []
    scrollingOnly = !generating
    lastFrame = nil
    maximumHeartbeatDelay = 0
    peakResidentBytes = 0
    let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
    lastHeartbeat = CACurrentMediaTime()
    memorySampleCount = 0
    expectedFrameInterval = nil
    let timer = Timer(
      timeInterval: 0.020, target: self, selector: #selector(heartbeatTick), userInfo: nil,
      repeats: true)
    RunLoop.main.add(timer, forMode: .common)
    heartbeat = timer
  }

  func userScrollChanged(_ active: Bool) {
    scrolling = active
    if active { beginIfNeeded() }
    if !active && !generating { finishWindow() }
  }

  @objc private func heartbeatTick() {
    accountHeartbeat()
    if let resident = ChatMeasurement.residentBytes() {
      peakResidentBytes = max(peakResidentBytes, resident)
      memorySampleCount += 1
    }
  }

  private func accountHeartbeat() {
    let now = CACurrentMediaTime()
    maximumHeartbeatDelay = max(maximumHeartbeatDelay, max(0, now - lastHeartbeat - 0.020))
    lastHeartbeat = now
  }

  @objc private func frame(_ link: CADisplayLink) {
    if let lastFrame, frameGaps.count < 60_000 {
      let gap = link.timestamp - lastFrame
      frameGaps.append(gap)
      if scrolling { scrollingFrameGaps.append(gap) }
    }
    lastFrame = link.timestamp
    expectedFrameInterval = link.targetTimestamp - link.timestamp
  }

  func finish(cancellationSeconds: Double?, firstUsableTextSeconds: Double?) {
    guard generating else { return }
    generating = false
    guard started != nil else { return }
    completion = (cancellationSeconds, firstUsableTextSeconds)
    if !scrolling { finishWindow() }
  }

  /// Background time must not be reported as an on-screen responsiveness delay.
  func suspend() {
    generating = false
    scrolling = false
    finishWindow(interrupted: true)
  }

  private func finishWindow(interrupted: Bool = false) {
    guard let started, let startedAt else { return }
    let duration = Self.seconds(started.duration(to: .now))
    self.started = nil
    accountHeartbeat()
    heartbeat?.invalidate()
    heartbeat = nil
    displayLink?.invalidate()
    displayLink = nil
    let sorted = frameGaps.sorted()
    let p95 =
      sorted.isEmpty ? nil : sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))]
    let scrollFrames = scrollingFrameGaps.sorted()
    let scrollP95 =
      scrollFrames.isEmpty
      ? nil : scrollFrames[min(scrollFrames.count - 1, Int(Double(scrollFrames.count - 1) * 0.95))]
    let sample = ChatUIResponsiveness(
      startedAt: startedAt, interrupted: interrupted,
      durationSeconds: duration, frameCount: sorted.count, p95FrameGapSeconds: p95,
      maximumFrameGapSeconds: sorted.last, maximumHeartbeatDelaySeconds: maximumHeartbeatDelay,
      peakResidentBytes: memorySampleCount > 0 ? peakResidentBytes : nil,
      firstUsableTextSeconds: completion.firstText, memorySampleCount: memorySampleCount,
      expectedFrameIntervalSeconds: expectedFrameInterval,
      cancellationSeconds: completion.cancellation,
      scrollingFrameCount: scrollFrames.count, p95ScrollingFrameGapSeconds: scrollP95,
      scrollingOnly: scrollingOnly)
    record(sample)
  }

  private static func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }
}

struct ChatUIResponsiveness: Codable, Sendable {
  let startedAt: Date
  let interrupted: Bool
  let durationSeconds: Double
  let frameCount: Int
  let p95FrameGapSeconds: Double?
  let maximumFrameGapSeconds: Double?
  let maximumHeartbeatDelaySeconds: Double
  let peakResidentBytes: UInt64?
  let firstUsableTextSeconds: Double?
  let memorySampleCount: Int
  let expectedFrameIntervalSeconds: Double?
  let cancellationSeconds: Double?
  let scrollingFrameCount: Int
  let p95ScrollingFrameGapSeconds: Double?
  let scrollingOnly: Bool
}

private actor ChatUIResponsivenessStore {
  static let shared = ChatUIResponsivenessStore()
  private var samples: [ChatUIResponsiveness] = []
  func append(_ sample: ChatUIResponsiveness) {
    samples.append(sample)
    samples = Array(samples.suffix(40))
    let url = URL.documentsDirectory.appending(path: "chat-ui-measurements.json")
    do {
      try JSONEncoder().encode(samples).write(to: url, options: [.atomic, .completeFileProtection])
      var file = url
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try file.setResourceValues(values)
    } catch {
      // Diagnostic failure must not change chat outcomes.
    }
  }
}
