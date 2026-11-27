import AIEvaluationCore
import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

private func absentStructuredRuntime() -> LlamaTextRuntime {
  LlamaTextRuntime(
    assetURL: URL(fileURLWithPath: "/absent-memoryos-json-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64))
}

@Test(arguments: [
  LlamaChatSampling.qwen3NonThinking(seed: UInt32.max),
  LlamaChatSampling.qwen35NonThinking(seed: UInt32.max),
])
func randomSeedSentinelFailsBeforeOpeningAsset(sampling: LlamaChatSampling) async {
  let runtime = LlamaTextRuntime(
    assetURL: URL(fileURLWithPath: "/absent-memoryos-json-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64), chatSampling: sampling)
  await #expect(throws: EvaluationError.invalidSuite("A fixed chat-sampling seed is required.")) {
    try await runtime.chat(
      turns: [.init(role: "user", text: "Fictional seeded request")], onText: { _ in })
  }
  await #expect(throws: EvaluationError.invalidSuite("A fixed chat-sampling seed is required.")) {
    try await runtime.generateJSON(
      turns: [.init(role: "user", text: "Fictional seeded request")],
      grammar: #"root ::= "{}""#, maximumOutputTokens: 32)
  }
}

@Test(arguments: [0, -1, 513, Int.max])
func structuredOutputBoundsFailBeforeOpeningAsset(limit: Int) async {
  do {
    _ = try await absentStructuredRuntime().generateJSON(
      turns: [.init(role: "user", text: "Fictional structured request")],
      grammar: #"root ::= "{}""#, maximumOutputTokens: limit)
    Issue.record("Invalid structured output bound was accepted")
  } catch EvaluationError.invalidSuite {
  } catch { Issue.record("Expected input rejection before asset loading: \(error)") }
}

@Test(arguments: [
  "", " \n", "root ::= \"before\u{0}after\"", String(repeating: "x", count: 32_001),
])
func unsafeOrUnboundedAppGrammarFailsBeforeOpeningAsset(grammar: String) async {
  do {
    _ = try await absentStructuredRuntime().generateJSON(
      turns: [.init(role: "user", text: "Fictional structured request")],
      grammar: grammar, maximumOutputTokens: 32)
    Issue.record("Invalid app grammar was accepted")
  } catch EvaluationError.invalidSuite {
  } catch { Issue.record("Expected app-grammar input rejection: \(error)") }
}

@Test func structuredRequestsKeepRoleAndNULValidation() async {
  do {
    _ = try await absentStructuredRuntime().generateJSON(
      turns: [.init(role: "user", text: "before\u{0}after")],
      grammar: #"root ::= "{}""#, maximumOutputTokens: 32)
    Issue.record("NUL-terminated source was accepted")
  } catch EvaluationError.invalidSuite {
  } catch { Issue.record("Expected source validation before asset access: \(error)") }
}

@Test func missingStructuredAssetUsesExistingRecoveryError() async {
  let model = LlamaChatModel(
    assetURL: URL(fileURLWithPath: "/absent-memoryos-json-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64),
    onMeasurement: { _, _ in Issue.record("Failed extraction reached chat metrics") })
  await #expect(throws: ChatError.modelUnavailable) {
    try await model.generateJSON(
      turns: [.init(role: .user, text: "Fictional structured request")],
      grammar: #"root ::= "{}""#, maximumOutputTokens: 32)
  }
}

/// Opt-in probes syntax/state/resource contracts, not extraction meaning or model quality.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"] != nil))
struct PreparedStructuredGenerationContracts {
  private func runtime() throws -> LlamaTextRuntime {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"])
    return LlamaTextRuntime(
      assetURL: URL(fileURLWithPath: path),
      expectedSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a")
  }

  @Test func freshGrammarStateAcceptsDifferentSchemasAndArabicUTF8() async throws {
    let runtime = try runtime()
    let request = [LlamaChatTurn(role: "user", text: "Return the required JSON object only.")]
    let first = try await runtime.generateJSON(
      turns: request, grammar: #"root ::= "{\"name\":\"ميرا\"}""#,
      maximumOutputTokens: 64)
    #expect(first == #"{"name":"ميرا"}"#)
    let second = try await runtime.generateJSON(
      turns: request, grammar: #"root ::= "{\"ok\":true}""#,
      maximumOutputTokens: 64)
    #expect(second == #"{"ok":true}"#)
    await runtime.unload()
  }

  @Test func invalidGrammarAndNonJSONCannotBecomeSuccessfulPayloads() async throws {
    let runtime = try runtime()
    let request = [LlamaChatTurn(role: "user", text: "Return the required JSON object only.")]
    await #expect(throws: EvaluationError.self) {
      try await runtime.generateJSON(
        turns: request, grammar: "root ::= [", maximumOutputTokens: 64)
    }
    await #expect(throws: EvaluationError.self) {
      try await runtime.generateJSON(
        turns: request, grammar: #"root ::= "not-json""#, maximumOutputTokens: 64)
    }
    let recovered = try await runtime.generateJSON(
      turns: request, grammar: #"root ::= "{}""#, maximumOutputTokens: 64)
    #expect(recovered == "{}")
    await runtime.unload()
  }

  @Test func truncatedJSONThrowsAndNextRequestGetsFreshSampler() async throws {
    let runtime = try runtime()
    let request = [LlamaChatTurn(role: "user", text: "Return the required JSON object only.")]
    await #expect(throws: ChatError.outputLimit) {
      try await runtime.generateJSON(
        turns: request,
        grammar: #"root ::= "{\"long\":\"abcdefghijklmnopqrstuvwxyz\"}""#,
        maximumOutputTokens: 1)
    }
    let recovered = try await runtime.generateJSON(
      turns: request, grammar: #"root ::= "{}""#, maximumOutputTokens: 64)
    #expect(recovered == "{}")
    await runtime.unload()
  }

  @Test func structuredBridgeDoesNotPolluteChatMetrics() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_CHAT_NATIVE_MODEL"])
    let model = LlamaChatModel(
      assetURL: URL(fileURLWithPath: path),
      expectedSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a",
      onMeasurement: { _, _ in Issue.record("Extraction reached ordinary chat metrics") })
    let result = try await model.generateJSON(
      turns: [.init(role: .user, text: "Return the required JSON object only.")],
      grammar: #"root ::= "{}""#, maximumOutputTokens: 64)
    #expect(result == "{}")
    await model.unload()
  }
}
