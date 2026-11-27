import ChatCore
import Foundation
import MemoryCore

enum RelationshipComposition {
  static func makeUseCases(memory: PersonalMemoryUseCases, model: any StructuredChatModel)
    -> RelationshipUnderstandingUseCases
  {
    RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model),
      reports: FileRelationshipReportRepository(
        url: URL.applicationSupportDirectory.appending(path: "RelationshipReports/review.json")))
  }
}

/// Rebuildable analysis only. The canonical originals stay in MemoryCore storage.
actor FileRelationshipReportRepository: RelationshipReportRepository {
  private let url: URL
  init(url: URL) { self.url = url }
  func load() throws -> [RelationshipSavedReport] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 256_000 else {
      throw RelationshipUnderstandingError.inputTooLarge
    }
    return try JSONDecoder().decode([RelationshipSavedReport].self, from: Data(contentsOf: url))
  }
  func save(_ report: RelationshipSavedReport) throws {
    let retained = try RelationshipSavedReport.retaining(report, in: load())
    try write(retained)
  }
  func remove(_ reports: [RelationshipSavedReport]) throws {
    let existing = try load()
    let retained = try RelationshipSavedReport.removing(reports, from: existing)
    guard retained.count != existing.count else { return }
    if retained.isEmpty {
      try removeAll()
    } else {
      try write(retained)
    }
  }
  private func write(_ retained: [RelationshipSavedReport]) throws {
    let data = try JSONEncoder().encode(retained)
    guard data.count <= 256_000 else { throw RelationshipUnderstandingError.inputTooLarge }
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var excluded = directory
    try excluded.setResourceValues(values)
    try data.write(to: url, options: [.atomic, .completeFileProtection])
  }
  func removeAll() throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
