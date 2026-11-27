import Foundation

/// Selects relevant passages without editing evidence or retaining queries.
public protocol MemoryEvidenceFiltering: Sendable {
  func selectRelevant(query: String, candidates: [ChatEvidence]) async throws -> Set<UUID>
}

/// Explicit app-owned names and record associations, never inferred speaker attribution.
public struct ChatEvidenceIdentity: Equatable, Sendable {
  public let names: [String]
  public let documentIDs: Set<UUID>
  /// Explicit owner confirmation of these names; absent metadata cannot enable query hints.
  public let canGroundQuery: Bool

  public init(names: [String], documentIDs: Set<UUID> = [], canGroundQuery: Bool = false) {
    self.names = names
    self.documentIDs = documentIDs
    self.canGroundQuery = canGroundQuery
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.names.map { Data($0.utf8) } == rhs.names.map { Data($0.utf8) }
      && lhs.documentIDs == rhs.documentIDs
      && lhs.canGroundQuery == rhs.canGroundQuery
  }
}

/// Optional capability; callers keep identity metadata separate from original evidence text.
public protocol SubjectAwareMemoryEvidenceFiltering: MemoryEvidenceFiltering {
  func selectRelevant(
    query: String, candidates: [ChatEvidence], identities: [ChatEvidenceIdentity]
  ) async throws -> Set<UUID>
}
