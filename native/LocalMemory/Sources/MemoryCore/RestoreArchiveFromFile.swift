import Foundation

public protocol ArchiveDataReader: Sendable {
  func readArchive(at url: URL) async throws -> Data
}

public struct RestoreArchiveFromFile: Sendable {
  private let useCases: LocalMemoryUseCases
  private let reader: any ArchiveDataReader

  public init(useCases: LocalMemoryUseCases, reader: any ArchiveDataReader) {
    self.useCases = useCases
    self.reader = reader
  }

  public func execute(_ url: URL) async throws {
    let data = try await reader.readArchive(at: url)
    try await useCases.restoreArchive(data)
  }
}
