import AIEvaluationCore
import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

private func absentChatRuntime() -> LlamaTextRuntime {
  LlamaTextRuntime(
    assetURL: URL(fileURLWithPath: "/nonexistent-memoryos-chat-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64))
}

@Test(arguments: [
  [],
  [LlamaChatTurn(role: "tool", text: "Unapproved tool result")],
  [LlamaChatTurn(role: "assistant", text: "No user request")],
  [
    LlamaChatTurn(role: "user", text: "First"), .init(role: "system", text: "Late system"),
    .init(role: "user", text: "Second"),
  ],
  [LlamaChatTurn(role: "user", text: "First"), .init(role: "user", text: "Second")],
  [LlamaChatTurn(role: "user", text: "Before\u{0}after")],
  [LlamaChatTurn(role: "system", text: "Before\u{0}after"), .init(role: "user", text: "Question")],
  [LlamaChatTurn(role: "user", text: "  \n")],
])
func malformedChatFailsBeforeAssetAccess(_ turns: [LlamaChatTurn]) async {
  do {
    _ = try await absentChatRuntime().chat(
      turns: turns,
      onText: { _ in
        Issue.record("Invalid input produced text.")
      })
    Issue.record("Invalid chat was accepted.")
  } catch EvaluationError.invalidSuite {
    // The absent model must not hide validation errors or silent C-string truncation.
  } catch { Issue.record("Expected invalidSuite, received \(error)") }
}

@Test func overlongChatFailsWithoutSilentlyDroppingTurns() async {
  await #expect(throws: ChatError.contextLimit) {
    _ = try await absentChatRuntime().chat(
      turns: [.init(role: "user", text: String(repeating: "ع", count: 50_001))],
      onText: { _ in
        Issue.record("An overlong prompt produced text.")
      })
  }
}

@Test func missingLocalModelMapsToChatRecoveryError() async {
  let adapter = LlamaChatModel(
    assetURL: URL(fileURLWithPath: "/nonexistent-memoryos-chat.gguf"),
    expectedSHA256: String(repeating: "0", count: 64))
  await #expect(throws: ChatError.modelUnavailable) {
    try await adapter.generate(
      turns: [.init(role: .user, text: "Hello")],
      onText: { _ in
        Issue.record("A missing model produced text.")
      })
  }
}

@Test func remoteChatAssetCannotStartNetworkLoading() async {
  let adapter = LlamaChatModel(
    assetURL: URL(string: "https://example.invalid/model.gguf")!,
    expectedSHA256: String(repeating: "0", count: 64))
  await #expect(throws: ChatError.modelUnavailable) {
    try await adapter.generate(
      turns: [.init(role: .user, text: "Hello")],
      onText: { _ in
        Issue.record("A remote model produced text.")
      })
  }
}

@Test func cancelledChatStaysCancelledThroughTheBridge() async {
  let adapter = LlamaChatModel(assetURL: URL(fileURLWithPath: "/unused"), expectedSHA256: "")
  let operation = Task {
    withUnsafeCurrentTask { $0?.cancel() }
    try await adapter.generate(turns: [.init(role: .user, text: "Hello")], onText: { _ in })
  }
  await #expect(throws: CancellationError.self) { try await operation.value }
}

@Test func failedBridgeDoesNotReportSuccessfulMeasurements() async {
  let model = LlamaChatModel(
    assetURL: URL(fileURLWithPath: "/nonexistent-memoryos-chat.gguf"),
    expectedSHA256: String(repeating: "0", count: 64),
    onMeasurement: { _, _ in Issue.record("A failed request must not report successful metrics.") })
  await #expect(throws: ChatError.modelUnavailable) {
    try await model.generate(turns: [.init(role: .user, text: "Hello")], onText: { _ in })
  }
}
