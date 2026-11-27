import ChatCore
import ChatPresentation
import Foundation
import RetrievalCore
import Testing

@testable import MemoryOS

private actor ClarificationChatRepository: ChatRepository {
  private var value = ChatSnapshot()
  func load() -> ChatSnapshot { value }
  func save(_ value: ChatSnapshot) { self.value = value }
}

private actor ClarificationRecorder: ChatMemoryRecording {
  private(set) var originals: [UUID: String] = [:]
  func preserve(conversationID: UUID, messageID: UUID, text: String, createdAt: Date) {
    originals[messageID] = text
  }
}

private struct ClarificationCandidates: MemorySearching {
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.prefix(limit).map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
  }
}

private actor ClarificationModel: StructuredChatModel {
  private var entered = false
  private var waiting: CheckedContinuation<Void, Never>?
  private var release: CheckedContinuation<Void, Never>?
  private(set) var structuredCalls = 0
  private(set) var replyCalls = 0

  func waitForPreflight() async {
    if entered { return }
    await withCheckedContinuation { waiting = $0 }
  }

  func releasePreflight() {
    release?.resume()
    release = nil
  }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async -> String {
    structuredCalls += 1
    if !entered {
      entered = true
      waiting?.resume()
      waiting = nil
      await withCheckedContinuation { release = $0 }
    }
    if grammar.contains("resolution") {
      return
        #"{"assessment":"The named subject is unresolved.","resolution":"unresolved"}"#
    }
    return #"{"assessment":"No unique name resolved.","subjects":[]}"#
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    replyCalls += 1
    Issue.record("An unresolved subject must not reach reply generation")
  }

  func unload() {}
}

@MainActor struct ChatClarificationRecoveryTests {
  @Test(arguments: [false, true])
  func actualRecallPreflightPreservesOriginalAndDraftWithoutGeneratingAReply(recording: Bool)
    async throws
  {
    let repository = ClarificationChatRepository()
    let model = ClarificationModel()
    let recorder = ClarificationRecorder()
    let source = MemorySearchRecord(id: UUID().uuidString, text: "Maya meets Friday.")
    let recall = LocalChatMemory(
      search: ClarificationCandidates(), relevance: SourceBoundedChatEvidenceFilter(model: model),
      readRecords: { [source] })
    let useCases = ChatUseCases(
      repository: repository, model: model, memory: recall, recorder: recording ? recorder : nil)
    let viewModel = ChatViewModel(useCases: useCases)
    await viewModel.load()
    let question = "When is Nora's meeting? Cafe\u{301}"
    let nextDraft = "Separate unsent draft · مسودة جديدة"
    viewModel.draft = question
    let sending = Task { await viewModel.send() }
    await model.waitForPreflight()
    if recording { viewModel.draft = nextDraft }
    await model.releasePreflight()
    await sending.value

    #expect(viewModel.error == .memorySubjectUnclear)
    #expect(!viewModel.isGenerating)
    #expect(await model.replyCalls == 0)
    #expect(await model.structuredCalls == 2)
    let beforeRetry = try #require(viewModel.currentConversation)
    if recording {
      let original = try #require(beforeRetry.messages.first)
      #expect(original.role == .user && original.text.utf8.elementsEqual(question.utf8))
      #expect(await recorder.originals[original.id]?.utf8.elementsEqual(question.utf8) == true)
      #expect(beforeRetry.messages.count == 2)
      #expect(beforeRetry.messages.last?.status == .failed)
      #expect(beforeRetry.messages.last?.text.isEmpty == true)
      #expect(beforeRetry.messages.last?.sources.isEmpty == true)
      #expect(viewModel.draft.utf8.elementsEqual(nextDraft.utf8))
      #expect(await viewModel.flushDraft())
      await viewModel.retry()
      #expect(viewModel.currentConversation?.messages.map(\.id) == beforeRetry.messages.map(\.id))
      #expect(await recorder.originals.count == 1)
      #expect(viewModel.draft.utf8.elementsEqual(nextDraft.utf8))
      let durable = await repository.load()
      #expect(durable.conversations.first?.draft.utf8.elementsEqual(nextDraft.utf8) == true)
      #expect(
        durable.conversations.first?.messages.first?.text.utf8.elementsEqual(question.utf8) == true)
    } else {
      #expect(beforeRetry.messages.isEmpty)
      #expect(viewModel.draft.utf8.elementsEqual(question.utf8))
      await viewModel.send()
      #expect(viewModel.currentConversation?.messages.isEmpty == true)
      #expect(viewModel.draft.utf8.elementsEqual(question.utf8))
    }
    #expect(viewModel.error == .memorySubjectUnclear)
    #expect(await model.structuredCalls == 4)
    #expect(await model.replyCalls == 0)
    await viewModel.interrupt()
  }

  @Test func clarificationCopyExplainsHowToResolveTheSubjectInBothLanguages() {
    let english = ChatCopy.error(.memorySubjectUnclear, language: .english)
    let arabic = ChatCopy.error(.memorySubjectUnclear, language: .arabic)
    #expect(english.contains("Which person or project") && english.contains("unique nickname"))
    #expect(english.contains("no memory answer was generated"))
    #expect(arabic.contains("أي شخص أو مشروع") && arabic.contains("لقب مميز"))
    #expect(arabic.contains("لم نولّد جواباً عن الذكريات"))
    #expect(english != ChatCopy.error(.retrievalFailed, language: .english))
    #expect(arabic != ChatCopy.error(.generationFailed, language: .arabic))
  }
}
