import ChatCore
import CryptoKit
import Foundation
import LocalMemoryRetrieval
import RetrievalCore
import Testing

@testable import MemoryOS

private enum PilotDeadlineError: Error, Equatable { case expired }

private func withPilotDeadline<T: Sendable>(
  seconds: Double, operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  let started = ProcessInfo.processInfo.systemUptime
  let value = try await withThrowingTaskGroup(of: T.self) { group in
    defer { group.cancelAll() }
    group.addTask { try await operation() }
    group.addTask {
      try await Task.sleep(for: .seconds(seconds))
      throw PilotDeadlineError.expired
    }
    guard let value = try await group.next() else { throw CancellationError() }
    return value
  }
  guard ProcessInfo.processInfo.systemUptime - started <= seconds else {
    throw PilotDeadlineError.expired
  }
  return value
}

private actor PilotCancellationReceipt {
  private(set) var joined = false
  func finish() { joined = true }
}

struct PublishedPilotBudgetTests {
  @Test func elapsedDeadlineRejectsImmediateResultAtZeroBudget() async {
    await #expect(throws: PilotDeadlineError.expired) {
      try await withPilotDeadline(seconds: 0) { true }
    }
  }

  @Test func deadlineJoinsCancelledWorkBeforeReturning() async {
    let receipt = PilotCancellationReceipt()
    await #expect(throws: PilotDeadlineError.expired) {
      try await withPilotDeadline(seconds: 0.02) {
        do { try await Task.sleep(for: .seconds(60)) } catch {
          await receipt.finish()
          throw error
        }
        return true
      }
    }
    #expect(await receipt.joined)
  }
}

/// Evaluation inputs contain no answers or supporting-source labels. Assets/results stay outside Git.
private struct PublishedPilot: Decodable {
  let schemaVersion: Int
  let protocolID: String
  let cases: [Case]
  struct Case: Decodable {
    let id: String
    let benchmark: String
    let category: String
    let personaID: String
    let question: String
    let questionDate: String
    let records: [Record]
  }
  struct Record: Decodable {
    let id: String
    let sourceID: String
    let sessionID: String
    let date: String
    let speaker: String
    let text: String
  }
}

private actor PilotChatRepository: ChatRepository {
  var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ value: ChatSnapshot) { self.value = value }
}

private actor PilotObservedSearch: MemorySearching {
  let base: LocalMemorySearch
  private(set) var hits: [MemorySearchHit] = []
  private(set) var seconds = 0.0
  private(set) var completed = false
  init(base: LocalMemorySearch) { self.base = base }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    let start = ProcessInfo.processInfo.systemUptime
    defer { seconds = ProcessInfo.processInfo.systemUptime - start }
    hits = try await base.search(query: query, records: records, limit: limit)
    completed = true
    return hits
  }
}

private actor PilotObservedMemory: ChatMemoryRetrieving {
  let base: LocalChatMemory
  private(set) var evidence: [ChatEvidence] = []
  private(set) var seconds = 0.0
  private(set) var completed = false
  init(base: LocalChatMemory) { self.base = base }
  func retrieve(query: String) async throws -> [ChatEvidence] {
    let start = ProcessInfo.processInfo.systemUptime
    defer { seconds = ProcessInfo.processInfo.systemUptime - start }
    evidence = try await base.retrieve(query: query)
    completed = true
    return evidence
  }
}

