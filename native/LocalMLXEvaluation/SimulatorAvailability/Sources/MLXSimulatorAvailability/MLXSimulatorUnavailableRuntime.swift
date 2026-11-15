import AIEvaluationCore

/// Availability evidence for the native Simulator lab. Actual MLX inference uses MLXEvaluationAdapter.
public struct MLXSimulatorUnavailableRuntime: TextRuntimeAdapter {
  public init() {}

  public static var reason: String {
    #if targetEnvironment(simulator)
      "The reviewed MLX runtime does not support iOS Simulator inference. Use an Apple silicon Mac or a physical iPhone for this configuration."
    #else
      "This availability adapter is for iOS Simulator only. Use MLXEvaluationAdapter on a supported Apple silicon Mac or physical iPhone."
    #endif
  }

  public func generate(request: TextRequest, settings: GenerationSettings) async throws
    -> TextOutput
  {
    try Task.checkCancellation()
    throw EvaluationError.unavailable(Self.reason)
  }
}
