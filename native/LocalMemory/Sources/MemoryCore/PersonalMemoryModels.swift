import Foundation

public enum PersonalMemoryKind: String, Codable, CaseIterable, Sendable {
  case fact, preference, goal, interpretation, idea, plan, workflow, commitment, summary
  case venting, rolePlay, conversationOnly

  public var createsMemory: Bool {
    self != .venting && self != .rolePlay && self != .conversationOnly
  }
}

public enum PersonalProfileKind: String, Codable, CaseIterable, Sendable {
  case selfProfile, person, project
}

public enum PersonalPhotoOrigin: String, Codable, CaseIterable, Sendable {
  case supplied, imported, generated
}

/// Immutable original; classification and analysis are separate, revisable metadata.
public struct PersonalMemorySource: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let conversationID: UUID?
  public let text: String
  public let createdAt: Date
  public let origin: String
  public let clarificationContext: PersonalMemoryClarificationContext?
  public var kind: PersonalMemoryKind?
  public var analysis: PersonalMemoryAnalysisState? = nil

  /// Older unanswered greetings need no rewrite or new derived memory to stop prompting.
  /// A meaning explicitly supplied by the owner always takes precedence.
  public var effectiveKind: PersonalMemoryKind? {
    kind
  }

  public init(
    id: UUID = UUID(), conversationID: UUID? = nil, text: String,
    createdAt: Date = Date(), origin: String = "chat", kind: PersonalMemoryKind? = nil,
    clarificationContext: PersonalMemoryClarificationContext? = nil
  ) {
    self.id = id
    self.conversationID = conversationID
    self.text = text
    self.createdAt = createdAt
    self.origin = origin
    self.clarificationContext = clarificationContext
    self.kind = kind
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.conversationID == rhs.conversationID
      && lhs.text.utf8.elementsEqual(rhs.text.utf8) && lhs.createdAt == rhs.createdAt
      && lhs.origin.utf8.elementsEqual(rhs.origin.utf8) && lhs.kind == rhs.kind
      && lhs.analysis == rhs.analysis && lhs.clarificationContext == rhs.clarificationContext
  }

  package var estimatedRetainedBytes: Int {
    text.utf8.count + origin.utf8.count + 320
      + (clarificationContext.map { $0.question.utf8.count + $0.quote.utf8.count + 64 } ?? 0)
  }
}

public enum PersonalMemoryInterpretationProvenance: String, Codable, Sendable {
  case ownerReviewed, aiProposed
}

public struct PersonalMemoryEntry: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public let kind: PersonalMemoryKind
  public var sourceIDs: [UUID]
  public var profileIDs: [UUID]
  public var categories: [String]
  public var confirmed: Bool
  public var evidence: [PersonalMemoryEvidence]? = nil
  public var supersededByID: UUID? = nil
  public var isOwnerCorrected: Bool? = nil
  /// Missing metadata is unknown provenance, not evidence of AI authorship.
  public var interpretationProvenance: PersonalMemoryInterpretationProvenance? = nil
  public var isEpisode: Bool? = nil
  public var eventTimeExpression: String? = nil
  /// Exact excerpts grouped by conversation; no model-generated claims.
  public var excerptConversationID: UUID? = nil
  public var isEditedExcerpt: Bool? = nil
  public var excerptProfilesAreEdited: Bool? = nil
  public let createdAt: Date

  public var interpretationStatus: PersonalMemoryInterpretationProvenance? {
    guard kind == .interpretation else { return nil }
    // Older explicit corrections remain evidence of owner review without a data rewrite.
    return isOwnerCorrected == true ? .ownerReviewed : interpretationProvenance
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    let sameTime: Bool
    switch (lhs.eventTimeExpression, rhs.eventTimeExpression) {
    case (nil, nil): sameTime = true
    case (.some(let left), .some(let right)): sameTime = left.utf8.elementsEqual(right.utf8)
    default: sameTime = false
    }
    return lhs.id == rhs.id && lhs.text.utf8.elementsEqual(rhs.text.utf8) && lhs.kind == rhs.kind
      && lhs.sourceIDs == rhs.sourceIDs && lhs.profileIDs == rhs.profileIDs
      && lhs.categories == rhs.categories && lhs.confirmed == rhs.confirmed
      && lhs.evidence == rhs.evidence && lhs.supersededByID == rhs.supersededByID
      && lhs.isOwnerCorrected == rhs.isOwnerCorrected
      && lhs.interpretationProvenance == rhs.interpretationProvenance
      && lhs.isEpisode == rhs.isEpisode && sameTime
      && lhs.excerptConversationID == rhs.excerptConversationID
      && lhs.isEditedExcerpt == rhs.isEditedExcerpt
      && lhs.excerptProfilesAreEdited == rhs.excerptProfilesAreEdited
      && lhs.createdAt == rhs.createdAt
  }
}

