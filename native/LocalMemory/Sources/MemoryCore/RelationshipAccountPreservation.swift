import Foundation

extension PersonalMemoryUseCases {
  /// Explicitly keeping a report preserves the user's account independently of rebuildable AI text.
  public func preserveRelationshipAccount(
    sourceIDs: [UUID], account: String, expectedRevision: UInt64
  ) async throws -> PersonalMemorySnapshot {
    try PersonalMemoryLimits.text(account, maximum: 4_000)
    let selected = Set(sourceIDs)
    guard !selected.isEmpty, selected.count == sourceIDs.count, selected.count <= 40 else {
      throw RelationshipUnderstandingError.invalidRequest
    }
    return try await edit("Preserved owner interpretation and original links") { next in
      guard next.revision == expectedRevision else {
        throw RelationshipUnderstandingError.staleResult
      }
      guard selected.isSubset(of: Set(next.sources.map(\.id))) else {
        throw RelationshipUnderstandingError.missingSource
      }
      let label = "Owner interpretation of original"
      for entry in next.currentEntries
      where entry.kind == .interpretation
        && entry.interpretationStatus == .ownerReviewed
        && entry.text.utf8.elementsEqual(account.utf8)
      {
        let originals = next.sources.filter {
          entry.sourceIDs.contains($0.id) && $0.origin == "relationship account"
            && $0.text.utf8.elementsEqual(account.utf8)
        }
        let linked = Set(
          next.links.filter { $0.fromID == entry.id && $0.label == label }.map(\.toID))
        if !originals.isEmpty && linked == selected { return }
      }
      let source = PersonalMemorySource(
        text: account, origin: "relationship account", kind: .interpretation)
      next.sources.append(source)
      let entry = PersonalMemoryEntry(
        id: UUID(), text: account, kind: .interpretation, sourceIDs: [source.id], profileIDs: [],
        categories: ["interpretation"], confirmed: false,
        interpretationProvenance: .ownerReviewed, createdAt: Date())
      next.entries.append(entry)
      for sourceID in sourceIDs {
        next.links.append(
          PersonalMemoryLink(id: UUID(), fromID: entry.id, toID: sourceID, label: label))
      }
    }
  }
}
