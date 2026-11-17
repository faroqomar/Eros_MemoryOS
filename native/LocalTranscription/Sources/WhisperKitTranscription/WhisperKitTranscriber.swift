import AudioCore
import Foundation
import TranscriptionSupport
import WhisperKit

/// Owns each SDK instance within one operation; only app-owned values cross the boundary.
public actor WhisperKitTranscriber: TranscriptionProvider {
  public nonisolated let id = "whisperkit"
  private var running = false

  public init() {}

  /// Accept only the reviewed multilingual tiny assets, before replacing an installed model.
  @discardableResult
  public static func validateModel(directory: URL) throws -> String {
    try TranscriptionModelFiles.validateWhisperKit(directory)
    let fingerprint = try TranscriptionModelIdentity.fingerprint(directory)
    guard fingerprint == "e2cfb4a0a36d03e2f7f88bbea36fc251919d67d8663c54bfd6c4a4ed85664c0e" else {
      throw LocalTranscriptionError.invalidModel
    }
    return fingerprint
  }

  public func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    guard !running else { throw LocalTranscriptionError.busy }
    running = true
    defer { running = false }
    try Task.checkCancellation()
    let fingerprint = try Self.validateModel(directory: modelDirectory)
    let samples = try TranscriptionPCM.load(audioURL)
    // Upstream loadTokenizerIfNeeded falls back to Hub after local parsing failure.
    // Load a local tokenizer explicitly and inject it BEFORE loadModels, so that
    // missing or malformed assets throw without making a network request.
    let tokenizer = try await AutoTokenizerWrapper.from(modelFolder: modelDirectory)
    let config = WhisperKitConfig(
      modelFolder: modelDirectory.path, tokenizerFolder: modelDirectory,
      verbose: false, prewarm: false, load: false, download: false)
    let engine = try await WhisperKit(config)
    engine.tokenizer = try LocalWhisperTokenizer(base: tokenizer)
    try Task.checkCancellation()
    try await engine.loadModels()
    do {
      guard let logits = engine.textDecoder.logitsSize,
        let embedding = engine.audioEncoder.embedSize,
        logits == 51_865, embedding == 384
      else {
        throw LocalTranscriptionError.invalidModel
      }
      engine.textDecoder.isModelMultilingual = true
      let options = DecodingOptions(
        verbose: false, task: .transcribe, temperature: 0,
        temperatureFallbackCount: 0, detectLanguage: true,
        skipSpecialTokens: true, withoutTimestamps: false, wordTimestamps: true,
        concurrentWorkerCount: 1)
      let results = try await engine.transcribe(audioArray: samples, decodeOptions: options) { _ in
        Task.isCancelled ? false : nil
      }
      try Task.checkCancellation()
      let passages = results.flatMap(\.segments).map {
        TranscriptPassage(
          startSeconds: Double($0.start), endSeconds: Double($0.end),
          text: $0.text, uncertain: $0.avgLogprob < -0.5 || $0.noSpeechProb > 0.5,
          speaker: nil,
          words: ($0.words ?? []).map { word in
            TranscriptWord(
              text: word.word, startSeconds: Double(word.start),
              endSeconds: Double(word.end), uncertain: word.probability < 0.6)
          })
      }
      await engine.unloadModels()
      return TranscriptionOutput(
        modelID: "whisperkit-1.1.1/\(engine.modelVariant)/sha256:\(fingerprint)",
        language: results.first?.language, passages: passages)
    } catch {
      await engine.unloadModels()
      throw error
    }
  }
}
