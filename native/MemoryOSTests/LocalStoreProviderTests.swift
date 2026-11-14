import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

@MainActor
struct LocalStoreProviderTests {
  @Test func blockedDirectoryCanRecoverInSameFeatureInstance() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    let directory = base.appending(path: "LocalRecords")
    try Data("fictional directory blocker".utf8).write(to: directory)
    let model = LocalRecordsViewModel(provider: LocalStoreProvider(directory: directory))
    model.draft = "Unsaved source / مصدر"
    await model.load()
    #expect(model.failure)
    #expect(!model.hasLoaded)
    #expect(model.draft == "Unsaved source / مصدر")
    try FileManager.default.removeItem(at: directory)
    await model.load()
    #expect(!model.failure)
    #expect(model.canSave)
    #expect(await model.saveCapture())
    let reopened = LocalRecordsViewModel(provider: LocalStoreProvider(directory: directory))
    await reopened.load()
    #expect(reopened.records.first?.id == model.records.first?.id)
    #expect(reopened.records.first?.originalText == "Unsaved source / مصدر")
  }
}
