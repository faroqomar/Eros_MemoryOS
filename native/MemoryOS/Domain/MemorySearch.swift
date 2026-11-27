import Foundation
import MemoryCore
import RetrievalCore

enum MemorySearchMode: String, CaseIterable, Identifiable, Sendable {
  case keyword, semantic, linked
  var id: String { rawValue }
}

enum MemorySearchKind: String, Sendable {
  case original, extracted, confirmed, confirmedInterpretation, hypothesis,
    unreviewedInterpretation,
    summary, savedRecord, profile
}

enum MemorySearchDestination: Hashable, Sendable {
  case source(UUID)
  case entry(UUID)
  case profile(UUID)
  case record(UUID)
}

struct MemorySearchDocument: Identifiable, Equatable, Sendable {
  let id: UUID
  let text: String
  let kind: MemorySearchKind
  let date: Date?
  let originalText: String?
  let detail: String
  let destination: MemorySearchDestination
  var contextIDs: [UUID] = []

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.date == rhs.date
      && lhs.destination == rhs.destination && lhs.contextIDs == rhs.contextIDs
      && lhs.text.utf8.elementsEqual(rhs.text.utf8)
      && lhs.detail.utf8.elementsEqual(rhs.detail.utf8)
      && equalSourceBytes(lhs.originalText, rhs.originalText)
  }
}

struct MemorySearchConnection: Identifiable, Equatable, Sendable {
  let from: UUID
  let to: UUID
  let label: String
  var id: String { from.uuidString + ":" + to.uuidString + ":" + label }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.from == rhs.from && lhs.to == rhs.to && lhs.label.utf8.elementsEqual(rhs.label.utf8)
  }
}

/// Explicit app-owned identity and record associations. Association does not establish authorship.
struct MemorySearchIdentity: Equatable, Sendable {
  let names: [String]
  let documentIDs: Set<String>
  let canGroundQuery: Bool

  init(names: [String], documentIDs: Set<String> = [], canGroundQuery: Bool = false) {
    self.names = names
    self.documentIDs = documentIDs
    self.canGroundQuery = canGroundQuery
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.documentIDs == rhs.documentIDs && lhs.names.count == rhs.names.count
      && lhs.canGroundQuery == rhs.canGroundQuery
      && zip(lhs.names, rhs.names).allSatisfy { $0.utf8.elementsEqual($1.utf8) }
  }

  static func make(personal: PersonalMemorySnapshot, availableDocumentIDs: Set<UUID>) -> [Self] {
    let currentEntries = personal.currentEntries
    let activeProfileIDs = Set(personal.profiles.filter { $0.mergedIntoID == nil }.map(\.id))
    let sourceIDs = Set(personal.sources.map(\.id))
    let entrySources = Dictionary(
      uniqueKeysWithValues: currentEntries.map { ($0.id, $0.sourceIDs) })
    var memberships: [UUID: Set<UUID>] = [:]
    for entry in currentEntries {
      for profileID in entry.profileIDs where activeProfileIDs.contains(profileID) {
        memberships[profileID, default: []].formUnion([entry.id] + entry.sourceIDs)
      }
    }
    for link in personal.links {
      let profileID: UUID
      let documentID: UUID
      if activeProfileIDs.contains(link.fromID) {
        (profileID, documentID) = (link.fromID, link.toID)
      } else if activeProfileIDs.contains(link.toID) {
        (profileID, documentID) = (link.toID, link.fromID)
      } else {
        continue
      }
      if let sources = entrySources[documentID] {
        memberships[profileID, default: []].formUnion([documentID] + sources)
      } else if sourceIDs.contains(documentID) {
        memberships[profileID, default: []].insert(documentID)
      }
    }
    return personal.profiles.filter { $0.mergedIntoID == nil }.map {
      .init(
        names: [$0.name] + $0.aliases,
        documentIDs: Set(
          memberships[$0.id, default: []].intersection(availableDocumentIDs).map(\.uuidString)),
        canGroundQuery: $0.kind != .selfProfile && $0.isSuggested == false)
    }
  }
}

