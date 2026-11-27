import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

@testable import MemoryOS

/// Explicit test selection only. App composition and the Files importer keep their selected asset.
@MainActor enum RuntimeTestModel {
  struct Configuration: Sendable {
    let selection: String
    let assetURL: URL
    let expectedSHA256: String
  }

  enum SelectionError: Error, Equatable { case unknownSelection(String) }

  static func configuration(
    selection: String? = ProcessInfo.processInfo.environment["MEMORYOS_TEST_LOCAL_MODEL"],
    resourceURL: URL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
  ) throws -> Configuration {
    switch selection {
    case nil:
      return Configuration(
        selection: "qwen3", assetURL: ChatComposition.modelAssetURL,
        expectedSHA256: ChatComposition.modelSHA256)
    case "qwen35":
      return Configuration(
        selection: "qwen35",
        assetURL: resourceURL.appending(path: "MemoryModels/Qwen3.5-4B-Q4_K_M.gguf"),
        expectedSHA256: "217002fa8008ef4fc6d548353a3aebef055a96e6ff8e0e2c0953ef8254a89c14")
    case .some(let value):
      throw SelectionError.unknownSelection(value)
    }
  }

  static func makeModel() throws -> any ChatModel {
    let configuration = try configuration()
    let sampling = try sampling(selection: configuration.selection)
    if configuration.selection == "qwen3", sampling == .greedy {
      return ChatComposition.makeModel()
    }
    return LlamaChatModel(
      assetURL: configuration.assetURL, expectedSHA256: configuration.expectedSHA256,
      chatSampling: sampling,
      onMeasurement: { output, seconds in
        let sample = ChatMeasurement(
          tokens: output.generatedTokenCount, firstTokenSeconds: output.firstTokenSeconds,
          preparationSeconds: output.preparationSeconds, totalSeconds: seconds,
          cold: output.wasColdLoad, residentBytes: ChatMeasurement.residentBytes())
        Task { await ChatMeasurementStore.shared.append(sample) }
      })
  }

  static func sampling(
    selection: String,
    profile: String? = ProcessInfo.processInfo.environment["MEMORYOS_TEST_CHAT_SAMPLING"],
    seed: String? = ProcessInfo.processInfo.environment["MEMORYOS_TEST_SAMPLING_SEED"]
  ) throws -> LlamaChatSampling {
    guard let profile else {
      guard seed == nil else {
        throw SelectionError.unknownSelection("sampling seed without profile")
      }
      return .greedy
    }
    guard profile == "qwen-nonthinking", let seed, let number = UInt32(seed),
      number != UInt32.max, String(number) == seed
    else { throw SelectionError.unknownSelection("sampling profile or seed") }
    switch selection {
    case "qwen3": return .qwen3NonThinking(seed: number)
    case "qwen35": return .qwen35NonThinking(seed: number)
    default: throw SelectionError.unknownSelection(selection)
    }
  }
}

@Suite @MainActor struct RuntimeTestModelSelectionTests {
  @Test func missingSamplingSelectionKeepsGreedyForBothModels() throws {
    for selection in ["qwen3", "qwen35"] {
      #expect(
        try RuntimeTestModel.sampling(selection: selection, profile: nil, seed: nil) == .greedy)
    }
  }

  @Test func explicitSamplingUsesTheSelectedModelsProfile() throws {
    #expect(
      try RuntimeTestModel.sampling(selection: "qwen3", profile: "qwen-nonthinking", seed: "42")
        == .qwen3NonThinking(seed: 42))
    #expect(
      try RuntimeTestModel.sampling(selection: "qwen35", profile: "qwen-nonthinking", seed: "42")
        == .qwen35NonThinking(seed: 42))
  }

  @Test(arguments: ["", "-1", "42.0", "042", " 42", "4294967295", "4294967296"])
  func invalidSamplingSeedCannotFallBackToAnotherProfile(_ seed: String) {
    #expect(throws: RuntimeTestModel.SelectionError.self) {
      try RuntimeTestModel.sampling(selection: "qwen3", profile: "qwen-nonthinking", seed: seed)
    }
  }

  @Test func incompleteOrUnknownSamplingConfigurationFailsClosed() {
    #expect(throws: RuntimeTestModel.SelectionError.self) {
      try RuntimeTestModel.sampling(selection: "qwen3", profile: nil, seed: "42")
    }
    #expect(throws: RuntimeTestModel.SelectionError.self) {
      try RuntimeTestModel.sampling(selection: "qwen3", profile: "qwen-nonthinking", seed: nil)
    }
    #expect(throws: RuntimeTestModel.SelectionError.self) {
      try RuntimeTestModel.sampling(selection: "qwen3", profile: "latest", seed: "42")
    }
    #expect(throws: RuntimeTestModel.SelectionError.self) {
      try RuntimeTestModel.sampling(
        selection: "unreviewed", profile: "qwen-nonthinking", seed: "42")
    }
  }

  @Test func defaultSelectionPreservesAppOwnedModelLocationAndHash() throws {
    let configuration = try RuntimeTestModel.configuration(selection: nil)
    #expect(configuration.selection == "qwen3")
    #expect(configuration.assetURL == ChatComposition.modelAssetURL)
    #expect(configuration.expectedSHA256 == ChatComposition.modelSHA256)
  }

  @Test func candidateUsesOnlyThePinnedBundledAsset() throws {
    let resources = URL(fileURLWithPath: "/fictional-test-bundle", isDirectory: true)
    let configuration = try RuntimeTestModel.configuration(
      selection: "qwen35", resourceURL: resources)
    #expect(configuration.selection == "qwen35")
    #expect(
      configuration.assetURL
        == resources.appending(path: "MemoryModels/Qwen3.5-4B-Q4_K_M.gguf"))
    #expect(
      configuration.expectedSHA256
        == "217002fa8008ef4fc6d548353a3aebef055a96e6ff8e0e2c0953ef8254a89c14")
  }

  @Test(arguments: ["", "qwen3", "latest", "Qwen35", "../outside.gguf"])
  func unknownSelectionDoesNotFallBack(_ selection: String) {
    #expect(throws: RuntimeTestModel.SelectionError.unknownSelection(selection)) {
      try RuntimeTestModel.configuration(selection: selection)
    }
  }
}
