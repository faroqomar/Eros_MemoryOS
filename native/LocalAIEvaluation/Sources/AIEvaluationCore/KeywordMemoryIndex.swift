import Foundation

/// Deterministic lexical control. This is not Wax, Cactus, semantic retrieval, or an AI model.
public actor KeywordMemoryIndex: MemoryIndexAdapter {
  private var indexed: [(record: SourceRecord, terms: Set<String>)] = []

  public init() {}

  public func rebuild(records: [SourceRecord]) async throws {
    try Task.checkCancellation()
    guard Set(records.map(\.id)).count == records.count,
      records.allSatisfy({ !$0.id.isEmpty })
    else { throw EvaluationError.invalidSuite("Source IDs must be nonempty and unique.") }
    var replacement: [(record: SourceRecord, terms: Set<String>)] = []
    for record in records {
      try Task.checkCancellation()
      replacement.append((record, Self.terms(record.text)))
    }
    indexed = replacement
  }

  public func search(query: String, limit: Int) async throws -> [RetrievedSource] {
    try Task.checkCancellation()
    guard limit > 0 else { throw EvaluationError.invalidResult("Search limit must be positive.") }
    let queryTerms = Self.terms(query)
    guard !queryTerms.isEmpty else { return [] }
    return indexed.compactMap { item -> (String, Int)? in
      let overlap = queryTerms.intersection(item.terms).count
      return overlap > 0 ? (item.record.id, overlap) : nil
    }
    .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 > rhs.1 }
    .prefix(limit)
    .map { RetrievedSource(sourceID: $0.0, score: Double($0.1)) }
  }

  private static func terms(_ text: String) -> Set<String> {
    let stopWords: Set<String> = [
      "a", "an", "the", "is", "are", "was", "were", "what", "when", "who", "where", "how",
      "of", "to", "in", "on", "and", "or", "does", "do", "did", "it", "its", "s", "for",
      "my", "your", "i", "from", "with", "be", "as", "this", "that", "at", "by", "no",
      "ما", "هو", "هي", "من", "في", "على", "متى", "هل", "و", "او", "شنو", "لو", "ال",
    ]
    let folded = text.folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    return Set(folded.components(separatedBy: CharacterSet.alphanumerics.inverted))
      .filter { !$0.isEmpty && !stopWords.contains($0) }
  }
}
