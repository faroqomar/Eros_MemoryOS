import AIEvaluationCore
import CryptoKit
import Foundation
import LlamaEvaluationAdapter
import Testing

private let request = TextRequest(instruction: "Use sources only.", question: "Where?", sources: [])

@Test(arguments: [
  TextRequest(instruction: "Use\u{0}all sources.", question: "Where?", sources: []),
  TextRequest(instruction: "Use sources only.", question: "Where\u{0}is it?", sources: []),
  TextRequest(
    instruction: "Use sources only.", question: "Where?",
    sources: [.init(id: "source\u{0}suffix", text: "Fictional source.", language: "en")]),
  TextRequest(
    instruction: "Use sources only.", question: "Where?",
    sources: [.init(id: "source", text: "Original\u{0}source suffix.", language: "en")]),
])
func embeddedNullPromptIsRejectedBeforeOpeningTheModel(_ nulRequest: TextRequest) async {
  let runtime = LlamaTextRuntime(
    assetURL: URL(fileURLWithPath: "/nonexistent-memoryos-nul-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64))
  do {
    _ = try await runtime.generate(request: nulRequest, settings: .init())
    Issue.record("The adapter accepted a prompt that the C string boundary would truncate.")
  } catch EvaluationError.invalidSuite {
    // Validation must happen before an absent model can hide the invalid prompt.
  } catch {
    Issue.record("Expected invalidSuite before model loading, received: \(error)")
  }
}

@Test func nativeSDKRejectsAHashVerifiedInvalidModel() async throws {
  let data = Data("This is a fictional invalid model, not GGUF.".utf8)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try data.write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  let runtime = LlamaTextRuntime(assetURL: url, expectedSHA256: digest)
  await #expect(throws: EvaluationError.self) {
    _ = try await runtime.generate(request: request, settings: .init())
  }
  await runtime.unload()
}

@Test func missingAssetCannotBecomeAResponse() async throws {
  let runtime = LlamaTextRuntime(
    assetURL: URL(fileURLWithPath: "/nonexistent-memoryos-fixture.gguf"),
    expectedSHA256: String(repeating: "0", count: 64))
  await #expect(throws: EvaluationError.self) {
    _ = try await runtime.generate(request: request, settings: .init())
  }
}

@Test func mismatchedAssetIsRejectedBeforeModelLoading() async throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try Data("fictional invalid GGUF".utf8).write(to: url)
  let runtime = LlamaTextRuntime(assetURL: url, expectedSHA256: String(repeating: "0", count: 64))
  do {
    _ = try await runtime.generate(request: request, settings: .init())
    Issue.record("The adapter accepted a mismatched asset.")
  } catch let error as EvaluationError {
    #expect(error.localizedDescription.contains("SHA-256 does not match"))
  }
}

@Test func unsupportedSamplingCannotSilentlyChangeTheExperiment() async {
  let runtime = LlamaTextRuntime(assetURL: URL(fileURLWithPath: "/unused"), expectedSHA256: "")
  await #expect(throws: EvaluationError.self) {
    _ = try await runtime.generate(request: request, settings: .init(temperature: 0.7))
  }
}

@Test func remoteAssetURLIsRejectedWithoutNetworkLoading() async {
  let runtime = LlamaTextRuntime(
    assetURL: URL(string: "https://example.invalid/model.gguf")!,
    expectedSHA256: String(repeating: "0", count: 64))
  do {
    _ = try await runtime.generate(request: request, settings: .init())
    Issue.record("A remote model URL was accepted.")
  } catch let error as EvaluationError {
    #expect(error.localizedDescription.contains("local file URL"))
  } catch { Issue.record("Expected the explicit local-only guard.") }
}

/// Test-only synchronous resolver state. The lock protects both the queue and call count.
private final class ColdAssetSequence: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [URL]
  private var calls = 0
  init(_ values: [URL]) { self.values = values }
  func resolve() -> URL {
    lock.withLock {
      calls += 1
      return values.isEmpty
        ? URL(filePath: "/unexpected-extra-memoryos-resolution") : values.removeFirst()
    }
  }
  var count: Int { lock.withLock { calls } }
}

@Test func eachFailedColdLoadResolvesOnceAndVerifiesThatResolvedLocalAsset() async throws {
  let corrupt = URL.temporaryDirectory.appending(path: "memoryos-resolver-" + UUID().uuidString)
  try Data("fictional corrupt weights".utf8).write(to: corrupt)
  defer { try? FileManager.default.removeItem(at: corrupt) }
  let sequence = ColdAssetSequence([
    URL(string: "https://example.invalid/no-network-model.gguf")!, corrupt,
    URL(filePath: "/nonexistent-memoryos-resolved-fixture.gguf"),
  ])
  let runtime = LlamaTextRuntime(
    assetURL: URL(filePath: "/unused-default-model.gguf"),
    expectedSHA256: String(repeating: "0", count: 64), assetURLResolver: { sequence.resolve() })
  for (index, reason) in ["local file URL", "SHA-256 does not match", "local GGUF model"]
    .enumerated()
  {
    do {
      _ = try await runtime.generate(request: request, settings: .init())
      Issue.record("An unavailable resolved asset generated output.")
    } catch let error as EvaluationError {
      #expect(error.localizedDescription.contains(reason))
    }
    #expect(sequence.count == index + 1)
  }
}

@Test func invalidPromptDoesNotInvokeTheColdAssetResolver() async {
  let sequence = ColdAssetSequence([URL(filePath: "/unused")])
  let runtime = LlamaTextRuntime(
    assetURL: URL(filePath: "/unused-default"),
    expectedSHA256: String(repeating: "0", count: 64), assetURLResolver: { sequence.resolve() })
  await #expect(throws: EvaluationError.self) {
    _ = try await runtime.generate(
      request: TextRequest(instruction: "before\u{0}after", question: "Where?", sources: []),
      settings: .init())
  }
  #expect(sequence.count == 0)
}
