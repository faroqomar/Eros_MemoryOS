import Foundation
import MemoryCore
import Observation

/// Feature state. Storage details enter only through app-owned use cases.
@MainActor
@Observable
final class LocalRecordsViewModel {
  private var useCases: LocalMemoryUseCases?
  private var archiveRestore: RestoreArchiveFromFile?
  private let provider: (any LocalMemorySessionProvider)?
  private(set) var records: [LocalRecord] = []
  private(set) var links: [MemoryCore.RecordLink] = []
  private(set) var isBusy = false
  private(set) var hasLoaded = false
  private(set) var error: LocalMemoryError?
  var failure: Bool { error != nil }
  var archiveData: Data?

  init(useCases: LocalMemoryUseCases?, archiveRestore: RestoreArchiveFromFile? = nil) {
    self.provider = nil
    self.archiveRestore = archiveRestore
    self.useCases = useCases
    error = useCases == nil ? .storageFailure : nil
  }

  init(provider: any LocalMemorySessionProvider) {
    self.provider = provider
    useCases = nil
    archiveRestore = nil
  }

  var activeRecords: [LocalRecord] { records.filter { $0.deletedAt == nil } }
  var trashedRecords: [LocalRecord] { records.filter { $0.deletedAt != nil } }

  func record(_ id: UUID) -> LocalRecord? { records.first { $0.id == id } }
  func connected(to id: UUID) -> [LocalRecord] {
    let ids = Set(
      links.compactMap { link in
        link.fromID == id ? link.toID : link.toID == id ? link.fromID : nil
      })
    return activeRecords.filter { ids.contains($0.id) }
  }

  func load() async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      if useCases == nil, let provider {
        let session = try await provider.open()
        useCases = session.useCases
        archiveRestore = session.archiveRestore
      }
      guard let useCases else { throw LocalMemoryError.storageFailure }
      try await refresh(useCases)
      error = nil
    } catch { self.error = (error as? LocalMemoryError) ?? .storageFailure }
  }

  func create(kind: RecordKind, text: String) async -> Bool {
    guard let useCases else {
      error = .storageFailure
      return false
    }
    return await mutate { _ = try await useCases.create(kind: kind, text: text) }
  }

  func correct(id: UUID, text: String) async -> Bool {
    guard let useCases else {
      error = .storageFailure
      return false
    }
    return await mutate { try await useCases.correct(id: id, text: text) }
  }

  func setDeleted(id: UUID, deleted: Bool) async -> Bool {
    guard let useCases else {
      error = .storageFailure
      return false
    }
    return await mutate { try await useCases.setDeleted(id: id, deleted: deleted) }
  }

  func link(from: UUID, to: UUID) async -> Bool {
    guard let useCases else {
      error = .storageFailure
      return false
    }
    return await mutate { try await useCases.link(from: from, to: to) }
  }

  func export() async {
    guard !isBusy, let useCases else {
      error = .storageFailure
      return
    }
    isBusy = true
    defer { isBusy = false }
    archiveData = nil
    do {
      archiveData = try await useCases.exportArchive()
      error = nil
    } catch { self.error = (error as? LocalMemoryError) ?? .storageFailure }
  }

  func importArchive(from url: URL) async -> Bool {
    guard let archiveRestore else {
      error = .storageFailure
      return false
    }
    return await mutate { try await archiveRestore.execute(url) }
  }

  func reportFileFailure() { error = .storageFailure }

  private func mutate(_ action: () async throws -> Void) async -> Bool {
    guard !isBusy, hasLoaded, let useCases else {
      error = .storageFailure
      return false
    }
    isBusy = true
    defer { isBusy = false }
    do {
      try await action()
    } catch {
      self.error = (error as? LocalMemoryError) ?? .storageFailure
      return false
    }
    // The write committed. A failed reread must not invite another create.
    do {
      try await refresh(useCases)
      error = nil
    } catch { self.error = (error as? LocalMemoryError) ?? .storageFailure }
    return true
  }

  private func refresh(_ useCases: LocalMemoryUseCases) async throws {
    let snapshot = try await useCases.snapshot()
    records = snapshot.records.sorted { $0.createdAt > $1.createdAt }
    links = snapshot.links
    hasLoaded = true
  }
}
