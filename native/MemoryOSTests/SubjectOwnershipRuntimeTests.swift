import ChatCore
import Foundation
import Testing

@testable import MemoryOS

/// Consumed source-filter regressions. Ranking is bypassed to isolate ownership
/// and ambiguity; these checks are not a new held-out or full-pipeline score.
@Suite(.serialized) @MainActor struct SubjectOwnershipRuntimeTests {
  private actor TraceModel: StructuredChatModel {
    let base: any StructuredChatModel
    private(set) var outputs: [String] = []
    init(base: any StructuredChatModel) { self.base = base }
    func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
      -> String
    {
      let output = try await base.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: maximumOutputTokens)
      outputs.append(output)
      return output
    }
    func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws {
      try await base.generate(turns: turns, onText: onText)
    }
    func unload() async { await base.unload() }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_OWNERSHIP_REGRESSION"] == "1"))
  func firstPersonOwnershipAndSharedNameAmbiguity() async throws {
    let model = TraceModel(base: LocalInferenceCoordinator(model: try RuntimeTestModel.makeModel()))
    let filter = SourceBoundedChatEvidenceFilter(model: model, unloadAfterSelection: false)
    let original = [
      ChatEvidence(id: UUID(), text: "I put my spare apartment key in the blue kitchen tin."),
      .init(
        id: UUID(),
        text:
          "Update: I moved my spare apartment key out of the blue kitchen tin and into the zipped pocket of my green backpack."
      ),
      .init(id: UUID(), text: "Rhea keeps her spare apartment key under a ceramic plant pot."),
    ]
    var results: [[String: Any]] = []
    let outputPath = ProcessInfo.processInfo.environment["MEMORYOS_OWNERSHIP_RESULTS"]
    func record(_ row: [String: Any]) throws {
      results.append(row)
      if let outputPath {
        try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
          .write(to: URL(fileURLWithPath: outputPath), options: .atomic)
      }
    }
    let before = await model.outputs.count
    let expected = Set(original.prefix(2).map(\.id))
    var selected = Set<UUID>()
    var ownerError: String?
    do {
      selected = try await filter.selectRelevant(
        query: "Where is my spare apartment key now?", candidates: original)
    } catch {
      ownerError = String(describing: error)
    }
    var ownerRow: [String: Any] = [
      "case": "consumed-self-key", "passed": selected == expected,
      "outputs": Array(await model.outputs.dropFirst(before)),
      "actual": selected.map(\.uuidString), "expected": expected.map(\.uuidString),
    ]
    ownerRow["error"] = ownerError
    try record(ownerRow)
    #expect(selected == expected, "The other person's key cannot answer where my key is.")

    let hasan = [
      ChatEvidence(id: UUID(), text: "حسن من فريق المحاسبة يخلص شغله الساعة أربعة العصر."),
      .init(id: UUID(), text: "ابن خالتي حسن يخلص شغله الساعة عشرة بالليل."),
    ]
    let names = [
      ChatEvidenceIdentity(names: ["حسن المحاسب", "حسن"], documentIDs: [hasan[0].id]),
      .init(names: ["حسن ابن الخالة", "حسن"], documentIDs: [hasan[1].id]),
    ]
    let ambiguityStart = await model.outputs.count
    var ambiguous = false
    var ambiguityError: String?
    do {
      _ = try await filter.selectRelevant(
        query: "حسن شوقت يخلص شغله؟", candidates: hasan, identities: names)
    } catch ChatError.memorySubjectUnclear {
      ambiguous = true
    } catch {
      ambiguityError = String(describing: error)
    }
    var ambiguityRow: [String: Any] = [
      "case": "consumed-shared-hasan", "passed": ambiguous,
      "outputs": Array(await model.outputs.dropFirst(ambiguityStart)),
    ]
    ambiguityRow["error"] = ambiguityError
    try record(ambiguityRow)
    #expect(ambiguous, "A shared Hasan name requires identity clarification.")
    await model.unload()
  }
}
