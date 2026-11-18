import Foundation
import MemoryCore
import MemorySQLite
import Testing

private actor OrganizerAnalyzer: PersonalMemoryAnalyzing {
  private let result: @Sendable (PersonalMemoryAnalysisInput, Int) -> PersonalMemoryAnalysis
  private(set) var sources: [UUID] = []

  init(_ result: @escaping @Sendable (PersonalMemoryAnalysisInput, Int) -> PersonalMemoryAnalysis) {
    self.result = result
  }

  func analyze(_ input: PersonalMemoryAnalysisInput) -> PersonalMemoryAnalysis {
    sources.append(input.source.id)
    return result(input, sources.count)
  }
}

private actor CancellableOrganizerAnalyzer: PersonalMemoryAnalyzing {
  nonisolated let started: AsyncStream<UUID>
  private let continuation: AsyncStream<UUID>.Continuation

  init() {
    let pair = AsyncStream<UUID>.makeStream()
    started = pair.stream
    continuation = pair.continuation
  }

  func analyze(_ input: PersonalMemoryAnalysisInput) async throws -> PersonalMemoryAnalysis {
    continuation.yield(input.source.id)
    try await Task.sleep(for: .seconds(300))
    return PersonalMemoryAnalysis()
  }
}

private func organizerResult(
  _ iterator: inout AsyncStream<PersonalMemoryProcessingUpdate>.Iterator
) async throws -> PersonalMemoryProcessingUpdate {
  while let update = await iterator.next() {
    if !update.isRunning { return update }
  }
  throw CancellationError()
}

