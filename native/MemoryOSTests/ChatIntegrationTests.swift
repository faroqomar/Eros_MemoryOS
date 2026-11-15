import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

struct ChatIntegrationTests {
  @Test func latestTopicWinsOverCompetingEarlierRecords() {
    let aliRecords = (0..<4).map { _ in
      LocalRecord(
        kind: .capture,
        originalText: "Ali Baghdad birthday", text: "Ali Baghdad birthday")
    }
    let zain = LocalRecord(
      kind: .person, originalText: "Zain lives in Basra", text: "Zain lives in Basra")
    let result = LocalChatMemory.match(
      query: "What do you remember about Zain?", records: aliRecords + [zain],
      previousQuestions: ["Ali Baghdad birthday"])
    #expect(result.map(\.id) == [zain.id])
    #expect(
      LocalChatMemory.match(
        query: "What else about him?", records: aliRecords + [zain],
        previousQuestions: ["What about Zain?"]
      ).map(\.id) == [zain.id])
    #expect(
      LocalChatMemory.match(
        query: "What else?", records: aliRecords + [zain],
        previousQuestions: ["What about Zain?", "What else?", "What else about him?"]
      ).map(\.id) == [zain.id])
    #expect(
      LocalChatMemory.match(
        query: "What about Noor?", records: aliRecords + [zain],
        previousQuestions: ["What about Zain?"]
      ).isEmpty)
  }
  @Test func retrievalUsesCorrectionsAndExcludesTrash() {
    let ali = UUID()
    let deleted = UUID()
    let records = [
      LocalRecord(
        id: ali, kind: .capture, originalText: "Ali meeting Friday", text: "Ali meeting Monday"),
      LocalRecord(
        id: deleted, kind: .capture, originalText: "Ali secret", text: "Ali secret",
        deletedAt: Date()),
    ]
    let evidence = LocalChatMemory.match(query: "What about Ali?", records: records)
    #expect(evidence.map(\.id) == [ali])
    #expect(evidence.map(\.text) == ["Ali meeting Monday"])
    #expect(LocalChatMemory.match(query: "missing person", records: records).isEmpty)
  }

  @Test func arabicAndMixedNameRetrieval() {
    let record = LocalRecord(
      kind: .capture, originalText: "موعد علي في Baghdad يوم الاثنين",
      text: "موعد علي في Baghdad يوم الاثنين")
    #expect(
      LocalChatMemory.match(query: "شنو موعد علي؟", records: [record]).map(\.id) == [record.id])
    #expect(LocalChatMemory.match(query: "BAGHDAD", records: [record]).map(\.id) == [record.id])
  }

  @Test func renderBlocksPreserveParagraphsListsAndCode() {
    let result = ChatFormatting.blocks(
      "First **bold** paragraph.\n\n- One\n2. Two\n\n```swift\nlet name = \"علي\"\n```\n\nLast.")
    #expect(result.count == 5)
    #expect(result[0].text == "First **bold** paragraph.")
    #expect(result[1].kind == .list("•"))
    #expect(result[2].kind == .list("2."))
    #expect(result[3].kind == .code("swift"))
    #expect(result[3].text == "let name = \"علي\"")
    #expect(result[4].text == "Last.")
    #expect(
      String(ChatFormatting.inline("**bold** and *emphasis*").characters) == "bold and emphasis")
  }

  @Test func unfinishedFenceRemainsReadableWhileStreaming() {
    let result = ChatFormatting.blocks("```\nprint(\"hello\")")
    #expect(result.count == 1)
    #expect(result.first?.kind == .code(""))
    #expect(result.first?.text == "print(\"hello\")")
  }
}
