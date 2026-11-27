import ChatCore
import Foundation
import MemoryCore
import MemorySQLite
import PersonalMemoryExtraction

struct PersonalChatRecorder: ChatMemoryRecording {
  let useCases: PersonalMemoryUseCases
  var organizer: (any PersonalMemoryOrganizing)? = nil

  func preserve(conversationID: UUID, messageID: UUID, text: String, createdAt: Date) async throws {
    _ = try await useCases.ingest(
      source: PersonalMemorySource(
        id: messageID, conversationID: conversationID, text: text, createdAt: createdAt))
    await organizer?.refresh()
  }

  func willGenerate() async { await organizer?.pause() }

  func didFinish(conversationID: UUID) async {
    await organizer?.resume(conversationID: conversationID)
  }
}

enum PersonalMemoryComposition {
  /// No evaluated model/prompt has passed the independent semantic adoption gate.
  static let automaticMemoryQualified = false
  static func makeUseCases(
    directory: URL = URL.applicationSupportDirectory.appending(path: "PersonalMemory")
  )
    -> PersonalMemoryUseCases
  {
    PersonalMemoryUseCases(
      repository: FilePersonalMemoryRepository(url: directory.appending(path: "memory.json")))
  }

  @MainActor static func makeViewModel(
    _ useCases: PersonalMemoryUseCases, organizer: (any PersonalMemoryOrganizing)? = nil,
    invalidateDerived: @escaping @Sendable () async throws -> Void = {}
  )
    -> PersonalMemoryViewModel
  {
    PersonalMemoryViewModel(
      useCases: useCases, imageImport: ImportPersonalImage(reader: PersonalImageReader()),
      archiveRestore: RestorePersonalMemoryArchive(
        useCases: useCases,
        reader: LocalArchiveFileReader(maximumBytes: PersonalMemoryLimits.archiveBytes)),
      organizer: organizer, automaticMemoryUnavailable: !automaticMemoryQualified,
      invalidateDerived: invalidateDerived)
  }

  static func makeOrganizer(
    _ useCases: PersonalMemoryUseCases, model: any StructuredChatModel
  ) -> any PersonalMemoryOrganizing {
    AutomaticPersonalMemoryOrganizer(
      useCases: useCases,
      analyzer: QualifiedPersonalMemoryAnalyzer(
        base: LocalPersonalMemoryAnalyzer(model: model), qualified: automaticMemoryQualified))
  }
}

private struct QualifiedPersonalMemoryAnalyzer: PersonalMemoryAnalyzing {
  let base: any PersonalMemoryAnalyzing
  let qualified: Bool

  func analyze(_ input: PersonalMemoryAnalysisInput) async throws -> PersonalMemoryAnalysis {
    guard qualified else { throw PersonalMemoryAnalysisRuntimeError.unqualified }
    return try await base.analyze(input)
  }
}
