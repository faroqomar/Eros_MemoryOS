import AIEvaluationCore
import Foundation

@main
struct EvaluationCLI {
  static func main() async throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.isEmpty || (arguments.count == 2 && arguments[0] == "--source-identity") else {
      throw EvaluationError.invalidSuite(
        "Usage: ai-evaluation [--source-identity COMMIT-OR-MANIFEST]")
    }
    let context = RunContext(
      environment: .host, purpose: .smoke, deviceModel: "Mac host",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceIdentity: arguments.last ?? "unrecorded",
      buildConfiguration: "Release requested by command",
      toolchain: "Record swift --version alongside this result", offlineConfirmed: false,
      conditions:
        "Synthetic lexical-control smoke only. No model, phone energy measurement or winner.")
    let configuration = CandidateConfiguration(
      id: "keyword-control", displayName: "Keyword control (no model)",
      provenance: [
        ComponentProvenance(
          sourceURL: "app-owned:LocalAIEvaluation/AIEvaluationCore/KeywordMemoryIndex.swift",
          revision: context.sourceIdentity,
          notes: "Deterministic lexical control, not Wax or Cactus.")
      ])
    let report = try await EvaluationRunner().run(
      suite: .fictional(), configuration: configuration, memory: KeywordMemoryIndex(), runtime: nil,
      context: context)
    let payload = CLIOutput(report: report, selectionBlockers: report.selectionBlockers)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(payload))
    FileHandle.standardOutput.write(Data("\n".utf8))
  }
}

private struct CLIOutput: Encodable {
  let report: EvaluationReport
  let selectionBlockers: [String]
}
