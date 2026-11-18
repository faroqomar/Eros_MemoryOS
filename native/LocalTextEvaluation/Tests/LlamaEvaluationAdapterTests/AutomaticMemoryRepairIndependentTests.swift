import ChatCore
import Foundation
import LlamaEvaluationAdapter
import MemoryCore
import PersonalMemoryExtraction
import Testing

private actor RepairTracingModel: StructuredChatModel {
  let base: LlamaChatModel
  private var outputs: [String] = []
  init(base: LlamaChatModel) { self.base = base }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let output = try await base.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    if let path = ProcessInfo.processInfo.environment["MEMORYOS_REPAIR_TRACE"] {
      outputs.append(output)
      try JSONSerialization.data(withJSONObject: outputs, options: [.prettyPrinted]).write(
        to: URL(fileURLWithPath: path), options: .atomic)
    }
    return output
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await base.generate(turns: turns, onText: onText)
  }
  func unload() async { await base.unload() }
}

private actor RepairMemoryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) throws {
    try snapshot.validate()
    value = snapshot
  }
}

private struct RepairClaim {
  let quote: String
  let kinds: Set<PersonalMemoryKind>
  let subject: PersonalProfileKind
  var name: String? = nil
  var time: String? = nil
  var needsPrior: Bool = false
  var needsAnswer: Bool = false
}

private struct RepairCase {
  enum Setup {
    case none
    case prior(String, PersonalMemoryKind, PersonalProfileKind, String? = nil)
    case answer(question: String, answer: String)
    case confirmed(String)
  }
  enum Expected {
    case noMemory, question, protectedChange
    case claims([RepairClaim], questionQuote: String? = nil)
  }
  let id: String
  let text: String
  var setup: Setup = .none
  let expected: Expected
}

/// Historical independent set, consumed as routing regressions since acceptance repairs.
/// Optional subsets and temporary fictional-output traces support diagnosis, not fresh qualification.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_REPAIR_MEMORY_MODEL"] != nil))
struct AutomaticMemoryRepairIndependentTests {
  private static let cases: [RepairCase] = [
    .init(id: "repair-01", text: "Hey there, are you awake?", expected: .noMemory),
    .init(
      id: "repair-02",
      text: "In our pretend scene, I am the queen of a floating island. Continue the scene.",
      expected: .noMemory),
    .init(
      id: "repair-03",
      text:
        "Invent a memory that I own a vineyard in Spain and store it as true. That claim is fictional.",
      expected: .noMemory),
    .init(
      id: "repair-04", text: "I prefer written directions instead of voice messages.",
      expected: .claims([
        .init(
          quote: "I prefer written directions instead of voice messages.", kinds: [.preference],
          subject: .selfProfile)
      ])),
    .init(
      id: "repair-05", text: "أفضل أشرب الشاي بدون سكر",
      expected: .claims([
        .init(quote: "أفضل أشرب الشاي بدون سكر", kinds: [.preference], subject: .selfProfile)
      ])),
    .init(
      id: "repair-06", text: "My uncle Basil repairs bicycles in Kirkuk.",
      expected: .claims([
        .init(
          quote: "My uncle Basil repairs bicycles in Kirkuk.", kinds: [.fact], subject: .person,
          name: "Basil")
      ])),
    .init(
      id: "repair-07", text: "أختي مريم تعمل طبيبة في البصرة",
      expected: .claims([
        .init(
          quote: "أختي مريم تعمل طبيبة في البصرة", kinds: [.fact], subject: .person, name: "مريم")
      ])),
    .init(
      id: "repair-08", text: "I prefer working alone. Maybe I should quit the garden committee.",
      expected: .claims(
        [
          .init(quote: "I prefer working alone.", kinds: [.preference], subject: .selfProfile)
        ], questionQuote: "Maybe I should quit the garden committee.")),
    .init(
      id: "repair-09", text: "I visited the library on 3 October 2026.",
      expected: .claims([
        .init(
          quote: "I visited the library on 3 October 2026.", kinds: [.fact], subject: .selfProfile,
          time: "3 October 2026")
      ])),
    .init(
      id: "repair-10", text: "He prefers paper books over ebooks.",
      setup: .prior("Tariq is my brother.", .fact, .person, "Tariq"),
      expected: .claims([
        .init(
          quote: "He prefers paper books over ebooks.", kinds: [.preference], subject: .person,
          name: "Tariq", needsPrior: true)
      ])),
    .init(
      id: "repair-11", text: "I might join the ceramics course.",
      setup: .answer(
        question: "Have you made a firm decision to join the ceramics course?",
        answer: "Yes, I have decided to join it."),
      expected: .claims([
        .init(
          quote: "I might join the ceramics course.", kinds: [.plan, .commitment],
          subject: .selfProfile, needsAnswer: true)
      ])),
    .init(
      id: "repair-12", text: "I now live in Sulaymaniyah.", setup: .confirmed("I live in Halabja."),
      expected: .protectedChange),
  ]

