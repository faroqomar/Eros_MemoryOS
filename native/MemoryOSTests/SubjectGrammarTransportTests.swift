import ChatCore
import Foundation
import RetrievalCore
import Testing

@testable import MemoryOS

private actor SubjectGrammarCandidates: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.map { .init(sourceID: $0.id, score: 1) }
  }
}

private actor SubjectGrammarCaptureModel: StructuredChatModel {
  private(set) var captured: (grammar: String, turns: [ChatTurn])?
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    if grammar.contains("\nsubject ::=") {
      captured = (grammar, turns)
      return #"{"assessment":"Controlled transport probe.","subjects":[]}"#
    }
    if grammar.contains("resolution") {
      return #"{"assessment":"Controlled transport probe.","resolution":"generic"}"#
    }
    return #"{"relevant":true}"#
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {}
  func unload() {}
}

/// Captures the actual production grammar without selecting a semantic answer.
/// The opt-in native contract feeds this unchanged grammar to the real parser.
enum SubjectGrammarTransportFixture {
  static func capture(query: String) async throws -> (grammar: String, turns: [ChatTurn]) {
    let model = SubjectGrammarCaptureModel()
    let record = MemorySearchRecord(id: "transport-source", text: "Fictional transport evidence.")
    let search = LocalMeaningSearch(candidates: SubjectGrammarCandidates(), model: model)
    let result = try await search.search(query: query, records: [record], limit: 1)
    #expect(result.map(\.sourceID) == [record.id])
    return try #require(await model.captured)
  }

  enum LiteralError: Error { case invalidTerminal }

  /// Decode the string-terminal subset emitted by the production JSON encoder.
  /// Unlike JSONDecoder alone, reject a GBNF-invalid escape such as backslash-slash.
  static func subjects(in grammar: String) throws -> [String] {
    let rule = try #require(grammar.components(separatedBy: "\nsubject ::= ").last)
    let scalars = Array(rule.unicodeScalars)
    var offset = 0
    var subjects: [String] = []
    while offset < scalars.count {
      let start = offset
      guard scalars[offset] == "\"" else { throw LiteralError.invalidTerminal }
      offset += 1
      var closed = false
      while offset < scalars.count {
        if scalars[offset] == "\\" {
          offset += 1
          guard offset < scalars.count,
            ["\"", "\\", "n", "r", "t", "u"].contains(String(scalars[offset]))
          else { throw LiteralError.invalidTerminal }
          offset += 1
        } else if scalars[offset] == "\"" {
          offset += 1
          closed = true
          break
        } else {
          offset += 1
        }
      }
      guard closed else { throw LiteralError.invalidTerminal }
      let terminal = String(String.UnicodeScalarView(scalars[start..<offset]))
      let json = try JSONDecoder().decode(String.self, from: Data(terminal.utf8))
      subjects.append(try JSONDecoder().decode(String.self, from: Data(json.utf8)))
      if offset < scalars.count {
        guard offset + 3 <= scalars.count,
          String(String.UnicodeScalarView(scalars[offset..<(offset + 3)])) == " | "
        else { throw LiteralError.invalidTerminal }
        offset += 3
      }
    }
    return subjects
  }
}

struct SubjectGrammarTransportTests {
  @Test(arguments: [
    "2023/12/21", "Aurora\"Boreal", #"folder\notes"#, "نادية/سلمى",
    #"folder\/notes"#, "Cafe\u{0301}/نور", "Aurora\" | root ::= \"Boreal",
  ])
  func literalChoicesRoundTripWithoutChangingQueryBytes(span: String) async throws {
    let query = "Find \(span) today."
    let captured = try await SubjectGrammarTransportFixture.capture(query: query)
    let subjects = try SubjectGrammarTransportFixture.subjects(in: captured.grammar)
    #expect(subjects.contains { Data($0.utf8) == Data(span.utf8) })
    #expect(subjects.allSatisfy { Data(query.utf8).range(of: Data($0.utf8)) != nil })
    let text = try #require(captured.turns.last?.text)
    let input = try JSONDecoder().decode([String: String].self, from: Data(text.utf8))
    #expect(Set(input.keys) == ["query"])
    #expect(input["query"].map { Data($0.utf8) } == Data(query.utf8))
  }
}
