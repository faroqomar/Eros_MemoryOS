import ChatCore
import Foundation
import RetrievalCore
import Testing

@testable import MemoryOS

private actor SpeedChatRepository: ChatRepository {
  private var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ snapshot: ChatSnapshot) { value = snapshot }
}

private struct SpeedCandidateSearch: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.prefix(limit).map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
  }
}

/// Reproduces the previous lifecycle only for a controlled before/after comparison.
private struct PreviousRelevanceLifecycle: MemoryEvidenceFiltering {
  let chat: any ChatModel
  let filter: SourceBoundedChatEvidenceFilter
  func selectRelevant(query: String, candidates: [ChatEvidence]) async throws -> Set<UUID> {
    guard !candidates.isEmpty else { return [] }
    await chat.unload()
    return try await filter.selectRelevant(query: query, candidates: candidates)
  }
}

private actor SpeedSamples {
  private(set) var firstText: Double?
  private(set) var retrieval: Double = 0
  func recordFirstText(_ seconds: Double) {
    if firstText == nil { firstText = seconds }
  }
  func recordRetrieval(_ seconds: Double) { retrieval = seconds }
}

/// Opt-in diagnostics for this file's fixed fictional inputs. Never log assessment or raw prompts.
private actor SpeedStageTrace {
  let lifecycle: String
  private var request = -1
  private var stageIndex = 0

  init(lifecycle: String) { self.lifecycle = lifecycle }
  func begin(request: Int) {
    self.request = request
    stageIndex = 0
  }

  func record(
    grammar: String, promptBytes: Int, maximumOutputTokens: Int,
    seconds: Double, output: String?, failed: Bool
  ) {
    stageIndex += 1
    let stage =
      grammar.contains("resolution")
      ? "subject-check"
      : (grammar.contains("subject") ? "subject-extraction" : "topic-selection")
    var result: [String: Any] = [
      "lifecycle": lifecycle, "request": request, "stageIndex": stageIndex,
      "stage": stage, "seconds": seconds, "promptBytes": promptBytes,
      "grammarBytes": grammar.utf8.count, "maximumOutputTokens": maximumOutputTokens,
      "outputBytes": output?.utf8.count ?? 0, "failed": failed,
    ]
    if let output,
      let row = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
    {
      for key in ["subject", "resolution", "relevant"] {
        if let value = row[key] { result[key] = value }
      }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
    else { return }
    print("MEMORYOS_CHAT_STAGE \(String(decoding: data, as: UTF8.self))")
  }
}

private struct SpeedTracedModel: StructuredChatModel {
  let base: any StructuredChatModel
  let trace: SpeedStageTrace

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await base.generate(turns: turns, onText: onText)
  }
  func unload() async { await base.unload() }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let start = Date()
    do {
      let output = try await base.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
      await trace.record(
        grammar: grammar, promptBytes: turns.reduce(0) { $0 + $1.text.utf8.count },
        maximumOutputTokens: maximumOutputTokens, seconds: Date().timeIntervalSince(start),
        output: output, failed: false)
      return output
    } catch {
      await trace.record(
        grammar: grammar, promptBytes: turns.reduce(0) { $0 + $1.text.utf8.count },
        maximumOutputTokens: maximumOutputTokens, seconds: Date().timeIntervalSince(start),
        output: nil, failed: true)
      throw error
    }
  }
}

private struct TimedSpeedMemory: ChatMemoryRetrieving {
  let base: LocalChatMemory
  let samples: SpeedSamples
  func retrieve(query: String) async throws -> [ChatEvidence] {
    let start = Date()
    let result = try await base.retrieve(query: query)
    await samples.recordRetrieval(Date().timeIntervalSince(start))
    return result
  }
}

