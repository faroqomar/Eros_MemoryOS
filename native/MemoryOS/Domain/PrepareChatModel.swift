import Foundation

protocol ChatModelPreparing: Sendable {
  func prepare(from url: URL) async throws
}

struct PrepareChatModel: Sendable {
  let importer: any ChatModelPreparing
  func execute(_ url: URL) async throws { try await importer.prepare(from: url) }
}
