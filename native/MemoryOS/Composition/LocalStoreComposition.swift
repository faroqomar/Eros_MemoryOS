import Foundation
import MemoryCore

/// The composition root injects a retryable store boundary without opening files on the UI actor.
enum LocalStoreComposition {
  @MainActor
  static func makeViewModel() -> LocalRecordsViewModel {
    let base = URL.applicationSupportDirectory.appending(
      path: "LocalRecords", directoryHint: .isDirectory)
    return LocalRecordsViewModel(provider: LocalStoreProvider(directory: base))
  }
}
