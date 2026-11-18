import Foundation
import LlamaEvaluationAdapter
import MemoryCore
import PersonalMemoryExtraction
import Testing

private actor IndependentMemoryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) throws {
    try snapshot.validate()
    value = snapshot
  }
}

private struct IndependentClaim {
  let quote: String
  let kinds: Set<PersonalMemoryKind>
  let subject: PersonalProfileKind
  var name: String? = nil
  var time: String? = nil
  var needsPrior: Bool = false
  var needsAnswer: Bool = false
}

private struct IndependentCase {
  enum Setup {
    case none
    case prior(String, PersonalMemoryKind, PersonalProfileKind, String? = nil)
    case answer(question: String, answer: String)
    case confirmed(String)
  }
  enum Expected {
    case noMemory, question, protectedChange
    case claims([IndependentClaim], updatesPrior: Bool = false)
  }
  let id: String
  let text: String
  var setup: Setup = .none
  let expected: Expected
}

/// Freeze these independent cases before running a proposed final prompt/model.
/// Never tune an extractor against this set and continue calling the set held out.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_AUTO_MEMORY_MODEL"] != nil))
struct AutomaticMemoryIndependentTests {
  private static let cases: [IndependentCase] = [
    .init(id: "ind-01", text: "Evening! How's it going?", expected: .noMemory),
    .init(id: "ind-02", text: "Please explain how rainbows form.", expected: .noMemory),
    .init(
      id: "ind-03", text: "I am only venting: I could throw this laptop out the window.",
      expected: .noMemory),
    .init(
      id: "ind-04", text: "For this story, I am a chef named Rami opening a cafe on Neptune.",
      expected: .noMemory),
    .init(
      id: "ind-05", text: "Some days I think I should move to another city.", expected: .question),
    .init(id: "ind-06", text: "محتار أترك النادي لو أبقى بيه", expected: .question),
    .init(
      id: "ind-07", text: "Silent rooms are my favourite places to work.",
      expected: .claims([
        .init(
          quote: "Silent rooms are my favourite places to work.", kinds: [.preference],
          subject: .selfProfile)
      ])),
    .init(
      id: "ind-08", text: "أفضّل أشتغل من الصبح",
      expected: .claims([
        .init(quote: "أفضّل أشتغل من الصبح", kinds: [.preference], subject: .selfProfile)
      ])),
    .init(
      id: "ind-09", text: "Nadia, my cousin, works as a pharmacist.",
      expected: .claims([
        .init(
          quote: "Nadia, my cousin, works as a pharmacist.", kinds: [.fact], subject: .person,
          name: "Nadia")
      ])),
    .init(
      id: "ind-10", text: "Omar prefers buses; I prefer travelling by train.",
      expected: .claims([
        .init(quote: "Omar prefers buses", kinds: [.preference], subject: .person, name: "Omar"),
        .init(quote: "I prefer travelling by train.", kinds: [.preference], subject: .selfProfile),
      ])),
    .init(
      id: "ind-11", text: "صديقي حسن يدرس الهندسة في الموصل",
      expected: .claims([
        .init(
          quote: "صديقي حسن يدرس الهندسة في الموصل", kinds: [.fact], subject: .person,
          name: "حسن")
      ])),
    .init(
      id: "ind-12", text: "I met Layla at the museum last Saturday.",
      expected: .claims([
        .init(
          quote: "I met Layla at the museum last Saturday.", kinds: [.fact],
          subject: .selfProfile, time: "last Saturday")
      ])),
    .init(
      id: "ind-13", text: "The Juniper project has a weekly review every Thursday.",
      expected: .claims([
        .init(
          quote: "The Juniper project has a weekly review every Thursday.",
          kinds: [.fact, .workflow], subject: .project, name: "Juniper")
      ])),
    .init(
      id: "ind-14", text: "She dislikes long phone calls.",
      setup: .prior("Hana is my sister.", .fact, .person, "Hana"),
      expected: .claims([
        .init(
          quote: "She dislikes long phone calls.", kinds: [.preference], subject: .person,
          name: "Hana", needsPrior: true)
      ])),
    .init(
      id: "ind-15", text: "I might stop volunteering.",
      setup: .answer(question: "Are you only venting about volunteering?", answer: "yes"),
      expected: .noMemory),
    .init(
      id: "ind-16", text: "I might stop volunteering.",
      setup: .answer(question: "Have you decided to stop volunteering?", answer: "yes"),
      expected: .claims([
        .init(
          quote: "I might stop volunteering.", kinds: [.plan, .commitment], subject: .selfProfile,
          needsAnswer: true)
      ])),
    .init(
      id: "ind-17", text: "I now prefer meetings on Thursdays.",
      setup: .prior("I prefer meetings on Tuesdays.", .preference, .selfProfile),
      expected: .claims(
        [
          .init(
            quote: "I now prefer meetings on Thursdays.", kinds: [.preference],
            subject: .selfProfile)
        ], updatesPrior: true)),
    .init(
      id: "ind-18", text: "I now live in Amman.", setup: .confirmed("I live in Erbil."),
      expected: .protectedChange),
  ]

  @Test(.timeLimit(.minutes(20)))
  func frozenCasesRequireCompleteClaimsAndCorrectAttribution() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["MEMORYOS_AUTO_MEMORY_MODEL"])
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
    let model = LlamaChatModel(assetURL: url, expectedSHA256: hash)
    let analyzer = LocalPersonalMemoryAnalyzer(model: model)
    var matchedCases = 0
    var supportedClaims = 0
    var matchedClaims = 0
    var unsafeAccepted = 0
    var elapsed: [Double] = []
    for item in Self.cases {
      let useCases = PersonalMemoryUseCases(repository: IndependentMemoryRepository())
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
        case .claims(let claims, let updatesPrior):
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
          passed = used.count == claims.count && accepted.count == claims.count && question == nil
          if updatesPrior {
            let old = try #require(priorEntry)
            let successor = state.entries.first { $0.id == old.id }?.supersededByID
            passed = passed && successor != nil && accepted.contains { $0.id == successor }
          }
        }
        outcome = passed ? "matched" : "mismatch"
      } catch { outcome = "rejected:\(error)" }
      let duration = start.duration(to: clock.now)
      elapsed.append(
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
      if case .claims(let claims, _) = item.expected {
        supportedClaims += claims.count
        matchedClaims += caseMatches
      }
      unsafeAccepted += caseUnsafe
      if passed { matchedCases += 1 }
      print(
        "AUTO_MEMORY_INDEPENDENT id=\(item.id) outcome=\(outcome) accepted=\(acceptedCount) unsafe=\(caseUnsafe) seconds=\(elapsed.last ?? 0)"
      )
    }
    await model.unload()
    let ordered = elapsed.sorted()
    let p95 = ordered[max(0, Int(ceil(Double(ordered.count) * 0.95)) - 1)]
    print(
      "AUTO_MEMORY_INDEPENDENT_SCORE cases=\(matchedCases)/\(Self.cases.count) claims=\(matchedClaims)/\(supportedClaims) unsafeAccepted=\(unsafeAccepted) p95seconds=\(p95)"
    )
    #expect(Double(matchedCases) / Double(Self.cases.count) >= 0.85)
    #expect(Double(matchedClaims) / Double(supportedClaims) >= 0.85)
    #expect(unsafeAccepted == 0)
  }

  private static func matches(
    _ entry: PersonalMemoryEntry, claim: IndependentClaim, source: PersonalMemorySource,
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
