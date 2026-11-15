import AIEvaluationCore
import AIEvaluationPresentation
import Darwin
import Foundation

#if canImport(LlamaEvaluationAdapter)
  import LlamaEvaluationAdapter
#endif
#if canImport(WaxEvaluationAdapter)
  import WaxEvaluationAdapter
#endif
#if canImport(CactusEvaluationAdapter)
  import CactusEvaluationAdapter
#endif
#if canImport(MLXEvaluationAdapter)
  import MLXEvaluationAdapter
#endif
#if canImport(MLXSimulatorAvailability)
  import MLXSimulatorAvailability
#endif

/// SDKs, file locations and platform adapters enter at this single app boundary.
enum LabComposition {
  @MainActor static func makeViewModel() -> LabViewModel {
    // Cactus reads this only when its process-wide CPU thread pool is first created.
    precondition(setenv("CACTUS_NUM_THREADS", "4", 1) == 0)
    #if targetEnvironment(simulator)
      let environment = RunContext.Environment.simulator
      let device =
        ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS Simulator"
    #else
      let environment = RunContext.Environment.physical
      let device = "Unverified iPhone model"
    #endif
    #if DEBUG
      let build = "Debug"
    #else
      let build = "Release"
    #endif
    let identity =
      Bundle.main.object(forInfoDictionaryKey: "LabSourceIdentity") as? String ?? "unrecorded"
    let context = RunContext(
      environment: environment, purpose: .comparison, deviceModel: device,
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceIdentity: identity, buildConfiguration: build, toolchain: "Xcode 27.2 / Swift 6.4.2",
      conditions:
        "Owner-selected simulator evaluation. Same fictional corpus; one cold suite followed by five warm suites using the same adapter. Each suite rebuilds its derived index. Text requests reuse weights with fresh context. CPU: llama decode/batch threads=4; Cactus CACTUS_NUM_THREADS=4 before first SDK use. OS/Accelerate scheduling may differ. Network isolation not instrumented. Battery/physical heat not measured."
    )
    let documents = URL.documentsDirectory
    let models = documents.appendingPathComponent("EvaluationModels")
    let indexes = documents.appendingPathComponent("EvaluationIndexes")
    let configurations = Dictionary(
      uniqueKeysWithValues: LabCatalog.candidates.map {
        (
          $0.id,
          CandidateConfiguration(
            id: $0.id, displayName: $0.title, provenance: provenance($0.id, identity: identity),
            scope: $0.id.hasPrefix("llama-") || $0.id == "mlx-qwen" ? .text : .retrieval)
        )
      })
    let useCase = RunEvaluationComparison(
      context: context, configurations: configurations,
      adapters: { id in
        #if canImport(WaxEvaluationAdapter)
          if id == "wax-lexical" {
            let adapter = WaxMemoryIndexAdapter(directory: indexes.appendingPathComponent("wax"))
            return EvaluationAdapters(
              memory: adapter, runtime: nil, cleanup: { try? await adapter.close() })
          }
        #endif
        #if canImport(CactusEvaluationAdapter)
          if id == "cactus" {
            let adapter = CactusMemoryIndexAdapter(
              modelDirectory: models.appendingPathComponent("cactus-qwen3-embedding-0.6b"),
              indexDirectory: indexes.appendingPathComponent("cactus"))
            return EvaluationAdapters(
              memory: adapter, runtime: nil, cleanup: { try? await adapter.close() })
          }
        #endif
        #if canImport(LlamaEvaluationAdapter)
          if id == "llama-qwen" || id == "llama-qwen06" {
            let small = id == "llama-qwen06"
            let runtime = LlamaTextRuntime(
              assetURL: models.appendingPathComponent(
                small ? "Qwen3-0.6B-Q4_K_M.gguf" : "Qwen3-1.7B-Q4_K_M.gguf"),
              expectedSHA256: small
                ? "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
                : "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897")
            return EvaluationAdapters(
              memory: KeywordMemoryIndex(), runtime: runtime, cleanup: { await runtime.unload() })
          }
        #endif
        #if targetEnvironment(simulator) && canImport(MLXSimulatorAvailability)
          if id == "mlx-qwen" {
            return EvaluationAdapters(
              memory: nil, runtime: MLXSimulatorUnavailableRuntime(), cleanup: {})
          }
        #endif
        #if canImport(MLXEvaluationAdapter)
          if id == "mlx-qwen" {
            let runtime = MLXTextRuntime(
              modelDirectory: models.appendingPathComponent("mlx-qwen3-0.6b-4bit-73e3e38d"))
            return EvaluationAdapters(memory: KeywordMemoryIndex(), runtime: runtime, cleanup: {})
          }
        #endif
        return EvaluationAdapters(
          memory: id == "keyword-control" ? KeywordMemoryIndex() : nil, runtime: nil, cleanup: {})
      },
      measurement: { id in
        var paths = [indexes.appendingPathComponent(id == "wax-lexical" ? "wax" : id)]
        if id == "llama-qwen" {
          paths.append(models.appendingPathComponent("Qwen3-1.7B-Q4_K_M.gguf"))
        }
        if id == "llama-qwen06" {
          paths.append(models.appendingPathComponent("Qwen3-0.6B-Q4_K_M.gguf"))
        }
        if id == "cactus" {
          paths.append(models.appendingPathComponent("cactus-qwen3-embedding-0.6b"))
        }
        return LabProcessMeasurement(storageURLs: paths)
      },
      writer: LabReportWriter(directory: documents.appendingPathComponent("EvaluationReports")))
    return LabViewModel(evaluator: useCase, validCandidateIDs: LabCatalog.candidates.map(\.id))
  }

