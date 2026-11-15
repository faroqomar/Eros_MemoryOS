import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

/// Explicit opt-in uses a pre-existing reviewed asset. Tests never download or use the network.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"] != nil))
struct PreparedLlamaChatContracts {
  private func runtime() throws -> LlamaTextRuntime {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"])
    return LlamaTextRuntime(
      assetURL: URL(fileURLWithPath: path),
      expectedSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a")
  }

  @Test func realFollowUpUsesEarlierTurnsAndStreamsPrefixText() async throws {
    let runtime = try runtime()
    defer { Task { await runtime.unload() } }
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let collector = Task {
      var values: [String] = []
      for await value in stream { values.append(value) }
      return values
    }
    let output = try await runtime.chat(
      turns: [
        .init(role: "system", text: "Answer briefly in English."),
        .init(role: "user", text: "My name is Mira. Reply OK."),
        .init(role: "assistant", text: "OK."),
        .init(role: "user", text: "What is my name? Reply with just my name."),
      ], onText: { continuation.yield($0) })
    continuation.finish()
    let chunks = await collector.value
    #expect(chunks.count > 1)
    #expect(chunks.last == output.text)
    #expect(zip(chunks, chunks.dropFirst()).allSatisfy { $1.hasPrefix($0) })
    #expect(output.text.contains("Mira"))
    #expect(output.firstTokenSeconds != nil)
    print(
      "CHAT_NATIVE_FOLLOWUP \(output.text) tokens=\(output.generatedTokenCount ?? 0) firstTokenSeconds=\(output.firstTokenSeconds ?? -1) preparationSeconds=\(output.preparationSeconds ?? -1)"
    )
  }

  @Test func successfulBridgeReportsCompletionMetricsOnce() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"])
    let (stream, continuation) = AsyncStream<(Int, Double, Double)>.makeStream()
    let collector = Task {
      var values: [(Int, Double, Double)] = []
      for await value in stream { values.append(value) }
      return values
    }
    let model = LlamaChatModel(
      assetURL: URL(fileURLWithPath: path),
      expectedSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a",
      onMeasurement: { output, duration in
        continuation.yield(
          (output.generatedTokenCount ?? 0, output.firstTokenSeconds ?? -1, duration))
      })
    try await model.generate(turns: [.init(role: .user, text: "Say hello.")], onText: { _ in })
    continuation.finish()
    let measurements = await collector.value
    #expect(measurements.count == 1)
    let measurement = try #require(measurements.first)
    #expect(measurement.0 > 0)
    #expect(measurement.1 > 0)
    #expect(measurement.2 >= measurement.1)
    await model.unload()
  }

  @Test func exactTokenContextOverflowRejectsBeforeAnyOutput() async throws {
    let runtime = try runtime()
    await #expect(throws: ChatError.contextLimit) {
      _ = try await runtime.chat(
        turns: [.init(role: "user", text: String(repeating: " x", count: 3000))],
        onText: { _ in
          Issue.record("Overflow must fail before output; no history may be silently truncated.")
        })
    }
    await runtime.unload()
  }

  @Test func cancellationPreservesAlreadyStreamedText() async throws {
    let runtime = try runtime()
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let collector = Task {
      var values: [String] = []
      for await value in stream { values.append(value) }
      return values
    }
    let operation = Task {
      try await runtime.chat(
        turns: [.init(role: "user", text: "List the numbers from 1 to 100, one number per line.")],
        onText: { text in
          continuation.yield(text)
          if text.count >= 8 { withUnsafeCurrentTask { $0?.cancel() } }
        })
    }
    await #expect(throws: CancellationError.self) { _ = try await operation.value }
    continuation.finish()
    let chunks = await collector.value
    #expect((chunks.last?.count ?? 0) >= 8)
    await runtime.unload()
  }

  @Test func outputLimitReportsThatTheStreamedReplyIsPartial() async throws {
    let runtime = try runtime()
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let collector = Task {
      var values: [String] = []
      for await value in stream { values.append(value) }
      return values
    }
    await #expect(throws: ChatError.outputLimit) {
      _ = try await runtime.chat(
        turns: [
          .init(
            role: "user",
            text: "List all integers from 1 to 1000 in order, with no omissions. Do not stop early."
          )
        ], onText: { continuation.yield($0) })
    }
    continuation.finish()
    let chunks = await collector.value
    #expect(!(chunks.last ?? "").isEmpty)
    await runtime.unload()
  }

  @Test func failedEmptyReplyDoesNotBreakTheNextUserTurn() async throws {
    let runtime = try runtime()
    let output = try await runtime.chat(
      turns: [
        .init(role: "user", text: "Hello"), .init(role: "assistant", text: ""),
        .init(role: "user", text: "Say hello."),
      ], onText: { _ in })
    #expect(!output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    await runtime.unload()
  }

  @Test func actualArabicOutputStreamsWithoutReplacementCharacters() async throws {
    let runtime = try runtime()
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let collector = Task {
      var values: [String] = []
      for await value in stream { values.append(value) }
      return values
    }
    let output = try await runtime.chat(
      turns: [.init(role: "user", text: "اكتب اسم علي فقط.")], onText: { continuation.yield($0) })
    continuation.finish()
    let chunks = await collector.value
    #expect(!output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    #expect(chunks.allSatisfy { !$0.contains("\u{FFFD}") })
    #expect(chunks.last == output.text)
    print("CHAT_NATIVE_ARABIC \(output.text)")
    await runtime.unload()
  }
}
