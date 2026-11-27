import Foundation

public enum RelationshipInsightKind: String, Codable, Sendable {
  case commitmentReview, unresolvedReview, recurringTopic
}

/// A prompt to inspect saved material, not a model assertion about a relationship.
public struct RelationshipProactiveInsight: Identifiable, Equatable, Sendable {
  public let id: String
  public let kind: RelationshipInsightKind
  public let topic: String?
  public let sourceIDs: [UUID]
  public let entryIDs: [UUID]
  public let firstRecordedAt: Date
  public let lastRecordedAt: Date
}

public enum RelationshipInsightProjector {
  /// Rebuild from the latest snapshot so corrections/deletions need no separate stale index.
  public static func project(
    _ snapshot: PersonalMemorySnapshot, limit: Int = 6
  ) -> [RelationshipProactiveInsight] {
    guard limit > 0 else { return [] }
    let sources = Dictionary(uniqueKeysWithValues: snapshot.sources.map { ($0.id, $0) })
    let entries = snapshot.currentEntries.filter {
      !$0.sourceIDs.isEmpty && $0.excerptConversationID == nil
        && $0.sourceIDs.allSatisfy { sources[$0] != nil }
    }
    var output: [RelationshipProactiveInsight] = []
    func insight(
      id: String, kind: RelationshipInsightKind, topic: String? = nil,
      entries: [PersonalMemoryEntry]
    ) -> RelationshipProactiveInsight? {
      let ids = Set(entries.flatMap(\.sourceIDs))
      let originals = ids.compactMap { sources[$0] }.sorted {
        $0.createdAt == $1.createdAt
          ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
      }
      guard let first = originals.first, let last = originals.last else { return nil }
      return RelationshipProactiveInsight(
        id: id, kind: kind, topic: topic, sourceIDs: originals.map(\.id),
        entryIDs: entries.map(\.id), firstRecordedAt: first.createdAt,
        lastRecordedAt: last.createdAt)
    }
    let recent = entries.sorted {
      $0.createdAt == $1.createdAt
        ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt
    }
    for entry in recent {
      let kind: RelationshipInsightKind?
      if entry.kind == .commitment {
        kind = .commitmentReview
      } else if entry.categories.contains(where: {
        $0.lowercased() == "unresolved" || $0 == "غير محسوم"
      }) {
        kind = .unresolvedReview
      } else {
        kind = nil
      }
      if let kind, let item = insight(id: entry.id.uuidString, kind: kind, entries: [entry]) {
        output.append(item)
      }
      if output.count >= min(limit, 12) { return output }
    }
    var topics: [String: [PersonalMemoryEntry]] = [:]
    let genericCategories = Set(PersonalMemoryKind.allCases.map(\.rawValue)).union([
      "Source excerpts"
    ])
    for entry in entries {
      for category in Set(entry.categories)
      where category.lowercased() != "unresolved"
        && category != "غير محسوم" && !genericCategories.contains(category)
      {
        topics[category, default: []].append(entry)
      }
    }
    for topic in topics.keys.sorted() {
      guard let values = topics[topic], Set(values.flatMap(\.sourceIDs)).count >= 2,
        let item = insight(
          id: "topic:" + topic, kind: .recurringTopic, topic: topic, entries: values)
      else { continue }
      output.append(item)
      if output.count >= min(limit, 12) { break }
    }
    return output
  }
}
