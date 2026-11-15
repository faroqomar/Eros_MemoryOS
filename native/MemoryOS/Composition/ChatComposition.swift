import ChatCore
import ChatPersistence
import ChatPresentation
import Foundation
import LlamaEvaluationAdapter
import MemoryCore

enum ChatComposition {
  @MainActor static func makePreparationViewModel() -> ChatModelPreparationViewModel {
    ChatModelPreparationViewModel(useCase: PrepareChatModel(importer: ChatModelImporter()))
  }
  @MainActor static func makeViewModel(provider: LocalStoreProvider) -> ChatViewModel {
    let base = URL.applicationSupportDirectory.appending(path: "LocalChat")
    let modelURL = URL.documentsDirectory.appending(path: "ChatModels/Qwen3-0.6B-Q4_K_M.gguf")
    let model = LlamaChatModel(
      assetURL: modelURL,
      expectedSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a",
      onMeasurement: { output, seconds in
        let sample = ChatMeasurement(
          tokens: output.generatedTokenCount,
          firstTokenSeconds: output.firstTokenSeconds,
          preparationSeconds: output.preparationSeconds,
          totalSeconds: seconds, cold: output.wasColdLoad,
          residentBytes: ChatMeasurement.residentBytes())
        Task { await ChatMeasurementStore.shared.append(sample) }
      })
    return ChatViewModel(
      useCases: ChatUseCases(
        repository: FileChatRepository(url: base.appending(path: "conversations.json")),
        model: model, memory: LocalChatMemory(provider: provider)))
  }
}

/// A fresh snapshot avoids retaining a provider index or stale corrections/deletions.
struct LocalChatMemory: ChatMemoryRetrieving {
  let provider: any LocalMemorySessionProvider

  func retrieve(query: String) async throws -> [ChatEvidence] {
    try await retrieve(query: query, previousQuestions: [])
  }

  func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence] {
    let session = try await provider.open()
    let snapshot = try await session.useCases.snapshot()
    return Self.match(query: query, records: snapshot.records, previousQuestions: previousQuestions)
  }

  static func match(query: String, records: [LocalRecord], previousQuestions: [String] = [])
    -> [ChatEvidence]
  {
    let ignored: Set<String> = [
      "what", "when", "where", "who", "the", "and", "about", "my",
      "memory", "memories", "tell", "does", "have", "with", "from", "this", "that", "is", "a",
      "do", "you", "remember", "know", "please", "else", "more", "his", "her", "him", "it", "them",
      "شنو", "عن", "من", "في", "على", "ماذا", "متى", "هو", "هي", "هل", "لي", "ذكرياتي", "بعد",
      "عنه", "عنها",
    ]
    func words(_ text: String) -> Set<String> {
      Set(
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
          .components(separatedBy: CharacterSet.alphanumerics.inverted)
          .filter { $0.count > 1 && !ignored.contains($0) })
    }
    // The latest explicit topic owns retrieval. Previous questions only resolve
    // referential follow-ups or break ties; old topics cannot fill the top three.
    let currentTerms = words(query)
    let previousTerms =
      previousQuestions.reversed().lazy.map(words).first(where: { !$0.isEmpty }) ?? []
    let terms = currentTerms.isEmpty ? previousTerms : currentTerms
    guard !terms.isEmpty else { return [] }
    return records.filter { $0.deletedAt == nil }.compactMap { record -> (LocalRecord, Int)? in
      let recordTerms = words(record.text)
      let primary = recordTerms.intersection(terms).count
      let secondary = min(99, recordTerms.intersection(previousTerms).count)
      return primary > 0 ? (record, primary * 100 + secondary) : nil
    }.sorted {
      $0.1 == $1.1 ? $0.0.id.uuidString < $1.0.id.uuidString : $0.1 > $1.1
    }.prefix(3).map { ChatEvidence(id: $0.0.id, text: $0.0.text) }
  }
}
