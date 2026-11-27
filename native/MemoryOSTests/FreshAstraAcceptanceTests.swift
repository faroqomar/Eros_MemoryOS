import ChatCore
import ChatPersistence
import CryptoKit
import Foundation
import LocalMemoryRetrieval
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

/// Deliberately excludes evaluation expectations from the decoder and from model requests.
private struct AstraFrozenInputs: Decodable {
  let schemaVersion: Int
  let id: String
  let inputs: [Case]
  struct Case: Decodable {
    let id: String
    let language: String
    let path: String
    let questionDate: String
    let sources: [Source]
    let query: String
    let profiles: [Profile]?
    let ownerAccount: String?
    let mutations: [Mutation]?
  }
  struct Source: Decodable {
    let id: UUID
    let text: String
    let createdAt: String
    let origin: String
    let kind: PersonalMemoryKind
  }
  struct Profile: Decodable {
    let names: [String]
    let sourceIndices: [Int]
    let canGroundQuery: Bool
  }
  struct Mutation: Decodable {
    let kind: String
    let entryLinkedToSourceIndex: Int?
    let sourceIndex: Int?
    let replacement: String?
    let confirmed: Bool?
  }
}

private actor AstraObservedMemory: ChatMemoryRetrieving {
  let base: LocalChatMemory
  private(set) var evidence: [ChatEvidence] = []
  private(set) var elapsed = 0.0
  private(set) var completed = false
  init(base: LocalChatMemory) { self.base = base }
  func retrieve(query: String) async throws -> [ChatEvidence] {
    try await retrieve(query: query, previousQuestions: [], excluding: [])
  }
  func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence] {
    try await retrieve(query: query, previousQuestions: previousQuestions, excluding: [])
  }
  func retrieve(query: String, previousQuestions: [String], excluding: Set<UUID>) async throws
    -> [ChatEvidence]
  {
    completed = false
    let started = ProcessInfo.processInfo.systemUptime
    defer { elapsed += ProcessInfo.processInfo.systemUptime - started }
    evidence = try await base.retrieve(
      query: query, previousQuestions: previousQuestions, excluding: excluding)
    completed = true
    return evidence
  }
}

private actor AstraFirstText {
  private(set) var time: Double?
  func observe(_ state: ChatSnapshot) {
    guard time == nil,
      let conversation = state.conversations.first(where: { $0.id == state.selectedID }),
      let message = conversation.messages.last, message.role == .assistant,
      !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    time = ProcessInfo.processInfo.systemUptime
  }
}

