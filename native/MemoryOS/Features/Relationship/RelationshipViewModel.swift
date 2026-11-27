import Foundation
import MemoryCore
import Observation

@MainActor @Observable
final class RelationshipViewModel {
  private(set) var snapshot = PersonalMemorySnapshot()
  private(set) var result: RelationshipUnderstandingResult?
  private(set) var savedReports: [RelationshipUnderstandingResult] = []
  private(set) var insights: [RelationshipProactiveInsight] = []
  private(set) var isBusy = false
  private(set) var isUpdatingSavedReports = false
  private(set) var error: Failure?
  var selected: Set<UUID> = [] { didSet { if selected != oldValue { inputChanged() } } }
  var question = "" { didSet { if question != oldValue { inputChanged() } } }
  var ownerInterpretation = "" { didSet { if ownerInterpretation != oldValue { inputChanged() } } }
  var relationship: RelationshipKind = .unspecified {
    didSet { if relationship != oldValue { inputChanged() } }
  }
  var mode: Mode = .discussion { didSet { if mode != oldValue { inputChanged() } } }
  var answerInArabic = false { didSet { if answerInArabic != oldValue { inputChanged() } } }
  @ObservationIgnored private let useCases: RelationshipUnderstandingUseCases
  @ObservationIgnored private var operation: Task<RelationshipUnderstandingResult, Error>?
  @ObservationIgnored private var generation: UInt64 = 0

  enum Failure { case storage, selection, tooLarge, invalidEvidence, stale, unavailable }
  enum Mode: String, CaseIterable, Identifiable {
    case discussion, patterns, advice, draft, conversation, topic, period
    var id: String { rawValue }
    var instruction: String {
      switch self {
      case .discussion:
        "Explain agreements, disagreements, unresolved issues, commitments, repair attempts and changes supported by this selection."
      case .patterns:
        "Describe a possible communication or emotional pattern, alternatives and counterevidence. Treat it as a hypothesis."
      case .advice:
        "Suggest a respectful next step, cite evidence and explain tradeoffs. Leave the decision to me."
      case .draft:
        "Draft a respectful optional reply based on these sources and explain its evidence. Do not send it."
      case .conversation: "Create a conversation-level summary with original evidence."
      case .topic: "Create a topic-level summary with original evidence."
      case .period:
        "Create a time-period summary of the selected dated records with original evidence."
      }
    }
  }

  init(useCases: RelationshipUnderstandingUseCases) { self.useCases = useCases }
  deinit { operation?.cancel() }

  func load() async {
    let token = generation
    let previousResult = result
    do {
      let current = try await useCases.memory.snapshot()
      let reports = try await useCases.loadSaved()
      let previousIsCurrent =
        if let previousResult { try await useCases.isCurrent(previousResult) } else { true }
      guard token == generation, !Task.isCancelled else { return }
      snapshot = current
      savedReports = reports
      insights = RelationshipInsightProjector.project(current)
      selected.formIntersection(Set(current.sources.map(\.id)))
      if !previousIsCurrent {
        self.result = nil
        self.error = .stale
      } else if error == .storage {
        error = nil
      }
    } catch {
      guard token == generation, !Task.isCancelled else { return }
      result = nil
      savedReports = []
      insights = []
      self.error = .storage
    }
  }

  func invalidate() {
    result = nil
    error = nil
  }

  private func inputChanged() {
    cancel()
    invalidate()
  }

  func saveReport() async {
    guard let result, !isBusy, !isUpdatingSavedReports else { return }
    let token = generation
    isBusy = true
    isUpdatingSavedReports = true
    defer {
      isUpdatingSavedReports = false
      if token == generation { isBusy = false }
    }
    do {
      let saved = try await useCases.save(result)
      guard token == generation else { return }
      let current = try await useCases.memory.snapshot()
      let reports = try await useCases.loadSaved()
      guard token == generation else { return }
      guard try await useCases.isCurrent(saved) else {
        throw RelationshipUnderstandingError.staleResult
      }
      guard token == generation else { return }
      self.result = saved
      snapshot = current
      savedReports = reports
      error = nil
    } catch RelationshipUnderstandingError.staleResult {
      guard token == generation else { return }
      self.result = nil
      self.error = .stale
    } catch { if token == generation { self.error = .storage } }
  }

