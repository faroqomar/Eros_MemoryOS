import Foundation
import TranscriptionSupport
import WhisperKit

/// Bridges the SDK's public local tokenizer to its Whisper protocol. Tokenization
/// itself stays in ArgmaxCore; this adapter provides token roles and word grouping.
struct LocalWhisperTokenizer: WhisperTokenizer {
  let base: TokenizerWrapper
  let specialTokens: SpecialTokens
  let allLanguageTokens: Set<Int>

  init(base: TokenizerWrapper) throws {
    self.base = base
    func required(_ name: String) throws -> Int {
      guard let value = base.convertTokenToId(name) else {
        throw LocalTranscriptionError.invalidModel
      }
      return value
    }
    guard let whitespace = base.encode(text: " ", addSpecialTokens: false).first else {
      throw LocalTranscriptionError.invalidModel
    }
    specialTokens = try SpecialTokens(
      endToken: required("<|endoftext|>"), englishToken: required("<|en|>"),
      noSpeechToken: required("<|nocaptions|>"), noTimestampsToken: required("<|notimestamps|>"),
      specialTokenBegin: required("<|endoftext|>"),
      startOfPreviousToken: required("<|startofprev|>"),
      startOfTranscriptToken: required("<|startoftranscript|>"),
      timeTokenBegin: required("<|0.00|>"),
      transcribeToken: required("<|transcribe|>"), translateToken: required("<|translate|>"),
      whitespaceToken: whitespace)
    let expression = try NSRegularExpression(pattern: "^<\\|[a-z]{2,3}\\|>$")
    allLanguageTokens = Set(
      (specialTokens.specialTokenBegin..<specialTokens.timeTokenBegin).filter {
        guard let token = base.convertIdToToken($0) else { return false }
        return expression.firstMatch(in: token, range: NSRange(token.startIndex..., in: token))
          != nil
      })
    guard allLanguageTokens.contains(specialTokens.englishToken),
      let arabic = base.convertTokenToId("<|ar|>"), allLanguageTokens.contains(arabic)
    else { throw LocalTranscriptionError.invalidModel }
  }

  func encode(text: String) -> [Int] { base.encode(text: text) }
  func decode(tokens: [Int]) -> String { base.decode(tokens: tokens) }
  func convertTokenToId(_ token: String) -> Int? { base.convertTokenToId(token) }
  func convertIdToToken(_ id: Int) -> String? { base.convertIdToToken(id) }

  func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
    var groups: [[Int]] = []
    var pending: [Int] = []
    for token in tokenIds {
      if token >= specialTokens.specialTokenBegin {
        if !pending.isEmpty {
          groups.append(pending)
          pending = []
        }
        groups.append([token])
      } else {
        let piece = base.decode(tokens: [token])
        if piece.first?.isWhitespace == true, !pending.isEmpty {
          groups.append(pending)
          pending = []
        }
        pending.append(token)
      }
    }
    if !pending.isEmpty { groups.append(pending) }
    return (groups.map { base.decode(tokens: $0) }, groups)
  }
}
