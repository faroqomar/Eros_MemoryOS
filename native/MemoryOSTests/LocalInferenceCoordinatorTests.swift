import AudioCore
import ChatCore
import Foundation
import Testing

@testable import MemoryOS

private actor InferenceLeaseProbe {
  private let holdFirst: String?
  private var didHold = false
  private var held: CheckedContinuation<Void, Never>?
  private var heldObservers: [CheckedContinuation<Void, Never>] = []
  private(set) var events: [String] = []
  private(set) var active = 0
  private(set) var maximumActive = 0
  private(set) var textResident = false
  private(set) var speechSawResidentText = false

  init(holdFirst: String? = nil) { self.holdFirst = holdFirst }

  func begin(_ kind: String) async {
    active += 1
    maximumActive = max(maximumActive, active)
    events.append("start-" + kind)
    if kind == "text" { textResident = true }
    if kind == "speech" { speechSawResidentText = textResident }
    if kind == holdFirst, !didHold {
      didHold = true
      await withCheckedContinuation { continuation in
        held = continuation
        for observer in heldObservers { observer.resume() }
        heldObservers = []
      }
    }
  }

  func finish(_ kind: String) {
    events.append("finish-" + kind)
    active -= 1
  }

  func unload() {
    events.append("unload")
    textResident = false
  }

  func waitUntilHeld() async {
    if held != nil { return }
    await withCheckedContinuation { heldObservers.append($0) }
  }

  func releaseHeld() {
    held?.resume()
    held = nil
  }
}

private struct LeaseTextModel: ChatModel {
  let probe: InferenceLeaseProbe
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    await probe.begin("text")
    await probe.finish("text")
    onText("Fictional local reply")
  }
  func unload() async { await probe.unload() }
}

private struct LeaseSpeechProvider: TranscriptionProvider {
  let id = "fixture"
  let probe: InferenceLeaseProbe
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    await probe.begin("speech")
    await probe.finish("speech")
    return TranscriptionOutput(modelID: "fixture", language: "en", passages: [])
  }
}

struct LocalInferenceCoordinatorTests {
  private let unusedURL = URL(fileURLWithPath: "/unused-inference-fixture")

  @Test(arguments: [true, false])
  func manualSpeechAndChatNeverOverlap(textFirst: Bool) async throws {
    let probe = InferenceLeaseProbe(holdFirst: textFirst ? "text" : "speech")
    let coordinator = LocalInferenceCoordinator(model: LeaseTextModel(probe: probe))
    let speech = CoordinatedTranscriber(
      base: LeaseSpeechProvider(probe: probe), coordinator: coordinator)
    let first = Task {
      if textFirst {
        try await coordinator.generate(turns: [], onText: { _ in })
      } else {
        _ = try await speech.transcribe(audioURL: unusedURL, modelDirectory: unusedURL)
      }
    }
    await probe.waitUntilHeld()
    let second = Task {
      if textFirst {
        _ = try await speech.transcribe(audioURL: unusedURL, modelDirectory: unusedURL)
      } else {
        try await coordinator.generate(turns: [], onText: { _ in })
      }
    }
    // The first fake engine stays suspended while the other request gets executor time.
    for _ in 0..<20 { await Task.yield() }
    #expect(await probe.active == 1)
    await probe.releaseHeld()
    try await first.value
    try await second.value
    #expect(await probe.maximumActive == 1)
    #expect(await probe.active == 0)
    #expect(await !probe.speechSawResidentText)
  }

  @Test func manualSpeechUnloadsIdleTextWeightsBeforeProviderStarts() async throws {
    let probe = InferenceLeaseProbe()
    let coordinator = LocalInferenceCoordinator(model: LeaseTextModel(probe: probe))
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(await probe.textResident)
    let speech = CoordinatedTranscriber(
      base: LeaseSpeechProvider(probe: probe), coordinator: coordinator)
    _ = try await speech.transcribe(audioURL: unusedURL, modelDirectory: unusedURL)
    #expect(
      await probe.events == [
        "start-text", "finish-text", "unload", "start-speech", "finish-speech",
      ])
    #expect(await !probe.speechSawResidentText)
  }

  @Test func cancelledQueuedSpeechDoesNotEnterProviderOrStrandLease() async throws {
    let probe = InferenceLeaseProbe(holdFirst: "text")
    let coordinator = LocalInferenceCoordinator(model: LeaseTextModel(probe: probe))
    let speech = CoordinatedTranscriber(
      base: LeaseSpeechProvider(probe: probe), coordinator: coordinator)
    let active = Task { try await coordinator.generate(turns: [], onText: { _ in }) }
    await probe.waitUntilHeld()
    let cancelled = Task {
      try await speech.transcribe(audioURL: unusedURL, modelDirectory: unusedURL)
    }
    for _ in 0..<20 { await Task.yield() }
    cancelled.cancel()
    await probe.releaseHeld()
    try await active.value
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    #expect(await !probe.events.contains("start-speech"))
    try await coordinator.generate(turns: [], onText: { _ in })
    _ = try await speech.transcribe(audioURL: unusedURL, modelDirectory: unusedURL)
    #expect(await probe.maximumActive == 1)
    #expect(await probe.active == 0)
    #expect(await probe.events.filter { $0 == "start-speech" }.count == 1)
  }
}
