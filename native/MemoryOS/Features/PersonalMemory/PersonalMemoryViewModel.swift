import Foundation
import MemoryCore
import Observation

@MainActor @Observable
final class PersonalMemoryViewModel {
  private(set) var snapshot = PersonalMemorySnapshot()
  private(set) var isBusy = false
  private(set) var isOrganizing = false
  private(set) var organizationFailed = false
  let automaticMemoryUnavailable: Bool
  private(set) var hasLoaded = false
  private(set) var failure: Failure?
  private(set) var suggestions: [PersonalProfile] = []
  var peopleQuery = ""
  var projectsQuery = ""
  @ObservationIgnored private let useCases: PersonalMemoryUseCases
  @ObservationIgnored private let imageImport: ImportPersonalImage
  @ObservationIgnored private let archiveRestore: RestorePersonalMemoryArchive?
  @ObservationIgnored private let organizer: (any PersonalMemoryOrganizing)?
  @ObservationIgnored private let invalidateDerived: @Sendable () async throws -> Void
  @ObservationIgnored private var organizationUpdates: Task<Void, Never>?
  private(set) var exportedArchive: Data?

  enum Failure { case storage, invalidImage, imageTooLarge, invalidAction, capacity }

  /// Reading context never changes a relationship-analysis request or its evidence set.
  func sourceContext(_ id: UUID) -> OriginalSourceContext? {
    OriginalSourceContextProjection.context(
      for: id, sources: snapshot.sources, links: snapshot.links)
  }

  init(
    useCases: PersonalMemoryUseCases, imageImport: ImportPersonalImage,
    archiveRestore: RestorePersonalMemoryArchive? = nil,
    organizer: (any PersonalMemoryOrganizing)? = nil,
    automaticMemoryUnavailable: Bool = false,
    invalidateDerived: @escaping @Sendable () async throws -> Void = {}
  ) {
    self.useCases = useCases
    self.imageImport = imageImport
    self.archiveRestore = archiveRestore
    self.organizer = organizer
    self.automaticMemoryUnavailable = automaticMemoryUnavailable
    self.invalidateDerived = invalidateDerived
  }

  deinit { organizationUpdates?.cancel() }

