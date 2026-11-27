import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

@testable import MemoryOS

private struct RuntimeContractMeasurement: Sendable {
  let wasColdLoad: Bool?
}

/// The signal marks entry to an actual JSON SDK call, not its first decoded token.
/// The separate streamed-token test establishes cancellation during native generation.
private actor ObservedRuntimeContractModel: StructuredChatModel {
  let base: LlamaChatModel
  let started: AsyncStream<Void>.Continuation
  private(set) var events: [String] = []
  private(set) var active = 0
  private(set) var maximumActive = 0

  init(base: LlamaChatModel, started: AsyncStream<Void>.Continuation) {
    self.base = base
    self.started = started
  }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    active += 1
    maximumActive = max(maximumActive, active)
    events.append("json-start")
    defer {
      active -= 1
      events.append("json-end")
    }
    started.yield(())
    return try await base.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    active += 1
    maximumActive = max(maximumActive, active)
    events.append("chat-start")
    defer {
      active -= 1
      events.append("chat-end")
    }
    try await base.generate(turns: turns, onText: onText)
  }

  func unload() async { await base.unload() }
}

/// No asset downloads or fallback. Root runs this suite alone with the pinned bundled model.
/// These are runtime contracts, not relationship accuracy or physical-device qualification.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RUNTIME_MODEL_CONTRACTS"] == "1")
)
@MainActor struct RuntimeModelContractTests {
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_TEST_CHAT_SAMPLING"] != nil),
    .timeLimit(.minutes(5)))
  func seededSamplingResetsAfterInterveningRequestTruncationAndReload() async throws {
    let configuration = try RuntimeTestModel.configuration()
    let sampling = try RuntimeTestModel.sampling(selection: configuration.selection)
    try #require(sampling != .greedy)
    let model = LlamaChatModel(
      assetURL: configuration.assetURL, expectedSHA256: configuration.expectedSHA256,
      chatSampling: sampling)
    let request = [
      ChatTurn(role: .user, text: "Choose one arbitrary color from the allowed choices.")
    ]
    let grammar =
      #"root ::= "{\"color\":" ("\"blue\"" | "\"red\"" | "\"green\"" | "\"purple\"") "}""#
    let before = try await model.generateJSON(
      turns: request, grammar: grammar, maximumOutputTokens: 32)
    let intervening = try await model.generateJSON(
      turns: [.init(role: .user, text: "Return only the required Arabic JSON.")],
      grammar: #"root ::= "{\"label\":\"دواء\"}""#, maximumOutputTokens: 32)
    #expect(intervening == #"{"label":"دواء"}"#)
    await #expect(throws: ChatError.outputLimit) {
      try await model.generateJSON(
        turns: request, grammar: grammar, maximumOutputTokens: 1)
    }
    let after = try await model.generateJSON(
      turns: request, grammar: grammar, maximumOutputTokens: 32)
    #expect(after == before)
    await model.unload()
    let reloaded = try await model.generateJSON(
      turns: request, grammar: grammar, maximumOutputTokens: 32)
    #expect(reloaded == before)
    await model.unload()
  }

  @Test(.timeLimit(.minutes(5)))
  func nativeDefaultSubjectGrammarAcceptsEscapedQuerySpans() async throws {
    let query = #"Find 2023/12/21 Aurora"Boreal folder\notes نادية/سلمى folder\/notes."#
    let captured = try await SubjectGrammarTransportFixture.capture(query: query)
    try await withModel { model, _ in
      // Pass production grammar and turns unchanged. The parser validates all choices,
      // including choices the model does not emit. This is not a semantic-quality test.
      let output = try await model.generateJSON(
        turns: captured.turns, grammar: captured.grammar, maximumOutputTokens: 160)
      let choices = try SubjectGrammarTransportFixture.subjects(in: captured.grammar)
      let value = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
      #expect(Set(value.keys) == ["assessment", "subjects"])
      let assessment = try #require(value["assessment"] as? String)
      #expect(!assessment.isEmpty)
      let subjects = try #require(value["subjects"] as? [String])
      #expect(subjects.count <= 4)
      #expect(
        subjects.allSatisfy { subject in
          choices.contains { Data($0.utf8) == Data(subject.utf8) }
        })
    }
  }

  @Test(.timeLimit(.minutes(5)))
  func nativeGrammarContextResetAndUnloadReload() async throws {
    try await withModel { model, measurements in
      let grammar = #"root ::= "{\"color\":" ("\"blue\"" | "\"red\"") "}""#
      let blue = [
        ChatTurn(
          role: .user,
          text:
            "The color in this request is blue. Return its color as JSON. Use this request only.")
      ]
      let red = [
        ChatTurn(
          role: .user,
          text: "The color in this request is red. Return its color as JSON. Use this request only."
        )
      ]
      let before = try await model.generateJSON(
        turns: blue, grammar: grammar, maximumOutputTokens: 32)
      let intervening = try await model.generateJSON(
        turns: red, grammar: grammar, maximumOutputTokens: 32)
      let after = try await model.generateJSON(
        turns: blue, grammar: grammar, maximumOutputTokens: 32)
      #expect(before == #"{"color":"blue"}"#)
      #expect(intervening == #"{"color":"red"}"#)
      #expect(after == before, "Independent requests must reset attention and recurrent state.")

      let arabic = try await model.generateJSON(
        turns: [.init(role: .user, text: "Return only the required JSON object.")],
        grammar: #"root ::= "{\"label\":\"دواء\",\"ok\":true}""#,
        maximumOutputTokens: 64)
      #expect(arabic == #"{"label":"دواء","ok":true}"#)
      #expect(!arabic.contains("\u{FFFD}"))

      await #expect(throws: ChatError.outputLimit) {
        try await model.generateJSON(
          turns: [.init(role: .user, text: "Return only the required JSON object.")],
          grammar: #"root ::= "{\"long\":\"abcdefghijklmnopqrstuvwxyz\"}""#,
          maximumOutputTokens: 1)
      }
      #expect(
        try await model.generateJSON(
          turns: [.init(role: .user, text: "Return only the required JSON object.")],
          grammar: #"root ::= "{\"ready\":true}""#, maximumOutputTokens: 32)
          == #"{"ready":true}"#)

      let turns = [ChatTurn(role: .user, text: "Reply with OK only.")]
      var measurementIterator = measurements.makeAsyncIterator()
      let warm = try await generateAndCollect(model: model, turns: turns)
      let warmMeasurement = try #require(await measurementIterator.next())
      #expect(warmMeasurement.wasColdLoad == false)
      #expect(!warm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      sample("before-unload")
      await model.unload()
      sample("after-unload")
      let reloaded = try await generateAndCollect(model: model, turns: turns)
      let reloadedMeasurement = try #require(await measurementIterator.next())
      #expect(reloadedMeasurement.wasColdLoad == true)
      #expect(reloaded == warm)
      sample("after-reload")
    }
  }

  @Test(.timeLimit(.minutes(5)))
  func cancellationDuringNativeOutputJoinsBeforeFreshRequest() async throws {
    try await withModel { model, _ in
      let clock = ContinuousClock()
      let (signals, signal) = AsyncStream<ContinuousClock.Instant>.makeStream(
        bufferingPolicy: .bufferingNewest(1))
      let operation = Task {
        try await model.generate(
          turns: [
            .init(role: .user, text: "List the integers from 1 to 200, one per line.")
          ],
          onText: { _ in
            // The runtime publishes only complete UTF-8; no reply content is retained here.
            signal.yield(clock.now)
            withUnsafeCurrentTask { $0?.cancel() }
          })
      }
      await #expect(throws: CancellationError.self) { _ = try await operation.value }
      let joined = clock.now
      signal.finish()
      var requested: ContinuousClock.Instant?
      for await instant in signals { requested = instant }
      let cancellation = try #require(requested)
      sample("cancel-joined", seconds: seconds(cancellation.duration(to: joined)))
      #expect(
        try await model.generateJSON(
          turns: [.init(role: .user, text: "Return only the required JSON object.")],
          grammar: #"root ::= "{\"recovered\":true}""#, maximumOutputTokens: 32)
          == #"{"recovered":true}"#)
      sample("cancel-recovered")
    }
  }

  @Test(.timeLimit(.minutes(5)))
  func coordinatorPreemptsActualSDKCallThenRecovers() async throws {
    let configuration = try RuntimeTestModel.configuration()
    let (signals, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let observed = ObservedRuntimeContractModel(
      base: LlamaChatModel(
        assetURL: configuration.assetURL, expectedSHA256: configuration.expectedSHA256),
      started: signal)
    let coordinator = LocalInferenceCoordinator(model: observed)
    let background = Task {
      try await coordinator.generateJSON(
        turns: [.init(role: .user, text: "Return the required long JSON object.")],
        grammar: #"root ::= "{\"value\":\"" [a-z]{800} "\"}""#,
        maximumOutputTokens: 512)
    }
    do {
      var iterator = signals.makeAsyncIterator()
      _ = try #require(await iterator.next())
      let clock = ContinuousClock()
      let start = clock.now
      let (chunks, chunk) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
      try await coordinator.generate(
        turns: [.init(role: .user, text: "Reply with Ready only.")],
        onText: { _ in chunk.yield(()) })
      chunk.finish()
      var chunkIterator = chunks.makeAsyncIterator()
      _ = try #require(await chunkIterator.next())
      await #expect(throws: CancellationError.self) { _ = try await background.value }
      sample("foreground-preemption-complete", seconds: seconds(start.duration(to: clock.now)))
      let events = await observed.events
      let stopped = try #require(events.firstIndex(of: "json-end"))
      let started = try #require(events.firstIndex(of: "chat-start"))
      #expect(stopped < started)
      let maximumActive = await observed.maximumActive
      let active = await observed.active
      #expect(maximumActive == 1)
      #expect(active == 0)
      #expect(
        try await coordinator.generateJSON(
          turns: [.init(role: .user, text: "Return only the required JSON object.")],
          grammar: #"root ::= "{\"ready\":true}""#, maximumOutputTokens: 32)
          == #"{"ready":true}"#)
      await coordinator.unload()
      signal.finish()
    } catch {
      background.cancel()
      _ = try? await background.value
      await coordinator.unload()
      signal.finish()
      throw error
    }
  }

  private func withModel(
    _ body:
      @MainActor (LlamaChatModel, AsyncStream<RuntimeContractMeasurement>) async throws -> Void
  ) async throws {
    let configuration = try RuntimeTestModel.configuration()
    print(
      "RUNTIME_MODEL_CONTRACT selection=\(configuration.selection) sha256=\(configuration.expectedSHA256)"
    )
    let (measurements, measurement) = AsyncStream<RuntimeContractMeasurement>.makeStream(
      bufferingPolicy: .bufferingNewest(1))
    let model = LlamaChatModel(
      assetURL: configuration.assetURL, expectedSHA256: configuration.expectedSHA256,
      onMeasurement: { output, _ in
        measurement.yield(RuntimeContractMeasurement(wasColdLoad: output.wasColdLoad))
      })
    defer { measurement.finish() }
    do { try await body(model, measurements) } catch {
      await model.unload()
      throw error
    }
    await model.unload()
  }

  /// ChatModel streams the cumulative reply. Keep its final value only for assertions.
  private func generateAndCollect(model: LlamaChatModel, turns: [ChatTurn]) async throws -> String {
    let (chunks, chunk) = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(1))
    do {
      try await model.generate(turns: turns, onText: { chunk.yield($0) })
    } catch {
      chunk.finish()
      throw error
    }
    chunk.finish()
    var final: String?
    for await value in chunks { final = value }
    return try #require(final)
  }

  private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }

  /// Endpoint resident-size samples only; they are not a peak or phone memory benchmark.
  private func sample(_ stage: String, seconds: Double? = nil) {
    let value: [String: Any] = [
      "stage": stage,
      "seconds": seconds.map { $0 as Any } ?? NSNull(),
      "sampleResidentBytes": ChatMeasurement.residentBytes().map { $0 as Any } ?? NSNull(),
    ]
    if let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
      print("RUNTIME_MODEL_SAMPLE " + String(decoding: bytes, as: UTF8.self))
    }
  }
}
