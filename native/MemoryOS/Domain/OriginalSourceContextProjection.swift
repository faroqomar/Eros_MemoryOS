import Foundation
import MemoryCore

struct OriginalSourceContext {
  let source: PersonalMemorySource
  let adjacent: [PersonalMemorySource]
  let linked: [(MemorySearchConnection, PersonalMemorySource)]
}

/// Shared original-only context. Derived entries, profiles and retrieval indexes are not inputs.
enum OriginalSourceContextProjection {
  static func context(
    for id: UUID, sources: [PersonalMemorySource], links: [PersonalMemoryLink]
  ) -> OriginalSourceContext? {
    guard let source = sources.first(where: { $0.id == id }) else { return nil }
    let adjacent: [PersonalMemorySource]
    if let conversationID = source.conversationID {
      let conversation = ordered(sources.filter { $0.conversationID == conversationID })
      if let index = conversation.firstIndex(where: { $0.id == id }) {
        adjacent = neighbors(at: index, in: conversation).filter { $0.id != id }
      } else {
        adjacent = []
      }
    } else {
      adjacent = []
    }
    let direct = links.filter { $0.fromID == id || $0.toID == id }
    let targetIDs = Set(direct.map { $0.fromID == id ? $0.toID : $0.fromID }).subtracting([id])
    let originals = Dictionary(
      uniqueKeysWithValues: sources.filter { targetIDs.contains($0.id) }.map { ($0.id, $0) })
    var seen = Set<String>()
    let linked = direct.compactMap { link -> (MemorySearchConnection, PersonalMemorySource)? in
      let target = link.fromID == id ? link.toID : link.fromID
      guard let original = originals[target] else { return nil }
      let connection = MemorySearchConnection(from: link.fromID, to: link.toID, label: link.label)
      guard seen.insert(connection.id).inserted else { return nil }
      return (connection, original)
    }
    return .init(source: source, adjacent: adjacent, linked: linked)
  }

  static func adjacentIDs(in sources: [PersonalMemorySource]) -> [UUID: [UUID]] {
    let conversations = Dictionary(grouping: sources.filter { $0.conversationID != nil }) {
      $0.conversationID!
    }
    var result: [UUID: [UUID]] = [:]
    for values in conversations.values {
      let conversation = ordered(values)
      for index in conversation.indices {
        result[conversation[index].id] = neighbors(at: index, in: conversation).map(\.id)
      }
    }
    return result
  }

  private static func ordered(_ sources: [PersonalMemorySource]) -> [PersonalMemorySource] {
    sources.sorted {
      $0.createdAt == $1.createdAt
        ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
    }
  }

  private static func neighbors(at index: Int, in sources: [PersonalMemorySource])
    -> [PersonalMemorySource]
  {
    Array(sources[max(0, index - 1)...min(sources.count - 1, index + 1)])
  }
}