  func load() async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      snapshot = try await useCases.snapshot()
      hasLoaded = true
      failure = nil
      observeOrganization()
    } catch { failure = .storage }
  }

  private func observeOrganization() {
    guard organizationUpdates == nil, let organizer else { return }
    organizationUpdates = Task { [weak self] in
      let updates = await organizer.updates()
      for await update in updates {
        guard !Task.isCancelled, let self else { return }
        if update.snapshot.revision >= self.snapshot.revision { self.snapshot = update.snapshot }
        self.isOrganizing = update.isRunning
        self.organizationFailed = update.hasFailure
      }
    }
  }

  func answerClarification(_ sourceID: UUID, answer: String) async -> Bool {
    let conversation = snapshot.sources.first { $0.id == sourceID }?.conversationID
    let saved = await change {
      try await useCases.answerClarification(sourceID: sourceID, answer: answer)
    }
    if saved { await organizer?.resume(conversationID: conversation) }
    return saved
  }

  func skipClarification(_ sourceID: UUID) async {
    _ = await change { try await useCases.skipClarification(sourceID: sourceID) }
  }

  func retryOrganization() async {
    guard !automaticMemoryUnavailable else { return }
    if await change({ try await useCases.retryAnalysis() }) {
      await organizer?.resume(conversationID: nil)
    }
  }

  @discardableResult
  private func change(_ action: () async throws -> PersonalMemorySnapshot) async -> Bool {
    guard !isBusy, hasLoaded else { return false }
    isBusy = true
    defer { isBusy = false }
    do {
      try await invalidateDerived()
      snapshot = try await action()
      failure = nil
      return true
    } catch PersonalMemoryError.storage {
      failure = .storage
      return false
    } catch PersonalMemoryError.limitReached {
      failure = .capacity
      return false
    } catch {
      failure = .invalidAction
      return false
    }
  }

  @discardableResult
  func createProfile(kind: PersonalProfileKind, name: String, aliases: String) async -> Bool {
    await change {
      try await useCases.createProfile(
        kind: kind, name: name,
        aliases: aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }
  }

  @discardableResult
  func updateProfile(_ id: UUID, name: String, aliases: String) async -> Bool {
    await change {
      try await useCases.updateProfile(
        id: id, name: name,
        aliases: aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }
  }

  func suggestPeople(_ name: String) async {
    do { suggestions = try await useCases.suggestPeople(name: name) } catch { failure = .storage }
  }

  @discardableResult
  func addReport(
    text: String, kind: PersonalMemoryKind, profileID: UUID?, question: String? = nil,
    sourceIDs: [UUID] = []
  ) async -> Bool {
    await change {
      if !sourceIDs.isEmpty {
        return try await useCases.addEntry(
          text: text, kind: kind, sourceIDs: sourceIDs,
          profileIDs: profileID.map { [$0] } ?? [], confirmed: kind == .fact, ownerReviewed: true)
      }
      return try await useCases.answerProfileQuestion(
        profileID: profileID ?? snapshot.selfProfileID,
        question: question ?? "Owner report", answer: text, kind: kind)
    }
  }

  @discardableResult
  func correct(_ entry: UUID, text: String, confirmedChange: Bool) async -> Bool {
    await change {
      try await useCases.updateEntry(id: entry, text: text, confirmedChange: confirmedChange)
    }
  }

  @discardableResult
  func organize(_ entry: UUID, categories: String, profiles: [UUID]) async -> Bool {
    await change {
      try await useCases.organize(
        entryID: entry,
        categories: categories.split(separator: ",").map {
          $0.trimmingCharacters(in: .whitespaces)
        },
        profileIDs: profiles)
    }
  }

  @discardableResult
  func merge(_ from: UUID, into: UUID) async -> Bool {
    await change { try await useCases.mergePeople(from: from, into: into, confirmed: true) }
  }

  @discardableResult
  func link(_ from: UUID, to: UUID, label: String) async -> Bool {
    await change { try await useCases.addLink(from: from, to: to, label: label) }
  }

  @discardableResult
  func photo(profile: UUID, url: URL, origin: PersonalPhotoOrigin) async -> Bool {
    guard !isBusy, hasLoaded else { return false }
    isBusy = true
    defer { isBusy = false }
    do {
      let bytes = try await imageImport(url)
      let source = PersonalMemorySource(
        text: "Image selected by owner: " + url.lastPathComponent,
        origin: "image import", kind: .conversationOnly)
      snapshot = try await useCases.setPhoto(
        profileID: profile, data: bytes, origin: origin, source: source)
      failure = nil
      return true
    } catch PersonalImageError.tooLarge { failure = .imageTooLarge } catch PersonalImageError
      .invalidImage
    { failure = .invalidImage } catch { failure = .storage }
    return false
  }

  func exportArchive() async -> Bool {
    guard !isBusy, hasLoaded else { return false }
    isBusy = true
    defer { isBusy = false }
    do {
      exportedArchive = try await useCases.exportArchive()
      failure = nil
      return true
    } catch {
      failure = .storage
      return false
    }
  }

  func finishExport(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      exportedArchive = nil
      failure = nil
    case .failure(let error):
      if isFileCancellation(error) { exportedArchive = nil } else { failure = .storage }
    }
  }

  func fileOperationFailed(_ error: Error) {
    if !isFileCancellation(error) { failure = .storage }
  }

  private func isFileCancellation(_ error: Error) -> Bool {
    let cocoa = error as NSError
    return cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError
  }

  func restoreArchive(_ url: URL) async {
    guard let archiveRestore else {
      failure = .invalidAction
      return
    }
    _ = await change { try await archiveRestore(url) }
  }

  func currentReplacement(for entryID: UUID) -> PersonalMemoryEntry? {
    let entries = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.id, $0) })
    guard let entry = entries[entryID] else { return nil }
    var current = entry
    var visited: Set<UUID> = []
    while let id = current.supersededByID, visited.insert(current.id).inserted,
      let next = entries[id]
    {
      current = next
    }
    return current.id != entry.id && current.supersededByID == nil ? current : nil
  }

  func dismissFailure() { failure = nil }
  func forgetSource(_ id: UUID) async -> Bool {
    await change { try await useCases.forgetSource(sourceID: id, confirmed: true) }
  }
  func undo() async { _ = await change { try await useCases.undo() } }
}
