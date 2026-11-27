import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor FreshRelationshipRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

/// Independent fictional cases frozen before the November 23 repair.
/// The assertions check explicit obligations, not broad semantic quality. A reviewer must also
/// inspect every returned claim against each case's manual criterion. An empty result fails a
/// supported case. Never tune production prompts to these names, phrases or expected answers.
/// Root coordinates SDK execution; no other model run may overlap this serialized suite.
@Suite(.serialized) @MainActor struct FreshRelationshipAcceptanceTests {
  private struct Case {
    let id: String
    let texts: [String]
    let question: String
    let arabic: Bool
    let requiredKinds: Set<RelationshipFindingKind>
    let forbiddenKinds: Set<RelationshipFindingKind>
    let manualCriterion: String
  }

  @Test(.timeLimit(.minutes(15)))
  func unseenOffersRequestsPromisesAndNegationPreserveMeaning() async throws {
    let cases: [Case] = [
      .init(
        id: "en-conditional-help",
        texts: ["Ilan: If you want, I can carry the boxes upstairs this evening."],
        question: "Who offers to do what, and has the offer been accepted? Answer in English.",
        arabic: false, requiredKinds: [.unresolved], forbiddenKinds: [.agreement, .commitment],
        manualCriterion:
          "Ilan offers to carry the recipient's boxes upstairs this evening, conditional on their wishes. No acceptance or completed carrying is evidenced; do not make the recipient the carrier."
      ),
      .init(
        id: "ar-request-link",
        texts: ["دانا: ممكن تبعث لي رابط الاجتماع قبل الظهر؟"],
        question: "اشرح من يطلب من الآخر ماذا، وهل يوجد وعد بإرسال الرابط؟ أجب بالعربية.",
        arabic: true, requiredKinds: [.unresolved], forbiddenKinds: [.agreement, .commitment],
        manualCriterion:
          "Dana asks the other person to send her the meeting link before noon. She does not offer or promise to send it, and the recipient has not accepted or completed the request."
      ),
      .init(
        id: "en-declined-offer-new-request",
        texts: [
          "Mika: I can book a taxi for you.",
          "Jules: Thanks, I will take the bus instead. Could you only send me the venue address?",
        ],
        question:
          "Explain who offered what, how the recipient responded, and what they requested instead. Answer in English.",
        arabic: false, requiredKinds: [.unresolved], forbiddenKinds: [.agreement],
        manualCriterion:
          "Mika offers to book a taxi for Jules. Jules declines that offer, states a bus plan, and asks Mika only for the venue address. Neither a taxi booking nor address delivery has occurred. Do not turn the offer into advice."
      ),
      .init(
        id: "ar-explicit-promise",
        texts: ["سامر: أوعدك أرجع لك الكتاب يوم الاثنين."],
        question: "ما الالتزام الصريح هنا ومن التزم به؟ أجب بالعربية ولا تفترض أنه نُفّذ.",
        arabic: true, requiredKinds: [.commitment], forbiddenKinds: [.agreement],
        manualCriterion:
          "Samer explicitly promises to return the book to the recipient on Monday. This is a future commitment, not a completed return, request, or promise by the recipient."
      ),
      .init(
        id: "en-negated-promise",
        texts: [
          "Priya: I have not promised to review the draft. I only asked when it is due."
        ],
        question:
          "Did Priya commit to review the draft? Explain what she actually states in English.",
        arabic: false, requiredKinds: [], forbiddenKinds: [.agreement, .commitment],
        manualCriterion:
          "Priya explicitly denies promising a review and says she asked about the deadline. No review commitment or completed review is supported; do not erase the negation."
      ),
      .init(
        id: "ar-reported-third-person",
        texts: ["رهف: أخوي قال راح يجيب الدواء لأمي. أنا فقط أنقل لك كلامه."],
        question:
          "من قال إنه سيحضر الدواء ولمن؟ فرّق بين ناقلة الكلام والشخص المقصود. أجب بالعربية.",
        arabic: true, requiredKinds: [], forbiddenKinds: [.agreement],
        manualCriterion:
          "Rahaf reports that her brother said he would bring medicine for their mother. The brother is the reported actor, the mother the recipient, and Rahaf only the messenger. This is a reported statement, not independently proven completion."
      ),
    ]
    let model = LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel())
    for item in cases { try await run(item, model: model) }
    await model.unload()
  }

  @Test(.timeLimit(.minutes(5)))
  func datedCommitmentDisagreementAndRepairRemainSeparateEvents() async throws {
    let model = LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel())
    let memory = PersonalMemoryUseCases(repository: FreshRelationshipRepository())
    let conversationID = UUID()
    let texts = [
      "Mariam: I promise to send the rent by Friday.",
      "Omar: Friday has passed and the rent has not arrived. I disagree with adding the extra fee.",
      "Mariam: I am sorry I missed Friday. I will send the rent on Monday instead.",
    ]
    let sources = texts.enumerated().map { index, text in
      PersonalMemorySource(
        conversationID: conversationID, text: text,
        createdAt: Date(timeIntervalSince1970: 1_731_600_000 + Double(index) * 86_400),
        origin: "fictional independent chronology", kind: .conversationOnly)
    }
    for source in sources { _ = try await memory.ingest(source: source) }
    let before = try await memory.snapshot()
    let started = Date()
    do {
      let result = try await RelationshipUnderstandingUseCases(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
      ).analyze(
        .init(
          sourceIDs: sources.map(\.id),
          question:
            "Build a timeline of the commitment, disagreement, and repair attempt across these three dated records. Keep separate events and their evidence. Explain the changed deadline without claiming payment occurred. Answer in English.",
          relationship: .family, focus: .discussion))
      let required: [(Int, RelationshipFindingKind)] = [
        (0, .commitment), (1, .disagreement), (2, .repairAttempt),
      ]
      for (sourceIndex, kind) in required {
        #expect(
          result.timeline.contains {
            $0.finding.kind == kind
              && $0.finding.evidence.contains { $0.sourceID == sources[sourceIndex].id }
              && $0.firstRecordedAt <= sources[sourceIndex].createdAt
              && $0.lastRecordedAt >= sources[sourceIndex].createdAt
          }, "Missing distinct cited timeline event: \(kind)")
      }
      #expect(result.timeline.count >= 3)
      #expect(
        result.timeline.map(\.firstRecordedAt)
          == result.timeline.map(\.firstRecordedAt).sorted())
      #expect(!result.insufficientEvidence && result.clarification == nil)
      #expect(result.draft == nil && result.summaries.isEmpty)
      checkEvidence(result, sources: sources)
      #expect(try await memory.snapshot() == before)
      print("FRESH_RELATIONSHIP_TIMELINE elapsed=\(Date().timeIntervalSince(started))")
      print(
        "FRESH_RELATIONSHIP_TIMELINE_PROPOSAL \(String(decoding: try JSONEncoder().encode(result.proposal), as: UTF8.self))"
      )
      // Manual: correct speakers, Friday-to-Monday change, explicit apology, fee disagreement,
      // and reported nonreceipt remain distinct. Do not claim payment or reconciliation occurred.
    } catch {
      Issue.record("Fresh multi-event timeline failed: \(error)")
      #expect(try await memory.snapshot() == before)
    }
    await model.unload()
  }

  private func run(_ item: Case, model: any StructuredChatModel) async throws {
    let memory = PersonalMemoryUseCases(repository: FreshRelationshipRepository())
    let conversationID = UUID()
    let sources = item.texts.enumerated().map { index, text in
      PersonalMemorySource(
        conversationID: conversationID, text: text,
        createdAt: Date(timeIntervalSince1970: 1_731_500_000 + Double(index) * 60),
        origin: "fictional independent meaning fixture", kind: .conversationOnly)
    }
    for source in sources { _ = try await memory.ingest(source: source) }
    let before = try await memory.snapshot()
    let started = Date()
    do {
      let result = try await RelationshipUnderstandingUseCases(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
      ).analyze(
        .init(
          sourceIDs: sources.map(\.id), question: item.question,
          relationship: .friend, focus: .discussion))
      #expect(!result.insufficientEvidence && result.clarification == nil, "Abstention: \(item.id)")
      #expect(!result.findings.isEmpty, "No supported observation: \(item.id)")
      #expect(result.draft == nil && result.summaries.isEmpty)
      let kinds = Set(result.findings.map(\.kind))
      #expect(item.requiredKinds.isSubset(of: kinds), "Missing event kind: \(item.id)")
      #expect(kinds.isDisjoint(with: item.forbiddenKinds), "Wrong modality: \(item.id)")
      let text = result.findings.map(\.text).joined(separator: " ")
      let arabic = text.unicodeScalars.filter { (0x0600...0x06FF).contains($0.value) }.count
      let latin = text.unicodeScalars.filter {
        (0x0041...0x005A).contains($0.value) || (0x0061...0x007A).contains($0.value)
      }.count
      #expect(item.arabic ? arabic > latin : latin > arabic, "Wrong answer language: \(item.id)")
      checkEvidence(result, sources: sources)
      #expect(try await memory.snapshot() == before)
      print("FRESH_RELATIONSHIP_CASE \(item.id) elapsed=\(Date().timeIntervalSince(started))")
      print("FRESH_RELATIONSHIP_MANUAL \(item.id) \(item.manualCriterion)")
      print(
        "FRESH_RELATIONSHIP_PROPOSAL \(item.id) \(String(decoding: try JSONEncoder().encode(result.proposal), as: UTF8.self))"
      )
    } catch {
      Issue.record("Fresh meaning case \(item.id) failed: \(error)")
      #expect(try await memory.snapshot() == before)
    }
  }

  private func checkEvidence(
    _ result: RelationshipUnderstandingResult, sources: [PersonalMemorySource]
  ) {
    let evidence = result.findings.flatMap { $0.evidence + $0.counterevidence }
    #expect(Set(evidence.map(\.sourceID)) == Set(sources.map(\.id)))
    #expect(
      evidence.allSatisfy { item in
        sources.contains {
          $0.id == item.sourceID
            && Data($0.text.utf8).range(of: Data(item.quote.utf8)) != nil
        }
      })
  }
}
