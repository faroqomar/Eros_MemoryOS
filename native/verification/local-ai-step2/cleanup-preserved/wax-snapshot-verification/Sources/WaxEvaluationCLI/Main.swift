import AIEvaluationCore
import Foundation
import WaxEvaluationAdapter

#if canImport(Darwin)
  import Darwin
#endif

@main
struct WaxEvaluationCLI {
  static func main() async throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 4 || arguments.count == 6, arguments[0] == "--source-identity",
      arguments[2] == "--toolchain", !arguments[1].isEmpty, !arguments[3].isEmpty,
      arguments.count == 4
        || (arguments[4] == "--sdk-patch-sha256" && arguments[5].count == 64
          && arguments[5].allSatisfy { $0.isHexDigit })
    else {
      throw EvaluationError.invalidSuite(
        "Usage: wax-evaluation --source-identity COMMIT-OR-MANIFEST --toolchain SWIFT-VERSION [--sdk-patch-sha256 SHA256]"
      )
    }
    let sdkNotes =
      arguments.count == 6
      ? "Wax 0.1.47 with explicit desktop guard patch sha256:" + arguments[5]
        + "; empty embedding traits; textOnly search; SDK default context budget."
      : "Wax 0.1.47 stock release; empty embedding traits; textOnly search; SDK default context budget."
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "memoryos-wax-host-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let adapter = WaxMemoryIndexAdapter(directory: root)
    let context = RunContext(
      environment: .host, purpose: .smoke, deviceModel: "Mac host",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceIdentity: arguments[1], buildConfiguration: buildConfiguration,
      toolchain: arguments[3], offlineConfirmed: false,
      conditions:
        "Real Wax FTS5 lexical retrieval on the shared fictional suite. Embeddings and text generation disabled. Host measurements cannot establish iPhone behavior or a component winner."
    )
    let configuration = CandidateConfiguration(
      id: "wax-lexical", displayName: "Wax lexical retrieval (no embedding model)",
      provenance: [
        .init(
          sourceURL: "https://github.com/christopherkarani/Wax",
          revision: "e4587f8cebb76aa92ece008253f13c66b756e68b",
          notes: sdkNotes
        )
      ], scope: .retrieval)
    do {
      let provisional = try await EvaluationRunner().run(
        suite: .fictional(), configuration: configuration, memory: adapter, runtime: nil,
        context: context)
      let telemetry = RunTelemetry(
        peakMemoryBytes: peakHostMemoryBytes(), storageBytes: try logicalBytes(at: root),
        measurementMethod:
          "macOS process-lifetime getrusage ru_maxrss high-water bytes; current derived index logical file sizes. No phone battery or thermal measurement."
      )
      let report = EvaluationReport(
        suiteID: provisional.suiteID, configuration: provisional.configuration,
        context: provisional.context, generatedAt: provisional.generatedAt,
        settings: provisional.settings, telemetry: telemetry, results: provisional.results)
      try await adapter.close()
      let output = CLIOutput(report: report, selectionBlockers: report.selectionBlockers)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      encoder.dateEncodingStrategy = .iso8601
      FileHandle.standardOutput.write(try encoder.encode(output))
      FileHandle.standardOutput.write(Data("\n".utf8))
      guard report.results.allSatisfy({ $0.retrievalStatus == .completed }) else {
        throw EvaluationError.invalidResult(
          "Wax retrieval failed; inspect the emitted evaluation report.")
      }
    } catch {
      try? await adapter.close()
      throw error
    }
  }

  private static var buildConfiguration: String {
    #if DEBUG
      "Debug"
    #else
      "Release"
    #endif
  }

  private static func logicalBytes(at directory: URL) throws -> UInt64 {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
    else { throw EvaluationError.invalidResult("Cannot enumerate the derived index footprint.") }
    var total: UInt64 = 0
    for case let file as URL in enumerator {
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      if values.isRegularFile == true, let count = values.fileSize { total += UInt64(count) }
    }
    return total
  }

  private static func peakHostMemoryBytes() -> UInt64? {
    #if os(macOS)
      var usage = rusage()
      guard getrusage(RUSAGE_SELF, &usage) == 0, usage.ru_maxrss > 0 else { return nil }
      return UInt64(usage.ru_maxrss)
    #else
      return nil
    #endif
  }
}

private struct CLIOutput: Encodable {
  let report: EvaluationReport
  let selectionBlockers: [String]
}
