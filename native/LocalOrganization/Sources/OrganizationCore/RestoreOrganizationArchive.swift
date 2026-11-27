import Foundation
import MemoryCore

/// The file boundary stays replaceable; the use case validates bytes and stable references.
public struct RestoreOrganizationArchive: Sendable {
  private let useCases: OrganizationUseCases
  private let reader: any ArchiveDataReader

  public init(useCases: OrganizationUseCases, reader: any ArchiveDataReader) {
    self.useCases = useCases
    self.reader = reader
  }

  public func execute(_ url: URL) async throws -> OrganizationSnapshot {
    let data = try await reader.readArchive(at: url)
    return try await useCases.restoreArchive(data)
  }
}
