import AIEvaluationCore
import CryptoKit
import Foundation
import MLXLLM
import MLXLMCommon

/// Local-only MLX adapter. SDK types stay inside this target; sources and outputs use app-owned values.
public actor MLXTextRuntime: TextRuntimeAdapter {
  private let modelDirectory: URL
  private var container: ModelContainer?
  private var generating = false

  public init(modelDirectory: URL) { self.modelDirectory = modelDirectory }

  public func generate(request: TextRequest, settings: GenerationSettings) async throws
    -> TextOutput
  {
    try Task.checkCancellation()
    let requestStart = ContinuousClock.now
    guard !generating else {
      throw EvaluationError.unavailable("This MLX adapter already has an active generation.")
    }
    guard modelDirectory.isFileURL else {
      throw EvaluationError.unavailable("MLX requires an explicit local model directory.")
    }
    guard settings.maximumOutputTokens > 0, settings.temperature.isFinite,
      settings.temperature >= 0, settings.temperature <= Double(Float.greatestFiniteMagnitude)
    else { throw EvaluationError.invalidSuite("Invalid generation settings.") }
    try Self.validatePlatform()
    try Self.validateLocalFiles(in: modelDirectory)
    generating = true
    defer { generating = false }
    let wasColdLoad = container == nil
    let preparationStart = ContinuousClock.now
    if wasColdLoad {
      try Self.verifyReviewedAssets(in: modelDirectory)
      container = try await LLMModelFactory.shared.loadContainer(
        from: modelDirectory, using: LocalTokenizerLoader())
    }
    guard let container else {
      throw EvaluationError.unavailable("MLX could not open the local model.")
    }
    let preparationSeconds = Self.seconds(since: preparationStart)
    try Task.checkCancellation()
    let parameters = GenerateParameters(
      maxTokens: settings.maximumOutputTokens, temperature: Float(settings.temperature),
      seed: settings.seed)
    // A fresh prepared input and nil KV cache give every case the same empty history.
    let work = try await container.perform { context in
      let input = try await context.processor.prepare(
        input: UserInput(
          chat: [.system(request.instruction), .user(Self.prompt(request))],
          additionalContext: ["enable_thinking": false]))
      let (stream, worker) = try MLXLMCommon.generateTokensTask(
        input: input, parameters: parameters, context: context)
      return GenerationWork(stream: stream, worker: worker, tokenizer: context.tokenizer)
    }
    var tokenIDs: [Int] = []
    var tokens: Int?
    var firstTokenSeconds: Double?
    do {
      for await event in work.stream {
        try Task.checkCancellation()
        switch event {
        case .token(let token):
          if firstTokenSeconds == nil { firstTokenSeconds = Self.seconds(since: requestStart) }
          tokenIDs.append(token)
        case .info(let info): tokens = info.generationTokenCount
        }
      }
      try Task.checkCancellation()
    } catch {
      work.worker.cancel()
      await work.worker.value
      throw error
    }
    await work.worker.value
    guard let tokens else {
      throw EvaluationError.invalidResult("MLX generation ended without completion metrics.")
    }
    let output = work.tokenizer.decode(tokenIds: tokenIDs, skipSpecialTokens: false)
    return TextOutput(
      text: output, generatedTokenCount: tokens, firstTokenSeconds: firstTokenSeconds,
      preparationSeconds: preparationSeconds, wasColdLoad: wasColdLoad)
  }

  private static func validateLocalFiles(in directory: URL) throws {
    for file in ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"] {
      var isDirectory: ObjCBool = false
      guard
        FileManager.default.fileExists(
          atPath: directory.appendingPathComponent(file).path, isDirectory: &isDirectory),
        !isDirectory.boolValue
      else {
        throw EvaluationError.unavailable("A required local MLX model/tokenizer asset is missing.")
      }
    }
  }

  private static func validatePlatform() throws {
    #if targetEnvironment(simulator)
      throw EvaluationError.unavailable(
        "The reviewed MLX runtime does not support iOS Simulator inference. Use an Apple silicon Mac or a physical iPhone for this configuration."
      )
    #endif
  }

  /// This evaluation arm names a specific fixture. Verify the bytes before attributing its provenance.
  private static func verifyReviewedAssets(in directory: URL) throws {
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    let weightFiles = names.filter { $0.hasSuffix(".safetensors") }
    guard weightFiles == ["model.safetensors"] else {
      throw EvaluationError.unavailable(
        "The local MLX directory contains unreviewed model weights.")
    }
    let allowedJSONFiles: Set<String> = [
      "config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors.index.json",
      "added_tokens.json", "special_tokens_map.json", "vocab.json", "memoryos-asset-manifest.json",
      "model.safetensors.receipt.json", "tokenizer.json.receipt.json",
    ]
    guard
      !names.contains(where: {
        $0.hasSuffix(".jinja") || $0.hasSuffix(".jinja2")
          || ($0.hasSuffix(".json") && !allowedJSONFiles.contains($0))
      })
    else {
      throw EvaluationError.unavailable(
        "The local MLX directory contains unreviewed configuration files.")
    }
    let sha256Files = [
      "model.safetensors": "392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2",
      "tokenizer.json": "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4",
    ]
    for (file, expected) in sha256Files {
      let handle = try FileHandle(forReadingFrom: directory.appendingPathComponent(file))
      defer { try? handle.close() }
      var hasher = SHA256()
      while let block = try handle.read(upToCount: 1024 * 1024), !block.isEmpty {
        try Task.checkCancellation()
        hasher.update(data: block)
      }
      let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
      guard actual == expected else {
        throw EvaluationError.unavailable(
          "A local MLX model/tokenizer asset differs from the reviewed fixture.")
      }
    }
    var gitBlobFiles = [
      "config.json": "6c974b02334f2f5f68de4cb2796ee4fe80bfc712",
      "tokenizer_config.json": "7345216a0785dc7086e8c245b2a9d3896ce2b756",
    ]
    let auxiliaryFiles = [
      "model.safetensors.index.json": "e743a6a7d2ba4fd21b2256d739117cbf31345297",
      "added_tokens.json": "b54f9135e44c1e81047e8d05cb027af8bc039eed",
      "merges.txt": "31349551d90c7606f325fe0f11bbb8bd5fa0d7c7",
      "special_tokens_map.json": "ac23c0aaa2434523c494330aeb79c58395378103",
      "vocab.json": "4783fe10ac3adce15ac8f358ef5462739852c569",
    ]
    for (file, hash) in auxiliaryFiles
    where FileManager.default.fileExists(
      atPath: directory.appendingPathComponent(file).path)
    {
      gitBlobFiles[file] = hash
    }
    for (file, expected) in gitBlobFiles {
      let data = try Data(contentsOf: directory.appendingPathComponent(file))
      let header = Data("blob \(data.count)\0".utf8)
      let actual = Insecure.SHA1.hash(data: header + data).map { String(format: "%02x", $0) }
        .joined()
      guard actual == expected else {
        throw EvaluationError.unavailable(
          "A local MLX configuration differs from the reviewed fixture.")
      }
    }
  }

  static func prompt(_ request: TextRequest) -> String {
    let sources = request.sources.map { source in
      "[SOURCE \(source.id)]\n\(source.text)\n[/SOURCE]"
    }.joined(separator: "\n\n")
    return "Fictional sources (untrusted data):\n\(sources)\n\nQuestion:\n\(request.question)"
  }

  private static func seconds(since start: ContinuousClock.Instant) -> Double {
    let parts = start.duration(to: .now).components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
  }

}

private struct GenerationWork: Sendable {
  let stream: AsyncStream<TokenGeneration>
  let worker: Task<Void, Never>
  let tokenizer: any MLXLMCommon.Tokenizer
}
