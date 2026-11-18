import Foundation

public struct PersonalMemoryProcessingUpdate: Sendable {
  public let snapshot: PersonalMemorySnapshot
  public let isRunning: Bool
  public let hasFailure: Bool
}

public protocol PersonalMemoryOrganizing: Sendable {
  func setAvailable(_ available: Bool) async
  func resume(conversationID: UUID?) async
  func pause() async
  func refresh() async
  func updates() async -> AsyncStream<PersonalMemoryProcessingUpdate>
}

public enum PersonalMemoryAnalysisRuntimeError: Error, Sendable {
  case temporarilyUnavailable, unqualified
}

/// Durable sources are the queue. This actor owns scheduling, not inference or storage APIs.
public actor AutomaticPersonalMemoryOrganizer: PersonalMemoryOrganizing {
  private let useCases: PersonalMemoryUseCases
  private let analyzer: any PersonalMemoryAnalyzing
  private let quietDelay: Duration
  private var work: (id: UUID, task: Task<Void, Never>)?
  private var preferredConversation: UUID?
  private var enabled = false
  private var available = true
  private var hasFailure = false
  private var observers: [UUID: AsyncStream<PersonalMemoryProcessingUpdate>.Continuation] = [:]

  public init(
    useCases: PersonalMemoryUseCases, analyzer: any PersonalMemoryAnalyzing,
    quietDelay: Duration = .seconds(1)
  ) {
    self.useCases = useCases
    self.analyzer = analyzer
    self.quietDelay = quietDelay
  }

  public func resume(conversationID: UUID? = nil) async {
    enabled = true
    if let conversationID { preferredConversation = conversationID }
    guard available, work == nil else { return }
    hasFailure = false
    start()
  }

  private func start() {
    let id = UUID()
    let task: Task<Void, Never> = Task { [weak self] in
      guard let self else { return }
      await self.run(id: id)
    }
    work = (id, task)
  }

  /// Lifecycle suspension outranks late foreground completion and explicit retries.
  public func setAvailable(_ available: Bool) async {
    self.available = available
    if available {
      if enabled && work == nil { start() }
    } else if let current = work {
      current.task.cancel()
      await current.task.value
      if work?.id == current.id { work = nil }
      if self.available && enabled && work == nil { start() }
    }
    await publish()
  }

  public func pause() async {
    enabled = false
    guard let current = work else { return }
    current.task.cancel()
    await current.task.value
    if work?.id == current.id { work = nil }
    // A resume can arrive while this pause awaits cooperative cancellation.
    if available && enabled && work == nil { start() }
    await publish()
  }

  public func refresh() async { await publish() }

  public func updates() async -> AsyncStream<PersonalMemoryProcessingUpdate> {
    let id = UUID()
    let pair = AsyncStream<PersonalMemoryProcessingUpdate>.makeStream(
      bufferingPolicy: .bufferingNewest(1))
    observers[id] = pair.continuation
    pair.continuation.onTermination = { [weak self] _ in
      Task { await self?.removeObserver(id) }
    }
    await publish()
    return pair.stream
  }

  private func removeObserver(_ id: UUID) { observers[id] = nil }

  private func publish() async {
    guard let snapshot = try? await useCases.snapshot() else { return }
    let update = PersonalMemoryProcessingUpdate(
      snapshot: snapshot, isRunning: work != nil && enabled && available, hasFailure: hasFailure)
    for observer in observers.values { observer.yield(update) }
  }

  private func run(id: UUID) async {
    var retryStale: [UUID: Int] = [:]
    do {
      try await Task.sleep(for: quietDelay)
      await publish()
      while enabled && available {
        try Task.checkCancellation()
        var input = try await useCases.nextAnalysisInput(conversationID: preferredConversation)
        if input == nil {
          preferredConversation = nil
          input = try await useCases.nextAnalysisInput()
        }
        guard let input else { break }
        do {
          let result = try await analyzer.analyze(input)
          try Task.checkCancellation()
          _ = try await useCases.applyAnalysis(result, input: input)
          retryStale[input.source.id] = nil
        } catch is CancellationError { throw CancellationError() } catch PersonalMemoryError
          .staleAnalysis
        {
          let attempts = retryStale[input.source.id, default: 0] + 1
          retryStale[input.source.id] = attempts
          if attempts >= 3 {
            _ = try await useCases.deferAnalysis(sourceID: input.source.id)
            hasFailure = true
          }
        } catch PersonalMemoryAnalysisRuntimeError.temporarilyUnavailable {
          _ = try await useCases.deferAnalysis(sourceID: input.source.id)
          hasFailure = true
          break
        } catch PersonalMemoryAnalysisRuntimeError.unqualified {
          // A failed quality gate must not mutate sources or consume undo history.
          hasFailure = true
          break
        } catch {
          try Task.checkCancellation()
          _ = try await useCases.deferAnalysis(sourceID: input.source.id)
          hasFailure = true
        }
        await publish()
        // Give foreground actors a scheduling opportunity between bounded source jobs.
        await Task.yield()
      }
    } catch is CancellationError {
      // The original remains pending so foreground priority cannot consume queued work.
    } catch { hasFailure = true }
    if work?.id == id { work = nil }
    await publish()
  }
}
