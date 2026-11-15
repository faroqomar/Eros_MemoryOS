import AIEvaluationCore
import Foundation
import Testing
import WaxEvaluationAdapter

struct WaxMemoryIndexAdapterTests {
  @Test func retrievesCanonicalUnicodeIDsAndPreservesIdenticalSources() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let adapter = WaxMemoryIndexAdapter(directory: root)
    let arabicID = "شخص-نور-١"
    let sources = [
      SourceRecord(id: arabicID, text: "Nour remembers the turquoise notebook.", language: "mixed"),
      SourceRecord(id: "duplicate", text: "Nour remembers the turquoise notebook.", language: "en"),
      SourceRecord(id: "other", text: "Samir bought a camera.", language: "en"),
    ]
    try await adapter.rebuild(records: sources)
    let result = try await adapter.search(query: "turquoise", limit: 10)
    #expect(Set(result.map(\.sourceID)) == [arabicID, "duplicate"])
    #expect(
      result.first(where: { $0.sourceID == arabicID })?.sourceID.utf8.elementsEqual(arabicID.utf8)
        == true)
    #expect(sources[0].text == "Nour remembers the turquoise notebook.")
    try await adapter.close()
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
  }

  @Test func rebuildRetractsRemovedAndCorrectedSourcesWithoutDeletingOtherFiles() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let retained = root.appendingPathComponent("canonical-source.txt")
    let original = Data("Original record stays outside provider ownership.".utf8)
    try original.write(to: retained)
    let adapter = WaxMemoryIndexAdapter(directory: root)
    try await adapter.rebuild(records: [
      .init(id: "removed", text: "Copper lantern", language: "en"),
      .init(id: "corrected", text: "Birthday is December", language: "en"),
    ])
    #expect(try await adapter.search(query: "Copper", limit: 5).map(\.sourceID) == ["removed"])
    try await adapter.rebuild(records: [
      .init(id: "corrected", text: "Birthday is September", language: "en", revision: 2)
    ])
    #expect(try await adapter.search(query: "Copper", limit: 5).isEmpty)
    #expect(try await adapter.search(query: "December", limit: 5).isEmpty)
    #expect(try await adapter.search(query: "September", limit: 5).map(\.sourceID) == ["corrected"])
    try await adapter.close()
    #expect(try Data(contentsOf: retained) == original)
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: root.path) == ["canonical-source.txt"])
  }

  @Test func rejectsUnavailableAndInvalidInputsAndRetainsPreviousIndex() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let adapter = WaxMemoryIndexAdapter(directory: root)
    await #expect(throws: EvaluationError.self) {
      _ = try await adapter.search(query: "birthday", limit: 5)
    }
    try await adapter.rebuild(records: [
      .init(id: "valid", text: "Purple birthday card", language: "en")
    ])
    await #expect(throws: EvaluationError.self) {
      try await adapter.rebuild(records: [
        .init(id: "duplicate", text: "One", language: "en"),
        .init(id: "duplicate", text: "Two", language: "en"),
      ])
    }
    #expect(try await adapter.search(query: "Purple", limit: 1).map(\.sourceID) == ["valid"])
    await #expect(throws: EvaluationError.self) {
      _ = try await adapter.search(query: "", limit: 5)
    }
    await #expect(throws: EvaluationError.self) {
      _ = try await adapter.search(query: "Purple", limit: 0)
    }
    try await adapter.rebuild(records: [])
    #expect(try await adapter.search(query: "Purple", limit: 5).isEmpty)
    try await adapter.close()
  }

  @Test func preservesArabicAndMixedLanguageLexicalSearch() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let adapter = WaxMemoryIndexAdapter(directory: root)
    try await adapter.rebuild(records: [
      .init(id: "عربي", text: "نور اشترت دفتر أزرق", language: "ar"),
      .init(id: "mixed", text: "سارة تراجع Project Atlas يوم الخميس", language: "mixed"),
    ])
    #expect(try await adapter.search(query: "دفتر", limit: 5).map(\.sourceID) == ["عربي"])
    #expect(try await adapter.search(query: "Atlas", limit: 5).map(\.sourceID) == ["mixed"])
    try await adapter.close()
  }

  @Test func storageFailurePreservesCallerOwnedFile() async throws {
    let file = temporaryRoot()
    let original = Data("Caller-owned original record".utf8)
    try original.write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let adapter = WaxMemoryIndexAdapter(directory: file)
    await #expect(throws: CocoaError.self) {
      try await adapter.rebuild(records: [
        .init(id: "fictional", text: "Amber notebook", language: "en")
      ])
    }
    #expect(try Data(contentsOf: file) == original)
    try await adapter.close()
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "memoryos-wax-tests-" + UUID().uuidString)
  }
}