  private static func provenance(_ id: String, identity: String) -> [ComponentProvenance] {
    switch id {
    case "keyword-control":
      return [
        .init(
          sourceURL: "app-owned:KeywordMemoryIndex", revision: identity,
          notes: "Lexical control; no model.")
      ]
    case "wax-lexical":
      return [
        .init(
          sourceURL: "https://github.com/christopherkarani/Wax",
          revision: "e4587f8cebb76aa92ece008253f13c66b756e68b",
          notes:
            "Wax 0.1.47 with recorded iOS desktop guards; textOnly retrieval; embeddings disabled.")
      ]
    case "cactus":
      return [
        .init(
          sourceURL: "https://github.com/cactus-compute/engine",
          revision: "40a7123b0788f5b38c5fe0daa0d909b4286fe773",
          notes:
            "Compatible v1.14 local-only CPU build; explicit last-token/L2 pooling. Four workers, top3, threshold0.35. See reproducible patch and build receipt."
        ),
        .init(
          sourceURL: "https://huggingface.co/Cactus-Compute/Qwen3-Embedding-0.6B",
          revision: "0df64898a34c75c209b9882110cd6f9aeb7115cd",
          modelAsset: "weights/qwen3-embedding-0.6b-int4.zip",
          modelSHA256: "22ff768a984fe931ac463b02cedce2ebd65172c6877d210bd5dc6d058fffbd7b",
          notes: "Archive and extracted file hashes must verify before local embedding."),
      ]
    case "llama-qwen", "llama-qwen06":
      let small = id == "llama-qwen06"
      return [
        .init(
          sourceURL: "https://github.com/ggml-org/llama.cpp",
          revision: "a956a852c9c8bc1fb07206364838ddef299178c0", notes: "b12387; CPU on simulator."),
        .init(
          sourceURL: "https://huggingface.co/unsloth/"
            + (small ? "Qwen3-0.6B-GGUF" : "Qwen3-1.7B-GGUF"),
          revision: small
            ? "50968a4468ef4233ed78cd7c3de230dd1d61a56b"
            : "d7f544eead698dbd1f15126ef60b45a1e1933222",
          modelAsset: small ? "Qwen3-0.6B-Q4_K_M.gguf" : "Qwen3-1.7B-Q4_K_M.gguf",
          modelSHA256: small
            ? "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
            : "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897",
          notes: "Community conversion; declared asset hash must pass local verification."),
      ]
    case "mlx-qwen":
      return [
        .init(
          sourceURL: "https://github.com/ml-explore/mlx-swift-lm",
          revision: "3b339ad6e3b3f44c8121ecff5131c7fd55e075e6",
          notes: "MLX Swift LM 3.32.3; simulator unsupported by upstream."),
        .init(
          sourceURL: "https://huggingface.co/mlx-community/Qwen3-0.6B-4bit",
          revision: "73e3e38d981303bc594367cd910ea6eb48349da8",
          modelAsset: "model.safetensors",
          modelSHA256: "392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2",
          notes: "Real Mac output comparison is recorded separately from simulator runs."),
      ]
    default: return []
    }
  }
}
