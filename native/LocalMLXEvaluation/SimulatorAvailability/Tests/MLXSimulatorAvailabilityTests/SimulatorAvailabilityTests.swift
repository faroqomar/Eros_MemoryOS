import AIEvaluationCore
import MLXSimulatorAvailability
import Testing

@Test func unavailableCandidateKeepsEveryCaseBlockedWithoutGeneratedValues() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(),
    configuration: .init(
      id: "mlx-simulator-unavailable", displayName: "MLX Simulator availability", scope: .text),
    memory: nil, runtime: MLXSimulatorUnavailableRuntime(),
    context: .init(
      environment: .host, purpose: .smoke, deviceModel: "Test host", operatingSystem: "Test OS",
      sourceIdentity: "SDK-free availability contract", buildConfiguration: "Release",
      toolchain: "Swift6"))
  #expect(report.results.count == EvaluationSuite.fictional().cases.count)
  #expect(report.results.allSatisfy { $0.generationStatus == .blocked })
  #expect(report.results.allSatisfy { $0.retrievalStatus == .notApplicable })
  #expect(report.results.allSatisfy { $0.generationIssue == MLXSimulatorUnavailableRuntime.reason })
  #expect(report.results.allSatisfy { $0.output == nil })
}
