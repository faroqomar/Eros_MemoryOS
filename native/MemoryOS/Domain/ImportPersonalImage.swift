import Foundation

/// The file picker supplies a URL. The platform adapter owns file access and image validation.
protocol PersonalImageReading: Sendable {
  func readImage(at url: URL) async throws -> Data
}

struct ImportPersonalImage: Sendable {
  let reader: any PersonalImageReading
  func callAsFunction(_ url: URL) async throws -> Data { try await reader.readImage(at: url) }
}

enum PersonalImageError: Error { case tooLarge, invalidImage }