/// Real pinned-model timings. Candidate ranking is fixed to isolate lifecycle cost;
/// this is not a whole-library search or physical-phone benchmark.
@Suite(.serialized) @MainActor struct ChatRuntimeSpeedTests {
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RUN_SPEED_COMPARISON"] == "1"),
    .timeLimit(.minutes(10)))
  func sharedWeightsReduceReloadsWithoutChangingSourcesOrAnswers() async throws {
    let firstID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    let secondID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    let records = [
      MemorySearchRecord(id: firstID.uuidString, text: "Rana: My meeting is on Friday at six."),
      MemorySearchRecord(id: secondID.uuidString, text: "علي: موعدي يوم الأحد الساعة العاشرة."),
    ]
    let cases: [(String, UUID, [String], [String])] = [
      ("When is Rana's meeting? Answer in one short sentence.", firstID, ["friday"], ["six", "6"]),
      ("متى موعد علي؟ أجب بجملة قصيرة.", secondID, ["الأحد", "الاحد"], ["العاشرة", "10", "١٠"]),
      ("When is Rana's meeting? Answer in one short sentence.", firstID, ["friday"], ["six", "6"]),
    ]
    for shared in [false, true] {
      let trace =
        ProcessInfo.processInfo.environment["MEMORYOS_TRACE_SPEED_STAGES"] == "1"
        ? SpeedStageTrace(lifecycle: shared ? "shared" : "previous") : nil
      func makeModel() throws -> any ChatModel {
        let model = try RuntimeTestModel.makeModel()
        guard let trace else { return model }
        let structured = try #require(model as? any StructuredChatModel)
        return SpeedTracedModel(base: structured, trace: trace)
      }
      let raw = try makeModel()
      let coordinator = LocalInferenceCoordinator(model: raw)
      let relevance: any MemoryEvidenceFiltering
      if shared {
        relevance = ChatComposition.makeRelevanceFilter(coordinator: coordinator)
      } else {
        let verifier = try #require(makeModel() as? any StructuredChatModel)
        relevance = PreviousRelevanceLifecycle(
          chat: coordinator, filter: SourceBoundedChatEvidenceFilter(model: verifier))
      }
      for (index, fixture) in cases.enumerated() {
        await trace?.begin(request: index)
        let samples = SpeedSamples()
        let memory = LocalChatMemory(
          search: SpeedCandidateSearch(), relevance: relevance, readRecords: { records })
        let useCases = ChatUseCases(
          repository: SpeedChatRepository(), model: coordinator,
          memory: TimedSpeedMemory(base: memory, samples: samples))
        _ = try await useCases.load()
        let start = Date()
        let residentSampler = RequestResidentSampler(read: { ChatMeasurement.residentBytes() })
        let measured: (value: ChatSnapshot, resident: RequestResidentSampler.Report)
        do {
          measured = try await residentSampler.measure {
            try await useCases.generate(submittedText: fixture.0) { state in
              if let reply = state.conversations.first(where: { $0.id == state.selectedID })?
                .messages
                .last,
                reply.role == .assistant,
                !reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              {
                await samples.recordFirstText(Date().timeIntervalSince(start))
              }
            }
          }
        } catch {
          var failure = await residentSampler.report?.fields ?? [:]
          failure["lifecycle"] = shared ? "shared" : "previous"
          failure["request"] = index
          failure["failed"] = true
          let data = try JSONSerialization.data(withJSONObject: failure, options: .sortedKeys)
          print("MEMORYOS_CHAT_SPEED_FAILURE \(String(decoding: data, as: UTF8.self))")
          await coordinator.unload()
          throw error
        }
        let snapshot = measured.value
        let total = Date().timeIntervalSince(start)
        let reply = try #require(
          snapshot.conversations.first(where: { $0.id == snapshot.selectedID })?.messages.last)
        let text = reply.text.lowercased()
        #expect(reply.status == .complete)
        #expect(reply.sources.map(\.id) == [fixture.1])
        #expect(
          fixture.2.contains(where: text.contains) && fixture.3.contains(where: text.contains))
        let firstText = try #require(await samples.firstText)
        var result: [String: Any] = [
          "lifecycle": shared ? "shared" : "previous",
          "model": try RuntimeTestModel.configuration().selection,
          "relevancePolicy": "subject-and-topic",
          "request": index,
          "firstTextSeconds": firstText,
          "retrievalSeconds": await samples.retrieval,
          "totalSeconds": total,
          "sourceCount": reply.sources.count,
          "answerBytes": reply.text.utf8.count,
        ]
        result.merge(measured.resident.fields) { _, sample in sample }
        let data = try JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
        print("MEMORYOS_CHAT_SPEED \(String(decoding: data, as: UTF8.self))")
      }
      await coordinator.unload()
    }
  }
}
