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

private actor BackgroundLeaseProbe {
  private let heldKind: String
  private var didHold = false
  private var release: AsyncThrowingStream<Void, Error>.Continuation?
  private var observers: [CheckedContinuation<Void, Never>] = []
  private(set) var events: [String] = []
  private(set) var active = 0
  private(set) var maximumActive = 0

  init(heldKind: String = "json") { self.heldKind = heldKind }

  func run(_ kind: String) async throws {
    try Task.checkCancellation()
    active += 1
    maximumActive = max(active, maximumActive)
    events.append("start-" + kind)
    defer {
      active -= 1
      events.append("finish-" + kind)
    }
    guard kind == heldKind, !didHold else { return }
    didHold = true
    let (stream, continuation) = AsyncThrowingStream<Void, Error>.makeStream()
    release = continuation
    for observer in observers { observer.resume() }
    observers = []
    do {
      try await withTaskCancellationHandler {
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        try Task.checkCancellation()
      } onCancel: {
        continuation.finish(throwing: CancellationError())
      }
    } catch {
      events.append("cancel-" + kind)
      throw error
    }
  }

  func waitUntilHeld() async {
    if release != nil { return }
    await withCheckedContinuation { observers.append($0) }
  }

  func releaseHeld() {
    release?.finish()
    release = nil
  }
}

private struct BackgroundLeaseModel: StructuredChatModel {
  let probe: BackgroundLeaseProbe
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await probe.run("chat")
    onText("Fictional local reply")
  }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let relevance =
      grammar.contains("subject ::=") || grammar.contains("resolution")
      || grammar.contains("relevant")
    try await probe.run(relevance ? "relevance" : "json")
    if grammar.contains("subject ::=") {
      return #"{"assessment":"Controlled unnamed query.","subjects":[]}"#
    }
    if grammar.contains("resolution") {
      return #"{"assessment":"Controlled unnamed query.","resolution":"generic"}"#
    }
    return relevance ? #"{"relevant":true}"# : "{}"
  }
  func unload() async { try? await probe.run("unload") }
}

private struct BackgroundLeaseSpeech: TranscriptionProvider {
  let id = "fixture"
  let probe: BackgroundLeaseProbe
  func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    try await probe.run("speech")
    return TranscriptionOutput(modelID: "fixture", language: "en", passages: [])
  }
}

extension LocalInferenceCoordinatorTests {
  @Test(arguments: ["chat", "speech", "unload", "relevance"])
  func foregroundWorkCancelsAndJoinsBackgroundJSON(kind: String) async throws {
    let probe = BackgroundLeaseProbe()
    let coordinator = LocalInferenceCoordinator(model: BackgroundLeaseModel(probe: probe))
    let background = Task {
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
    }
    await probe.waitUntilHeld()
    switch kind {
    case "chat": try await coordinator.generate(turns: [], onText: { _ in })
    case "speech":
      _ = try await coordinator.transcribe(
        provider: BackgroundLeaseSpeech(probe: probe), audioURL: unusedURL,
        modelDirectory: unusedURL)
    case "relevance":
      _ = try await coordinator.selectRelevant(
        query: "fixture",
        candidates: [.init(id: UUID(), text: "Fictional source")])
    default: await coordinator.unload()
    }
    await #expect(throws: CancellationError.self) { try await background.value }
    let events = await probe.events
    let finished = try #require(events.firstIndex(of: "finish-json"))
    let started = try #require(events.firstIndex(of: "start-" + kind))
    #expect(finished < started)
    #expect(events.contains("cancel-json"))
    #expect(await probe.maximumActive == 1)
    #expect(await probe.active == 0)
    // The cancelled background slot must be reusable, with the same model and lease.
    #expect(
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
        == "{}")
  }

  @Test func callerCancellationPropagatesAndSecondBackgroundRequestCannotOverlap() async throws {
    let probe = BackgroundLeaseProbe()
    let coordinator = LocalInferenceCoordinator(model: BackgroundLeaseModel(probe: probe))
    let first = Task {
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
    }
    await probe.waitUntilHeld()
    await #expect(throws: ChatError.busy) {
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
    }
    first.cancel()
    await #expect(throws: CancellationError.self) { try await first.value }
    #expect(await probe.active == 0)
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(await probe.maximumActive == 1)
  }

  @Test func cancelledQueuedJSONDoesNotEnterModelOrStrandForegroundLease() async throws {
    let probe = BackgroundLeaseProbe(heldKind: "chat")
    let coordinator = LocalInferenceCoordinator(model: BackgroundLeaseModel(probe: probe))
    let first = Task { try await coordinator.generate(turns: [], onText: { _ in }) }
    await probe.waitUntilHeld()
    let queued = Task {
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
    }
    for _ in 0..<20 { await Task.yield() }
    queued.cancel()
    await probe.releaseHeld()
    try await first.value
    await #expect(throws: CancellationError.self) { try await queued.value }
    #expect(await !probe.events.contains("start-json"))
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(await probe.maximumActive == 1)
    #expect(await probe.active == 0)
  }

  @Test func relevanceCancellationReleasesLeaseBeforeNextChat() async throws {
    let probe = BackgroundLeaseProbe(heldKind: "relevance")
    let coordinator = LocalInferenceCoordinator(model: BackgroundLeaseModel(probe: probe))
    let task = Task {
      try await coordinator.selectRelevant(
        query: "fixture",
        candidates: [.init(id: UUID(), text: "Fictional source")])
    }
    await probe.waitUntilHeld()
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(await probe.maximumActive == 1)
    #expect(await probe.active == 0)
    #expect(await probe.events.contains("cancel-relevance"))
  }

  @Test func queuedCancelledRelevanceNeverLoadsAndEmptyBatchDoesNotInterrupt() async throws {
    let probe = BackgroundLeaseProbe(heldKind: "chat")
    let coordinator = LocalInferenceCoordinator(model: BackgroundLeaseModel(probe: probe))
    let chat = Task { try await coordinator.generate(turns: [], onText: { _ in }) }
    await probe.waitUntilHeld()
    #expect(
      try await coordinator.selectRelevant(query: "fixture", candidates: []).isEmpty)
    let queued = Task {
      try await coordinator.selectRelevant(
        query: "fixture",
        candidates: [.init(id: UUID(), text: "Fictional source")])
    }
    for _ in 0..<20 { await Task.yield() }
    queued.cancel()
    await probe.releaseHeld()
    try await chat.value
    await #expect(throws: CancellationError.self) { try await queued.value }
    #expect(await !probe.events.contains("start-relevance"))
    #expect(await !probe.events.contains("start-unload"))
    try await coordinator.generate(turns: [], onText: { _ in })
  }

  @Test func modelWithoutStructuredCapabilityCannotSilentlyUseChatFallback() async {
    let coordinator = LocalInferenceCoordinator(model: LeaseTextModel(probe: InferenceLeaseProbe()))
    await #expect(throws: ChatError.modelUnavailable) {
      try await coordinator.generateJSON(turns: [], grammar: "fixture", maximumOutputTokens: 64)
    }
    await #expect(throws: ChatError.modelUnavailable) {
      try await coordinator.selectRelevant(
        query: "fixture", candidates: [.init(id: UUID(), text: "Fictional source")])
    }
  }
}

