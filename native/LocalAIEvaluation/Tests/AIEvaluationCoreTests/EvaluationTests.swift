import Foundation
import Testing

@testable import AIEvaluationCore

private let hostContext = RunContext(
  environment: .host, purpose: .smoke, deviceModel: "Test host", operatingSystem: "Test OS",
  sourceIdentity: "test-source", buildConfiguration: "Release", toolchain: "Swift 6")
private let candidate = CandidateConfiguration(id: "test", displayName: "Test")

@Test func retrievalOnlyRunDoesNotRequireASeparateTextModel() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(),
    configuration: .init(id: "retrieval", displayName: "Retrieval", scope: .retrieval),
    memory: KeywordMemoryIndex(), runtime: nil, context: hostContext)
  #expect(
    report.results.allSatisfy {
      $0.retrievalStatus == .completed && $0.generationStatus == .notApplicable && $0.output == nil
    })
}

@Test func textOnlyRunUsesCanonicalCorpusWithoutAProviderIndex() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: .init(id: "text", displayName: "Text", scope: .text),
    memory: nil, runtime: FixedRuntime(output: .init(text: "Synthetic contract output")),
    context: hostContext)
  #expect(
    report.results.allSatisfy {
      $0.retrievalStatus == .notApplicable && $0.generationStatus == .completed
    })
}

@Test func reportVersionOneStillDecodesWithoutScope() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: nil, runtime: nil, context: hostContext)
  var json = try #require(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
  json["formatVersion"] = 1
  var config = try #require(json["configuration"] as? [String: Any])
  config.removeValue(forKey: "scope")
  json["configuration"] = config
  let decoded = try EvaluationReport.decode(JSONSerialization.data(withJSONObject: json))
  #expect(decoded.formatVersion == 1)
  #expect(decoded.configuration.scope == .combined)
  #expect(decoded.results == report.results)
}

@Test func fictionalCorpusHasRequiredLanguagesAndNoPrivateData() {
  let suite = EvaluationSuite.fictional()
  #expect(suite.cases.count >= 12)
  #expect(Set(suite.cases.map(\.language)) == ["en", "ar", "ar-IQ", "ar-en"])
  #expect(Set(suite.records.map(\.id)).count == suite.records.count)
  #expect(suite.cases.contains(where: { $0.expectedSourceIDs.isEmpty }))
}

@Test func lexicalControlRetrievesArabicAndEnglishSourceIDs() async throws {
  let index = KeywordMemoryIndex()
  try await index.rebuild(records: EvaluationSuite.fictional().records)
  #expect(
    try await index.search(query: "Maya Haddad birthday", limit: 1).first?.sourceID == "en-birthday"
  )
  #expect(try await index.search(query: "زينب كريم", limit: 1).first?.sourceID == "ar-birthday")
  #expect(try await index.search(query: "زوزو", limit: 1).first?.sourceID == "name-alias")
  #expect(try await index.search(query: "Noura passport", limit: 3).isEmpty)
}

@Test func rebuildingReplacesCorrectionsAndRemovesDeletedSources() async throws {
  let index = KeywordMemoryIndex()
  let old = SourceRecord(id: "stable", text: "Meeting Tuesday", language: "en")
  try await index.rebuild(records: [
    old, SourceRecord(id: "removed", text: "Obsolete plan", language: "en"),
  ])
  try await index.rebuild(records: [
    SourceRecord(id: "stable", text: "Meeting Friday", language: "en", revision: 2)
  ])
  #expect(try await index.search(query: "Tuesday", limit: 2).isEmpty)
  #expect(try await index.search(query: "Obsolete", limit: 2).isEmpty)
  #expect(try await index.search(query: "Friday", limit: 2).map(\.sourceID) == ["stable"])
  #expect(old.text == "Meeting Tuesday")
}

@Test func unavailableAdaptersProduceBlockedResultsWithoutInventedOutputOrMetrics() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: nil, runtime: nil, context: hostContext)
  #expect(report.results.count == EvaluationSuite.fictional().cases.count)
  #expect(
    report.results.allSatisfy {
      $0.retrievalStatus == .blocked && $0.generationStatus == .blocked && $0.output == nil
        && $0.searchSeconds == nil && $0.generationSeconds == nil && $0.sourceRecall == nil
    })
  #expect(report.telemetry.peakMemoryBytes == nil)
  #expect(report.telemetry.batteryDropPercentagePoints == nil)
  #expect(!report.selectionBlockers.isEmpty)
}

