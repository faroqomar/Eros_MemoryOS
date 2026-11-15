import Foundation

public protocol EvaluationRunning: Sendable {
  func run(candidateID: String) async throws -> EvaluationReport
  func run(candidateID: String, progress: @escaping @Sendable (EvaluationProgress) async -> Void)
    async throws -> EvaluationReport
}

extension EvaluationRunning {
  public func run(
    candidateID: String, progress: @escaping @Sendable (EvaluationProgress) async -> Void
  ) async throws -> EvaluationReport {
    try await run(candidateID: candidateID)
  }
}

public protocol RunMeasuring: Sendable {
  func start() async
  func finish() async -> RunTelemetry
}
public protocol EvaluationReportWriting: Sendable {
  func write(_ report: EvaluationReport) async throws
}

public struct EvaluationAdapters: Sendable {
  public init(
    memory: (any MemoryIndexAdapter)?, runtime: (any TextRuntimeAdapter)?,
    cleanup: @escaping @Sendable () async -> Void
  ) {
    self.memory = memory
    self.runtime = runtime
    self.cleanup = cleanup
  }
  let memory: (any MemoryIndexAdapter)?
  let runtime: (any TextRuntimeAdapter)?
  let cleanup: @Sendable () async -> Void
}

/// One cold suite followed by five warm suites; SDK state survives between repetitions.
public struct RunEvaluationComparison: EvaluationRunning {
  public init(
    context: RunContext, configurations: [String: CandidateConfiguration],
    adapters: @escaping @Sendable (String) -> EvaluationAdapters,
    measurement: @escaping @Sendable (String) -> any RunMeasuring,
    writer: any EvaluationReportWriting, repetitionCount: Int = 6
  ) {
    self.context = context
    self.configurations = configurations
    self.adapters = adapters
    self.measurement = measurement
    self.writer = writer
    self.repetitionCount = repetitionCount
  }
  let repetitionCount: Int
  let context: RunContext
  let configurations: [String: CandidateConfiguration]
  let adapters: @Sendable (String) -> EvaluationAdapters
  let measurement: @Sendable (String) -> any RunMeasuring
  let writer: any EvaluationReportWriting

  public func run(candidateID: String) async throws -> EvaluationReport {
    try await run(candidateID: candidateID, progress: { _ in })
  }

  public func run(
    candidateID: String, progress: @escaping @Sendable (EvaluationProgress) async -> Void
  )
    async throws -> EvaluationReport
  {
    guard let configuration = configurations[candidateID] else {
      throw EvaluationError.invalidSuite("Unknown evaluation configuration.")
    }
    guard (1...6).contains(repetitionCount) else {
      throw EvaluationError.invalidSuite("Use one to six recorded suite repetitions.")
    }
    let implementations = adapters(candidateID)
    let batchID = UUID().uuidString
    let count = repetitionCount
    let suite = EvaluationSuite.fictional()
    var final: EvaluationReport?
    do {
      for iteration in 0..<count {
        try Task.checkCancellation()
        let probe = measurement(candidateID)
        let runContext = RunContext(
          environment: context.environment, purpose: context.purpose,
          deviceModel: context.deviceModel,
          operatingSystem: context.operatingSystem, sourceIdentity: context.sourceIdentity,
          buildConfiguration: context.buildConfiguration, toolchain: context.toolchain,
          offlineConfirmed: context.offlineConfirmed, conditions: context.conditions,
          batchID: batchID, repetition: iteration, repetitionCount: count)
        await probe.start()
        let result: EvaluationReport
        do {
          result = try await EvaluationRunner().run(
            suite: suite, configuration: configuration,
            memory: implementations.memory, runtime: implementations.runtime, context: runContext,
            progress: { value in
              await progress(
                .init(
                  completedCases: iteration * suite.cases.count + value.completedCases,
                  totalCases: count * suite.cases.count, currentCaseID: value.currentCaseID))
            })
        } catch {
          _ = await probe.finish()
          throw error
        }
        let telemetry = await probe.finish()
        try Task.checkCancellation()
        let report = EvaluationReport(
          suiteID: result.suiteID, configuration: result.configuration, context: result.context,
          generatedAt: result.generatedAt, settings: result.settings, telemetry: telemetry,
          results: result.results, manualReviews: result.manualReviews,
          indexBuildSeconds: result.indexBuildSeconds)
        try await writer.write(report)
        final = report
        // Missing assets or unsupported runtimes need one honest report, not six identical failures.
        if result.results.allSatisfy({
          $0.retrievalStatus != .completed && $0.generationStatus != .completed
        }) {
          break
        }
      }
      await implementations.cleanup()
      guard let final else { throw EvaluationError.invalidResult("No completed evaluation suite.") }
      return final
    } catch {
      await implementations.cleanup()
      throw error
    }
  }
}