struct AutomaticPersonalMemoryOrganizerTests {
  private func archive() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "memory.json")
  }

  @Test(.timeLimit(.minutes(1)))
  func startupProcessesPersistedBacklogAndSecondLaunchDoesNotRepeatIt() async throws {
    let url = try archive()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let source = PersonalMemorySource(text: "Morning walks help me focus")
    let first = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    _ = try await first.ingest(source: source)

    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let analyzer = OrganizerAnalyzer { input, _ in
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: input.source.text, kind: .preference, subjectKind: .selfProfile)
      ])
    }
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: reopened, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await organizer.resume()
    let completed = try await organizerResult(&updates)
    #expect(!completed.hasFailure)
    #expect(completed.snapshot.analysisPendingSources.isEmpty)
    #expect(completed.snapshot.currentEntries.map(\.text) == [source.text])
    #expect(
      completed.snapshot.currentEntries.first?.evidence == [
        PersonalMemoryEvidence(sourceID: source.id, quote: source.text)
      ])
    await organizer.pause()

    let reloaded = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let next = AutomaticPersonalMemoryOrganizer(
      useCases: reloaded, analyzer: analyzer, quietDelay: .zero)
    var nextUpdates = await next.updates().makeAsyncIterator()
    _ = await nextUpdates.next()
    await next.resume()
    let unchanged = try await organizerResult(&nextUpdates)
    #expect(unchanged.snapshot == completed.snapshot)
    #expect(await analyzer.sources == [source.id])
    await next.pause()
  }

  @Test(.timeLimit(.minutes(1)))
  func foregroundPauseCancelsAnalysisWithoutConsumingThePersistedSource() async throws {
    let url = try archive()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let useCases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let source = PersonalMemorySource(text: "Cedar needs a quieter workspace")
    _ = try await useCases.ingest(source: source)
    let before = try await useCases.snapshot()
    let analyzer = CancellableOrganizerAnalyzer()
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var started = analyzer.started.makeAsyncIterator()
    await organizer.resume()
    #expect(await started.next() == source.id)
    await organizer.pause()
    #expect(try await useCases.snapshot() == before)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    #expect(try await reopened.snapshot().analysisPendingSources.map(\.id) == [source.id])
    #expect(try await reopened.snapshot().entries.isEmpty)
  }

  @Test(.timeLimit(.minutes(1)))
  func malformedAnalysisDefersTheOriginalAndExplicitRetryProcessesIt() async throws {
    let url = try archive()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let useCases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let source = PersonalMemorySource(text: "I enjoy working beside the window")
    _ = try await useCases.ingest(source: source)
    let analyzer = OrganizerAnalyzer { input, attempt in
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: attempt == 1 ? "Invented information" : input.source.text,
          kind: .preference, subjectKind: .selfProfile)
      ])
    }
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await organizer.resume()
    let deferred = try await organizerResult(&updates)
    #expect(deferred.hasFailure)
    #expect(deferred.snapshot.deferredSources.map(\.id) == [source.id])
    #expect(deferred.snapshot.entries.isEmpty)
    #expect(deferred.snapshot.pendingSources.isEmpty)
    #expect(deferred.snapshot.sources.first?.text == source.text)
    _ = try await useCases.retryAnalysis(sourceID: source.id)
    await organizer.resume()
    let recovered = try await organizerResult(&updates)
    #expect(!recovered.hasFailure)
    #expect(recovered.snapshot.deferredSources.isEmpty)
    #expect(recovered.snapshot.currentEntries.map(\.text) == [source.text])
    #expect(await analyzer.sources == [source.id, source.id])
    await organizer.pause()
  }

  @Test(.timeLimit(.minutes(1)))
  func undoOfAutomaticOrganizationSurvivesWorkerRestart() async throws {
    let url = try archive()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let useCases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let source = PersonalMemorySource(text: "I like short meetings")
    _ = try await useCases.ingest(source: source)
    let analyzer = OrganizerAnalyzer { input, _ in
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(quote: input.source.text, kind: .preference)
      ])
    }
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await organizer.resume()
    _ = try await organizerResult(&updates)
    await organizer.pause()
    let undone = try await useCases.undo()
    #expect(undone.sources.first?.analysis?.status == .ignored)
    #expect(undone.entries.isEmpty)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let restarted = AutomaticPersonalMemoryOrganizer(
      useCases: reopened, analyzer: analyzer, quietDelay: .zero)
    var restartedUpdates = await restarted.updates().makeAsyncIterator()
    _ = await restartedUpdates.next()
    await restarted.resume()
    let result = try await organizerResult(&restartedUpdates)
    #expect(result.snapshot == undone)
    #expect(result.snapshot.sources.first?.text == source.text)
    #expect(await analyzer.sources == [source.id])
    await restarted.pause()
  }

  @Test(.timeLimit(.minutes(1)))
  func backgroundReplacementCannotOverwriteAnOwnerCorrection() async throws {
    let url = try archive()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let useCases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    let original = PersonalMemorySource(text: "I prefer early meetings")
    _ = try await useCases.ingest(source: original)
    let input = try #require(try await useCases.nextAnalysisInput())
    let derived = try await useCases.applyAnalysis(
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(quote: original.text, kind: .preference)
      ]), input: input)
    let entry = try #require(derived.currentEntries.first)
    _ = try await useCases.updateEntry(id: entry.id, text: "I prefer afternoon meetings")
    let later = PersonalMemorySource(text: "I prefer evening meetings")
    _ = try await useCases.ingest(source: later)
    let analyzer = OrganizerAnalyzer { input, _ in
      PersonalMemoryAnalysis(memories: [
        PersonalMemoryProposal(
          quote: input.source.text, kind: .preference, replacesEntryID: entry.id)
      ])
    }
    let organizer = AutomaticPersonalMemoryOrganizer(
      useCases: useCases, analyzer: analyzer, quietDelay: .zero)
    var updates = await organizer.updates().makeAsyncIterator()
    _ = await updates.next()
    await organizer.resume()
    let result = try await organizerResult(&updates)
    #expect(!result.hasFailure)
    #expect(result.snapshot.currentEntries.map(\.text) == ["I prefer afternoon meetings"])
    #expect(result.snapshot.currentEntries.first?.isOwnerCorrected == true)
    #expect(result.snapshot.pendingSources.map(\.id) == [later.id])
    #expect(result.snapshot.sources.map(\.text) == [original.text, later.text])
    await organizer.pause()
  }
}
