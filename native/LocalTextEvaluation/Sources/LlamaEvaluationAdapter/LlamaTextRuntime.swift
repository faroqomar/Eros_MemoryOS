import AIEvaluationCore
import ChatCore
import CryptoKit
import Foundation
import llama

/// Plain values for the reviewed upstream chat-template boundary.
public struct LlamaChatTurn: Equatable, Sendable {
  public let role: String
  public let text: String
  public init(role: String, text: String) {
    self.role = role
    self.text = text
  }
}

/// Explicit evaluation profiles. The app keeps greedy decoding until a sampled
/// profile passes its separate quality gate. Seeds reset for each request.
public enum LlamaChatSampling: Equatable, Sendable {
  case greedy
  case qwen3NonThinking(seed: UInt32)
  case qwen35NonThinking(seed: UInt32)
}

/// Explicit profiles for the plain-text ChatML output of the pinned template API.
/// Qwen3.5 requires enable_thinking=false semantics; its /no_think text command
/// does not select a mode. The closed boundary below is the official template's
/// non-thinking assistant prefix. Sampling and model selection stay unchanged.
enum ReviewedLlamaChatTemplate {
  static func complete(_ prompt: String, architecture: String) throws
    -> String
  {
    guard architecture == "qwen3" || architecture == "qwen35" else { return prompt }
    guard prompt.hasSuffix("<|im_start|>assistant\n") else {
      throw EvaluationError.unavailable(
        "The Qwen template did not expose its reviewed assistant prefix.")
    }
    return prompt + "<think>\n\n</think>\n\n"
  }
}

