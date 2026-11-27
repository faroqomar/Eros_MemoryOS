import ChatCore
import Foundation
import MemoryCore
import RetrievalCore

/// Indexes rank IDs. Only a fresh app-owned snapshot supplies answer evidence.
struct LocalChatMemory: ChatMemoryRetrieving {
  let readSnapshot: @Sendable () async throws -> RecallSnapshot
  let search: any MemorySearching
  let relevance: (any MemoryEvidenceFiltering)?

  init(
    provider: any LocalMemorySessionProvider, personalMemory: PersonalMemoryUseCases?,
    search: any MemorySearching, relevance: (any MemoryEvidenceFiltering)? = nil
  ) {
    self.search = search
    self.relevance = relevance
    readSnapshot = {
      let session = try await provider.open()
      let records = try await session.useCases.snapshot().records
      let personal = try await personalMemory?.snapshot()
      return Self.makeSnapshot(local: records, personal: personal)
    }
  }

  init(
    search: any MemorySearching, relevance: (any MemoryEvidenceFiltering)? = nil,
    readRecords: @escaping @Sendable () async throws -> [MemorySearchRecord]
  ) {
    self.init(search: search, relevance: relevance) {
      RecallSnapshot(records: try await readRecords())
    }
  }

  init(
    search: any MemorySearching, relevance: (any MemoryEvidenceFiltering)? = nil,
    readSnapshot: @escaping @Sendable () async throws -> RecallSnapshot
  ) {
    self.search = search
    self.relevance = relevance
    self.readSnapshot = readSnapshot
  }

  func retrieve(query: String) async throws -> [ChatEvidence] {
    try await retrieve(query: query, previousQuestions: [], excluding: [])
  }

