import AIEvaluationCore
import CactusEvaluationAdapter
import Foundation

@main
struct CactusEvaluationCLI {
  static func main() async throws {
    let arguments = CommandLine.arguments
    func value(_ flag: String) -> String? {
      guard let offset = arguments.firstIndex(of: flag), arguments.indices.contains(offset + 1)
      else { return nil }
      return arguments[offset + 1]
    }
    guard let modelPath = value("--model-directory") else {
      throw EvaluationError.unavailable(
        "Use --model-directory with a verified local Cactus embedding model. No download or cloud fallback is enabled."
      )
    }
    let outputPath = value("--output")
    let networkDenied = arguments.contains("--network-denied")
    let sourceIdentity = value("--source-identity") ?? "unrecorded"
    let threadConfiguration =
      ProcessInfo.processInfo.environment["CACTUS_NUM_THREADS"]
      ?? "upstream hardware_concurrency default"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "memoryos-cactus-run-" + UUID().uuidString)
    let adapter = CactusMemoryIndexAdapter(
      modelDirectory: URL(fileURLWithPath: modelPath), indexDirectory: directory)
    let report = try await EvaluationRunner().run(
      suite: .fictional(),
      configuration: .init(
        id: "cactus-qwen3-embedding-int4-cpu-last-token",
        displayName: "Cactus local-only · Qwen3 Embedding 0.6B int4 · CPU",
        provenance: [
          .init(
            sourceURL: "https://github.com/cactus-compute/engine",
            revision: CactusMemoryIndexAdapter.upstreamRevision,
            notes:
              "Local-only upstream patch; see artifact receipt. No telemetry or curl transport. CPU, normalized embeddings, query instruction, explicit last-token pooling, similarity threshold0.35."
          ),
          .init(
            sourceURL: "https://huggingface.co/Cactus-Compute/Qwen3-Embedding-0.6B",
            revision: CactusMemoryIndexAdapter.modelRevision,
            modelAsset: "weights/qwen3-embedding-0.6b-int4.zip",
            modelSHA256: CactusMemoryIndexAdapter.modelArchiveSHA256),
        ], scope: .retrieval),
      memory: adapter, runtime: nil,
      context: .init(
        environment: .host, purpose: .smoke, deviceModel: "Mac host",
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        sourceIdentity: sourceIdentity, buildConfiguration: "Release",
        toolchain: "Record swift --version with invocation", offlineConfirmed: networkDenied,
        conditions:
          "Actual Cactus CPU embedding/index on fictional sources. Host smoke only. CPU worker setting: \(threadConfiguration); actual worker count: \(CactusMemoryIndexAdapter.configuredWorkerCount). No text generation model, phone cost or winner."
      ))
    await adapter.close()
    try? FileManager.default.removeItem(at: directory)
    let data = try report.jsonData()
    if let outputPath {
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    } else {
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }
  }
}
