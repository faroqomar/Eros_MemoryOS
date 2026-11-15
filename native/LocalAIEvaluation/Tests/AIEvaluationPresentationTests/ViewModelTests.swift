import AIEvaluationCore
import AIEvaluationPresentation
import Foundation
import Testing

private func blockedReport(candidateID: String = "keyword-control") -> EvaluationReport {
  EvaluationReport(
    suiteID: "fixture", configuration: .init(id: candidateID, displayName: candidateID),
    context: .init(
      environment: .simulator, purpose: .smoke, deviceModel: "Simulator", operatingSystem: "Test",
      sourceIdentity: "test", buildConfiguration: "Release", toolchain: "Swift 6"),
    results: [])
}

@Test @MainActor func measuredProgressReachesPresentationAndResetsOnSelection() async {
  let model = EvaluationViewModel(
    evaluator: ProgressEvaluator(), validCandidateIDs: ["keyword-control", "wax"])
  await model.run()?.value
  #expect(model.progress?.completedCases == 15)
  #expect(model.progress?.totalCases == 15)
  model.select("wax")
  #expect(model.progress == nil)
}

private struct ProgressEvaluator: EvaluationRunning {
  func run(candidateID: String) async throws -> EvaluationReport {
    blockedReport(candidateID: candidateID)
  }
  func run(candidateID: String, progress: @escaping @Sendable (EvaluationProgress) async -> Void)
    async throws -> EvaluationReport
  {
    await progress(.init(completedCases: 15, totalCases: 15, currentCaseID: "last"))
    return blockedReport(candidateID: candidateID)
  }
}

@Test @MainActor func successfulRunPublishesExportAndAllowsRerun() async throws {
  let evaluator = ImmediateEvaluator()
  let model = EvaluationViewModel(
    evaluator: evaluator, validCandidateIDs: ["keyword-control", "wax"])
  let first = try #require(model.run())
  #expect(model.running)
  #expect(model.run() == nil)
  await first.value
  #expect(!model.running)
  #expect(model.report?.configuration.id == "keyword-control")
  #expect(model.exportData != nil)
  #expect(model.message == nil)
  model.select("wax")
  #expect(model.report == nil && model.exportData == nil)
  await model.run()?.value
  #expect(model.report?.configuration.id == "wax")
  #expect(await evaluator.received == ["keyword-control", "wax"])
}

@Test @MainActor func unavailableCandidateReportRemainsBlockedWithoutUIFailure() async {
  let model = EvaluationViewModel(
    evaluator: ImmediateEvaluator(), validCandidateIDs: ["keyword-control"])
  await model.run()?.value
  #expect(model.report != nil)
  #expect(!model.report!.selectionBlockers.isEmpty)
  #expect(model.message == nil)
}

@Test @MainActor func invalidSelectionDoesNotChangeCandidateOrStartUseCase() async {
  let evaluator = ImmediateEvaluator()
  let model = EvaluationViewModel(evaluator: evaluator, validCandidateIDs: ["keyword-control"])
  model.select("unknown")
  #expect(model.selectedID == "keyword-control")
  #expect(await evaluator.received.isEmpty)
  let invalid = EvaluationViewModel(evaluator: evaluator, validCandidateIDs: ["wax"])
  #expect(invalid.run() == nil)
  #expect(!invalid.running)
  #expect(invalid.message != nil)
}

@Test @MainActor func cancellationPreventsLateNoncooperativeResultAndOverlappingRerun() async throws
{
  let evaluator = SuspendedEvaluator()
  let model = EvaluationViewModel(
    evaluator: evaluator, validCandidateIDs: ["keyword-control", "wax"])
  let task = try #require(model.run())
  await evaluator.waitUntilStarted()
  model.cancel()
  #expect(model.running)
  model.select("wax")
  #expect(model.selectedID == "keyword-control")
  #expect(model.run() == nil)
  await evaluator.finish()
  await task.value
  #expect(!model.running)
  #expect(model.report == nil)
  #expect(model.exportData == nil)
  #expect(model.message?.contains("Cancelled") == true)
  #expect(await evaluator.count == 1)
}

@Test @MainActor func immediateCancelDoesNotPublishAResult() async throws {
  let model = EvaluationViewModel(
    evaluator: ImmediateEvaluator(), validCandidateIDs: ["keyword-control"])
  let task = try #require(model.run())
  model.cancel()
  await task.value
  #expect(model.report == nil && model.exportData == nil)
  #expect(!model.running)
}

@Test @MainActor func failedRunClearsOldResultsAndDoesNotExposePrivateDiagnostic() async {
  let evaluator = FailingEvaluator()
  let model = EvaluationViewModel(evaluator: evaluator, validCandidateIDs: ["keyword-control"])
  await model.run()?.value
  #expect(model.report == nil && model.exportData == nil)
  #expect(!model.running)
  #expect(model.message != nil)
  #expect(model.message?.contains("private-secret") == false)
}

private actor ImmediateEvaluator: EvaluationRunning {
  private(set) var received: [String] = []
  func run(candidateID: String) async throws -> EvaluationReport {
    received.append(candidateID)
    return blockedReport(candidateID: candidateID)
  }
}

private actor SuspendedEvaluator: EvaluationRunning {
  private(set) var count = 0
  private var pending: CheckedContinuation<Void, Never>?
  private var started: CheckedContinuation<Void, Never>?
  func run(candidateID: String) async throws -> EvaluationReport {
    count += 1
    await withCheckedContinuation { continuation in
      pending = continuation
      started?.resume()
      started = nil
    }
    return blockedReport(candidateID: candidateID)
  }
  func waitUntilStarted() async {
    if count > 0 { return }
    await withCheckedContinuation { started = $0 }
  }
  func finish() {
    pending?.resume()
    pending = nil
  }
}

private struct FailingEvaluator: EvaluationRunning {
  struct PrivateError: Error, LocalizedError { var errorDescription: String? { "private-secret" } }
  func run(candidateID: String) async throws -> EvaluationReport { throw PrivateError() }
}