/// A completed harness run is not an accuracy pass. The independent scorer owns labels and grades.
/// The app's actual hybrid ranking, subject filter, source limits and answer prompt stay in use.
@Suite(.serialized) @MainActor struct PublishedMemoryBenchmarkTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_PUBLISHED_INPUT"] != nil))
  func frozenPublishedPilotThroughAppPipeline() async throws {
    let env = ProcessInfo.processInfo.environment
    let inputURL = URL(fileURLWithPath: try #require(env["MEMORYOS_PUBLISHED_INPUT"]))
    let outputURL = URL(fileURLWithPath: try #require(env["MEMORYOS_PUBLISHED_OUTPUT"]))
    let expectedHash = try #require(env["MEMORYOS_PUBLISHED_SHA256"])
    let bytes = try Data(contentsOf: inputURL)
    let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try #require(hash == expectedHash, "Frozen input identity changed")
    let pilot = try JSONDecoder().decode(PublishedPilot.self, from: bytes)
    try #require(pilot.schemaVersion == 1 && !pilot.cases.isEmpty)
    try #require(Set(pilot.cases.map(\.id)).count == pilot.cases.count)
    let budget = try #require(Double(env["MEMORYOS_PUBLISHED_BUDGET_SECONDS"] ?? "1800"))
    try #require(budget > 0 && budget <= 7200)
    let caseBudget = try #require(Double(env["MEMORYOS_PUBLISHED_CASE_SECONDS"] ?? "300"))
    try #require(caseBudget > 0 && caseBudget <= 300)
    // Cooperative cancellation joins native work before another case starts; elapsed includes overrun.
    let runStarted = ProcessInfo.processInfo.systemUptime
    var rows: [[String: Any]] = []
    func persist() throws {
      let result: [String: Any] = [
        "protocolID": pilot.protocolID, "inputSHA256": hash,
        "model": try RuntimeTestModel.configuration().selection,
        "modelSHA256": try RuntimeTestModel.configuration().expectedSHA256,
        "budgetSeconds": budget, "caseBudgetSeconds": caseBudget, "results": rows,
        "runElapsedSeconds": ProcessInfo.processInfo.systemUptime - runStarted,
        "protocol":
          "Full selected histories; app hybrid top8, default relevance, top3 evidence; question date appended as explicit context; independent cases and model unload; manual scoring separate.",
      ]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: outputURL, options: .atomic)
    }
    for item in pilot.cases {
      var row: [String: Any] = [
        "caseID": item.id, "benchmark": item.benchmark, "category": item.category,
        "recordCount": item.records.count, "status": "budget-not-run",
        "retrievedSourceIDs": [], "retrievedUUIDs": [], "answer": "", "seconds": 0,
      ]
      guard ProcessInfo.processInfo.systemUptime - runStarted < budget else {
        rows.append(row)
        try persist()
        continue
      }
      let started = ProcessInfo.processInfo.systemUptime
      let directory = URL.temporaryDirectory.appending(path: "published-pilot-" + UUID().uuidString)
      let index = LocalMemorySearch(
        directory: directory,
        cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
        provider: .hybrid, minimumSimilarity: -1)
      let search = PilotObservedSearch(base: index)
      let model = LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel())
      let records = item.records.map { MemorySearchRecord(id: $0.id, text: $0.text) }
      let memory = PilotObservedMemory(
        base: LocalChatMemory(
          search: search, relevance: ChatComposition.makeRelevanceFilter(coordinator: model),
          readRecords: { records }))
      var requestStarted: Double?
      do {
        try #require(Set(records.map(\.id)).count == records.count)
        try #require(records.allSatisfy { UUID(uuidString: $0.id) != nil })
        let chat = ChatUseCases(repository: PilotChatRepository(), model: model, memory: memory)
        _ = try await chat.load()
        let request = item.question + "\nQuestion date: " + item.questionDate
        let now = ProcessInfo.processInfo.systemUptime
        let allowed = min(caseBudget - (now - started), budget - (now - runStarted))
        row["allowedRequestSeconds"] = max(0, allowed)
        guard allowed > 0 else { throw PilotDeadlineError.expired }
        requestStarted = ProcessInfo.processInfo.systemUptime
        let state = try await withPilotDeadline(seconds: allowed) {
          try await chat.generate(submittedText: request) { _ in }
        }
        let reply = try #require(
          state.conversations.first(where: { $0.id == state.selectedID })?.messages.last)
        row["answer"] = reply.text
        row["replyStatus"] = reply.status.rawValue
        row["status"] = reply.status == .complete ? "completed" : "runtime-error"
      } catch PilotDeadlineError.expired {
        row["status"] = "budget-timeout"
        row["error"] =
          "Cooperative deadline reached; cancelled operation joined before continuation."
      } catch {
        row["status"] = "runtime-error"
        row["error"] = String(describing: error)
      }
      if let requestStarted {
        row["requestSeconds"] = ProcessInfo.processInfo.systemUptime - requestStarted
      }
      let evidence = await memory.evidence
      let mapping = Dictionary(uniqueKeysWithValues: item.records.map { ($0.id.lowercased(), $0) })
      row["retrievedUUIDs"] = evidence.map { $0.id.uuidString.lowercased() }
      row["retrievedSourceIDs"] = evidence.compactMap {
        mapping[$0.id.uuidString.lowercased()]?.sourceID
      }
      row["retrievedSessionIDs"] = evidence.compactMap {
        mapping[$0.id.uuidString.lowercased()]?.sessionID
      }
      row["evidence"] = evidence.map { ["id": $0.id.uuidString, "text": $0.text] }
      row["candidateSourceIDs"] = await search.hits.compactMap {
        mapping[$0.sourceID.lowercased()]?.sourceID
      }
      row["indexAndRankingSeconds"] = await search.seconds
      row["rankingCompleted"] = await search.completed
      row["retrievalCompleted"] = await memory.completed
      row["retrievalSeconds"] = await memory.seconds
      let cleanupStarted = ProcessInfo.processInfo.systemUptime
      row["operationSeconds"] = cleanupStarted - started
      if row["status"] as? String == "budget-timeout" {
        row["deadlineOvershootSeconds"] = max(
          0,
          (row["requestSeconds"] as? Double ?? 0) - (row["allowedRequestSeconds"] as? Double ?? 0))
      }
      await model.unload()
      do { try await index.purge() } catch { row["cleanupError"] = String(describing: error) }
      do { try await index.close() } catch { row["closeError"] = String(describing: error) }
      if FileManager.default.fileExists(atPath: directory.path) {
        do { try FileManager.default.removeItem(at: directory) } catch {
          row["directoryCleanupError"] = String(describing: error)
          row["retainedDirectory"] = directory.path
        }
      }
      row["cleanupSeconds"] = ProcessInfo.processInfo.systemUptime - cleanupStarted
      row["seconds"] = ProcessInfo.processInfo.systemUptime - started
      rows.append(row)
      try persist()
      print("PUBLISHED_PILOT_CASE \(item.id) status=\(row["status"]!) seconds=\(row["seconds"]!)")
    }
  }
}