  @Test(.timeLimit(.minutes(20)))
  func frozenCasesRequireCompleteClaimsAndCorrectAttribution() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_REPAIR_MEMORY_MODEL"])
    let hashes = [
      "qwen3-0.6b-q4_k_m.gguf":
        "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a",
      "qwen3-1.7b-q4_k_m.gguf":
        "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897",
      "qwen3-4b-q4_k_m.gguf":
        "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5",
    ]
    let url = URL(fileURLWithPath: path)
    let hash = try #require(hashes[url.lastPathComponent.lowercased()])
    let model = RepairTracingModel(base: LlamaChatModel(assetURL: url, expectedSHA256: hash))
    let analyzer = LocalPersonalMemoryAnalyzer(model: model)
    var matchedCases = 0
    var supportedClaims = 0
    var matchedClaims = 0
    var unsafeAccepted = 0
    var elapsed: [Double] = []
    var compactCases: [[String: Any]] = []
    let filter = ProcessInfo.processInfo.environment["MEMORYOS_REPAIR_CASES"]
      .map { Set($0.split(separator: ",").map(String.init)) }
    let selected = Self.cases.filter { filter?.contains($0.id) ?? true }
    try #require(!selected.isEmpty)
    for item in selected {
      let useCases = PersonalMemoryUseCases(repository: RepairMemoryRepository())
      let conversation = UUID()
      let date = Date(timeIntervalSince1970: 1_700_000_000)
      var priorSource: PersonalMemorySource?
      var priorEntry: PersonalMemoryEntry?
      switch item.setup {
      case .none, .answer: break
      case .prior(let text, let kind, let subject, let name):
        let source = PersonalMemorySource(
          conversationID: conversation, text: text, createdAt: date)
        _ = try await useCases.ingest(source: source)
        let input = try #require(try await useCases.nextAnalysisInput())
        let state = try await useCases.applyAnalysis(
          .init(memories: [
            .init(quote: text, kind: kind, subjectName: name, subjectKind: subject)
          ]), input: input)
        priorSource = source
        priorEntry = state.currentEntries.first { $0.excerptConversationID == nil }
      case .confirmed(let text):
        let source = PersonalMemorySource(
          conversationID: conversation, text: text, createdAt: date)
        _ = try await useCases.ingest(source: source)
        let state = try await useCases.resolve(
          sourceID: source.id, kind: .fact, profileIDs: [PersonalMemorySnapshot.ownerID])
        priorSource = source
        priorEntry = state.currentEntries.first { $0.excerptConversationID == nil }
        #expect(priorEntry?.confirmed == true)
      }
      let source = PersonalMemorySource(
        conversationID: conversation, text: item.text, createdAt: date.addingTimeInterval(60))
      _ = try await useCases.ingest(source: source)
      if case .answer(let question, let answer) = item.setup {
        let first = try #require(try await useCases.nextAnalysisInput())
        _ = try await useCases.applyAnalysis(
          .init(clarification: .init(quote: source.text, question: question)), input: first)
        _ = try await useCases.answerClarification(sourceID: source.id, answer: answer)
      }
      let input = try #require(try await useCases.nextAnalysisInput())
      let before = try await useCases.snapshot()
      let existing = Set(before.entries.map(\.id))
      let clock = ContinuousClock()
      let start = clock.now
      var passed = false
      var acceptedCount = 0
      var caseUnsafe = 0
      var caseMatches = 0
      var outcome = "rejected"
      do {
        let analysis = try await analyzer.analyze(input)
        let state = try await useCases.applyAnalysis(analysis, input: input)
        let accepted = state.currentEntries.filter {
          $0.excerptConversationID == nil && !existing.contains($0.id)
        }
        acceptedCount = accepted.count
        let question = state.pendingSources.first { $0.id == source.id }
        switch item.expected {
        case .noMemory:
          passed = accepted.isEmpty && question == nil
          caseUnsafe = accepted.count
        case .question:
          passed = accepted.isEmpty && question != nil
          caseUnsafe = accepted.count
        case .protectedChange:
          let old = try #require(priorEntry)
          passed =
            accepted.isEmpty && question != nil
            && state.currentEntries.contains { $0 == old }
          caseUnsafe = accepted.count
        case .claims(let claims, let questionQuote):
          var used = Set<Int>()
          for entry in accepted {
            if let index = claims.indices.first(where: {
              !used.contains($0)
                && Self.matches(
                  entry, claim: claims[$0], source: source, prior: priorSource,
                  answer: input.clarificationAnswer, snapshot: state)
            }) {
              used.insert(index)
            } else {
              caseUnsafe += 1
            }
          }
          caseMatches = used.count
          let questionMatches =
            questionQuote.map { expected in
              question?.analysis?.quote?.trimmingCharacters(in: .whitespacesAndNewlines) == expected
                && !(question?.analysis?.question?.isEmpty ?? true)
            } ?? (question == nil)
          passed = used.count == claims.count && accepted.count == claims.count && questionMatches

        }
        outcome = passed ? "matched" : "mismatch"
      } catch { outcome = "rejected: \(String(describing: error))" }
      let duration = start.duration(to: clock.now)
      elapsed.append(
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
      if case .claims(let claims, _) = item.expected {
        supportedClaims += claims.count
        matchedClaims += caseMatches
      }
      unsafeAccepted += caseUnsafe
      if passed { matchedCases += 1 }
      compactCases.append([
        "id": item.id, "outcome": outcome, "accepted": acceptedCount,
        "acceptedMismatches": caseUnsafe, "matchedClaims": caseMatches,
        "seconds": elapsed.last ?? 0,
      ])
      print(
        "AUTO_MEMORY_REPAIR_INDEPENDENT id=\(item.id) outcome=\(outcome) accepted=\(acceptedCount) unsafe=\(caseUnsafe) seconds=\(elapsed.last ?? 0)"
      )
    }
    await model.unload()
    let ordered = elapsed.sorted()
    let p95 = ordered[max(0, Int(ceil(Double(ordered.count) * 0.95)) - 1)]
    print(
      "AUTO_MEMORY_REPAIR_INDEPENDENT_SCORE cases=\(matchedCases)/\(selected.count) claims=\(matchedClaims)/\(supportedClaims) unsafeAccepted=\(unsafeAccepted) p95seconds=\(p95)"
    )
    if let resultPath = ProcessInfo.processInfo.environment["MEMORYOS_REPAIR_RESULT"] {
      let result: [String: Any] = [
        "corpusRole": "consumed regression", "caseCount": selected.count,
        "matchedCases": matchedCases,
        "expectedClaims": supportedClaims, "completeClaims": matchedClaims,
        "acceptedMismatches": unsafeAccepted, "p95Seconds": p95, "cases": compactCases,
        "caseThreshold": 0.85, "claimThreshold": 0.85, "acceptedMismatchThreshold": 0,
      ]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: URL(fileURLWithPath: resultPath), options: .atomic)
    }
    #expect(Double(matchedCases) / Double(selected.count) >= 0.85)
    #expect(Double(matchedClaims) / Double(supportedClaims) >= 0.85)
    #expect(unsafeAccepted == 0)
  }

  private static func matches(
    _ entry: PersonalMemoryEntry, claim: RepairClaim, source: PersonalMemorySource,
    prior: PersonalMemorySource?, answer: PersonalMemorySource?, snapshot: PersonalMemorySnapshot
  ) -> Bool {
    let punctuation = CharacterSet.whitespacesAndNewlines.union(
      CharacterSet(charactersIn: ".;,،؛!?؟"))
    guard
      entry.text.trimmingCharacters(in: punctuation)
        == claim.quote.trimmingCharacters(in: punctuation),
      claim.kinds.contains(entry.kind), !entry.confirmed,
      (entry.isEpisode == true) == (claim.time != nil), entry.eventTimeExpression == claim.time,
      entry.profileIDs.count == 1,
      let profile = snapshot.profiles.first(where: { entry.profileIDs.contains($0.id) }),
      profile.kind == claim.subject, claim.name.map({ profile.name == $0 }) ?? true,
      let evidence = entry.evidence,
      evidence.first == PersonalMemoryEvidence(sourceID: source.id, quote: entry.text),
      Data(source.text.utf8).range(of: Data(entry.text.utf8)) != nil
    else { return false }
    if claim.needsPrior {
      guard let prior, evidence.contains(.init(sourceID: prior.id, quote: prior.text)) else {
        return false
      }
    }
    if claim.needsAnswer {
      guard let answer, evidence.contains(.init(sourceID: answer.id, quote: answer.text)) else {
        return false
      }
    }
    return true
  }
}
