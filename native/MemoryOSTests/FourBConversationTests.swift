import ChatCore
import Foundation
import Testing

@testable import MemoryOS

// Fictional, bounded conversation checks. Model inference is sequential within this suite.
@Suite(.serialized) @MainActor struct FourBConversationTests {
  @Test func selectedModelUnderstandsInstructionsFollowupsAndArabicNegation() async throws {
    let model = ChatComposition.makeModel()
    let scenarios: [(String, [ChatTurn], String)] = [
      (
        "instruction",
        [
          .init(
            role: .system, text: "Follow the user's instructions. Give only the requested answer."),
          .init(
            role: .user, text: "The label is LANTERN. Reply with only that label in lowercase."),
        ], "lantern"
      ),
      (
        "followup",
        [
          .init(
            role: .system, text: "Answer using this conversation. Give only the requested answer."),
          .init(role: .user, text: "Suggest a way to keep track of my weekly tasks."),
          .init(
            role: .assistant, text: "I suggest a paper planner because you prefer handwriting."),
          .init(role: .user, text: "Why did you suggest that? Answer in a short phrase."),
        ], "handwriting"
      ),
      (
        "iraqi-negation",
        [
          .init(role: .system, text: "أجب بالعربية من النص فقط وباختصار."),
          .init(role: .user, text: "حيدر ما يروح للجامعة بالباص، يروح مشي. شلون يروح للجامعة؟"),
        ], "مشي"
      ),
      (
        "current-correction",
        [
          .init(
            role: .system,
            text: "Answer using the latest stated information. Give only the requested day."),
          .init(role: .user, text: "Our fictional review used to be Monday. It is now Thursday."),
          .init(role: .assistant, text: "The review is now Thursday."),
          .init(role: .user, text: "Which day is the review now?"),
        ], "thursday"
      ),
    ]
    var passed = 0
    for (id, turns, expected) in scenarios {
      let result = FourBResponseCapture()
      let started = Date()
      do {
        try await model.generate(turns: turns) { result.replace($0) }
        let raw = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = raw.lowercased()
        let matched: Bool
        switch id {
        case "instruction": matched = raw == expected
        case "iraqi-negation":
          matched = ["مشي", "ماشي", "الأقدام", "الاقدام"].contains { text.contains($0) }
        default: matched = text.contains(expected)
        }
        #expect(matched, "Conversation meaning check failed: \(id)")
        if matched { passed += 1 }
        print(
          "MEMORYOS_FOURB_CASE id=\(id) matched=\(matched) seconds=\(Date().timeIntervalSince(started))"
        )
      } catch {
        await model.unload()
        throw error
      }
    }
    await model.unload()
    #expect(passed == scenarios.count)
    print("MEMORYOS_FOURB_SUMMARY cases=\(scenarios.count) passed=\(passed)")
  }
}

// The runtime callback is synchronous and may run outside the main actor.
private final class FourBResponseCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var value = ""
  func replace(_ text: String) { lock.withLock { value = text } }
  var text: String { lock.withLock { value } }
}