public struct PersonalProfile: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let kind: PersonalProfileKind
  public var name: String
  public var aliases: [String]
  public var mergedIntoID: UUID?
  public var photoID: UUID?
  /// True for an AI proposal, false after owner creation/name edits, nil for unreviewed names.
  public var isSuggested: Bool? = nil

  public init(
    id: UUID = UUID(), kind: PersonalProfileKind, name: String,
    aliases: [String] = [], mergedIntoID: UUID? = nil, photoID: UUID? = nil
  ) {
    self.id = id
    self.kind = kind
    self.name = name
    self.aliases = aliases
    self.mergedIntoID = mergedIntoID
    self.photoID = photoID
  }
}

public struct PersonalMemoryLink: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let fromID: UUID
  public let toID: UUID
  public let label: String
}

public struct PersonalPhoto: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let data: Data
  public let origin: PersonalPhotoOrigin
  public let sourceID: UUID?
  public let createdAt: Date
}

/// A reversible graph revision never owns the original sources or image bytes.
public struct PersonalMemoryGraph: Codable, Equatable, Sendable {
  package var entries: [PersonalMemoryEntry]
  package var profiles: [PersonalProfile]
  package var links: [PersonalMemoryLink]
  package var classifications: [UUID: PersonalMemoryKind]
  package var analysisStates: [UUID: PersonalMemoryAnalysisState]? = nil

  package init(
    entries: [PersonalMemoryEntry], profiles: [PersonalProfile],
    links: [PersonalMemoryLink], classifications: [UUID: PersonalMemoryKind],
    analysisStates: [UUID: PersonalMemoryAnalysisState]? = nil
  ) {
    self.entries = entries
    self.profiles = profiles
    self.links = links
    self.classifications = classifications
    self.analysisStates = analysisStates
  }

  package var estimatedRetainedBytes: Int {
    entries.reduce(0) {
      $0 + $1.text.utf8.count + 320 + ($1.sourceIDs.count + $1.profileIDs.count) * 40
        + $1.categories.reduce(0) { $0 + $1.utf8.count }
        + ($1.evidence?.reduce(0) { $0 + $1.quote.utf8.count + 64 } ?? 0)
        + ($1.eventTimeExpression?.utf8.count ?? 0)
    }
      + profiles.reduce(0) {
        $0 + $1.name.utf8.count + 240 + $1.aliases.reduce(0) { $0 + $1.utf8.count }
      } + links.reduce(0) { $0 + $1.label.utf8.count + 200 } + classifications.count * 64
      // UUID + pooled-value reference + map overhead. The budget counts each payload once.
      + (analysisStates?.count ?? 0) * 32
  }
}

public struct PersonalMemoryEvent: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let summary: String
  public let createdAt: Date
  package let before: PersonalMemoryGraph
  package init(id: UUID, summary: String, createdAt: Date, before: PersonalMemoryGraph) {
    self.id = id
    self.summary = summary
    self.createdAt = createdAt
    self.before = before
  }
  public var previousEntries: [PersonalMemoryEntry] { before.entries }
}

public struct PersonalMemorySnapshot: Codable, Equatable, Sendable {
  public static let ownerID = UUID(uuidString: "684E16CE-5E54-489A-A946-32FF9BA338B8")!
  public var formatVersion: Int = 1
  public var revision: UInt64 = 0
  public var sources: [PersonalMemorySource] = []
  public var entries: [PersonalMemoryEntry] = []
  public var profiles: [PersonalProfile] = [
    PersonalProfile(id: ownerID, kind: .selfProfile, name: "You")
  ]
  public var links: [PersonalMemoryLink] = []
  public var events: [PersonalMemoryEvent] = []
  public var photos: [PersonalPhoto] = []

