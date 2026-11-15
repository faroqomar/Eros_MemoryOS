import ChatCore
import Foundation
import Observation

/// UI state calls use cases only. No provider, database, or filesystem API enters this module.
@MainActor @Observable
public final class ChatViewModel {
  public private(set) var snapshot = ChatSnapshot()
  public private(set) var isLoading = false
  public private(set) var isTransitioning = false
  public private(set) var hasLoaded = false
  public private(set) var isGenerating = false
  public private(set) var isStopping = false
  public private(set) var lastCancellationSeconds: Double?
  public private(set) var firstUsableTextSeconds: Double?
  public private(set) var error: ChatError?
  private var localDraft = ""
  private var localMemoryMode = false
  @ObservationIgnored private let useCases: ChatUseCases
  @ObservationIgnored private var draftSave: Task<Void, Never>?
  @ObservationIgnored private var generation: Task<Void, Never>?
  @ObservationIgnored private var generationToken: UUID?
  @ObservationIgnored private var receivedGenerationStart = false
  @ObservationIgnored private var generationStarted: ContinuousClock.Instant?
  @ObservationIgnored private var priorReplyText: String?
  @ObservationIgnored private var stopInstant: ContinuousClock.Instant?

  public init(useCases: ChatUseCases) { self.useCases = useCases }

  public var conversations: [ChatConversation] { snapshot.conversations }
  public var currentConversation: ChatConversation? {
    snapshot.conversations.first { $0.id == snapshot.selectedID }
  }
  public var draft: String {
    get { localDraft }
    set {
      guard hasLoaded, !isLoading, !isTransitioning else { return }
      localDraft = newValue
      scheduleDraftSave()
    }
  }
  public var memoryMode: Bool {
    get { localMemoryMode }
    set {
      guard hasLoaded, !isLoading, !isTransitioning else { return }
      localMemoryMode = newValue
      scheduleDraftSave()
    }
  }
  public var canSend: Bool {
    hasLoaded && !isLoading && !isTransitioning && !isGenerating
      && !localDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && localDraft.utf8.count <= ChatLimits.draftBytes
  }

  public func clearError() { error = nil }

