/// App-owned structured inference. Grammar comes from trusted app code, never source messages.
/// A successful result is complete UTF-8 JSON; callers still validate schema and source evidence.
public protocol StructuredChatModel: ChatModel {
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) async throws
    -> String
}
