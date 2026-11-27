import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

struct RelationshipReportRepositoryTests {
  @Test func fileCleanupRemovesOnlyObservedVersionsAndKeepsNewerReportOnReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "reports.json")
    let repository = FileRelationshipReportRepository(url: url)
    func report(_ question: String, _ date: TimeInterval) -> RelationshipSavedReport {
      .init(
        revision: 1, request: .init(sourceIDs: [], question: question), proposal: .init(),
        createdAt: Date(timeIntervalSince1970: date))
    }
    let observed = report("Earlier question", 100)
    let replacement = report("Earlier question", 101)
    let retained = report("Another question", 102)
    try await repository.save(observed)
    try await repository.save(replacement)
    try await repository.save(retained)
    try await repository.remove([observed])
    #expect(try await repository.load() == [replacement, retained])
    try await repository.remove([replacement])
    #expect(try await FileRelationshipReportRepository(url: url).load() == [retained])
    try await repository.remove([retained])
    #expect(try await repository.load().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }
}
