import Foundation
import MemoryCore

/// Disk-only sharing keeps full undo graphs without encoding unchanged values fifty times.
/// Public backup/export remains the ordinary, self-contained PersonalMemorySnapshot JSON.
struct PersonalMemoryStorageArchive: Codable {
  private let storageVersion: Int
  private var snapshot: PersonalMemorySnapshot
  private let entries: [PersonalMemoryEntry]
  private let profiles: [PersonalProfile]
  private let links: [PersonalMemoryLink]
  private let classifications: [[UUID: PersonalMemoryKind]]
  private let analysisStates: [StoredAnalysis]?
  private let events: [StoredEvent]

  private struct StoredGraph: Codable {
    let entries: [Int]
    let profiles: [Int]
    let links: [Int]
    let classifications: Int
    let analyses: [Int]?
  }

  private struct StoredAnalysis: Identifiable, Codable, Equatable {
    let id: UUID
    let state: PersonalMemoryAnalysisState
  }

  private struct StoredEvent: Codable {
    let id: UUID
    let summary: String
    let createdAt: Date
    let before: StoredGraph
  }

  init(_ value: PersonalMemorySnapshot) {
    storageVersion = 2
    snapshot = value
    snapshot.events = []
    var entryPool = ValuePool<PersonalMemoryEntry>()
    var profilePool = ValuePool<PersonalProfile>()
    var linkPool = ValuePool<PersonalMemoryLink>()
    var classificationPool: [[UUID: PersonalMemoryKind]] = []
    var analysisPool = ValuePool<StoredAnalysis>()
    let sourceOrder = Dictionary(
      uniqueKeysWithValues: value.sources.enumerated().map { ($0.element.id, $0.offset) })
    var previousAnalysisValues: [UUID: PersonalMemoryAnalysisState]?
    var previousAnalysisReferences: [Int]?
    var stored: [StoredEvent] = []
    for event in value.events {
      let graph = event.before
      let classification: Int
      if let index = classificationPool.firstIndex(of: graph.classifications) {
        classification = index
      } else {
        classification = classificationPool.count
        classificationPool.append(graph.classifications)
      }
      let analyses: [Int]?
      if let values = graph.analysisStates {
        if values == previousAnalysisValues {
          analyses = previousAnalysisReferences
        } else {
          analyses = values.sorted {
            sourceOrder[$0.key, default: Int.max] < sourceOrder[$1.key, default: Int.max]
          }.map { item in
            analysisPool.insert(StoredAnalysis(id: item.key, state: item.value))
          }
          previousAnalysisValues = values
          previousAnalysisReferences = analyses
        }
      } else {
        analyses = nil
      }
      stored.append(
        StoredEvent(
          id: event.id, summary: event.summary, createdAt: event.createdAt,
          before: StoredGraph(
            entries: graph.entries.map { entryPool.insert($0) },
            profiles: graph.profiles.map { profilePool.insert($0) },
            links: graph.links.map { linkPool.insert($0) }, classifications: classification,
            analyses: analyses)))
    }
    entries = entryPool.values
    profiles = profilePool.values
    links = linkPool.values
    classifications = classificationPool
    analysisStates = analysisPool.values.isEmpty ? nil : analysisPool.values
    events = stored
  }

  private enum CodingKeys: String, CodingKey {
    case storageVersion, snapshot, entries, profiles, links, classifications, analysisStates, events
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard let version = try values.decodeIfPresent(Int.self, forKey: .storageVersion) else {
      // Earlier installations stored a full snapshot. Reading never rewrites the file.
      let legacy = try PersonalMemorySnapshot(from: decoder)
      try legacy.validate()
      self.init(legacy)
      return
    }
    guard version == 1 || version == 2 else { throw PersonalMemoryError.unsupportedVersion }
    self.init(
      snapshot: try values.decode(PersonalMemorySnapshot.self, forKey: .snapshot),
      entries: try values.decode([PersonalMemoryEntry].self, forKey: .entries),
      profiles: try values.decode([PersonalProfile].self, forKey: .profiles),
      links: try values.decode([PersonalMemoryLink].self, forKey: .links),
      classifications: try values.decode(
        [[UUID: PersonalMemoryKind]].self, forKey: .classifications),
      analysisStates: try values.decodeIfPresent(
        [StoredAnalysis].self, forKey: .analysisStates),
      events: try values.decode([StoredEvent].self, forKey: .events))
  }

