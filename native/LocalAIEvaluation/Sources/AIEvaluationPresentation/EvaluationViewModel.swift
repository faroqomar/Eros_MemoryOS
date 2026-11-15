import AIEvaluationCore
import Foundation
import Observation

/// Presentation state only. The injected use case owns adapters, records and evaluation rules.
@MainActor @Observable
public final class EvaluationViewModel {
  @ObservationIgnored private let evaluator: any EvaluationRunning
  @ObservationIgnored private let validCandidateIDs: Set<String>
  @ObservationIgnored private var activeRun: Task<Void, Never>?

  public private(set) var running = false
  public private(set) var report: EvaluationReport?
  public private(set) var exportData: Data?
  public private(set) var message: String?
  public private(set) var selectedID: String
  public private(set) var progress: EvaluationProgress?

  public init(
    evaluator: any EvaluationRunning, validCandidateIDs: [String],
    selectedID: String = "keyword-control"
  ) {
    self.evaluator = evaluator
    self.validCandidateIDs = Set(validCandidateIDs)
    self.selectedID = selectedID
  }

  public func select(_ id: String) {
    guard !running, validCandidateIDs.contains(id) else { return }
    selectedID = id
    report = nil
    exportData = nil
    message = nil
    progress = nil
  }

  @discardableResult
  public func run() -> Task<Void, Never>? {
    guard !running else { return nil }
    guard validCandidateIDs.contains(selectedID) else {
      message = "Choose an available evaluation configuration. / اختر إعداد اختبار متاحًا."
      return nil
    }
    running = true
    progress = nil
    report = nil
    exportData = nil
    message = nil
    let candidateID = selectedID
    let task = Task { [weak self, evaluator] in
      do {
        try Task.checkCancellation()
        let result = try await evaluator.run(
          candidateID: candidateID,
          progress: { [weak self] value in
            await self?.recordProgress(value)
          })
        try Task.checkCancellation()
        let data = try result.jsonData()
        self?.report = result
        self?.exportData = data
      } catch {
        self?.report = nil
        self?.exportData = nil
        if error is CancellationError || Task.isCancelled {
          self?.message = "Cancelled. No final result. / أُلغي الاختبار."
        } else {
          // Provider diagnostics may contain payloads or local paths. Keep this UI message bounded.
          self?.message =
            "The evaluation failed. Check the prepared local assets and retry. / تعذّر الاختبار. تحقق من ملفات النموذج المحلية ثم أعد المحاولة."
        }
      }
      self?.running = false
      self?.activeRun = nil
    }
    activeRun = task
    return task
  }

  public func cancel() {
    guard let activeRun else { return }
    activeRun.cancel()
    report = nil
    exportData = nil
    message = "Cancelling… / جارٍ الإلغاء…"
    // Keep running true until the use case returns. A non-cooperative runtime must not overlap a rerun.
  }

  private func recordProgress(_ value: EvaluationProgress) {
    guard running, !Task.isCancelled else { return }
    progress = value
  }
}
