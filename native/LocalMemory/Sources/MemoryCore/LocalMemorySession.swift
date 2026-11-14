import Foundation

/// App-owned use cases available after a successful local store connection.
public struct LocalMemorySession: Sendable {
  public let useCases: LocalMemoryUseCases
  public let archiveRestore: RestoreArchiveFromFile

  public init(useCases: LocalMemoryUseCases, archiveRestore: RestoreArchiveFromFile) {
    self.useCases = useCases
    self.archiveRestore = archiveRestore
  }
}

/// Opening can fail and retry without replacing feature state or unsaved input.
public protocol LocalMemorySessionProvider: Sendable {
  func open() async throws -> LocalMemorySession
}
