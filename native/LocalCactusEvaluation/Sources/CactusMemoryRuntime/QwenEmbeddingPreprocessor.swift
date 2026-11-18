import Foundation

/// The pinned model's tokenizer pipeline around Cactus's native byte-level BPE.
/// This transforms only inference inputs, never canonical source text.
struct QwenEmbeddingPreprocessor {
  enum Failure: Error { case unsupportedTokenizer, invalidInput, invalidTokens }
  enum Piece: Equatable {
    case text(String)
    case token(UInt32)
  }

  private struct Kind: Decodable { let type: String }
  private struct AddedToken: Decodable {
    let id: UInt32
    let content: String
    let singleWord: Bool
    let lstrip: Bool
    let rstrip: Bool
    let normalized: Bool
    enum CodingKeys: String, CodingKey {
      case id, content, lstrip, rstrip, normalized
      case singleWord = "single_word"
    }
  }
  private struct Step: Decodable {
    let type: String
    let pattern: [String: String]?
    let behavior: String?
    let invert: Bool?
    let addPrefixSpace: Bool?
    let useRegex: Bool?
    enum CodingKeys: String, CodingKey {
      case type, pattern, behavior, invert
      case addPrefixSpace = "add_prefix_space"
      case useRegex = "use_regex"
    }
  }
  private struct PreTokenizer: Decodable {
    let type: String
    let pretokenizers: [Step]
  }
  private struct TemplatePart: Decodable {
    struct Value: Decodable {
      let id: String
      let typeID: Int
      enum CodingKeys: String, CodingKey {
        case id
        case typeID = "type_id"
      }
    }
    let sequence: Value?
    let specialToken: Value?
    enum CodingKeys: String, CodingKey {
      case sequence = "Sequence"
      case specialToken = "SpecialToken"
    }
  }
  private struct PostStep: Decodable {
    struct Token: Decodable {
      let id: String
      let ids: [UInt32]
      let tokens: [String]
    }
    let type: String
    let addPrefixSpace: Bool?
    let useRegex: Bool?
    let single: [TemplatePart]?
    let specialTokens: [String: Token]?
    enum CodingKeys: String, CodingKey {
      case type, single
      case addPrefixSpace = "add_prefix_space"
      case useRegex = "use_regex"
      case specialTokens = "special_tokens"
    }
  }
  private struct PostProcessor: Decodable {
    let type: String
    let processors: [PostStep]
  }
  private struct Configuration: Decodable {
    let normalizer: Kind
    let addedTokens: [AddedToken]
    let preTokenizer: PreTokenizer
    let postProcessor: PostProcessor
    enum CodingKeys: String, CodingKey {
      case normalizer
      case addedTokens = "added_tokens"
      case preTokenizer = "pre_tokenizer"
      case postProcessor = "post_processor"
    }
  }

  private let split: NSRegularExpression
  private let addedTokens: [AddedToken]
  let endToken: UInt32
  static let maximumTokens = 32768
  static let vocabularySize: UInt32 = 151669

  init(tokenizerData: Data) throws {
    let configuration = try JSONDecoder().decode(Configuration.self, from: tokenizerData)
    let pre = configuration.preTokenizer
    let post = configuration.postProcessor
    guard configuration.normalizer.type == "NFC", pre.type == "Sequence",
      pre.pretokenizers.count == 2, pre.pretokenizers[0].type == "Split",
      pre.pretokenizers[0].behavior == "Isolated", pre.pretokenizers[0].invert == false,
      let pattern = pre.pretokenizers[0].pattern?["Regex"], !pattern.isEmpty,
      pre.pretokenizers[1].type == "ByteLevel",
      pre.pretokenizers[1].addPrefixSpace == false, pre.pretokenizers[1].useRegex == false,
      post.type == "Sequence", post.processors.count == 2,
      post.processors[0].type == "ByteLevel", post.processors[0].addPrefixSpace == false,
      post.processors[0].useRegex == false, post.processors[1].type == "TemplateProcessing",
      let template = post.processors[1].single, template.count == 2,
      template[0].sequence?.id == "A", template[0].sequence?.typeID == 0,
      template[0].specialToken == nil, template[1].sequence == nil,
      let end = template[1].specialToken, end.typeID == 0,
      let endDefinition = post.processors[1].specialTokens?[end.id],
      endDefinition.id == end.id, endDefinition.tokens == [end.id],
      endDefinition.ids == [151643], !configuration.addedTokens.isEmpty,
      configuration.addedTokens.count <= 256
    else { throw Failure.unsupportedTokenizer }
    var ids = Set<UInt32>()
    var contents = Set<Data>()
    guard
      configuration.addedTokens.allSatisfy({ token in
        !token.content.isEmpty && !token.content.utf8.contains(0)
          && token.content.utf8.count <= 256 && token.id < Self.vocabularySize
          && !token.singleWord && !token.lstrip && !token.rstrip && !token.normalized
          && ids.insert(token.id).inserted && contents.insert(Data(token.content.utf8)).inserted
      }), configuration.addedTokens.contains(where: { $0.content == end.id && $0.id == 151643 })
    else { throw Failure.unsupportedTokenizer }
    split = try NSRegularExpression(pattern: pattern)
    addedTokens = configuration.addedTokens
    endToken = 151643
  }

  /// Added tokens match the original input first; NFC applies only between them.
  func pieces(in text: String) throws -> [Piece] {
    guard text.utf8.count <= 131072, !text.utf8.contains(0) else { throw Failure.invalidInput }
    let original = text as NSString
    var result: [Piece] = []
    var offset = 0
    while offset < original.length {
      var next: (range: NSRange, id: UInt32)?
      for token in addedTokens {
        let range = original.range(
          of: token.content, options: .literal,
          range: NSRange(location: offset, length: original.length - offset))
        guard range.location != NSNotFound else { continue }
        if next == nil || range.location < next!.range.location
          || (range.location == next!.range.location && range.length > next!.range.length)
        {
          next = (range, token.id)
        }
      }
      let end = next?.range.location ?? original.length
      if end > offset {
        let normalized = original.substring(with: NSRange(location: offset, length: end - offset))
          .precomposedStringWithCanonicalMapping
        let normalizedNSString = normalized as NSString
        let matches = split.matches(
          in: normalized, range: NSRange(location: 0, length: normalizedNSString.length))
        var consumed = 0
        for match in matches {
          guard match.range.location == consumed, match.range.length > 0 else {
            throw Failure.unsupportedTokenizer
          }
          result.append(.text(normalizedNSString.substring(with: match.range)))
          consumed = NSMaxRange(match.range)
        }
        guard consumed == normalizedNSString.length else { throw Failure.unsupportedTokenizer }
      }
      if let next {
        result.append(.token(next.id))
        offset = NSMaxRange(next.range)
      } else {
        offset = original.length
      }
    }
    return result
  }

  func tokenIDs(for text: String, tokenize: (String) throws -> [UInt32]) throws -> [UInt32] {
    var result: [UInt32] = []
    for piece in try pieces(in: text) {
      let tokens: [UInt32]
      switch piece {
      case .text(let value): tokens = try tokenize(value)
      case .token(let id): tokens = [id]
      }
      guard !tokens.isEmpty, tokens.allSatisfy({ $0 < Self.vocabularySize }),
        result.count + tokens.count < Self.maximumTokens
      else { throw Failure.invalidTokens }
      result.append(contentsOf: tokens)
    }
    // TemplateProcessing appends EOS even when the input already ends in EOS.
    result.append(endToken)
    return result
  }
}