/// Resident-session evaluation adapter. The first request loads the model; later requests reset KV state. It never downloads assets or opens a network connection.
/// This actor owns the C handles. It retains a valid resident session until explicit unload;
/// partially constructed native handles are freed on load failure or cancellation.
public actor LlamaTextRuntime: TextRuntimeAdapter {
  /// Initial/fallback path; the composition may resolve another local path on a cold load.
  public let assetURL: URL
  public let expectedSHA256: String
  private let assetURLResolver: (@Sendable () throws -> URL)?
  private let chatSampling: LlamaChatSampling
  private static let backend: Void = { llama_backend_init() }()
  private var session: LlamaSession?
  private final class LlamaSession {
    let model: OpaquePointer
    let context: OpaquePointer
    let sampler: UnsafeMutablePointer<llama_sampler>
    let vocab: OpaquePointer
    init(
      model: OpaquePointer, context: OpaquePointer, sampler: UnsafeMutablePointer<llama_sampler>,
      vocab: OpaquePointer
    ) {
      self.model = model
      self.context = context
      self.sampler = sampler
      self.vocab = vocab
    }
    deinit {
      llama_sampler_free(sampler)
      llama_free(context)
      llama_model_free(model)
    }
  }

  public init(
    assetURL: URL, expectedSHA256: String,
    assetURLResolver: (@Sendable () throws -> URL)? = nil,
    chatSampling: LlamaChatSampling = .greedy
  ) {
    self.assetURL = assetURL
    self.expectedSHA256 = expectedSHA256
    self.assetURLResolver = assetURLResolver
    self.chatSampling = chatSampling
  }

  public func generate(request: TextRequest, settings: GenerationSettings) async throws
    -> TextOutput
  {
    try Task.checkCancellation()
    // The upstream chat template accepts NUL-terminated C strings. Refuse an
    // embedded terminator rather than silently dropping the remaining source.
    guard !request.instruction.utf8.contains(0), !request.question.utf8.contains(0),
      request.sources.allSatisfy({ !$0.id.utf8.contains(0) && !$0.text.utf8.contains(0) })
    else {
      throw EvaluationError.invalidSuite("Prompt fields must not contain embedded NUL characters.")
    }
    try Self.validateKnownReservedContent(
      [request.instruction, request.question] + request.sources.flatMap { [$0.id, $0.text] })
    guard settings.temperature == 0, (1...256).contains(settings.maximumOutputTokens) else {
      throw EvaluationError.unavailable(
        "This adapter supports greedy temperature 0 and 1–256 output tokens only. Seed is unused by greedy sampling."
      )
    }
    return try infer(
      maximumOutputTokens: settings.maximumOutputTokens, chatMode: false,
      prompt: { try applyTemplate(request: request, model: $0) }, onText: nil)
  }

  /// Role-based chat uses the same reviewed native session and greedy sampler as evaluation.
  /// Native calls execute on this actor, outside the UI actor. Cancellation is cooperative:
  /// a synchronous upstream load or decode must return before the next check can run.
  public func chat(turns: [LlamaChatTurn], onText: @escaping @Sendable (String) -> Void)
    async throws
    -> TextOutput
  {
    try Task.checkCancellation()
    try validateChatSampling()
    try Self.validateChat(turns)
    return try infer(
      maximumOutputTokens: 256, chatMode: true,
      prompt: { try makePrompt(turns: turns, model: $0) }, onText: onText)
  }

  /// Uses trusted application grammar with fresh sampling state and the existing resident weights.
  /// Complete JSON is returned only after generation finishes; partial payloads are never published.
  public func generateJSON(
    turns: [LlamaChatTurn], grammar: String, maximumOutputTokens: Int
  ) async throws -> String {
    try Task.checkCancellation()
    try validateChatSampling()
    try Self.validateChat(turns)
    guard (1...512).contains(maximumOutputTokens), !grammar.utf8.contains(0),
      !grammar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      grammar.utf8.count <= 32_000
    else {
      throw EvaluationError.invalidSuite(
        "Structured generation requires bounded app grammar and 1–512 output tokens.")
    }
    let result = try infer(
      maximumOutputTokens: maximumOutputTokens, chatMode: true, grammar: grammar,
      prompt: { try makePrompt(turns: turns, model: $0) }, onText: nil)
    guard let data = result.text.data(using: .utf8),
      (try? JSONSerialization.jsonObject(with: data)) != nil
    else { throw EvaluationError.invalidResult("Structured output was not complete JSON.") }
    try Task.checkCancellation()
    return result.text
  }

  private func validateChatSampling() throws {
    switch chatSampling {
    case .greedy: break
    case .qwen3NonThinking(let seed), .qwen35NonThinking(let seed):
      // llama.cpp reserves this value for a fresh random seed. A caller must
      // provide a replayable seed for these explicit evaluation profiles.
      guard seed != UInt32.max else {
        throw EvaluationError.invalidSuite("A fixed chat-sampling seed is required.")
      }
    }
  }

  private static func validateChat(_ turns: [LlamaChatTurn]) throws {
    guard !turns.isEmpty, turns.last?.role == "user", turns.count <= 1001 else {
      throw EvaluationError.invalidSuite(
        "A chat needs a final user message and at most 1001 turns.")
    }
    var nextRole = "user"
    var totalBytes = 0
    for (index, turn) in turns.enumerated() {
      guard ["system", "user", "assistant"].contains(turn.role),
        !turn.text.utf8.contains(0),
        turn.role == "assistant"
          || !turn.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw EvaluationError.invalidSuite(
          "Chat roles or text are invalid; embedded NUL is refused.")
      }
      if turn.role == "system" {
        guard index == 0 else {
          throw EvaluationError.invalidSuite("The system turn must come first.")
        }
      } else {
        guard turn.role == nextRole else {
          throw EvaluationError.invalidSuite("Chat user and assistant turns must alternate.")
        }
        nextRole = turn.role == "user" ? "assistant" : "user"
      }
      totalBytes += turn.text.utf8.count
      guard totalBytes <= 100_000 else { throw ChatError.contextLimit }
      try validateKnownReservedContent([turn.text])
    }
  }

  /// Refuse content that would become template structure when the full prompt is
  /// tokenized with parse_special=true. Preserve the stored original; never escape,
  /// replace or truncate its content at this provider boundary.
  private static func validateKnownReservedContent(_ contents: [String]) throws {
    let reserved = ["<|im_start|>", "<|im_end|>", "<|endoftext|>", "<think>", "</think>"]
    guard contents.allSatisfy({ content in !reserved.contains(where: { content.contains($0) }) })
    else {
      // Keep the recovery error generic; do not embed source text or marker payloads.
      throw ChatError.generationFailed
    }
  }

  /// Additional control/EOG markers depend on the loaded vocabulary. Check each
  /// content field before template assembly, without adding BOS/EOS to that field.
  private static func validateVocabularyContent(
    _ contents: [String], vocab: OpaquePointer
  ) throws {
    for content in contents {
      try Task.checkCancellation()
      var tokens = [llama_token](repeating: 0, count: 2048)
      let count = content.withCString {
        llama_tokenize(vocab, $0, Int32(content.utf8.count), &tokens, 2048, false, true)
      }
      // A field larger than the entire context cannot fit the eventual prompt.
      // Refuse it rather than checking or returning a truncated token prefix.
      guard count >= 0 else { throw ChatError.contextLimit }
      guard
        !tokens.prefix(Int(count)).contains(where: {
          llama_vocab_is_control(vocab, $0) || llama_vocab_is_eog(vocab, $0)
        })
      else { throw ChatError.generationFailed }
    }
  }

  private func infer(
    maximumOutputTokens: Int, chatMode: Bool,
    grammar: String? = nil,
    prompt makePrompt: (OpaquePointer) throws -> String,
    onText: (@Sendable (String) -> Void)?
  ) throws -> TextOutput {
    let clock = ContinuousClock()
    let start = clock.now
    let cold = session == nil
    if session == nil { session = try loadSession() }
    guard let session else { throw EvaluationError.unavailable("No loaded llama.cpp session.") }
    let context = session.context
    let vocab = session.vocab
    // Historical fixed-setting evaluation stays greedy. Chat profiles are explicit
    // dependencies; provider code does not read environment flags or choose a model.
    let requestSampling: LlamaChatSampling = chatMode ? chatSampling : .greedy
    let requestSampler =
      grammar != nil || requestSampling != .greedy
      ? try makeRequestSampler(grammar: grammar, sampling: requestSampling, vocab: vocab) : nil
    defer { if let requestSampler { llama_sampler_free(requestSampler) } }
    let sampler = requestSampler ?? session.sampler
    llama_memory_clear(llama_get_memory(context), true)
    llama_sampler_reset(sampler)
    let preparation = elapsed(start.duration(to: clock.now))
    let prompt = try makePrompt(session.model)
    var tokens = [llama_token](repeating: 0, count: 2048)
    let tokenCount = prompt.withCString {
      llama_tokenize(vocab, $0, Int32(prompt.utf8.count), &tokens, 2048, true, true)
    }
    guard tokenCount > 0, Int(tokenCount) + maximumOutputTokens <= 2048 else {
      if chatMode { throw ChatError.contextLimit }
      throw EvaluationError.unavailable(
        "Prompt and output exceed the fixed 2048-token evaluation context. No truncation was applied."
      )
    }
    try Task.checkCancellation()
    let promptStatus = tokens.withUnsafeMutableBufferPointer {
      llama_decode(context, llama_batch_get_one($0.baseAddress, tokenCount))
    }
    try Task.checkCancellation()
    guard promptStatus == 0 else {
      throw EvaluationError.invalidResult("Prompt decode failed (\(promptStatus)).")
    }
    var outputBytes = [UInt8]()
    var generated = 0
    var firstToken: Double?
    for _ in 0..<maximumOutputTokens {
      try Task.checkCancellation()
      var token = llama_sampler_sample(sampler, context, -1)
      if llama_vocab_is_eog(vocab, token) { break }
      if firstToken == nil { firstToken = elapsed(start.duration(to: clock.now)) }
      generated += 1
      var piece = [CChar](repeating: 0, count: 256)
      var count = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, false)
      if count < 0 {
        piece = [CChar](repeating: 0, count: Int(-count))
        count = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, false)
      }
      guard count >= 0 else { throw EvaluationError.invalidResult("Token decoding failed.") }
      outputBytes.append(contentsOf: piece.prefix(Int(count)).map { UInt8(bitPattern: $0) })
      // A token can end inside an Arabic or emoji UTF-8 sequence. Publish only complete text.
      if let text = String(bytes: outputBytes, encoding: .utf8) { onText?(text) }
      let status = withUnsafeMutablePointer(to: &token) {
        llama_decode(context, llama_batch_get_one($0, 1))
      }
      guard status == 0 else {
        throw EvaluationError.invalidResult("Token decode failed (\(status)).")
      }
    }
    if chatMode && generated == maximumOutputTokens { throw ChatError.outputLimit }
    guard let text = String(bytes: outputBytes, encoding: .utf8) else {
      throw EvaluationError.invalidResult(
        "Output cap ended inside a UTF-8 sequence. No replacement text was returned.")
    }
    return TextOutput(
      text: text, generatedTokenCount: generated, firstTokenSeconds: firstToken,
      preparationSeconds: preparation, wasColdLoad: cold)
  }

  private func makeRequestSampler(
    grammar: String?, sampling: LlamaChatSampling, vocab: OpaquePointer
  ) throws -> UnsafeMutablePointer<llama_sampler> {
    guard let chain = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
      throw EvaluationError.unavailable("Cannot create structured sampler chain.")
    }
    var retained = false
    defer { if !retained { llama_sampler_free(chain) } }
    // The chain owns children after addition. Sampling already accepts the selected token.
    if let grammar {
      guard
        let grammarSampler = grammar.withCString({ text in
          "root".withCString { llama_sampler_init_grammar(vocab, text, $0) }
        })
      else { throw EvaluationError.invalidSuite("The app grammar could not be parsed.") }
      llama_sampler_chain_add(chain, grammarSampler)
    }
    func add(_ child: UnsafeMutablePointer<llama_sampler>?) throws {
      guard let child else { throw EvaluationError.unavailable("Cannot create chat sampler.") }
      llama_sampler_chain_add(chain, child)
    }
    switch sampling {
    case .greedy:
      try add(llama_sampler_init_greedy())
    case .qwen3NonThinking(let seed), .qwen35NonThinking(let seed):
      // Model-card general non-thinking profiles. Penalties precede probability
      // filtering, as in the pinned llama.cpp common sampler. Only generated tokens
      // enter this fresh chain; originals and prior requests never enter its history.
      if case .qwen35NonThinking = sampling {
        try add(llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 2048, 1, 0, 1.5))
      }
      try add(llama_sampler_init_top_k(20))
      try add(llama_sampler_init_top_p(0.8, 1))
      try add(llama_sampler_init_temp(0.7))
      try add(llama_sampler_init_dist(seed))
    }
    retained = true
    return chain
  }

  /// The composition root retains one runtime across the batch. This releases its resident model.
  public func unload() { session = nil }

  private func loadSession() throws -> LlamaSession {
    try Task.checkCancellation()
    // Resolve once, then verify and load the same path. Failures leave no resident session,
    // so the next request can observe a successful local import without recreating this adapter.
    let loadURL = try assetURLResolver?() ?? assetURL
    try Task.checkCancellation()
    try verifyAsset(at: loadURL)
    _ = Self.backend
    var modelParams = llama_model_default_params()
    // This reviewed configuration is CPU + Accelerate on every evaluation platform.
    modelParams.n_gpu_layers = 0
    guard let model = llama_model_load_from_file(loadURL.path, modelParams) else {
      throw EvaluationError.unavailable("llama.cpp could not load the verified local GGUF asset.")
    }
    var retained = false
    defer { if !retained { llama_model_free(model) } }
    try Task.checkCancellation()
    var params = llama_context_default_params()
    params.n_ctx = 2048
    params.n_batch = 2048
    params.n_threads = 4
    params.n_threads_batch = 4
    guard let context = llama_init_from_model(model, params) else {
      throw EvaluationError.unavailable("llama.cpp could not create a 2048-token context.")
    }
    defer { if !retained { llama_free(context) } }
    guard let vocab = llama_model_get_vocab(model), let sampler = llama_sampler_init_greedy() else {
      throw EvaluationError.unavailable("llama.cpp could not create its vocabulary/sampler.")
    }
    retained = true
    return LlamaSession(model: model, context: context, sampler: sampler, vocab: vocab)
  }

  private func verifyAsset(at loadURL: URL) throws {
    guard loadURL.isFileURL else {
      throw EvaluationError.unavailable(
        "A local file URL is required; network model loading is disabled.")
    }
    guard expectedSHA256.count == 64, expectedSHA256.allSatisfy(\.isHexDigit) else {
      throw EvaluationError.unavailable("A reviewed 64-digit SHA-256 is required.")
    }
    guard let stream = InputStream(url: loadURL) else {
      throw EvaluationError.unavailable(
        "The local GGUF model is missing. No automatic download or cloud fallback is enabled.")
    }
    stream.open()
    defer { stream.close() }
    var hasher = SHA256()
    var buffer = [UInt8](repeating: 0, count: 65536)
    while true {
      try Task.checkCancellation()
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count >= 0 else {
        throw EvaluationError.unavailable("Cannot read the local GGUF model.")
      }
      if count == 0 { break }
      hasher.update(data: Data(buffer.prefix(count)))
    }
    let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    guard actual == expectedSHA256.lowercased() else {
      throw EvaluationError.unavailable(
        "The local model SHA-256 does not match the reviewed asset. Model loading was refused.")
    }
  }

  private func applyTemplate(request: TextRequest, model: OpaquePointer) throws -> String {
    let sourceText = request.sources.map { "[\($0.id)] \($0.text)" }.joined(separator: "\n")
    let content =
      "\(request.instruction)\n\nUNTRUSTED SOURCES:\n\(sourceText)\n\nQUESTION:\n\(request.question)\n/no_think"
    return try makePrompt(turns: [.init(role: "user", text: content)], model: model)
  }

  private func makePrompt(
    turns: [LlamaChatTurn], model: OpaquePointer
  ) throws -> String {
    guard let vocab = llama_model_get_vocab(model) else {
      throw EvaluationError.unavailable("The local model vocabulary is unavailable.")
    }
    try Self.validateKnownReservedContent(turns.map(\.text))
    try Self.validateVocabularyContent(turns.map(\.text), vocab: vocab)
    var allocations: [UnsafeMutablePointer<CChar>] = []
    defer { for allocation in allocations { free(allocation) } }
    var messages: [llama_chat_message] = []
    for turn in turns {
      guard let role = strdup(turn.role) else {
        throw EvaluationError.unavailable("Cannot allocate the chat role.")
      }
      allocations.append(role)
      guard let body = strdup(turn.text) else {
        throw EvaluationError.unavailable("Cannot allocate the chat text.")
      }
      allocations.append(body)
      messages.append(llama_chat_message(role: UnsafePointer(role), content: UnsafePointer(body)))
    }
    let requestedSize = turns.reduce(4096) { $0 + $1.text.utf8.count * 2 + 64 }
    var output = [CChar](repeating: 0, count: requestedSize)
    let size = messages.withUnsafeBufferPointer {
      llama_chat_apply_template(
        llama_model_chat_template(model, nil), $0.baseAddress, $0.count, true, &output,
        Int32(output.count))
    }
    guard size > 0, size < output.count else {
      throw EvaluationError.unavailable(
        "The model chat template is unsupported or exceeds the prompt buffer.")
    }
    let prompt = String(
      decoding: output.prefix(Int(size)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    var architecture = [CChar](repeating: 0, count: 64)
    let architectureSize = llama_model_meta_val_str(
      model, "general.architecture", &architecture, 64)
    let name =
      architectureSize > 0 && architectureSize < 64
      ? String(
        decoding: architecture.prefix(Int(architectureSize)).map { UInt8(bitPattern: $0) },
        as: UTF8.self) : ""
    return try ReviewedLlamaChatTemplate.complete(prompt, architecture: name)
  }

  private func elapsed(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }
}
