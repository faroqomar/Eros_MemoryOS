import Foundation

/// Lightweight block rendering; input remains verbatim for copy and persistence.
enum ChatFormatting {
  struct Block: Identifiable, Equatable {
    enum Kind: Equatable {
      case paragraph, heading
      case list(String)
      case code(String)
    }
    let id: Int
    let kind: Kind
    let text: String
  }

  static func blocks(_ text: String) -> [Block] {
    var result: [Block] = []
    var paragraph: [String] = []
    var code: [String]? = nil
    var language = ""
    func append(_ kind: Block.Kind, _ value: String) {
      result.append(Block(id: result.count, kind: kind, text: value))
    }
    func flush() {
      if !paragraph.isEmpty {
        append(.paragraph, paragraph.joined(separator: "\n"))
        paragraph = []
      }
    }
    for line in text.components(separatedBy: "\n") {
      if line.hasPrefix("```") {
        flush()
        if let lines = code {
          append(.code(language), lines.joined(separator: "\n"))
          code = nil
        } else {
          language = String(line.dropFirst(3))
          code = []
        }
      } else if code != nil {
        code?.append(line)
      } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
        flush()
      } else if line.hasPrefix("#") {
        flush()
        append(.heading, line.drop(while: { $0 == "#" || $0 == " " }).description)
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
        flush()
        append(.list("•"), String(line.dropFirst(2)))
      } else if let dot = line.firstIndex(of: "."),
        !line[..<dot].isEmpty, line[..<dot].allSatisfy(\.isNumber),
        line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " "
      {
        flush()
        append(
          .list(String(line[...dot])),
          String(line.dropFirst(line.distance(from: line.startIndex, to: dot) + 2)))
      } else {
        paragraph.append(line)
      }
    }
    flush()
    if let code { append(.code(language), code.joined(separator: "\n")) }
    return result
  }

  static func inline(_ text: String) -> AttributedString {
    var result =
      (try? AttributedString(
        markdown: text,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
    // Generated links are text. Only app-owned source controls open records.
    result.link = nil
    return result
  }
}
