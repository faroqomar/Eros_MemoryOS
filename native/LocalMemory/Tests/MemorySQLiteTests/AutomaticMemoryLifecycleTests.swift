import Foundation
import MemoryCore
import Testing

private actor LifecycleRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

private actor LifecycleAnalyzer: PersonalMemoryAnalyzing {
  nonisolated let events: AsyncStream<String>
  private let continuation: AsyncStream<String>.Continuation
  private var releaseFirst: CheckedContinuation<Void, Never>?
  private var attempts = 0

  init() {
    let pair = AsyncStream<String>.makeStream()
    events = pair.stream
    continuation = pair.continuation
  }

  func analyze(_ input: PersonalMemoryAnalysisInput) async throws -> PersonalMemoryAnalysis {
    attempts += 1
    if attempts == 1 {
      continuation.yield("started")
      try await withTaskCancellationHandler {
        await withCheckedContinuation { releaseFirst = $0 }
        try Task.checkCancellation()
      } onCancel: {
        self.continuation.yield("cancelled")
      }
    }
    return PersonalMemoryAnalysis()
  }

  func finishCancellation() {
    releaseFirst?.resume()
    releaseFirst = nil
  }
}

struct AutomaticMemoryLifecycleTests {
  @Test(.timeLimit(.minutes(1)))
  func lifecycleSuspensionRejectsLateCompletionUntilActiveAgain() async throws {
    let useCases = PersonalMemoryUseCases(repository: LifecycleRepository())
    let source = PersonalMemorySource(text: "I enjoy quiet evenings")
    _ = try await useCases.ingest(source: source)
    let analyzer = LifecycleAnalyzer()
    var events = analyzer.events.makeAsyncIterator()
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    await organizer.resume()
    #expect(await events.next() == "started")
    let suspend = Task { await organizer.setAvailable(false) }
    #expect(await events.next() == "cancelled")
    // Interruption of visible generation can finish after lifecycle suspension.
    await organizer.resume()
    await analyzer.finishCancellation()
    await suspend.value
    #expect(try await useCases.snapshot().analysisPendingSources.map(\.id) == [source.id])
    #expect(try await useCases.snapshot().entries.isEmpty)
    await organizer.setAvailable(true)
    while let update = await updates.next() {
      if update.snapshot.sources.first?.analysis?.status == .processed { break }
    }
    #expect(try await useCases.snapshot().analysisPendingSources.isEmpty)
    await organizer.pause()
  }

  @Test(.timeLimit(.minutes(1)))
  func resumeDuringForegroundCancellationRestartsPersistedWork() async throws {
    let useCases = PersonalMemoryUseCases(repository: LifecycleRepository())
    let source = PersonalMemorySource(text: "I enjoy quiet evenings")
    _ = try await useCases.ingest(source: source)
    let analyzer = LifecycleAnalyzer()
    var events = analyzer.events.makeAsyncIterator()
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    await organizer.resume()
    #expect(await events.next() == "started")
    let pause = Task { await organizer.pause() }
    #expect(await events.next() == "cancelled")
    await organizer.resume()
    await analyzer.finishCancellation()
    await pause.value
    while let update = await updates.next() {
      if update.snapshot.sources.first?.analysis?.status == .processed { break }
    }
    #expect(try await useCases.snapshot().analysisPendingSources.isEmpty)
    #expect(try await useCases.snapshot().sources.first?.text == source.text)
    await organizer.pause()
  }
}
