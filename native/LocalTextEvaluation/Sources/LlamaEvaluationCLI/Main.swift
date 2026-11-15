import AIEvaluationCore
import Darwin
import Foundation
import LlamaEvaluationAdapter

@main
struct LlamaEvaluationCLI {
  static func main() async throws {
    let arguments = CommandLine.arguments
    func argument(_ key: String) -> String? {
      guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else {
        return nil
      }
      return arguments[index + 1]
    }
    guard let model = argument("--model"), let checksum = argument("--sha256"),
      let identity = argument("--source-identity")
    else {
      throw EvaluationError.invalidSuite(
        "Use --model PATH --sha256 HASH --source-identity SOURCE [--output FILE].")
    }
    let small = checksum == "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
    guard small || checksum == "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897"
    else {
      throw EvaluationError.invalidSuite(
        "This CLI accepts the two reviewed Qwen3 GGUF hashes only.")
    }
    let configuration = CandidateConfiguration(
      id: URL(fileURLWithPath: model).deletingPathExtension().lastPathComponent,
      displayName: "llama.cpp · local reviewed GGUF",
      provenance: [
        .init(
          sourceURL: "https://github.com/ggml-org/llama.cpp",
          revision: "a956a852c9c8bc1fb07206364838ddef299178c0",
          notes:
            "First case cold; later cases reuse resident weights with cleared KV state. Temperature zero; greedy seed unused. Four threads; 2048 context; output cap 256."
        ),
        .init(
          sourceURL: "https://huggingface.co/unsloth/"
            + (small ? "Qwen3-0.6B-GGUF" : "Qwen3-1.7B-GGUF"),
          revision: small
            ? "50968a4468ef4233ed78cd7c3de230dd1d61a56b"
            : "d7f544eead698dbd1f15126ef60b45a1e1933222",
          modelAsset: small ? "Qwen3-0.6B-Q4_K_M.gguf" : "Qwen3-1.7B-Q4_K_M.gguf",
          modelSHA256: checksum,
          notes: "Exact community conversion; full asset SHA-256 is verified before loading."),
      ], scope: .text)
    let context = RunContext(
      environment: .host, purpose: .comparison, deviceModel: "Mac host",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceIdentity: identity, buildConfiguration: "Release",
      toolchain: "Swift 6.4.2 / Xcode 27.2",
      conditions:
        "Host quality/integration comparison. Not iPhone or simulator performance. No network client in adapter."
    )
    let runtime = LlamaTextRuntime(assetURL: URL(fileURLWithPath: model), expectedSHA256: checksum)
    let report = try await EvaluationRunner().run(
      suite: .fictional(), configuration: configuration, memory: KeywordMemoryIndex(),
      runtime: runtime, context: context)
    await runtime.unload()
    let data = try report.jsonData()
    if let output = argument("--output") {
      try data.write(to: URL(fileURLWithPath: output), options: .atomic)
    } else {
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }
  }
}
