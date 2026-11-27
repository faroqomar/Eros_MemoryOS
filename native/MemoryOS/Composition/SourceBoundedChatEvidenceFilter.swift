import ChatCore
import Foundation
import RetrievalCore

/// Uses the same subject and topic checks as memory search on an already ranked batch.
/// It neither changes passages nor infers aliases or participant identity.
struct SourceBoundedChatEvidenceFilter: SubjectAwareMemoryEvidenceFiltering {
  let model: any StructuredChatModel
  var unloadAfterSelection = true
  /// Experimental; ordinary app composition leaves this disabled until independent qualification.
  var useKnownIdentityHints = false

  func selectRelevant(query: String, candidates: [ChatEvidence]) async throws -> Set<UUID> {
    try await selectRelevant(query: query, candidates: candidates, identities: [])
  }

  func selectRelevant(
    query: String, candidates: [ChatEvidence], identities: [ChatEvidenceIdentity]
  ) async throws -> Set<UUID> {
    try Task.checkCancellation()
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      query.utf8.count <= 4_096, candidates.count <= 8,
      Set(candidates.map(\.id)).count == candidates.count,
      candidates.allSatisfy({ !$0.text.isEmpty && $0.text.utf8.count <= 1_600 }),
      identities.count <= 2_000,
      identities.allSatisfy({
        !$0.names.isEmpty && $0.names.count <= 101 && $0.documentIDs.count <= 30_000
          && $0.names.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 240
          }
      })
    else { throw ChatError.messageTooLong }
    guard !candidates.isEmpty else { return [] }
    let records = candidates.map { MemorySearchRecord(id: $0.id.uuidString, text: $0.text) }
    let search = LocalMeaningSearch(
      candidates: OfferedEvidence(), model: model, unloadAfterSearch: unloadAfterSelection,
      useKnownIdentityHints: useKnownIdentityHints)
    let offeredIDs = Set(candidates.map(\.id))
    let aliases = identities.map {
      MemorySearchIdentity(
        names: $0.names,
        documentIDs: Set($0.documentIDs.intersection(offeredIDs).map(\.uuidString)),
        canGroundQuery: $0.canGroundQuery)
    }
    let hits: [MemorySearchHit]
    do {
      hits = try await search.search(
        query: query, records: records, limit: candidates.count, identityAliases: aliases)
    } catch MemorySearchFailure.ambiguousSubject {
      throw ChatError.memorySubjectUnclear
    }
    try Task.checkCancellation()
    let offered = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id.uuidString, $0) })
    var selected = Set<UUID>()
    for hit in hits {
      guard let original = offered[hit.sourceID], let passage = hit.matchedText,
        Data(passage.utf8) == Data(original.text.utf8), selected.insert(original.id).inserted
      else { throw ChatError.generationFailed }
    }
    return selected
  }

  private struct OfferedEvidence: MemorySearching {
    func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
      records.map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
    }
  }
}
