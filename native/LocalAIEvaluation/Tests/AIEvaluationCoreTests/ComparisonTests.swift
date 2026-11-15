import Foundation
import Testing

@testable import AIEvaluationCore

private let comparisonContext = RunContext(
  environment: .simulator, purpose: .comparison, deviceModel: "Test simulator",
  operatingSystem: "Test",
  sourceIdentity: "test", buildConfiguration: "Release", toolchain: "Swift 6")

private actor ComparisonRecorder: EvaluationReportWriting {
  private(set) var reports: [EvaluationReport] = []
  private(set) var starts = 0
  private(set) var finishes = 0
  private(set) var cleanups = 0
  func write(_ report: EvaluationReport) { reports.append(report) }
  func start() { starts += 1 }
  func finish() { finishes += 1 }
  func cleanup() { cleanups += 1 }
}

private struct TestProbe: RunMeasuring {
  let recorder: ComparisonRecorder
  func start() async { await recorder.start() }
  func finish() async -> RunTelemetry {
    await recorder.finish()
    return .init(
      peakMemoryBytes: 1234, storageBytes: 0, measurementMethod: "Controlled test dependency")
  }
}

private actor CountedIndex: MemoryIndexAdapter {
  let index = KeywordMemoryIndex()
  let cancelOnRebuild: Int?
  private(set) var rebuilds = 0
  init(cancelOnRebuild: Int? = nil) { self.cancelOnRebuild = cancelOnRebuild }
  func rebuild(records: [SourceRecord]) async throws {
    rebuilds += 1
    if cancelOnRebuild == rebuilds { throw CancellationError() }
    try await index.rebuild(records: records)
  }
  func search(query: String, limit: Int) async throws -> [RetrievedSource] {
    try await index.search(query: query, limit: limit)
  }
}

private func comparison(_ index: CountedIndex, _ recorder: ComparisonRecorder, count: Int)
  -> RunEvaluationComparison
{
  RunEvaluationComparison(
    context: comparisonContext,
    configurations: ["control": .init(id: "control", displayName: "Control", scope: .retrieval)],
    adapters: { _ in .init(memory: index, runtime: nil, cleanup: { await recorder.cleanup() }) },
    measurement: { _ in TestProbe(recorder: recorder) }, writer: recorder, repetitionCount: count)
}

@Test func repeatedComparisonPersistsOrderedSuitesAndClosesOnce() async throws {
  let index = CountedIndex()
  let recorder = ComparisonRecorder()
  let report = try await comparison(index, recorder, count: 3).run(candidateID: "control")
  let saved = await recorder.reports
  #expect(saved.count == 3)
  #expect(saved.map(\.context.repetition) == [0, 1, 2])
  #expect(Set(saved.compactMap(\.context.batchID)).count == 1)
  #expect(saved.allSatisfy { $0.context.repetitionCount == 3 && $0.indexBuildSeconds != nil })
  #expect(report == saved.last)
  #expect(await index.rebuilds == 3)
  #expect(await recorder.starts == 3)
  #expect(await recorder.finishes == 3)
  #expect(await recorder.cleanups == 1)
}

@Test func cancellationKeepsOnlyCompletedSuitesAndClosesResources() async {
  let index = CountedIndex(cancelOnRebuild: 2)
  let recorder = ComparisonRecorder()
  await #expect(throws: CancellationError.self) {
    try await comparison(index, recorder, count: 3).run(candidateID: "control")
  }
  #expect(await recorder.reports.count == 1)
  #expect(await recorder.starts == 2)
  #expect(await recorder.finishes == 2)
  #expect(await recorder.cleanups == 1)
}

@Test func invalidRepetitionCountFailsBeforeAnyEngineWork() async {
  let index = CountedIndex()
  let recorder = ComparisonRecorder()
  await #expect(throws: EvaluationError.self) {
    try await comparison(index, recorder, count: 0).run(candidateID: "control")
  }
  #expect(await index.rebuilds == 0)
  #expect(await recorder.starts == 0)
  #expect(await recorder.reports.isEmpty)
}