  @discardableResult
  func clearSavedReports() async -> Bool {
    guard !isUpdatingSavedReports else { return false }
    isUpdatingSavedReports = true
    defer { isUpdatingSavedReports = false }
    do {
      try await useCases.invalidateReports()
      savedReports = []
      error = nil
      return true
    } catch {
      self.error = .storage
      return false
    }
  }

  func openSaved(_ report: RelationshipUnderstandingResult) async {
    cancel()
    let token = generation
    do {
      let current = try await useCases.isCurrent(report)
      guard token == generation, !Task.isCancelled else { return }
      guard current else {
        result = nil
        self.error = .stale
        await load()
        return
      }
      selected = Set(report.input.request.sourceIDs)
      ownerInterpretation = report.input.request.ownerInterpretation ?? ""
      relationship = report.input.request.relationship
      mode = Mode(rawValue: report.input.request.focus?.rawValue ?? "discussion") ?? .discussion
      let requestQuestion = report.input.request.question
      let english = mode.instruction + "\nAnswer in English."
      let arabic = mode.instruction + "\nAnswer in Arabic."
      answerInArabic = requestQuestion.hasPrefix(arabic)
      if requestQuestion.hasPrefix(english) || requestQuestion.hasPrefix(arabic) {
        let prefix = answerInArabic ? arabic : english
        question = String(requestQuestion.dropFirst(prefix.count))
          .trimmingCharacters(in: .newlines)
      } else if requestQuestion.hasPrefix("Answer in Arabic.\n") {
        answerInArabic = true
        question = String(requestQuestion.dropFirst("Answer in Arabic.\n".count))
      } else if requestQuestion.hasPrefix("Answer in English.\n") {
        answerInArabic = false
        question = String(requestQuestion.dropFirst("Answer in English.\n".count))
      } else {
        question = requestQuestion
      }
      result = report
      error = nil
    } catch {
      guard token == generation, !Task.isCancelled else { return }
      self.error = .storage
    }
  }

  func cancel() {
    generation &+= 1
    operation?.cancel()
    operation = nil
    isBusy = false
  }

  func analyze() async {
    guard !isBusy else { return }
    invalidate()
    guard !selected.isEmpty else {
      self.error = .selection
      return
    }
    generation &+= 1
    let token = generation
    let language = answerInArabic ? "Answer in Arabic." : "Answer in English."
    // The typed focus already selects the analysis task. Prepending every discussion
    // category to a specific question made the audit demand unrelated answers.
    let scopedQuestion =
      question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? mode.instruction + "\n" + language
      : language + "\n" + question
    let request = RelationshipAnalysisRequest(
      sourceIDs: selected.sorted { $0.uuidString < $1.uuidString },
      question: scopedQuestion,
      ownerInterpretation: ownerInterpretation.trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty ? nil : ownerInterpretation,
      draftRequested: mode == .draft, relationship: relationship,
      focus: RelationshipAnalysisFocus(rawValue: mode.rawValue))
    isBusy = true
    let operation = Task { try await useCases.analyze(request) }
    self.operation = operation
    defer {
      if token == generation {
        isBusy = false
        self.operation = nil
      }
    }
    do {
      let report = try await operation.value
      guard token == generation else { return }
      result = report
    } catch is CancellationError {
      // A cancelled request retains no partial interpretation.
    } catch RelationshipUnderstandingError.inputTooLarge {
      if token == generation { self.error = .tooLarge }
    } catch RelationshipUnderstandingError.staleResult {
      if token == generation { self.error = .stale }
    } catch RelationshipUnderstandingError.invalidRequest {
      if token == generation { self.error = .selection }
    } catch is RelationshipUnderstandingError {
      if token == generation { self.error = .invalidEvidence }
    } catch { if token == generation { self.error = .unavailable } }
  }
}