/// Executes frozen fictional inputs once through actual app use cases. Completion is not a semantic pass.
@Suite(.serialized) @MainActor struct FreshAstraAcceptanceTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_ASTRA_INPUT"] != nil))
  func frozenIndependentCases() async throws {
    let environment = ProcessInfo.processInfo.environment
    let input = URL(fileURLWithPath: try #require(environment["MEMORYOS_ASTRA_INPUT"]))
    let output = URL(fileURLWithPath: try #require(environment["MEMORYOS_ASTRA_OUTPUT"]))
    let bytes = try Data(contentsOf: input)
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    let frozenCounts = [
      "b2adb4683bd208c4bfcc93ae71a8933ba5183d6a8a57d88c3d6783eb7fddd93c": 14,
      // Consumed correction regression: only question date moves after the actual update.
      "db4a077c612279f61e5093ed9df56c03fcef674c0d95f0e12eff593190952691": 1,
      // Independent repair verification; inputs frozen before reviewing implementation changes.
      "9afeb494a51296974abf4685beae42b49963ab7775031a2a40c1c73a2c7c6ed8": 8,
      // Consumed full-app group replay retains original profiles and source links.
      "110d61fc74add6e752039469da411e4f728c09f3adf4b6f8badadb813b6d4bb6": 1,
      // Third repair: independently frozen inputs; labels never enter model requests.
      "a42c6e2788f2a78378d2ee4cf2cd6d67e3706abf9b549682ea8028d7e218797d": 12,
    ]
    let expectedCount = try #require(frozenCounts[digest], "Unrecognized frozen fixture")
    let frozen = try JSONDecoder().decode(AstraFrozenInputs.self, from: bytes)
    try #require(frozen.schemaVersion == 1 && frozen.inputs.count == expectedCount)
    try #require(Set(frozen.inputs.map(\.id)).count == frozen.inputs.count)
    let configuration = try RuntimeTestModel.configuration()
    let budget = try #require(Double(environment["MEMORYOS_ASTRA_BUDGET_SECONDS"] ?? "1800"))
    try #require(budget > 0 && budget <= 7200)
    let runStarted = ProcessInfo.processInfo.systemUptime
    var rows: [[String: Any]] = []
    func persist() throws {
      let result: [String: Any] = [
        "fixtureID": frozen.id, "fixtureSHA256": digest,
        "model": configuration.selection, "modelSHA256": configuration.expectedSHA256,
        "budgetSeconds": budget, "results": rows,
        "protocol":
          "Frozen inputs only; actual isolated file repositories/use cases; app default hybrid retrieval and subject filter; independent case model unload. Manual semantic grading remains separate. Budget checked between cases.",
        "automaticMemoryQualified": PersonalMemoryComposition.automaticMemoryQualified,
      ]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    }
    for item in frozen.inputs {
      let submittedQuery = item.query + "\nQuestion date: " + item.questionDate
      var row: [String: Any] = [
        "caseID": item.id, "path": item.path, "language": item.language,
        "status": "budget-not-run", "seconds": 0, "questionDateApplied": true,
      ]
      guard ProcessInfo.processInfo.systemUptime - runStarted < budget else {
        rows.append(row)
        try persist()
        continue
      }
      let directory = URL.temporaryDirectory.appending(
        path: "astra-acceptance-" + UUID().uuidString)
      let personal = PersonalMemoryComposition.makeUseCases(
        directory: directory.appending(path: "personal"))
      let model = LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel())
      let organizer = PersonalMemoryComposition.makeOrganizer(personal, model: model)
      let index = LocalMemorySearch(
        directory: directory.appending(path: "index"),
        cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
        provider: .hybrid, minimumSimilarity: -1)
      let started = ProcessInfo.processInfo.systemUptime
      let timing = AstraFirstText()
      do {
        let formatter = ISO8601DateFormatter()
        let conversationID = UUID()
        for source in item.sources {
          let date = try #require(formatter.date(from: source.createdAt))
          _ = try await personal.ingest(
            source: .init(
              id: source.id, conversationID: conversationID, text: source.text,
              createdAt: date, origin: source.origin, kind: source.kind))
        }
        for profile in item.profiles ?? [] {
          let name = try #require(profile.names.first)
          try #require(
            profile.canGroundQuery, "This frozen set uses explicit owner-created profiles")
          let state = try await personal.createProfile(
            kind: .person, name: name, aliases: Array(profile.names.dropFirst()))
          let added = try #require(state.profiles.first(where: { $0.name == name }))
          for sourceIndex in profile.sourceIndices {
            try #require(item.sources.indices.contains(sourceIndex))
            _ = try await personal.addLink(
              from: added.id, to: item.sources[sourceIndex].id,
              label: "fixture explicit association")
          }
        }
        for mutation in item.mutations ?? [] {
          switch mutation.kind {
          case "update-entry":
            let position = try #require(mutation.entryLinkedToSourceIndex)
            try #require(item.sources.indices.contains(position))
            let snapshot = try await personal.snapshot()
            let entry = try #require(
              snapshot.currentEntries.first(where: {
                $0.sourceIDs.contains(item.sources[position].id) && $0.kind == .fact
              }))
            _ = try await personal.updateEntry(
              id: entry.id, text: try #require(mutation.replacement),
              confirmedChange: mutation.confirmed == true)
          case "delete-source":
            let position = try #require(mutation.sourceIndex)
            try #require(item.sources.indices.contains(position))
            _ = try await personal.forgetSource(
              sourceID: item.sources[position].id, confirmed: mutation.confirmed == true)
          case "begin-temporary-session", "send-query", "end-temporary-session",
            "reopen-ordinary-session":
            try #require(item.path == "chat-lifecycle")
          default:
            Issue.record("Unimplemented frozen mutation: \(mutation.kind)")
            throw ChatError.invalidArchive
          }
        }
        let before = try await personal.snapshot()
        row["sourceIDsBeforeRequest"] = before.sources.map { $0.id.uuidString }
        row["currentEntriesBeforeRequest"] = before.currentEntries.map {
          ["id": $0.id.uuidString, "text": $0.text, "kind": $0.kind.rawValue]
        }
        if item.path == "relationship" {
          let useCases = RelationshipUnderstandingUseCases(
            memory: personal, analyzer: LocalRelationshipAnalyzer(model: model))
          let viewModel = RelationshipViewModel(useCases: useCases)
          viewModel.selected = Set(item.sources.map(\.id))
          viewModel.question = submittedQuery
          row["relationshipMode"] = "discussion"
          viewModel.ownerInterpretation = item.ownerAccount ?? ""
          viewModel.answerInArabic = item.language == "ar-IQ"
          let requestStarted = ProcessInfo.processInfo.systemUptime
          await viewModel.analyze()
          row["requestSeconds"] = ProcessInfo.processInfo.systemUptime - requestStarted
          if let result = viewModel.result {
            row["status"] = "completed"
            row["proposal"] = try JSONSerialization.jsonObject(
              with: JSONEncoder().encode(result.proposal))
            row["insufficientEvidence"] = result.insufficientEvidence
            row["inputRevision"] = result.input.revision
          } else {
            row["status"] = "runtime-error"
            row["error"] = String(describing: viewModel.error)
          }
          row["personalStateUnchanged"] = try await personal.snapshot() == before
        } else if item.path == "memory-search-answer" || item.path == "chat-lifecycle" {
          let observed = AstraObservedMemory(
            base: LocalChatMemory(
              search: index, relevance: ChatComposition.makeRelevanceFilter(coordinator: model),
              readSnapshot: {
                LocalChatMemory.makeSnapshot(local: [], personal: try await personal.snapshot())
              }))
          let repository = FileChatRepository(url: directory.appending(path: "chat.json"))
          let recorder = PersonalChatRecorder(useCases: personal, organizer: organizer)
          let chat = ChatUseCases(
            repository: repository, model: model, memory: observed, recorder: recorder)
          _ = try await chat.load()
          let durableBefore = try await repository.load()
          if item.path == "chat-lifecycle" { _ = try await chat.startTemporary() }
          var generationError: String?
          let requestStarted = ProcessInfo.processInfo.systemUptime
          do {
            let state = try await chat.generate(submittedText: submittedQuery) { state in
              await timing.observe(state)
            }
            let reply = try #require(
              state.conversations.first(where: { $0.id == state.selectedID })?.messages.last)
            row["answer"] = reply.text
            row["replyStatus"] = reply.status.rawValue
            row["sources"] = try JSONSerialization.jsonObject(
              with: JSONEncoder().encode(reply.sources))
            row["status"] = reply.status == .complete ? "completed" : "runtime-error"
          } catch {
            generationError = String(describing: error)
            row["status"] = "runtime-error"
            row["error"] = String(describing: error)
            row["clarificationFailure"] = (error as? ChatError) == .memorySubjectUnclear
            if (error as? ChatError) == .memorySubjectUnclear {
              row["status"] = "needs-clarification"
            }
          }
          row["requestSeconds"] = ProcessInfo.processInfo.systemUptime - requestStarted
          await organizer.pause()
          row["retrievedEvidence"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(await observed.evidence))
          row["retrievalSeconds"] = await observed.elapsed
          row["retrievalCompleted"] = await observed.completed
          if let first = await timing.time { row["firstTextSeconds"] = first - requestStarted }
          if item.path == "chat-lifecycle" {
            _ = try await chat.endTemporary()
            let reopened = ChatUseCases(
              repository: repository, model: model, memory: observed, recorder: recorder)
            let state = try await reopened.load()
            let durableAfter = try await repository.load()
            row["temporaryConversationsAfterReopen"] =
              state.conversations.filter(\.isTemporary).count
            row["durableConversationIDsUnchanged"] =
              durableBefore.conversations.map(\.id) == durableAfter.conversations.map(\.id)
            row["durableMessagesUnchanged"] =
              durableBefore.conversations.flatMap(\.messages)
              == durableAfter.conversations.flatMap(\.messages)
            row["personalStateUnchanged"] = try await personal.snapshot() == before
            row["privateQueryRetained"] = durableAfter.conversations.flatMap(\.messages).contains {
              $0.text.contains(submittedQuery)
            }
            row["existingMemoryReadCheck"] =
              "Original sources remain available in reopened app-owned storage; this query does not ask for existing facts."
            if generationError != nil { row["lifecycleChecksAfterGenerationFailure"] = true }
          }
        } else {
          row["status"] = "unimplemented-path"
          row["error"] = item.path
          Issue.record("Unimplemented frozen path: \(item.path)")
        }
        let after = try await personal.snapshot()
        row["sourceIDsAfterRequest"] = after.sources.map { $0.id.uuidString }
        row["newDerivedEntries"] =
          after.currentEntries.filter { entry in
            !before.currentEntries.contains(where: { $0.id == entry.id })
              && entry.excerptConversationID == nil
          }.count
        row["originalSourceBytesPreserved"] = item.sources.filter { original in
          before.sources.contains(where: { $0.id == original.id })
        }.allSatisfy { original in
          after.sources.contains(where: {
            $0.id == original.id && $0.text.utf8.elementsEqual(original.text.utf8)
          })
        }
      } catch {
        row["status"] = "runtime-error"
        row["error"] = String(describing: error)
      }
      row["seconds"] = ProcessInfo.processInfo.systemUptime - started
      await organizer.pause()
      await model.unload()
      var cleanupErrors: [String] = []
      do { try await index.purge() } catch { cleanupErrors.append(String(describing: error)) }
      do { try await index.close() } catch { cleanupErrors.append(String(describing: error)) }
      do {
        if FileManager.default.fileExists(atPath: directory.path) {
          try FileManager.default.removeItem(at: directory)
        }
      } catch { cleanupErrors.append(String(describing: error)) }
      if !cleanupErrors.isEmpty { row["cleanupErrors"] = cleanupErrors }
      rows.append(row)
      try persist()
      print("FRESH_ASTRA_CASE \(item.id) status=\(row["status"]!) seconds=\(row["seconds"]!)")
    }
  }
}
