import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
  case capture, brainMap, profiles, projects, memories, birthdays, settings
  var id: String { rawValue }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .capture: language.text("Capture", "التقاط")
    case .brainMap: language.text("BrainMap", "خريطة الذاكرة")
    case .profiles: language.text("People", "الأشخاص")
    case .projects: language.text("Projects", "المشاريع")
    case .memories: language.text("Memories", "الذكريات")
    case .birthdays: language.text("Birthdays", "أعياد الميلاد")
    case .settings: language.text("Settings", "الإعدادات")
    }
  }

  var symbol: String {
    switch self {
    case .capture: "mic"
    case .brainMap: "brain"
    case .profiles: "person"
    case .projects: "folder"
    case .memories: "doc.text"
    case .birthdays: "gift"
    case .settings: "gearshape"
    }
  }
}

@MainActor
@Observable
final class DemoSession {
  let catalog: DemoCatalog
  var reminderChoices: [String: ReminderChoice] = [:]

  init(catalog: DemoCatalog = .sample) { self.catalog = catalog }

  func reminder(for birthdayID: String) -> ReminderChoice {
    reminderChoices[birthdayID] ?? .off
  }

  func chooseReminder(_ choice: ReminderChoice, for birthdayID: String) {
    guard catalog.birthday(birthdayID) != nil else { return }
    reminderChoices[birthdayID] = choice
  }

  private let sectionStates = Dictionary(
    uniqueKeysWithValues: AppSection.allCases.map { ($0, DemoSectionState()) })

  func state(for section: AppSection) -> DemoSectionState { sectionStates[section]! }

  var language: AppLanguage = .english
  var section: AppSection = .capture
}

/// View state survives a section switch without keeping inactive controls mounted.
@MainActor
@Observable
final class DemoSectionState {
  var path: [DemoDestination] = []
  var query = ""
  var topRecordID: String?
  var focusedRecordID = "ali"
  var mapListMode = false
}
