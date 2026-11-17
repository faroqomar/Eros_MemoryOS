import AudioCore
import Foundation
import TranscriptionSupport
import whisper

// The C abort callback may run on a worker thread. NSLock protects the only
// mutable value, and the handler lifetime encloses every callback invocation.
private final class CancellationFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false
  func cancel() { lock.withLock { value = true } }
  var cancelled: Bool { lock.withLock { value } }
}

public enum WhisperCppLanguage: String, CaseIterable, Codable, Sendable {
  case automatic = "auto"
  case english = "en"
  case arabic = "ar"
}

public actor WhisperCppTranscriber: TranscriptionProvider {
  public typealias Model = WhisperCppModel

  public nonisolated let id = "whisper.cpp"
  private static let configureLogs: Void = { whisper_log_set({ _, _, _ in }, nil) }()
  private let model: WhisperCppModel
  private let language: WhisperCppLanguage

  public init(model: WhisperCppModel = .tiny, language: WhisperCppLanguage = .automatic) {
    self.model = model
    self.language = language
  }

  public static func validateModel(directory: URL, model: WhisperCppModel = .tiny) throws {
    _ = try TranscriptionModelFiles.whisperCppModel(directory, model: model)
  }

  public func transcribe(audioURL: URL, modelDirectory: URL) async throws -> TranscriptionOutput {
    try Task.checkCancellation()
    let modelFile = try TranscriptionModelFiles.whisperCppModel(modelDirectory, model: model)
    let samples = try TranscriptionPCM.load(audioURL)
    let flag = CancellationFlag()
    return try await withTaskCancellationHandler {
      Self.configureLogs
      var contextOptions = whisper_context_default_params()
      contextOptions.use_gpu = false
      guard let context = whisper_init_from_file_with_params(modelFile.path, contextOptions) else {
        throw LocalTranscriptionError.invalidModel
      }
      defer { whisper_free(context) }
      try Task.checkCancellation()
      var options = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
      options.n_threads = Int32(min(4, max(1, ProcessInfo.processInfo.activeProcessorCount)))
      options.translate = false
      options.print_progress = false
      options.print_realtime = false
      options.print_timestamps = false
      options.print_special = false
      options.token_timestamps = true
      options.temperature = 0
      options.temperature_inc = 0
      options.no_context = true
      options.abort_callback_user_data = Unmanaged.passUnretained(flag).toOpaque()
      options.abort_callback = { pointer in
        guard let pointer else { return false }
        return Unmanaged<CancellationFlag>.fromOpaque(pointer).takeUnretainedValue().cancelled
      }
      let status = language.rawValue.withCString { language in
        options.language = language
        return samples.withUnsafeBufferPointer {
          whisper_full(context, options, $0.baseAddress, Int32($0.count))
        }
      }
      try Task.checkCancellation()
      guard status == 0 else { throw LocalTranscriptionError.inferenceFailed }
      let passages = (0..<whisper_full_n_segments(context)).map { index in
        let text = String(cString: whisper_full_get_segment_text(context, index))
        let start = Double(whisper_full_get_segment_t0(context, index)) / 100
        let end = Double(whisper_full_get_segment_t1(context, index)) / 100
        var words: [TranscriptWord] = []
        var bytes: [UInt8] = []
        var wordStart = start
        var wordEnd = start
        var uncertain = false
        func appendWord() {
          guard !bytes.isEmpty, wordStart >= start, wordEnd >= wordStart,
            wordEnd <= end + 0.05
          else { return }
          // Reassemble UTF-8 bytes across BPE pieces before decoding Arabic text.
          let text = String(decoding: bytes, as: UTF8.self)
          words.append(
            TranscriptWord(
              text: text, startSeconds: wordStart,
              endSeconds: wordEnd, uncertain: uncertain))
        }
        for token in 0..<whisper_full_n_tokens(context, index) {
          let data = whisper_full_get_token_data(context, index, token)
          guard data.id < whisper_token_eot(context),
            let tokenText = whisper_full_get_token_text(context, index, token)
          else { continue }
          let piece = Array(
            UnsafeBufferPointer(
              start: UnsafeRawPointer(tokenText)
                .assumingMemoryBound(to: UInt8.self), count: strlen(tokenText)))
          if piece.first == 32, !bytes.isEmpty {
            appendWord()
            bytes = []
            uncertain = false
          }
          if bytes.isEmpty { wordStart = Double(data.t0) / 100 }
          bytes.append(contentsOf: piece)
          wordEnd = Double(data.t1) / 100
          uncertain = uncertain || data.p < 0.6
        }
        appendWord()
        return TranscriptPassage(
          startSeconds: start, endSeconds: end,
          text: text,
          uncertain: words.contains(where: \.uncertain)
            || whisper_full_get_segment_no_speech_prob(context, index) > 0.5,
          speaker: nil, words: words)
      }
      let language = whisper_lang_str(whisper_full_lang_id(context)).map { String(cString: $0) }
      return TranscriptionOutput(
        modelID: model.modelID,
        language: language, passages: passages)
    } onCancel: {
      flag.cancel()
    }
  }
}