  private init(
    snapshot: PersonalMemorySnapshot, entries: [PersonalMemoryEntry],
    profiles: [PersonalProfile], links: [PersonalMemoryLink],
    classifications: [[UUID: PersonalMemoryKind]],
    analysisStates: [StoredAnalysis]?, events: [StoredEvent]
  ) {
    storageVersion = 2
    self.snapshot = snapshot
    self.entries = entries
    self.profiles = profiles
    self.links = links
    self.classifications = classifications
    self.analysisStates = analysisStates
    self.events = events
  }

  func expanded() throws -> PersonalMemorySnapshot {
    guard snapshot.events.isEmpty, events.count <= PersonalMemoryLimits.retainedEvents,
      entries.count <= PersonalMemoryLimits.archiveBytes / 2 / 320,
      profiles.count <= PersonalMemoryLimits.archiveBytes / 2 / 240,
      links.count <= PersonalMemoryLimits.archiveBytes / 2 / 200,
      classifications.count <= events.count,
      classifications.allSatisfy({ $0.count <= PersonalMemoryLimits.sources }),
      (analysisStates?.count ?? 0) <= PersonalMemoryLimits.archiveBytes / 2 / 240
    else { throw PersonalMemoryError.invalidArchive }
    try snapshot.validate()
    var result = snapshot
    // Enforce the same logical budget while expanding, before retaining another graph.
    let sourceBytes: Int = result.sources.reduce(0) { $0 + $1.estimatedRetainedBytes }
    let photoBytes: Int = result.photos.reduce(0) {
      $0 + (($1.data.count + 2) / 3) * 4 + 256
    }
    var retainedBudget = PersonalMemoryRetainedBudget(originalBytes: sourceBytes + photoBytes)
    try retainedBudget.add(result.graph)
    var usedEntries = Set<Int>()
    var usedProfiles = Set<Int>()
    var usedLinks = Set<Int>()
    var usedClassifications = Set<Int>()
    var usedAnalyses = Set<Int>()
    var sharedAnalyses: [[Int]: [UUID: PersonalMemoryAnalysisState]] = [:]
    for event in events {
      let before = event.before
      guard before.entries.count <= PersonalMemoryLimits.entries,
        before.profiles.count <= PersonalMemoryLimits.profiles, before.links.count <= 20_000,
        classifications.indices.contains(before.classifications)
      else { throw PersonalMemoryError.invalidArchive }
      let states: [UUID: PersonalMemoryAnalysisState]?
      if let indices = before.analyses {
        guard let analysisStates, indices.count <= PersonalMemoryLimits.sources else {
          throw PersonalMemoryError.invalidArchive
        }
        if let shared = sharedAnalyses[indices] {
          states = shared
        } else {
          let values = try resolve(indices, in: analysisStates)
          guard Set(values.map(\.id)).count == values.count else {
            throw PersonalMemoryError.invalidArchive
          }
          let expanded = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0.state) })
          states = expanded
          sharedAnalyses[indices] = expanded
        }
        usedAnalyses.formUnion(indices)
      } else {
        states = nil
      }
      let graph = PersonalMemoryGraph(
        entries: try resolve(before.entries, in: entries),
        profiles: try resolve(before.profiles, in: profiles),
        links: try resolve(before.links, in: links),
        classifications: classifications[before.classifications], analysisStates: states)
      try retainedBudget.add(graph)
      result.events.append(
        PersonalMemoryEvent(
          id: event.id, summary: event.summary, createdAt: event.createdAt, before: graph))
      usedEntries.formUnion(before.entries)
      usedProfiles.formUnion(before.profiles)
      usedLinks.formUnion(before.links)
      usedClassifications.insert(before.classifications)
    }
    guard usedEntries.count == entries.count, usedProfiles.count == profiles.count,
      usedLinks.count == links.count, usedClassifications.count == classifications.count,
      usedAnalyses.count == (analysisStates?.count ?? 0)
    else { throw PersonalMemoryError.invalidArchive }
    try result.validate()
    return result
  }

  private func resolve<Value>(_ indices: [Int], in values: [Value]) throws -> [Value] {
    try indices.map { index in
      guard values.indices.contains(index) else { throw PersonalMemoryError.invalidArchive }
      return values[index]
    }
  }
}

private struct ValuePool<Value: Identifiable & Equatable> where Value.ID: Hashable {
  var values: [Value] = []
  private var indices: [Value.ID: [Int]] = [:]

  mutating func insert(_ value: Value) -> Int {
    if let index = indices[value.id]?.first(where: { values[$0] == value }) { return index }
    let index = values.count
    values.append(value)
    indices[value.id, default: []].append(index)
    return index
  }
}
