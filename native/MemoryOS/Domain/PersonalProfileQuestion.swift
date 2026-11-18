import MemoryCore

/// Typed prompts carry their intended meaning independently of localized display text.
enum PersonalProfileQuestion: String, Identifiable, CaseIterable {
  case priority, preference, relationship, communication
  var id: String { rawValue }
  var kind: PersonalMemoryKind {
    switch self {
    case .priority: .goal
    case .preference: .preference
    case .relationship: .fact
    case .communication: .interpretation
    }
  }
  static func questions(for kind: PersonalProfileKind) -> [Self] {
    kind == .selfProfile ? [.priority, .preference] : [.relationship, .communication]
  }
}