  public init() {}
  public var selfProfileID: UUID { Self.ownerID }
  public var pendingSources: [PersonalMemorySource] {
    sources.filter { $0.analysis?.status == .needsClarification }
  }
  public var analysisPendingSources: [PersonalMemorySource] {
    sources.filter {
      $0.origin == "chat"
        && ($0.analysis?.status == .pending || ($0.analysis == nil && $0.kind == nil))
    }
  }
  public var deferredSources: [PersonalMemorySource] {
    sources.filter { $0.analysis?.status == .deferred }
  }
  public var currentEntries: [PersonalMemoryEntry] { entries.filter { $0.supersededByID == nil } }

  package var graph: PersonalMemoryGraph {
    let states = Dictionary(
      uniqueKeysWithValues: sources.compactMap { source in
        source.analysis.map { (source.id, $0) }
      })
    let sharedStates: [UUID: PersonalMemoryAnalysisState]?
    if let previous = events.last?.before.analysisStates, previous == states {
      sharedStates = previous
    } else {
      sharedStates = states.isEmpty ? nil : states
    }
    return PersonalMemoryGraph(
      entries: entries, profiles: profiles, links: links,
      classifications: Dictionary(
        uniqueKeysWithValues: sources.compactMap { source in
          source.kind.map { (source.id, $0) }
        }), analysisStates: sharedStates)
  }

  mutating func apply(_ graph: PersonalMemoryGraph) {
    entries = graph.entries
    profiles = graph.profiles
    links = graph.links
    for index in sources.indices {
      sources[index].kind = graph.classifications[sources[index].id]
      sources[index].analysis = graph.analysisStates?[sources[index].id]
    }
  }
}

public struct PersonalMemoryIngestion: Equatable, Sendable {
  public let sourceID: UUID
  public let needsClarification: Bool
}

public protocol PersonalMemoryRepository: Sendable {
  func load() async throws -> PersonalMemorySnapshot
  func save(_ snapshot: PersonalMemorySnapshot) async throws
}

public enum PersonalMemoryError: Error, Equatable, Sendable {
  case storage, invalidArchive, unsupportedVersion, limitReached, missingSource, missingEntry
  case missingProfile, unresolvedSource, confirmationRequired, conflictingSource, invalidPhoto
  case nothingToUndo, invalidLink
  case staleAnalysis, invalidAnalysis
}

public enum PersonalMemoryLimits {
  public static let textBytes = 32_000
  public static let imageBytes = 5 * 1024 * 1024
  public static let archiveBytes = 64 * 1024 * 1024
  public static let sources = 10_000
  public static let entries = 10_000
  public static let profiles = 2_000
  public static let retainedEvents = 50

  static func text(_ value: String, maximum: Int = textBytes) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      value.utf8.count <= maximum
    else { throw PersonalMemoryError.limitReached }
  }
}

