import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor IndependentArabicRoleRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

// Fixed fictional probes only; bounded wire diagnostics stay in the external test log.
private actor ArabicRoleTraceModel: StructuredChatModel {
  let base: any StructuredChatModel
  init(base: any StructuredChatModel) { self.base = base }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
  {
    let value = try await base.generateJSON(
      turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    print("ARABIC_ROLE_WIRE \(value)")
    return value
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
    try await base.generate(turns: turns, onText: onText)
  }
  func unload() async { await base.unload() }
}

/// Three fresh action/actor/recipient/modality probes frozen before execution.
/// Manual semantic review is required; structural checks cannot establish role fidelity.
@Suite(.serialized) @MainActor struct IndependentArabicRoleTests {
  @Test(.timeLimit(.minutes(5)))
  func freshArabicOffersRequestsAndRefusalsPreserveWhoDoesWhat() async throws {
    let cases: [(String, [String], String)] = [
      (
        "offer-review",
        ["زيد: إذا تريد، أگدر أراجع ملفك الليلة وأرسلك ملاحظاتي."],
        "من يعرض مراجعة ملف من؟ وضّح العرض دون تحويله إلى طلب أو فعل منجز."
      ),
      (
        "request-listening",
        ["هدى: ممكن تسمعيني خمس دقايق بدون ما تقاطعيني؟"],
        "من يطلب من الآخر أن يستمع؟ لا تعكس المتكلم والمستمع."
      ),
      (
        "offer-refusal-request",
        [
          "باسم: أقدر أوصلك للمحطة إذا تحبين.",
          "سارة: شكراً، لكن أوصل نفسي اليوم. أحتاج منك بس ترسل عنوان المحطة.",
        ],
        "اشرح العرض والرفض والطلب الأخير مع من يفعل ماذا. لا تستنتج أن التوصيلة تمت."
      ),
    ]
    let model = ArabicRoleTraceModel(
      base: LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel()))
    for (id, texts, question) in cases {
      let memory = PersonalMemoryUseCases(repository: IndependentArabicRoleRepository())
      let conversation = UUID()
      let sources = texts.enumerated().map { index, text in
        PersonalMemorySource(
          conversationID: conversation, text: text,
          createdAt: Date(timeIntervalSince1970: 1_700_500_000 + Double(index) * 60),
          origin: "fictional independent Arabic role fixture", kind: .conversationOnly)
      }
      for source in sources { _ = try await memory.ingest(source: source) }
      let before = try await memory.snapshot()
      let useCases = RelationshipUnderstandingUseCases(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
      let started = Date()
      do {
        let result = try await useCases.analyze(
          .init(
            sourceIDs: sources.map(\.id), question: question,
            relationship: .colleague, focus: .discussion))
        let evidence = result.findings.flatMap { $0.evidence + $0.counterevidence }
        let exact = evidence.allSatisfy { quote in
          sources.contains { source in
            source.id == quote.sourceID
              && Data(source.text.utf8).range(of: Data(quote.quote.utf8)) != nil
          }
        }
        let text = result.findings.map(\.text).joined(separator: " ")
        let arabic = text.unicodeScalars.filter { (0x0600...0x06FF).contains($0.value) }.count
        let latin = text.unicodeScalars.filter {
          (0x0041...0x005A).contains($0.value) || (0x0061...0x007A).contains($0.value)
        }.count
        #expect(!result.findings.isEmpty && arabic > latin, "Missing natural Arabic answer: \(id)")
        #expect(
          exact && Set(evidence.map(\.sourceID)) == Set(sources.map(\.id)),
          "Missing/changed original evidence: \(id)")
        #expect(result.draft == nil && result.summaries.isEmpty)
        #expect(
          !result.findings.contains { [.agreement, .commitment].contains($0.kind) },
          "A request/conditional offer/declined lift is not an accepted commitment: \(id)")
        #expect(try await memory.snapshot() == before)
        print("FRESH_ARABIC_ROLE \(id) exact=\(exact) elapsed=\(Date().timeIntervalSince(started))")
        print(
          "FRESH_ARABIC_PROPOSAL \(id) \(String(decoding: try JSONEncoder().encode(result.proposal), as: UTF8.self))"
        )
      } catch {
        Issue.record("Fresh Arabic role case \(id) failed: \(error)")
        #expect(try await memory.snapshot() == before)
      }
    }
    await model.unload()
  }
}
