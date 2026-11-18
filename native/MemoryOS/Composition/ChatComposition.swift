import ChatCore
import ChatPersistence
import ChatPresentation
import Foundation
import LlamaEvaluationAdapter
import LocalMemoryRetrieval
import MemoryCore

enum ChatComposition {
  static let modelFilename = "Qwen3-4B-Q4_K_M.gguf"
  static let modelSHA256 = "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5"
  static var modelAssetURL: URL {
    let imported = URL.documentsDirectory.appending(path: "ChatModels/" + modelFilename)
    return FileManager.default.fileExists(atPath: imported.path)
      ? imported
      : (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appending(
        path: "MemoryModels/" + modelFilename)
  }

  @MainActor static func makePreparationViewModel() -> ChatModelPreparationViewModel {
    ChatModelPreparationViewModel(useCase: PrepareChatModel(importer: ChatModelImporter()))
  }
  @MainActor static func makeModel() -> any ChatModel {
    let modelURL = modelAssetURL
    let model = LlamaChatModel(
      assetURL: modelURL,
      expectedSHA256: modelSHA256,
      onMeasurement: { output, seconds in
        let sample = ChatMeasurement(
          tokens: output.generatedTokenCount,
          firstTokenSeconds: output.firstTokenSeconds,
          preparationSeconds: output.preparationSeconds,
          totalSeconds: seconds, cold: output.wasColdLoad,
          residentBytes: ChatMeasurement.residentBytes())
        Task { await ChatMeasurementStore.shared.append(sample) }
      })
    return model
  }

  @MainActor static func makeViewModel(
    provider: LocalStoreProvider,
    voiceTranscriber: any VoiceTranscribing, model: any ChatModel,
    personalMemory: PersonalMemoryUseCases? = nil,
    organizer: (any PersonalMemoryOrganizing)? = nil,
    relevance: (any MemoryEvidenceFiltering)? = nil
  ) -> ChatViewModel {
    let base = URL.applicationSupportDirectory.appending(path: "LocalChat")
    return ChatViewModel(
      useCases: ChatUseCases(
        repository: FileChatRepository(url: base.appending(path: "conversations.json")),
        model: model,
        memory: LocalChatMemory(
          provider: provider, personalMemory: personalMemory,
          search: LocalMemorySearch(
            directory: URL.applicationSupportDirectory.appending(path: "MemoryRecall"),
            cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
            provider: .hybrid, minimumSimilarity: relevance == nil ? 0.65 : -1),
          relevance: relevance),
        voiceTranscriber: voiceTranscriber,
        recorder: personalMemory.map { PersonalChatRecorder(useCases: $0, organizer: organizer) }))
  }

  @MainActor static func makeRelevanceFilter(
    coordinator: LocalInferenceCoordinator
  ) -> any MemoryEvidenceFiltering {
    let url = modelAssetURL
    let model = LlamaChatModel(
      assetURL: url,
      expectedSHA256: modelSHA256)
    return CoordinatedEvidenceFilter(
      base: LocalModelEvidenceFilter(model: model), coordinator: coordinator)
  }
}