extension PersonalMemorySnapshot {
  public func validate() throws {
    guard formatVersion == 1 else { throw PersonalMemoryError.unsupportedVersion }
    guard revision < UInt64.max, sources.count <= PersonalMemoryLimits.sources,
      entries.count <= PersonalMemoryLimits.entries,
      profiles.count <= PersonalMemoryLimits.profiles,
      links.count <= 20_000, photos.count <= 2_000,
      events.count <= PersonalMemoryLimits.retainedEvents
    else { throw PersonalMemoryError.limitReached }
    let sourceIDs = Set(sources.map(\.id))
    guard sourceIDs.count == sources.count, Set(photos.map(\.id)).count == photos.count,
      Set(events.map(\.id)).count == events.count
    else { throw PersonalMemoryError.invalidArchive }
    let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    for source in sources {
      try PersonalMemoryLimits.text(source.text)
      try PersonalMemoryLimits.text(source.origin, maximum: 240)
      guard source.createdAt.timeIntervalSince1970.isFinite else {
        throw PersonalMemoryError.invalidArchive
      }
      if let context = source.clarificationContext {
        guard source.origin == "clarification answer",
          let parent = sourcesByID[context.parentSourceID],
          parent.origin == "chat", parent.conversationID == source.conversationID
        else { throw PersonalMemoryError.invalidArchive }
        try PersonalMemoryLimits.text(context.question, maximum: 1_600)
        _ = try PersonalMemoryUseCases.exactRange(context.quote, in: parent.text)
      }
    }
    for photo in photos {
      guard !photo.data.isEmpty, photo.data.count <= PersonalMemoryLimits.imageBytes,
        photo.createdAt.timeIntervalSince1970.isFinite,
        photo.sourceID.map(sourceIDs.contains) ?? true,
        photo.origin != .imported || photo.sourceID != nil
      else { throw PersonalMemoryError.invalidPhoto }
    }
    // Bound retained payloads before encoding an archive or keeping another undo revision.
    let sourceBytes: Int = sources.reduce(0) { $0 + $1.estimatedRetainedBytes }
    let photoBytes: Int = photos.reduce(0) { $0 + (($1.data.count + 2) / 3) * 4 + 256 }
    var retainedBudget = PersonalMemoryRetainedBudget(originalBytes: sourceBytes + photoBytes)
    var entryCache = PersonalMemoryValidationCache()
    try retainedBudget.add(graph)
    try validateGraph(
      graph, sourceIDs: sourceIDs, sourcesByID: sourcesByID, entryCache: &entryCache)
    for event in events {
      try PersonalMemoryLimits.text(event.summary, maximum: 240)
      guard event.createdAt.timeIntervalSince1970.isFinite else {
        throw PersonalMemoryError.invalidArchive
      }
      try retainedBudget.add(event.before)
      try validateGraph(
        event.before, sourceIDs: sourceIDs, sourcesByID: sourcesByID, entryCache: &entryCache)
    }
  }

