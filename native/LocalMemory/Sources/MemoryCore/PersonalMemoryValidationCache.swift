import Foundation

/// A validation call can reuse immutable proofs; graph-dependent rules still run for every graph.
struct PersonalMemoryValidationCache {
  private struct CheckedEntry {
    let entry: PersonalMemoryEntry
    let ranges: [Range<Int>]

    func matches(_ other: PersonalMemoryEntry) -> Bool {
      entry == other
        && zip(entry.categories, other.categories).allSatisfy {
          $0.0.utf8.elementsEqual($0.1.utf8)
        }
    }
  }

  private var entries: [UUID: [CheckedEntry]] = [:]

  mutating func evidenceRanges(
    for entry: PersonalMemoryEntry, sources: [UUID: PersonalMemorySource]
  ) throws -> [Range<Int>] {
    if let checked = entries[entry.id]?.first(where: { $0.matches(entry) }) {
      return checked.ranges
    }
    try PersonalMemoryLimits.text(entry.text)
    guard entry.kind.createsMemory, !entry.sourceIDs.isEmpty, entry.sourceIDs.count <= 100,
      entry.profileIDs.count <= 100,
      Set(entry.sourceIDs).count == entry.sourceIDs.count,
      Set(entry.profileIDs).count == entry.profileIDs.count,
      entry.categories.count <= 30,
      entry.createdAt.timeIntervalSince1970.isFinite,
      entry.kind != .interpretation || !entry.confirmed
    else { throw PersonalMemoryError.invalidArchive }
    var ranges: [Range<Int>] = []
    if let evidence = entry.evidence {
      guard !evidence.isEmpty, evidence.count <= 100,
        Set(evidence.map(\.sourceID)) == Set(entry.sourceIDs),
        entry.isOwnerCorrected == true
          || evidence.first?.quote.utf8.elementsEqual(entry.text.utf8) == true
      else { throw PersonalMemoryError.invalidArchive }
      for item in evidence {
        guard let source = sources[item.sourceID] else {
          throw PersonalMemoryError.invalidArchive
        }
        ranges.append(try PersonalMemoryUseCases.exactRange(item.quote, in: source.text))
      }
    }
    if let expression = entry.eventTimeExpression {
      guard entry.isEpisode == true,
        entry.evidence?.contains(where: {
          Data($0.quote.utf8).range(of: Data(expression.utf8)) != nil
        }) == true
      else { throw PersonalMemoryError.invalidArchive }
      try PersonalMemoryLimits.text(expression, maximum: 4_096)
    }
    for category in entry.categories { try PersonalMemoryLimits.text(category, maximum: 120) }
    entries[entry.id, default: []].append(CheckedEntry(entry: entry, ranges: ranges))
    return ranges
  }
}
