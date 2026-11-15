import AIEvaluationCore
import Foundation
import Testing

@testable import MLXEvaluationAdapter

@Test func missingAssetsStayUnavailableAndDoNotDownload() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let runtime = MLXTextRuntime(modelDirectory: directory)
  #if targetEnvironment(simulator)
    let expected = EvaluationError.unavailable(
      "The reviewed MLX runtime does not support iOS Simulator inference. Use an Apple silicon Mac or a physical iPhone for this configuration."
    )
  #else
    let expected = EvaluationError.unavailable(
      "A required local MLX model/tokenizer asset is missing.")
  #endif
  await #expect(throws: expected) {
    try await runtime.generate(
      request: TextRequest(instruction: "Use the source.", question: "Hello", sources: []),
      settings: .init())
  }
  #expect(!FileManager.default.fileExists(atPath: directory.path))
}

@Test func remoteModelURLIsRejectedBeforeAnyLoading() async throws {
  let runtime = MLXTextRuntime(
    modelDirectory: try #require(URL(string: "https://example.invalid/model")))
  await #expect(
    throws: EvaluationError.unavailable("MLX requires an explicit local model directory.")
  ) {
    try await runtime.generate(
      request: TextRequest(instruction: "Use the source.", question: "Hello", sources: []),
      settings: .init())
  }
}

@Test func changedAssetBytesAreRejectedBeforeSDKModelLoad() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  for file in ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"] {
    try Data("altered-fixture".utf8).write(to: directory.appendingPathComponent(file))
  }
  let runtime = MLXTextRuntime(modelDirectory: directory)
  #if targetEnvironment(simulator)
    let expected = EvaluationError.unavailable(
      "The reviewed MLX runtime does not support iOS Simulator inference. Use an Apple silicon Mac or a physical iPhone for this configuration."
    )
  #else
    let expected = EvaluationError.unavailable(
      "A local MLX model/tokenizer asset differs from the reviewed fixture.")
  #endif
  await #expect(throws: expected) {
    try await runtime.generate(
      request: .init(instruction: "", question: "Hello", sources: []), settings: .init())
  }
}

@Test(arguments: [
  GenerationSettings(maximumOutputTokens: 0), GenerationSettings(temperature: .nan),
  GenerationSettings(temperature: .greatestFiniteMagnitude),
])
func invalidSettingsAreRejectedBeforeLoading(_ settings: GenerationSettings) async {
  let runtime = MLXTextRuntime(modelDirectory: URL(fileURLWithPath: "/missing-fixture"))
  await #expect(throws: EvaluationError.invalidSuite("Invalid generation settings.")) {
    try await runtime.generate(
      request: .init(instruction: "", question: "", sources: []),
      settings: settings)
  }
}

@Test func promptPreservesFictionalUnicodeAndContainsNoAnswerKey() {
  let suite = EvaluationSuite.fictional()
  let item = suite.cases[0]
  let request = TextRequest(
    instruction: "Only source data.", question: item.query, sources: suite.records)
  let prompt = MLXTextRuntime.prompt(request)
  #expect(prompt.contains("Café نور 🌙"))
  #expect(prompt.contains("[SOURCE ar-birthday]"))
  #expect(prompt.contains(item.query))
  #expect(!prompt.contains(item.reviewGuidance))
  #expect(!prompt.contains("expectedSourceIDs"))
}

@Test func cancellationBeforeLoadDoesNotAccessModel() async throws {
  let runtime = MLXTextRuntime(modelDirectory: URL(fileURLWithPath: "/missing-fixture"))
  let (gate, continuation) = AsyncStream<Void>.makeStream()
  let task = Task {
    var iterator = gate.makeAsyncIterator()
    _ = await iterator.next()
    return try await runtime.generate(
      request: .init(instruction: "", question: "", sources: []), settings: .init())
  }
  task.cancel()
  continuation.finish()
  await #expect(throws: CancellationError.self) { try await task.value }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_MLX_MODEL_DIR"] != nil))
func realLocalModelGeneratesBoundedText() async throws {
  let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_MLX_MODEL_DIR"])
  let runtime = MLXTextRuntime(modelDirectory: URL(fileURLWithPath: path))
  let output = try await runtime.generate(
    request: .init(
      instruction: "Use only the fictional source and answer briefly.",
      question: "When is Maya Haddad's birthday?",
      sources: [EvaluationSuite.fictional().records[0]]),
    settings: .init(maximumOutputTokens: 32))
  #expect(!output.text.isEmpty)
  let tokens = try #require(output.generatedTokenCount)
  #expect(tokens > 0 && tokens <= 32)
  #expect(output.wasColdLoad == true)
  #expect(try #require(output.preparationSeconds) >= 0)
  #expect(try #require(output.firstTokenSeconds) > 0)
  let warm = try await runtime.generate(
    request: .init(instruction: "Answer briefly.", question: "Say hello.", sources: []),
    settings: .init(maximumOutputTokens: 16))
  #expect(!warm.text.isEmpty)
  #expect(warm.wasColdLoad == false)
  #expect(try #require(warm.generatedTokenCount) <= 16)
  let longRun = Task {
    try await runtime.generate(
      request: .init(
        instruction: "Write the complete list from 1 to 100. Keep going until 100.",
        question: "List the numbers from 1 to 100, separated by commas.", sources: []),
      settings: .init(maximumOutputTokens: 256))
  }
  try await Task.sleep(for: .milliseconds(50))
  longRun.cancel()
  await #expect(throws: CancellationError.self) { try await longRun.value }
  let afterCancel = try await runtime.generate(
    request: .init(instruction: "Answer briefly.", question: "Say hello.", sources: []),
    settings: .init(maximumOutputTokens: 16))
  #expect(!afterCancel.text.isEmpty)
  #expect(afterCancel.wasColdLoad == false)
  // Language correctness still needs human review; nonempty output only proves the real SDK ran.
}
