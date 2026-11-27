import Foundation

extension PersonalMemoryUseCases {
  /// Permanent, explicit erasure also invalidates prior undo data that contains the source.
  /// Normal corrections continue to retain the immutable original instead.
  public func forgetSource(sourceID: UUID, confirmed: Bool) async throws -> PersonalMemorySnapshot {
    guard confirmed else { throw PersonalMemoryError.confirmationRequired }
    return try await edit("Deleted original and dependent memory", retainsUndo: false) { next in
      guard next.sources.contains(where: { $0.id == sourceID }) else {
        throw PersonalMemoryError.missingSource
      }
      var removed: Set<UUID> = [sourceID]
      var priorCount = 0
      while priorCount != removed.count {
        priorCount = removed.count
        for source in next.sources {
          if let parent = source.clarificationContext?.parentSourceID, removed.contains(parent) {
            removed.insert(source.id)
          }
        }
        let accountEntries = Set(
          next.links.filter {
            $0.label == "Owner interpretation of original" && removed.contains($0.toID)
          }.map(\.fromID))
        for entry in next.entries where accountEntries.contains(entry.id) {
          for source in next.sources
          where entry.sourceIDs.contains(source.id)
            && source.origin == "relationship account"
          {
            removed.insert(source.id)
          }
        }
      }
      next.sources.removeAll { removed.contains($0.id) }
      next.entries.removeAll { !removed.isDisjoint(with: $0.sourceIDs) }
      next.photos.removeAll { $0.sourceID.map(removed.contains) ?? false }
      let photoIDs = Set(next.photos.map(\.id))
      let entryIDs = Set(next.entries.map(\.id))
      for index in next.profiles.indices {
        if let id = next.profiles[index].photoID, !photoIDs.contains(id) {
          next.profiles[index].photoID = nil
        }
      }
      for index in next.entries.indices {
        if let id = next.entries[index].supersededByID, !entryIDs.contains(id) {
          next.entries[index].supersededByID = nil
        }
      }
      for index in next.sources.indices {
        let state = next.sources[index].analysis
        if state?.answerSourceID.map(removed.contains) == true
          || state?.protectedEntryID.map({ !entryIDs.contains($0) }) == true
        {
          next.sources[index].analysis = PersonalMemoryAnalysisState(status: .deferred)
        }
      }
      let allIDs = Set(next.sources.map(\.id)).union(entryIDs).union(next.profiles.map(\.id))
      next.links.removeAll { !allIDs.contains($0.fromID) || !allIDs.contains($0.toID) }
      next.events.removeAll()
    }
  }
}