@Test func runnerScoresRealRetrievalAndKeepsCanonicalSnapshot() async throws {
  let suite = EvaluationSuite.fictional()
  let original = suite.records
  let report = try await EvaluationRunner().run(
    suite: suite, configuration: candidate, memory: KeywordMemoryIndex(), runtime: nil,
    context: hostContext)
  let birthday = try #require(report.results.first(where: { $0.id == "en-birthday" }))
  #expect(birthday.retrievalStatus == .completed)
  #expect(birthday.sourceRecall == 1)
  #expect(birthday.searchSeconds != nil)
  #expect(birthday.generationStatus == .blocked)
  #expect(suite.records == original)
}

@Test(arguments: [
  [RetrievedSource(sourceID: "invented")],
  [RetrievedSource(sourceID: "en-birthday"), RetrievedSource(sourceID: "en-birthday")],
])
func runnerRejectsUnknownAndDuplicateSources(_ sources: [RetrievedSource]) async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: FixedIndex(sources: sources),
    runtime: nil,
    context: hostContext)
  #expect(
    report.results.allSatisfy {
      $0.retrievalStatus == .failed && $0.sourceRecall == nil && $0.retrievedSourceIDs.isEmpty
    })
}

@Test func runnerRejectsExcessResultsAndNonfiniteScores() async throws {
  let suite = EvaluationSuite.fictional()
  let sources = suite.records.prefix(4).map { RetrievedSource(sourceID: $0.id) }
  for returned in [sources, [RetrievedSource(sourceID: "en-birthday", score: .nan)]] {
    let report = try await EvaluationRunner().run(
      suite: suite, configuration: candidate, memory: FixedIndex(sources: returned), runtime: nil,
      context: hostContext)
    #expect(report.results.allSatisfy { $0.retrievalStatus == .failed })
  }
}

@Test func absentRuntimeNeverCountsAsLanguageQualityPass() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: KeywordMemoryIndex(), runtime: nil,
    context: hostContext)
  #expect(report.manualReviews.isEmpty)
  #expect(report.results.allSatisfy { $0.generationStatus == .blocked && $0.output == nil })
  #expect(report.selectionBlockers.contains(where: { $0.contains("human") }))
}

@Test func runtimeReceivesSameCorpusAndNoAnswerKeyForEachCase() async throws {
  let spy = RecordingRuntime()
  let suite = EvaluationSuite.fictional()
  let report = try await EvaluationRunner().run(
    suite: suite, configuration: candidate, memory: nil, runtime: spy, context: hostContext)
  let requests = await spy.requests
  #expect(requests.count == suite.cases.count)
  #expect(requests.map(\.question) == suite.cases.map(\.query))
  #expect(requests.allSatisfy { $0.sources == suite.records })
  #expect(
    requests.allSatisfy {
      !$0.instruction.contains("reviewGuidance") && !$0.instruction.contains("expectedSourceIDs")
    })
  #expect(
    report.results.allSatisfy {
      $0.generationStatus == .completed && $0.output?.text == "Unreviewed generated text"
    })
  #expect(report.manualReviews.isEmpty)
  #expect(!report.selectionBlockers.isEmpty)
}

@Test func unavailableRuntimeStaysBlockedAndUnexpectedErrorsStaySanitized() async throws {
  let blocked = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: nil,
    runtime: FailingRuntime(error: .unavailable("Model asset is missing.")), context: hostContext)
  #expect(blocked.results.allSatisfy { $0.generationStatus == .blocked && $0.output == nil })
  let failed = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: ErrorIndex(), runtime: nil,
    context: hostContext)
  #expect(
    failed.results.allSatisfy {
      $0.retrievalStatus == .failed && !($0.retrievalIssue?.contains("private-token") ?? true)
        && !($0.retrievalIssue?.contains("diagnostic log") ?? true)
    })
}

@Test func cancellationDoesNotReturnACompletedReport() async throws {
  let task = Task {
    try await EvaluationRunner().run(
      suite: .fictional(), configuration: candidate, memory: nil, runtime: CancellingRuntime(),
      context: hostContext)
  }
  task.cancel()
  await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func adapterCancellationPropagates() async {
  await #expect(throws: CancellationError.self) {
    try await EvaluationRunner().run(
      suite: .fictional(), configuration: candidate, memory: nil, runtime: CancellingRuntime(),
      context: hostContext)
  }
}

@Test func invalidSuiteFailsBeforeCallingProviders() async {
  let duplicate = SourceRecord(id: "same", text: "x", language: "en")
  await #expect(throws: EvaluationError.self) {
    try await EvaluationRunner().run(
      suite: EvaluationSuite(
        id: "bad", records: [duplicate, duplicate], cases: EvaluationSuite.fictional().cases),
      configuration: candidate, memory: nil, runtime: nil, context: hostContext)
  }
}

