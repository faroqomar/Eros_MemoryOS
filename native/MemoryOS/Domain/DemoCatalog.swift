import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
  case english = "en"
  case arabic = "ar"
  var id: String { rawValue }
  var name: String { self == .english ? "English" : "العربية" }

  func text(_ english: String, _ arabic: String) -> String {
    self == .english ? english : arabic
  }
}

enum DemoDestination: Hashable {
  case personalProfile(UUID)
  case personalEntry(UUID)
  case personalSource(UUID)
}
