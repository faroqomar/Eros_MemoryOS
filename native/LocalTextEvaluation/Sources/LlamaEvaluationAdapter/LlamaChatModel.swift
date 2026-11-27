import AIEvaluationCore
import ChatCore
import Foundation

/// Thin, replaceable bridge from the MemoryOS-owned model contract to the reviewed local runtime.
/// There is no network client, downloader, source store, or cloud fallback in this adapter.
public struct LlamaChatModel: StructuredChatModel {
  private let runtime: LlamaTextRuntime
  private let onMeasurement: @Sendable (TextOutput, Double) -> Void

  /// A local composition-owned resolver can select a newly imported asset on the next cold load.
  /// A valid resident session stays loaded until explicit unload.
  /// The optional composition-owned callback receives successful native metrics and total seconds.
  /// The default callback records nothing. Callers must exclude reply content from operational logs.
  public init(
    assetURL: URL, expectedSHA256: String,
    assetURLResolver: (@Sendable () throws -> URL)? = nil,
    chatSampling: LlamaChatSampling = .greedy,
    onMeasurement: @escaping @Sendable (TextOutput, Double) -> Void = { _, _ in }
  ) {
    runtime = LlamaTextRuntime(
      assetURL: assetURL, expectedSHA256: expectedSHA256, assetURLResolver: assetURLResolver,
      chatSampling: chatSampling)
    self.onMeasurement = onMeasurement
  }

  public func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws
  {
    do {
      let clock = ContinuousClock()
      let start = clock.now
      let output = try await runtime.chat(
        turns: turns.map { LlamaChatTurn(role: $0.role.rawValue, text: $0.text) }, onText: onText)
      let duration = start.duration(to: clock.now)
      let seconds =
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
      onMeasurement(output, seconds)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as ChatError {
      throw error
    } catch let error as EvaluationError {
      switch error {
      case .unavailable: throw ChatError.modelUnavailable
      default: throw ChatError.generationFailed
      }
    } catch {
      throw ChatError.generationFailed
    }
  }

  public func unload() async { await runtime.unload() }

  /// Background extraction deliberately does not report ordinary chat latency measurements.
  public func generateJSON(
    turns: [ChatTurn], grammar: String, maximumOutputTokens: Int
  ) async throws -> String {
    do {
      return try await runtime.generateJSON(
        turns: turns.map { LlamaChatTurn(role: $0.role.rawValue, text: $0.text) },
        grammar: grammar, maximumOutputTokens: maximumOutputTokens)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as ChatError {
      throw error
    } catch let error as EvaluationError {
      switch error {
      case .unavailable: throw ChatError.modelUnavailable
      default: throw ChatError.generationFailed
      }
    } catch { throw ChatError.generationFailed }
  }
}