@Test func exportRoundtripKeepsUnicodeIDsAndAbsentTelemetry() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: KeywordMemoryIndex(), runtime: nil,
    context: hostContext)
  let decoded = try EvaluationReport.decode(report.jsonData())
  #expect(decoded.results == report.results)
  #expect(decoded.context == hostContext)
  #expect(decoded.telemetry == RunTelemetry())
  #expect(decoded.selectionBlockers == report.selectionBlockers)
  let suite = EvaluationSuite.fictional()
  #expect(
    try JSONDecoder().decode(EvaluationSuite.self, from: JSONEncoder().encode(suite)) == suite)
}

@Test func rawProviderScoresSurviveExportWithoutNormalization() async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate,
    memory: FixedIndex(sources: [
      .init(sourceID: "unicode-name", score: -0.75),
      .init(sourceID: "name-alias"),
    ]), runtime: nil, context: hostContext)
  let decoded = try EvaluationReport.decode(report.jsonData())
  #expect(decoded.results.allSatisfy { $0.retrievedScores == ["unicode-name": -0.75] })
  #expect(decoded.results.allSatisfy { $0.retrievedSourceIDs == ["unicode-name", "name-alias"] })
}

@Test func repeatedRunsDoNotAccumulatePriorIndexState() async throws {
  let index = KeywordMemoryIndex()
  let suite = EvaluationSuite.fictional()
  for _ in 0..<2 {
    let report = try await EvaluationRunner().run(
      suite: suite, configuration: candidate, memory: index, runtime: nil, context: hostContext)
    #expect(report.results.count == suite.cases.count)
    #expect(report.results.allSatisfy { $0.retrievalStatus == .completed })
  }
}

@Test(arguments: [
  TextOutput(text: "x", generatedTokenCount: -1), TextOutput(text: "x", generatedTokenCount: 257),
  TextOutput(text: "x", firstTokenSeconds: -1),
  TextOutput(text: "x", preparationSeconds: -1),
  TextOutput(text: "x", preparationSeconds: .nan),
])
func invalidRuntimeMeasurementsFail(_ output: TextOutput) async throws {
  let report = try await EvaluationRunner().run(
    suite: .fictional(), configuration: candidate, memory: nil,
    runtime: FixedRuntime(output: output),
    context: hostContext)
  #expect(report.results.allSatisfy { $0.generationStatus == .failed && $0.output == nil })
}

@Test func progressCountsActualCompletedCases() async throws {
  let collector = ProgressCollector()
  let suite = EvaluationSuite.fictional()
  _ = try await EvaluationRunner().run(
    suite: suite, configuration: candidate, memory: KeywordMemoryIndex(), runtime: nil,
    context: hostContext, progress: { await collector.record($0) })
  let values = await collector.values
  #expect(values.count == suite.cases.count * 2)
  #expect(values.first?.completedCases == 0)
  #expect(values.last?.completedCases == suite.cases.count)
  #expect(values.allSatisfy { $0.totalCases == suite.cases.count })
  #expect(values.map(\.completedCases) == values.map(\.completedCases).sorted())
}

private actor ProgressCollector {
  private(set) var values: [EvaluationProgress] = []
  func record(_ value: EvaluationProgress) { values.append(value) }
}

@Test func telemetryZeroAndMissingStayDistinct() {
  let missing = RunTelemetry()
  let observedZero = RunTelemetry(batteryDropPercentagePoints: 0)
  #expect(missing.batteryDropPercentagePoints == nil)
  #expect(observedZero.batteryDropPercentagePoints == 0)
  #expect(missing != observedZero)
}

private struct FixedIndex: MemoryIndexAdapter {
  let sources: [RetrievedSource]
  func rebuild(records: [SourceRecord]) async throws {}
  func search(query: String, limit: Int) async throws -> [RetrievedSource] { sources }
}

private actor RecordingRuntime: TextRuntimeAdapter {
  private(set) var requests: [TextRequest] = []
  func generate(request: TextRequest, settings: GenerationSettings) async throws -> TextOutput {
    requests.append(request)
    return TextOutput(text: "Unreviewed generated text", generatedTokenCount: 4)
  }
}

private struct FixedRuntime: TextRuntimeAdapter {
  let output: TextOutput
  func generate(request: TextRequest, settings: GenerationSettings) async throws -> TextOutput {
    output
  }
}

private struct FailingRuntime: TextRuntimeAdapter {
  let error: EvaluationError
  func generate(request: TextRequest, settings: GenerationSettings) async throws -> TextOutput {
    throw error
  }
}

private struct CancellingRuntime: TextRuntimeAdapter {
  func generate(request: TextRequest, settings: GenerationSettings) async throws -> TextOutput {
    throw CancellationError()
  }
}

private struct ErrorIndex: MemoryIndexAdapter {
  struct PrivateError: Error, CustomStringConvertible { let description = "private-token" }
  func rebuild(records: [SourceRecord]) async throws { throw PrivateError() }
  func search(query: String, limit: Int) async throws -> [RetrievedSource] { [] }
}
