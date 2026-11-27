import Foundation

/// A metadata-only edit with compare-and-swap values. Originals and claims stay unchanged.
public struct PersonalMemoryOrganizationChange: Codable, Equatable, Sendable {
  public let entryID: UUID
  public let categories: [String]
  public let profileIDs: [UUID]
  public let expectedCategories: [String]
  public let expectedProfileIDs: [UUID]
  public init(
    entryID: UUID, categories: [String], profileIDs: [UUID],
    expectedCategories: [String], expectedProfileIDs: [UUID]
  ) {
    self.entryID = entryID
    self.categories = categories
    self.profileIDs = profileIDs
    self.expectedCategories = expectedCategories
    self.expectedProfileIDs = expectedProfileIDs
  }
  public var reversed: Self {
    Self(
      entryID: entryID, categories: expectedCategories, profileIDs: expectedProfileIDs,
      expectedCategories: categories, expectedProfileIDs: profileIDs)
  }
}

extension PersonalMemoryUseCases {
  public func organizeBatch(_ changes: [PersonalMemoryOrganizationChange], expectedRevision: UInt64)
    async throws -> PersonalMemorySnapshot
  {
    try await edit("Applied explicit organization rule") { next in
      guard next.revision == expectedRevision, Set(changes.map(\.entryID)).count == changes.count
      else {
        throw PersonalMemoryError.staleAnalysis
      }
      for change in changes {
        guard
          let index = next.entries.firstIndex(where: {
            $0.id == change.entryID && $0.supersededByID == nil
          })
        else { throw PersonalMemoryError.missingEntry }
        guard next.entries[index].categories == change.expectedCategories,
          next.entries[index].profileIDs == change.expectedProfileIDs
        else { throw PersonalMemoryError.staleAnalysis }
        next.entries[index].categories = change.categories
        next.entries[index].profileIDs = change.profileIDs
        if next.entries[index].excerptConversationID != nil {
          next.entries[index].excerptProfilesAreEdited = true
        }
      }
    }
  }
}
