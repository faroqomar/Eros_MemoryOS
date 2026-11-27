import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
  case capture, chat, recordings, brainMap, profiles, projects, memories, search, understanding,
    calendar, birthdays, organization, settings
  var id: String { rawValue }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .capture: language.text("Capture", "التقاط")
    case .chat: language.text("Chat", "المحادثة")
    case .recordings: language.text("Recordings", "التسجيلات")
    case .brainMap: language.text("Brain", "خريطة الذاكرة")
    case .profiles: language.text("People", "الأشخاص")
    case .projects: language.text("Projects", "المشاريع")
    case .memories: language.text("Notes", "الملاحظات")
    case .search: language.text("Search memory", "بحث الذاكرة")
    case .understanding: language.text("Understand", "فهم النقاش")
    case .organization: language.text("Rules and views", "القواعد والعروض")
    case .calendar: language.text("Calendar", "التقويم")
    case .birthdays: language.text("Birthdays", "أعياد الميلاد")
    case .settings: language.text("Settings", "الإعدادات")
    }
  }

  var symbol: String {
    switch self {
    case .capture: "mic"
    case .chat: "bubble.left.and.bubble.right"
    case .recordings: "waveform"
    case .brainMap: "brain"
    case .profiles: "person"
    case .projects: "folder"
    case .memories: "doc.text"
    case .search: "magnifyingglass"
    case .understanding: "text.bubble"
    case .organization: "line.3.horizontal.decrease.circle"
    case .calendar: "calendar"
    case .birthdays: "gift"
    case .settings: "gearshape"
    }
  }
}

enum CalendarRange: Hashable {
  case month, week
}

@MainActor
@Observable
final class DemoSession {
  private let sectionStates = Dictionary(
    uniqueKeysWithValues: AppSection.allCases.map { ($0, DemoSectionState()) })

  func state(for section: AppSection) -> DemoSectionState { sectionStates[section]! }

  var language: AppLanguage = .english
  var section: AppSection = .capture
  var captureEntry = UUID()
  var captureShowsConversation = false
  var brainFocusID: UUID?
  var calendarRange = CalendarRange.month
  var calendarDate = Date()
  var notesShowOriginals = false

  func captureConversationBinding() -> Binding<Bool> {
    let entry = captureEntry
    return Binding(
      get: { self.captureShowsConversation },
      set: { visible in
        guard self.captureEntry == entry else { return }
        self.captureShowsConversation = visible
      }
    )
  }

  func openHome() {
    captureShowsConversation = false
    captureEntry = UUID()
    section = .capture
  }
}

/// View state survives a section switch without keeping inactive controls mounted.
@MainActor
@Observable
final class DemoSectionState {
  var path: [DemoDestination] = []
}