  public func load() async {
    guard !isLoading, !hasLoaded else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      apply(try await useCases.load(), replaceInput: true)
      hasLoaded = true
      error = nil
    } catch { report(error) }
  }

  private func apply(_ state: ChatSnapshot, replaceInput: Bool = false) {
    guard state.revision >= snapshot.revision else { return }
    snapshot = state
    if replaceInput {
      localDraft = currentConversation?.draft ?? ""
      localMemoryMode = currentConversation?.memoryMode ?? false
    }
  }

  private func report(_ failure: Error) {
    if !(failure is CancellationError) { error = (failure as? ChatError) ?? .generationFailed }
  }

  private func scheduleDraftSave() {
    draftSave?.cancel()
    guard hasLoaded, let id = snapshot.selectedID else { return }
    let draft = localDraft
    let memoryMode = localMemoryMode
    draftSave = Task { [weak self, useCases] in
      do {
        try await Task.sleep(for: .milliseconds(180))
        let state = try await useCases.updateDraft(
          draft, memoryMode: memoryMode, conversationID: id)
        guard let self else { return }
        // An autosave must not replace newer input or a generation update.
        if state.revision >= self.snapshot.revision { self.apply(state) }
      } catch { if let self { self.report(error) } }
    }
  }

  @discardableResult public func flushDraft() async -> Bool {
    draftSave?.cancel()
    draftSave = nil
    guard hasLoaded, let id = snapshot.selectedID else { return false }
    do {
      let state = try await useCases.updateDraft(
        localDraft, memoryMode: localMemoryMode, conversationID: id)
      if state.revision >= snapshot.revision { apply(state) }
      if error == .storage { error = nil }
      return true
    } catch {
      report(error)
      return false
    }
  }

  public func newConversation() async {
    guard !isLoading, !isTransitioning, !isGenerating else { return }
    isTransitioning = true
    defer { isTransitioning = false }
    guard await flushDraft() else { return }
    do {
      apply(try await useCases.newConversation(), replaceInput: true)
      error = nil
    } catch { report(error) }
  }

  public func open(_ id: UUID) async {
    guard !isLoading, !isTransitioning, !isGenerating else { return }
    isTransitioning = true
    defer { isTransitioning = false }
    guard await flushDraft() else { return }
    do {
      apply(try await useCases.open(id), replaceInput: true)
      error = nil
    } catch { report(error) }
  }

  public func rename(_ id: UUID, title: String) async {
    guard !isLoading, !isTransitioning else { return }
    isTransitioning = true
    defer { isTransitioning = false }
    do {
      apply(try await useCases.rename(id, title: title))
      error = nil
    } catch { report(error) }
  }

  public func delete(_ id: UUID) async {
    guard !isLoading, !isTransitioning, !isGenerating else { return }
    isTransitioning = true
    defer { isTransitioning = false }
    guard await flushDraft() else { return }
    do {
      apply(try await useCases.delete(id), replaceInput: true)
      error = nil
    } catch { report(error) }
  }

  public func send() async {
    guard canSend else { return }
    await run(reusingReply: false)
  }

  public func retry() async {
    guard !isTransitioning, !isLoading, !isGenerating,
      let last = currentConversation?.messages.last, last.role == .assistant,
      last.status != .complete
    else { return }
    await run(reusingReply: true)
  }

  public func regenerate() async {
    guard !isTransitioning, !isLoading, !isGenerating,
      currentConversation?.messages.last?.role == .assistant
    else { return }
    await run(reusingReply: true)
  }

  private func run(reusingReply: Bool) async {
    guard !isTransitioning, !isLoading, !isGenerating else { return }
    isGenerating = true
    isStopping = false
    generationStarted = .now
    priorReplyText = reusingReply ? currentConversation?.messages.last?.text : nil
    firstUsableTextSeconds = nil
    lastCancellationSeconds = nil
    stopInstant = nil
    error = nil
    let submittedDraft = localDraft
    guard await flushDraft() else {
      isGenerating = false
      isStopping = false
      return
    }
    let token = UUID()
    generationToken = token
    receivedGenerationStart = false
    let task = Task { [weak self, useCases] in
      do {
        let state = try await useCases.generate(
          submittedText: reusingReply ? nil : submittedDraft, reusingReply: reusingReply
        ) { [weak self] state in
          await self?.receive(
            state, token: token, submittedDraft: reusingReply ? nil : submittedDraft)
        }
        self?.apply(state)
      } catch { self?.report(error) }
      guard let self, self.generationToken == token else { return }
      if let stopInstant = self.stopInstant {
        let duration = stopInstant.duration(to: .now)
        self.lastCancellationSeconds =
          Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
      }
      self.isGenerating = false
      self.isStopping = false
      self.generation = nil
      self.generationToken = nil
    }
    generation = task
    if isStopping { task.cancel() }
    await task.value
  }

  private func receive(_ state: ChatSnapshot, token: UUID, submittedDraft: String?) {
    guard generationToken == token else { return }
    if firstUsableTextSeconds == nil,
      let reply = state.conversations.first(where: { $0.id == state.selectedID })?.messages.last,
      reply.role == .assistant, !reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      priorReplyText == nil || reply.text != priorReplyText,
      let generationStarted
    {
      let duration = generationStarted.duration(to: .now)
      firstUsableTextSeconds =
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
    let first = !receivedGenerationStart
    receivedGenerationStart = true
    apply(state)
    if first, let submittedDraft, localDraft.utf8.elementsEqual(submittedDraft.utf8) {
      localDraft = ""
    }
  }

  public func stop() {
    guard isGenerating else { return }
    if !isStopping { stopInstant = .now }
    isStopping = true
    generation?.cancel()
  }

  /// Call for backgrounding or memory pressure. Native work joins before weights unload.
  public func interrupt() async {
    stop()
    await generation?.value
    await flushDraft()
    await useCases.unload()
  }
}
