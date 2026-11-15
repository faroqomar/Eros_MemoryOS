import Foundation

public enum ChatRole: String, Codable, Sendable { case system, user, assistant }

public struct ChatTurn: Equatable, Sendable {
  public let role: ChatRole
  public let text: String
  public init(role: ChatRole, text: String) {
    self.role = role
    self.text = text
  }
}

/// Values crossing this interface belong to MemoryOS. Providers never receive a repository.
public protocol ChatModel: Sendable {
  /// The callback receives the entire generated text so far, with valid UTF-8.
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) async throws
  func unload() async
}

public struct ChatEvidence: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let text: String
  public init(id: UUID, text: String) {
    self.id = id
    self.text = text
  }
}

public protocol ChatMemoryRetrieving: Sendable {
  /// Read current app-owned records. Corrections replace old evidence; deleted records are excluded.
  func retrieve(query: String) async throws -> [ChatEvidence]
  /// Keep the current question separate so retrieval can prioritize a topic change.
  func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence]
}

extension ChatMemoryRetrieving {
  public func retrieve(query: String, previousQuestions: [String]) async throws -> [ChatEvidence] {
    try await retrieve(query: query)
  }
}

public struct NoChatMemory: ChatMemoryRetrieving {
  public init() {}
  public func retrieve(query: String) async throws -> [ChatEvidence] { [] }
}

public enum ChatMessageStatus: String, Codable, Sendable {
  case generating, complete, stopped, failed, interrupted
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let role: ChatRole
  public var text: String
  public var status: ChatMessageStatus
  public var sources: [ChatEvidence]
  public let createdAt: Date

  public init(
    id: UUID = UUID(), role: ChatRole, text: String,
    status: ChatMessageStatus = .complete, sources: [ChatEvidence] = [], createdAt: Date = Date()
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.status = status
    self.sources = sources
    self.createdAt = createdAt
  }
}

public struct ChatConversation: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public var title: String
  public var messages: [ChatMessage]
  public var draft: String
  public var memoryMode: Bool
  public let createdAt: Date

  public init(
    id: UUID = UUID(), title: String = "New chat", messages: [ChatMessage] = [],
    draft: String = "", memoryMode: Bool = false, createdAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.messages = messages
    self.draft = draft
    self.memoryMode = memoryMode
    self.createdAt = createdAt
  }
}

public struct ChatSnapshot: Codable, Equatable, Sendable {
  public var formatVersion: Int
  public var conversations: [ChatConversation]
  public var selectedID: UUID?
  /// Monotonic ordering prevents a delayed save from overwriting a newer snapshot.
  public var revision: UInt64

  public init(
    formatVersion: Int = 1, conversations: [ChatConversation] = [],
    selectedID: UUID? = nil, revision: UInt64 = 0
  ) {
    self.formatVersion = formatVersion
    self.conversations = conversations
    self.selectedID = selectedID
    self.revision = revision
  }
}

public protocol ChatRepository: Sendable {
  func load() async throws -> ChatSnapshot
  func save(_ snapshot: ChatSnapshot) async throws
}

public enum ChatError: Error, Equatable, Sendable {
  case storage, unsupportedVersion, invalidArchive, blankMessage, messageTooLong
  case contextLimit, conversationLimit, missingConversation, busy, modelUnavailable,
    generationFailed
  case retrievalFailed, noEvidence, outputLimit
}

public enum ChatLimits {
  public static let draftBytes = 32_000
  public static let titleBytes = 240
  public static let conversations = 200
  public static let messagesPerConversation = 1000
  public static let archiveBytes = 32 * 1024 * 1024
  /// A conservative preflight in bytes. The runtime also enforces its exact token limit.
  public static let promptBytes = 6000
}

extension ChatSnapshot {
  public func validate() throws {
    guard formatVersion == 1 else { throw ChatError.unsupportedVersion }
    guard revision < UInt64.max, conversations.count <= ChatLimits.conversations,
      Set(conversations.map(\.id)).count == conversations.count,
      selectedID == nil || conversations.contains(where: { $0.id == selectedID })
    else {
      throw ChatError.invalidArchive
    }
    var messageIDs = Set<UUID>()
    for conversation in conversations {
      guard !conversation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        conversation.title.utf8.count <= ChatLimits.titleBytes,
        conversation.draft.utf8.count <= ChatLimits.draftBytes,
        conversation.messages.count <= ChatLimits.messagesPerConversation,
        conversation.messages.count.isMultiple(of: 2),
        conversation.createdAt.timeIntervalSince1970.isFinite
      else { throw ChatError.invalidArchive }
      for (position, message) in conversation.messages.enumerated() {
        guard messageIDs.insert(message.id).inserted,
          message.role == (position.isMultiple(of: 2) ? .user : .assistant),
          message.role != .user
            || (message.status == .complete && message.sources.isEmpty
              && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
          message.text.utf8.count <= ChatLimits.draftBytes,
          message.sources.count <= 20,
          Set(message.sources.map(\.id)).count == message.sources.count,
          message.sources.allSatisfy({ $0.text.utf8.count <= ChatLimits.draftBytes }),
          message.createdAt.timeIntervalSince1970.isFinite
        else { throw ChatError.invalidArchive }
      }
    }
  }
}
