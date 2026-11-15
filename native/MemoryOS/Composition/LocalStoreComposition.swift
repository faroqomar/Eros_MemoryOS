import Foundation
import MemoryCore

/// The composition root injects a retryable store boundary without opening files on the UI actor.
enum LocalStoreComposition {
  @MainActor
  static func makeViewModel(provider: LocalStoreProvider) -> LocalRecordsViewModel {
    LocalRecordsViewModel(provider: provider)
  }
}
