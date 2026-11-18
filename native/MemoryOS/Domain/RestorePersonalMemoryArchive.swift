import Foundation
import MemoryCore

struct RestorePersonalMemoryArchive: Sendable {
  let useCases: PersonalMemoryUseCases
  let reader: any ArchiveDataReader
  func callAsFunction(_ url: URL) async throws -> PersonalMemorySnapshot {
    try await useCases.restoreArchive(try await reader.readArchive(at: url))
  }
}
