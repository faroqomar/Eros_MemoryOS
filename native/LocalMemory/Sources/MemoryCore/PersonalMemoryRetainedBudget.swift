import Foundation

/// Matches disk pooling without omitting the references retained by each undo graph.
package struct PersonalMemoryRetainedBudget {
  package private(set) var bytes: Int
  private var states: [UUID: [PersonalMemoryAnalysisState]] = [:]

  package init(originalBytes: Int) { bytes = originalBytes }

  package mutating func add(_ graph: PersonalMemoryGraph) throws {
    bytes += graph.estimatedRetainedBytes
    try requireBound()
    for (sourceID, state) in graph.analysisStates ?? [:] {
      if states[sourceID]?.contains(state) == true { continue }
      states[sourceID, default: []].append(state)
      bytes += 272 + (state.question?.utf8.count ?? 0) + (state.quote?.utf8.count ?? 0)
      try requireBound()
    }
  }

  private func requireBound() throws {
    guard bytes <= PersonalMemoryLimits.archiveBytes / 2 else {
      throw PersonalMemoryError.limitReached
    }
  }
}