/// Canonically equivalent spelling still changes the original passage bytes.
private func equalSourceBytes(_ lhs: String?, _ rhs: String?) -> Bool {
  switch (lhs, rhs) {
  case (.some(let lhs), .some(let rhs)): lhs.utf8.elementsEqual(rhs.utf8)
  case (.none, .none): true
  default: false
  }
}

protocol MemorySubjectSearching: MemorySearching {
  func search(
    query: String, records: [MemorySearchRecord], limit: Int,
    identityAliases: [MemorySearchIdentity]
  ) async throws -> [MemorySearchHit]
}

struct MemorySearchCollection: Equatable, Sendable {
  var documents: [MemorySearchDocument]
  var connections: [MemorySearchConnection]
  var identityAliases: [MemorySearchIdentity] = []

  func document(_ id: UUID) -> MemorySearchDocument? { documents.first { $0.id == id } }

  func connections(to id: UUID) -> [(MemorySearchConnection, MemorySearchDocument)] {
    connections.compactMap { connection in
      let target =
        connection.from == id ? connection.to : connection.to == id ? connection.from : nil
      guard let target, let document = document(target) else { return nil }
      return (connection, document)
    }
  }

  static func make(personal: PersonalMemorySnapshot, local: RecordSnapshot) -> Self {
    var documents: [MemorySearchDocument] = []
    var connections: [MemorySearchConnection] = []
    let currentEntries = personal.currentEntries
    let correctedSourceIDs = Set(
      personal.entries.filter {
        $0.isOwnerCorrected == true || $0.supersededByID != nil
      }.flatMap(\.sourceIDs))
    let contexts = OriginalSourceContextProjection.adjacentIDs(in: personal.sources)
    for source in personal.sources {
      let corrected = correctedSourceIDs.contains(source.id)
      let context = contexts[source.id, default: []]
      documents.append(
        .init(
          id: source.id, text: source.text, kind: .original, date: source.createdAt,
          originalText: nil, detail: corrected ? "historicalOriginal" : "originalStatement",
          destination: .source(source.id), contextIDs: context))
    }
    for entry in currentEntries {
      let kind: MemorySearchKind =
        entry.kind == .interpretation
        ? (entry.interpretationStatus == .ownerReviewed
          ? .confirmedInterpretation
          : entry.interpretationStatus == .aiProposed ? .hypothesis : .unreviewedInterpretation)
        : entry.kind == .summary ? .summary : entry.confirmed ? .confirmed : .extracted
      documents.append(
        .init(
          id: entry.id, text: entry.text, kind: kind, date: entry.createdAt,
          originalText: nil, detail: entry.kind.rawValue, destination: .entry(entry.id),
          contextIDs: entry.sourceIDs))
      for id in entry.sourceIDs {
        connections.append(.init(from: entry.id, to: id, label: "source"))
      }
      for id in entry.profileIDs {
        connections.append(.init(from: entry.id, to: id, label: "profile"))
      }
    }
    for profile in personal.profiles where profile.mergedIntoID == nil {
      documents.append(
        .init(
          id: profile.id, text: profile.name, kind: .profile, date: nil, originalText: nil,
          detail: profile.kind.rawValue, destination: .profile(profile.id)))
    }
    let activeLocal = local.records.filter { $0.deletedAt == nil }
    for record in activeLocal {
      documents.append(
        .init(
          id: record.id, text: record.text, kind: .savedRecord, date: record.createdAt,
          originalText: record.originalText, detail: record.kind.rawValue,
          destination: .record(record.id)))
    }
    connections += personal.links.map { .init(from: $0.fromID, to: $0.toID, label: $0.label) }
    connections += local.links.map { .init(from: $0.fromID, to: $0.toID, label: "linkedRecord") }
    // Provider namespaces must not let duplicate IDs expose another record as evidence.
    var known = Set<UUID>()
    documents = documents.filter { known.insert($0.id).inserted }
    var edges = Set<String>()
    connections = connections.filter {
      known.contains($0.from) && known.contains($0.to) && edges.insert($0.id).inserted
    }
    return .init(
      documents: documents, connections: connections,
      identityAliases: MemorySearchIdentity.make(personal: personal, availableDocumentIDs: known))
  }
}

