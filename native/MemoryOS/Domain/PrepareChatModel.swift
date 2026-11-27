import Foundation

/// The reviewed asset identity is shared by preparation, runtime loading, and Settings.
struct ChatModelAsset: Equatable, Sendable {
  let name: String
  let filename: String
  let sha256: String
  let byteCount: Int64
}

enum ChatModelPreparationFailure: Error, Equatable, Sendable {
  case differentModel, unreadableFile, notEnoughSpace, couldNotSave, busy
}

protocol ChatModelPreparing: Sendable {
  func prepare(from url: URL) async throws
}

struct PrepareChatModel: Sendable {
  let asset: ChatModelAsset
  let importer: any ChatModelPreparing
  func execute(_ url: URL) async throws { try await importer.prepare(from: url) }
}