  private func validateGraph(
    _ graph: PersonalMemoryGraph, sourceIDs: Set<UUID>,
    sourcesByID: [UUID: PersonalMemorySource], entryCache: inout PersonalMemoryValidationCache
  ) throws {
    let profileIDs = Set(graph.profiles.map(\.id))
    let entryIDs = Set(graph.entries.map(\.id))
    let allIDs = profileIDs.union(entryIDs).union(sourceIDs)
    guard profileIDs.count == graph.profiles.count, entryIDs.count == graph.entries.count,
      profileIDs.isDisjoint(with: sourceIDs), entryIDs.isDisjoint(with: sourceIDs),
      entryIDs.isDisjoint(with: profileIDs), graph.links.count <= 20_000,
      graph.entries.count <= PersonalMemoryLimits.entries,
      graph.profiles.count <= PersonalMemoryLimits.profiles,
      Set(graph.links.map(\.id)).count == graph.links.count,
      graph.classifications.keys.allSatisfy(sourceIDs.contains),
      graph.analysisStates?.keys.allSatisfy(sourceIDs.contains) ?? true,
      graph.profiles.filter({ $0.kind == .selfProfile }).map(\.id) == [Self.ownerID]
    else { throw PersonalMemoryError.invalidArchive }
    for (id, state) in graph.analysisStates ?? [:] {
      guard
        state.hasDeferredRemainder != true
          || [.pending, .deferred, .needsClarification].contains(state.status)
      else { throw PersonalMemoryError.invalidArchive }
      guard state.version == 1, state.appliedRevision.map({ $0 < UInt64.max }) ?? true,
        state.answerSourceID.map(sourceIDs.contains) ?? true,
        state.protectedEntryID.map(entryIDs.contains) ?? true
      else { throw PersonalMemoryError.invalidArchive }
      if let answer = state.answerSourceID {
        guard let parent = sourcesByID[id],
          let original = sourcesByID[answer],
          original.origin == "clarification answer",
          original.conversationID == parent.conversationID
        else { throw PersonalMemoryError.invalidArchive }
      }
      let hasAnswerContext =
        state.answerSourceID != nil
        && (state.status == .pending || state.status == .deferred || state.status == .processed)
      if state.status == .needsClarification || hasAnswerContext {
        guard let question = state.question, let quote = state.quote,
          let source = sourcesByID[id]
        else { throw PersonalMemoryError.invalidArchive }
        try PersonalMemoryLimits.text(question, maximum: 1_600)
        _ = try PersonalMemoryUseCases.exactRange(quote, in: source.text)
        if hasAnswerContext,
          let answerID = state.answerSourceID, let answer = sourcesByID[answerID],
          let context = answer.clarificationContext
        {
          guard context.parentSourceID == id,
            context.question.utf8.elementsEqual(question.utf8),
            context.quote.utf8.elementsEqual(quote.utf8)
          else { throw PersonalMemoryError.invalidArchive }
        }
      } else if state.question != nil || state.quote != nil || state.protectedEntryID != nil {
        throw PersonalMemoryError.invalidArchive
      }
    }
    let photoIDs = Set(photos.map(\.id))
    for profile in graph.profiles {
      try PersonalMemoryLimits.text(profile.name, maximum: 240)
      guard profile.aliases.count <= 100 else { throw PersonalMemoryError.limitReached }
      for alias in profile.aliases { try PersonalMemoryLimits.text(alias, maximum: 240) }
      guard profile.photoID.map(photoIDs.contains) ?? true else {
        throw PersonalMemoryError.invalidArchive
      }
      if let target = profile.mergedIntoID {
        guard profile.kind == .person, target != profile.id,
          graph.profiles.contains(where: {
            $0.id == target && $0.kind == .person && $0.mergedIntoID == nil
          })
        else { throw PersonalMemoryError.invalidArchive }
      }
    }
    for entry in graph.entries {
      let evidenceRanges = try entryCache.evidenceRanges(for: entry, sources: sourcesByID)
      guard
        entry.sourceIDs.allSatisfy({ id in
          guard let source = sourcesByID[id] else { return false }
          return graph.classifications[id]?.createsMemory == true
            || (entry.evidence != nil
              && (source.origin == "clarification answer"
                || (source.origin == "chat" && graph.classifications[id] == .conversationOnly
                  && graph.analysisStates?[id]?.status == .processed)))
        }),
        entry.profileIDs.allSatisfy({ id in
          graph.profiles.contains { $0.id == id && $0.mergedIntoID == nil }
        })
      else { throw PersonalMemoryError.invalidArchive }
      if let evidence = entry.evidence {
        for (index, item) in evidence.enumerated() {
          guard let source = sourcesByID[item.sourceID] else {
            throw PersonalMemoryError.invalidArchive
          }
          let evidenceRange = evidenceRanges[index]
          if let state = graph.analysisStates?[source.id], state.status == .needsClarification,
            let unresolved = state.quote
          {
            let unresolvedRange = try PersonalMemoryUseCases.exactRange(unresolved, in: source.text)
            guard !evidenceRange.overlaps(unresolvedRange) else {
              throw PersonalMemoryError.invalidArchive
            }
          }
        }
      }
      if let target = entry.supersededByID {
        guard target != entry.id, entryIDs.contains(target),
          entry.kind != .summary, !entry.confirmed, entry.isOwnerCorrected != true,
          entry.interpretationStatus != .ownerReviewed
        else { throw PersonalMemoryError.invalidArchive }
      }
      if let conversation = entry.excerptConversationID {
        guard entry.kind == .summary, !entry.confirmed,
          entry.sourceIDs.allSatisfy({ id in
            sourcesByID[id]?.conversationID == conversation
          })
        else { throw PersonalMemoryError.invalidArchive }
      } else if entry.isEditedExcerpt != nil || entry.excerptProfilesAreEdited != nil {
        throw PersonalMemoryError.invalidArchive
      }
    }
    var checked = Set<UUID>()
    let successors = Dictionary(
      uniqueKeysWithValues: graph.entries.compactMap { entry in
        entry.supersededByID.map { (entry.id, $0) }
      })
    for id in successors.keys where !checked.contains(id) {
      var path = Set<UUID>()
      var current: UUID? = id
      while let value = current, !checked.contains(value) {
        guard path.insert(value).inserted else { throw PersonalMemoryError.invalidArchive }
        current = successors[value]
      }
      checked.formUnion(path)
    }
    for link in graph.links {
      guard link.fromID != link.toID, allIDs.contains(link.fromID), allIDs.contains(link.toID)
      else { throw PersonalMemoryError.invalidLink }
      try PersonalMemoryLimits.text(link.label, maximum: 120)
    }
  }
}