struct MemorySearchResult: Identifiable, Equatable, Sendable {
  let document: MemorySearchDocument
  let passage: String
  let connection: String?
  var id: UUID { document.id }
}

struct MemorySearchResponse: Sendable {
  let collection: MemorySearchCollection
  let results: [MemorySearchResult]
}

enum MemorySearchFailure: Error, Equatable {
  case unavailable, invalidResult, changed, invalidQuery, ambiguousSubject
}

/// Ranking adapters return IDs and exact passages. Fresh app-owned snapshots own every displayed value.
actor MemorySearchUseCases {
  let readCollection: @Sendable () async throws -> MemorySearchCollection
  private let keyword: any MemorySearching
  private let semantic: any MemorySearching
  private let purgeProviders: @Sendable () async throws -> Void

  init(
    keyword: any MemorySearching, semantic: any MemorySearching,
    purgeProviders: @escaping @Sendable () async throws -> Void = {},
    readCollection: @escaping @Sendable () async throws -> MemorySearchCollection
  ) {
    self.keyword = keyword
    self.semantic = semantic
    self.purgeProviders = purgeProviders
    self.readCollection = readCollection
  }

  func collection() async throws -> MemorySearchCollection { try await readCollection() }

  func invalidateIndexes() async throws { try await purgeProviders() }

  func search(query: String, mode: MemorySearchMode) async throws -> [MemorySearchResult] {
    try await searchSnapshot(query: query, mode: mode).results
  }

  func searchSnapshot(query: String, mode: MemorySearchMode) async throws -> MemorySearchResponse {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty, query.utf8.count <= 4_096 else { throw MemorySearchFailure.invalidQuery }
    let before = try await readCollection()
    try Task.checkCancellation()
    let provider = mode == .semantic ? semantic : keyword
    let records = before.documents.map { MemorySearchRecord(id: $0.id.uuidString, text: $0.text) }
    let hits: [MemorySearchHit]
    if mode == .semantic, let provider = provider as? any MemorySubjectSearching {
      hits = try await provider.search(
        query: query, records: records, limit: 12, identityAliases: before.identityAliases)
    } else {
      hits = try await provider.search(query: query, records: records, limit: 12)
    }
    try Task.checkCancellation()
    let after = try await readCollection()
    guard before == after else { throw MemorySearchFailure.changed }
    guard hits.count <= 12 else { throw MemorySearchFailure.invalidResult }
    var seen = Set<UUID>()
    var results: [MemorySearchResult] = []
    for hit in hits {
      guard hit.score.isFinite, let id = UUID(uuidString: hit.sourceID),
        let document = after.document(id)
      else { throw MemorySearchFailure.invalidResult }
      let passage = hit.matchedText ?? document.text
      guard !passage.isEmpty, document.text.range(of: passage, options: .literal) != nil else {
        throw MemorySearchFailure.invalidResult
      }
      if seen.insert(id).inserted {
        results.append(.init(document: document, passage: passage, connection: nil))
      }
    }
    if mode == .linked {
      let seeds = results
      for seed in seeds {
        for (connection, document) in after.connections(to: seed.id)
        where seen.insert(document.id).inserted {
          results.append(
            .init(document: document, passage: document.text, connection: connection.label))
          if results.count >= 40 { return .init(collection: after, results: results) }
        }
      }
    }
    return .init(collection: after, results: results)
  }
}