private actor ResidentLeaseModel: StructuredChatModel {
  private let subject: String?
  private(set) var resident = false
  private(set) var loads = 0
  private(set) var unloads = 0
  private(set) var queries: [String] = []
  init(subject: String? = nil) { self.subject = subject }
  private func load() {
    if !resident { loads += 1 }
    resident = true
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    load()
    onText("Fictional reply")
  }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    load()
    queries.append(turns.last?.text ?? "")
    if grammar.contains("subject ::=") {
      if let subject {
        return "{\"assessment\":\"Controlled named query.\",\"subjects\":[\"\(subject)\"]}"
      }
      return #"{"assessment":"Controlled unnamed query.","subjects":[]}"#
    }
    if grammar.contains("resolution") {
      if subject != nil {
        return #"{"assessment":"Controlled named query.","resolution":"complete"}"#
      }
      return #"{"assessment":"Controlled unnamed query.","resolution":"generic"}"#
    }
    return #"{"relevant":true}"#
  }
  func unload() {
    resident = false
    unloads += 1
  }
}

extension LocalInferenceCoordinatorTests {
  @Test func sharedCoordinatorForwardsTypedIdentityWithoutChangingPassages() async throws {
    let model = ResidentLeaseModel(subject: "Nora")
    let coordinator = LocalInferenceCoordinator(model: model)
    let filter = try #require(
      await ChatComposition.makeRelevanceFilter(coordinator: coordinator)
        as? any SubjectAwareMemoryEvidenceFiltering)
    let evidence = ChatEvidence(id: UUID(), text: "Prefers a written reply.")
    #expect(
      try await filter.selectRelevant(
        query: "What reply does Nora prefer?", candidates: [evidence],
        identities: [.init(names: ["Nora", "نورا"], documentIDs: [evidence.id])]) == [evidence.id])
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data((await model.queries).last!.utf8))
        as? [String: String])
    #expect(payload["passage"] == evidence.text && payload["appLinkedSubject"] == "Nora")
    let loads = await model.loads
    let unloads = await model.unloads
    #expect(loads == 1 && unloads == 0)
  }

  @Test func chatAndRelevanceReuseOneResidentModelUntilExplicitUnload() async throws {
    let model = ResidentLeaseModel()
    let coordinator = LocalInferenceCoordinator(model: model)
    let filter = await ChatComposition.makeRelevanceFilter(coordinator: coordinator)
    let first = ChatEvidence(id: UUID(), text: "Nora offered to review the draft.")
    let changed = ChatEvidence(id: first.id, text: "Nora withdrew the offer.")
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(
      try await filter.selectRelevant(query: "Nora's offer?", candidates: [first]) == [first.id])
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(
      try await filter.selectRelevant(query: "Nora's offer?", candidates: [changed]) == [first.id])
    #expect(await model.loads == 1)
    #expect(await model.unloads == 0)
    let queries = await model.queries
    #expect(queries.count == 6 && queries[2] != queries[5])
    await coordinator.unload()
    #expect(await !model.resident)
    try await coordinator.generate(turns: [], onText: { _ in })
    #expect(await model.loads == 2)
    await coordinator.unload()
  }
}
