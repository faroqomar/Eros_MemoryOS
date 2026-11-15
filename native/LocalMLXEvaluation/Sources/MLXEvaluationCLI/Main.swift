import AIEvaluationCore
import Foundation
import MLXEvaluationAdapter

@main
struct MLXEvaluationCLI {
  private static var buildConfiguration: String {
    #if DEBUG
      "Debug"
    #else
      "Release"
    #endif
  }

  static func main() async throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard [4, 6].contains(arguments.count), arguments[0] == "--model-dir",
      arguments[2] == "--source-identity",
      arguments.count == 4 || arguments[4] == "--output"
    else {
      throw EvaluationError.invalidSuite(
        "Usage: mlx-evaluation --model-dir LOCAL_DIRECTORY --source-identity COMMIT_OR_MANIFEST [--output REPORT.json]"
      )
    }
    let runtime = MLXTextRuntime(modelDirectory: URL(fileURLWithPath: arguments[1]))
    let context = RunContext(
      environment: .host, purpose: .smoke, deviceModel: "Mac host",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceIdentity: arguments[3], buildConfiguration: buildConfiguration,
      toolchain: "Xcode 27.2 / Swift 6.4.2",
      conditions:
        "Local MLX model, fresh chat per case, temperature 0, seed 42, Qwen3 thinking disabled. Host smoke only; no phone claims. Other SDK builds/downloads may be active; timings are not controlled benchmarks."
    )
    let candidate = CandidateConfiguration(
      id: "mlx-qwen3-0.6b-4bit", displayName: "MLX Swift LM · Qwen3-0.6B MLX 4-bit",
      provenance: [
        ComponentProvenance(
          sourceURL: "https://github.com/ml-explore/mlx-swift-lm",
          revision: "3b339ad6e3b3f44c8121ecff5131c7fd55e075e6",
          modelAsset:
            "mlx-community/Qwen3-0.6B-4bit@73e3e38d981303bc594367cd910ea6eb48349da8/model.safetensors",
          modelSHA256: "392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2",
          notes: "Model and tokenizer files require the separately verified local asset manifest.")
      ], scope: .text)
    let report = try await EvaluationRunner().run(
      suite: .fictional(), configuration: candidate, memory: nil, runtime: runtime,
      context: context)
    let data = try report.jsonData()
    if arguments.count == 6 {
      try data.write(to: URL(fileURLWithPath: arguments[5]), options: .atomic)
    } else {
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }
  }
}