  func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence] {
    try await retrieve(query: query, previousQuestions: previousQuestions, excluding: [])
  }

  func retrieve(query: String, previousQuestions: [String], excluding: Set<UUID>) async throws
    -> [ChatEvidence]
  {
    let excluded = Set(excluding.map(\.uuidString))
    let originalSnapshot = try await readSnapshot()
    let records = originalSnapshot.records.filter { !excluded.contains($0.id) }
    let resolvedQuery = Self.boundedQuery(
      Self.resolvedQuery(query, previousQuestions: previousQuestions))
    guard !resolvedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
    let limit = relevance == nil ? 3 : 8
    var hits = try await search.search(query: resolvedQuery, records: records, limit: limit)
    try Task.checkCancellation()
    let before = Dictionary(
      records.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
    if let relevance {
      guard hits.count <= limit else {
        throw RetrievalError.invalidResult("Too many recall candidates.")
      }
      var seen: Set<UUID> = []
      let candidates = hits.compactMap { hit -> ChatEvidence? in
        guard let id = UUID(uuidString: hit.sourceID), hit.score.isFinite,
          let text = before[hit.sourceID], !excluding.contains(id), seen.insert(id).inserted
        else { return nil }
        let passage = hit.matchedText ?? text
        guard !passage.isEmpty, let matchedRange = text.range(of: passage, options: .literal) else {
          return nil
        }
        let raw: String
        if let original = originalSnapshot.sourceTexts[hit.sourceID],
          let sourceRange = text.range(of: original, options: .literal)
        {
          // Provider labels are not statements by the author. Verify only the matching source text.
          let lower = max(matchedRange.lowerBound, sourceRange.lowerBound)
          let upper = min(matchedRange.upperBound, sourceRange.upperBound)
          guard lower < upper else { return nil }
          raw = String(text[lower..<upper])
        } else {
          raw = passage
        }
        return ChatEvidence(id: id, text: Self.excerpt(raw))
      }
      let selected: Set<UUID>
      if let subjectAware = relevance as? any SubjectAwareMemoryEvidenceFiltering {
        selected = try await subjectAware.selectRelevant(
          query: resolvedQuery, candidates: candidates, identities: originalSnapshot.identities)
      } else {
        selected = try await relevance.selectRelevant(query: resolvedQuery, candidates: candidates)
      }
      guard selected.isSubset(of: Set(candidates.map(\.id))) else {
        throw RetrievalError.invalidResult("Relevance returned an unknown source.")
      }
      hits = hits.filter { UUID(uuidString: $0.sourceID).map(selected.contains) ?? false }
    }
    try Task.checkCancellation()
    // Search and model verification both suspend. Neither may return a deleted or changed source.
    let current = try await readSnapshot()
    guard originalSnapshot.identities == current.identities else {
      throw RetrievalError.invalidResult(
        "Profile identity or source associations changed during recall.")
    }
    let after = Dictionary(
      current.records.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
    var seen: Set<UUID> = []
    var evidence: [ChatEvidence] = []
    for hit in hits {
      guard let text = before[hit.sourceID], let fresh = after[hit.sourceID],
        text.utf8.elementsEqual(fresh.utf8), hit.score.isFinite
      else { continue }
      let passage = hit.matchedText ?? text
      guard !passage.isEmpty, text.range(of: passage, options: .literal) != nil else { continue }
      // Put the current correction next to an older matching statement, even when its wording changed.
      for relatedID in current.replacements[hit.sourceID] ?? [] {
        guard let related = after[relatedID], let prior = before[relatedID],
          prior.utf8.elementsEqual(related.utf8), let id = UUID(uuidString: relatedID),
          !excluding.contains(id), seen.insert(id).inserted
        else { continue }
        evidence.append(
          ChatEvidence(
            id: id, text: Self.excerpt(related),
            sourceText: current.sourceTexts[relatedID]))
      }
      guard let id = UUID(uuidString: hit.sourceID), !excluding.contains(id),
        seen.insert(id).inserted
      else { continue }
      let label = text.first == "[" ? String(text.prefix(while: { $0 != "]" })) + "] " : ""
      evidence.append(
        ChatEvidence(
          id: id,
          text: Self.excerpt(passage == text ? text : label + passage),
          sourceText: current.sourceTexts[hit.sourceID]
        ))
    }
    return Array(evidence.prefix(3))
  }

  struct RecallSnapshot: Sendable {
    var records: [MemorySearchRecord]
    var replacements: [String: [String]] = [:]
    var sourceTexts: [String: String] = [:]
    var identities: [ChatEvidenceIdentity] = []
  }

  static func makeSnapshot(local: [LocalRecord], personal: PersonalMemorySnapshot?)
    -> RecallSnapshot
  {
    var replacements: [String: [String]] = [:]
    var sourceTexts = Dictionary(
      local.map { ($0.id.uuidString, $0.text) }, uniquingKeysWith: { first, _ in first })
    let bySource = Self.entriesBySource(personal)
    if let personal {
      for source in personal.sources { sourceTexts[source.id.uuidString] = source.text }
      for entry in personal.entries { sourceTexts[entry.id.uuidString] = entry.text }
      let entries = Dictionary(uniqueKeysWithValues: personal.entries.map { ($0.id, $0) })
      for source in personal.sources {
        var currentIDs: [String] = []
        for entry in bySource[source.id] ?? [] {
          var current = entry
          var visited: Set<UUID> = []
          while let replacementID = current.supersededByID,
            visited.insert(current.id).inserted, let replacement = entries[replacementID]
          {
            current = replacement
          }
          if current.supersededByID == nil
            && (current.id != entry.id || current.isOwnerCorrected == true
              || current.interpretationStatus == .ownerReviewed)
          {
            currentIDs.append(current.id.uuidString)
          }
        }
        replacements[source.id.uuidString] = Array(Set(currentIDs)).sorted()
      }
    }
    let records = records(local: local, personal: personal, bySource: bySource)
    let identities =
      personal.map {
        MemorySearchIdentity.make(
          personal: $0, availableDocumentIDs: Set(records.compactMap { UUID(uuidString: $0.id) })
        ).map {
          ChatEvidenceIdentity(
            names: $0.names, documentIDs: Set($0.documentIDs.compactMap(UUID.init(uuidString:))),
            canGroundQuery: $0.canGroundQuery)
        }
      } ?? []
    return RecallSnapshot(
      records: records, replacements: replacements, sourceTexts: sourceTexts, identities: identities
    )
  }

  static func records(
    local: [LocalRecord], personal: PersonalMemorySnapshot?,
    bySource: [UUID: [PersonalMemoryEntry]]? = nil
  )
    -> [MemorySearchRecord]
  {
    let bySource = bySource ?? Self.entriesBySource(personal)
    var records = local.filter { $0.deletedAt == nil }.map {
      MemorySearchRecord(
        id: $0.id.uuidString,
        text: "[saved record; created \($0.createdAt.ISO8601Format())] \($0.text)")
    }
    if let personal {
      // Partial extraction must not hide the rest of an original conversation.
      records += personal.sources.map { source in
        let meaning = source.kind?.rawValue ?? "meaning unresolved"
        var text =
          "[original statement; \(source.createdAt.ISO8601Format()); \(meaning); not a confirmed fact] \(source.text)"
        let linked = bySource[source.id] ?? []
        if linked.contains(where: { $0.supersededByID != nil || $0.isOwnerCorrected == true }) {
          text =
            "[historical original; \(source.createdAt.ISO8601Format()); \(meaning); later revised; not a current fact] \(source.text)"
        }
        if let context = source.clarificationContext {
          text += "\n[Answer to question: \(Self.prefixBytes(context.question, maximum: 512))]"
        }
        return MemorySearchRecord(id: source.id.uuidString, text: text)
      }
      records += personal.currentEntries.map { entry in
        let names = Self.prefixBytes(
          personal.profiles.filter { entry.profileIDs.contains($0.id) }
            .flatMap { [$0.name] + $0.aliases }.joined(separator: " "), maximum: 240)
        let status: String
        if entry.kind == .interpretation {
          switch entry.interpretationStatus {
          case .ownerReviewed:
            status = "owner-reviewed interpretation; revisable; not an established fact"
          case .aiProposed:
            status = "AI-proposed hypothesis; unconfirmed; not an established fact"
          case nil:
            status = "interpretation; author unknown; unreviewed; not an established fact"
          }
        } else {
          status =
            entry.confirmed || entry.isOwnerCorrected == true
            ? "owner-confirmed" : "user-reported / revisable"
        }
        let text =
          "[\(entry.kind.rawValue); \(status); record created \(entry.createdAt.ISO8601Format())] \(names) \(entry.text)"
        return MemorySearchRecord(id: entry.id.uuidString, text: text)
      }
    }
    var seen: Set<String> = []
    return records.filter { seen.insert($0.id).inserted }
  }

  private static func entriesBySource(_ personal: PersonalMemorySnapshot?) -> [UUID:
    [PersonalMemoryEntry]]
  {
    var result: [UUID: [PersonalMemoryEntry]] = [:]
    for entry in personal?.entries ?? [] {
      for id in entry.sourceIDs { result[id, default: []].append(entry) }
    }
    return result
  }

  /// Resolve short references only. A new explicit subject must own its own lookup.
  static func resolvedQuery(_ query: String, previousQuestions: [String]) -> String {
    func normalized(_ text: String) -> String {
      let folded = text.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      ).decomposedStringWithCanonicalMapping
      // Foundation's folding retains Arabic vowel marks. Normalize only the
      // reference lookup; the returned questions keep their original bytes.
      let unmarked = String(
        String.UnicodeScalarView(
          folded.unicodeScalars.filter { !CharacterSet.nonBaseCharacters.contains($0) }))
      return unmarked.components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: " ")
    }
    let references = Set(
      [
        "what else", "what else about him", "what else about her", "tell me more", "and then",
        "شنو بعد", "وبعدين", "ماذا أيضا", "المزيد",
      ].map(normalized))
    guard references.contains(normalized(query)),
      let prior = previousQuestions.reversed().first(where: {
        !normalized($0).isEmpty && !references.contains(normalized($0))
      })
    else { return query }
    return prior + "\n" + query
  }

  /// Whole-character excerpts keep the chat request bounded; archive originals remain intact.
  static func excerpt(_ text: String) -> String {
    let maximum = 1100
    guard text.utf8.count > maximum else { return text }
    let candidate = "[Partial source excerpt] " + text
    var result = ""
    for character in candidate {
      guard result.utf8.count + String(character).utf8.count <= maximum else { break }
      result.append(character)
    }
    return result
  }

  static func boundedQuery(_ query: String) -> String {
    let query = query.replacingOccurrences(of: "\0", with: " ")
    guard query.utf8.count > 4096 else { return query }
    var head = ""
    var tail = ""
    for scalar in query.unicodeScalars {
      guard head.utf8.count + scalar.utf8.count <= 2000 else { break }
      head.unicodeScalars.append(scalar)
    }
    for scalar in query.unicodeScalars.reversed() {
      guard tail.utf8.count + scalar.utf8.count <= 2000 else { break }
      tail.unicodeScalars.insert(scalar, at: tail.unicodeScalars.startIndex)
    }
    return head + "\n" + tail
  }

  static func prefixBytes(_ text: String, maximum: Int) -> String {
    var result = ""
    for scalar in text.unicodeScalars {
      guard result.utf8.count + scalar.utf8.count <= maximum else { break }
      result.unicodeScalars.append(scalar)
    }
    return result
  }
}
