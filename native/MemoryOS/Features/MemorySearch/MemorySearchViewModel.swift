import Foundation
import Observation

@MainActor @Observable
final class MemorySearchViewModel {
  var query = "" { didSet { if oldValue != query { invalidate() } } }
  var mode: MemorySearchMode = .keyword { didSet { if oldValue != mode { invalidate() } } }
  private(set) var results: [MemorySearchResult] = []
  private(set) var graph = MemorySearchCollection(documents: [], connections: [])
  private(set) var isBusy = false
  private(set) var searched = false
  private(set) var failure: MemorySearchFailure?
  private(set) var elapsedSeconds: Double?
  @ObservationIgnored private let useCases: MemorySearchUseCases
  @ObservationIgnored private var generation: UInt64 = 0
  @ObservationIgnored private var operation: Task<MemorySearchResponse, Error>?

  init(useCases: MemorySearchUseCases) { self.useCases = useCases }
  deinit { operation?.cancel() }

  func invalidate() {
    cancel()
  }

  func cancel() {
    generation &+= 1
    operation?.cancel()
    operation = nil
    isBusy = false
    results = []
    searched = false
    failure = nil
    elapsedSeconds = nil
  }

  @discardableResult
  func invalidateSavedEvidence() async -> Bool {
    invalidate()
    graph = .init(documents: [], connections: [])
    do {
      try await useCases.invalidateIndexes()
      return true
    } catch {
      failure = .unavailable
      return false
    }
  }

  func load() async {
    guard !isBusy else { return }
    isBusy = true
    let ticket = generation
    defer { if ticket == generation { isBusy = false } }
    do {
      let current = try await useCases.collection()
      guard ticket == generation else { return }
      if current != graph {
        results = []
        searched = false
        elapsedSeconds = nil
      }
      graph = current
      failure = nil
    } catch {
      guard ticket == generation else { return }
      graph = .init(documents: [], connections: [])
      invalidate()
      failure = .unavailable
    }
  }

  func search() async {
    guard !isBusy else { return }
    results = []
    failure = nil
    searched = false
    isBusy = true
    let ticket = generation
    let submittedQuery = query
    let submittedMode = mode
    let start = ContinuousClock.now
    defer {
      if ticket == generation {
        isBusy = false
        operation = nil
      }
    }
    do {
      let useCases = useCases
      let operation = Task {
        try await useCases.searchSnapshot(query: submittedQuery, mode: submittedMode)
      }
      self.operation = operation
      let found = try await operation.value
      let current = try await useCases.collection()
      try Task.checkCancellation()
      guard ticket == generation else { return }
      // Recheck after the final await, including source context and relationship metadata.
      guard found.collection == current else {
        throw MemorySearchFailure.changed
      }
      graph = current
      results = found.results
      elapsedSeconds =
        Double(start.duration(to: .now).components.attoseconds) / 1e18
        + Double(start.duration(to: .now).components.seconds)
      searched = true
    } catch is CancellationError {
      if ticket == generation { results = [] }
    } catch {
      guard ticket == generation else { return }
      results = []
      failure = (error as? MemorySearchFailure) ?? .unavailable
    }
  }
}
