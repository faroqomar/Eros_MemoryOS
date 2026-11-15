import AIEvaluationCore
import Foundation

actor LabReportWriter: EvaluationReportWriting {
  private let directory: URL
  init(directory: URL) { self.directory = directory }

  func write(_ report: EvaluationReport) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = report.configuration.id + "-" + UUID().uuidString + ".json"
    try report.jsonData().write(to: directory.appendingPathComponent(name), options: .atomic)
  }
}
