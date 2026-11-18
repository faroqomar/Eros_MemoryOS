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

struct DemoText: Sendable {
  let english: String
  let arabic: String

  init(_ english: String, _ arabic: String) {
    self.english = english
    self.arabic = arabic
  }

  func value(in language: AppLanguage) -> String {
    language.text(english, arabic)
  }

  func matches(_ query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || english.localizedStandardContains(trimmed)
      || arabic.localizedStandardContains(trimmed)
  }
}

enum DemoRecordKind: Sendable {
  case person, project, capture

  var symbol: String {
    switch self {
    case .person: "person"
    case .project: "folder"
    case .capture: "text.alignleading"
    }
  }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .person: language.text("Person", "شخص")
    case .project: language.text("Project", "مشروع")
    case .capture: language.text("Capture", "ملاحظة")
    }
  }
}

struct DemoRecord: Identifiable, Sendable {
  let id: String
  let kind: DemoRecordKind
  let title: DemoText
  let summary: DemoText
  // Original sample text stays in its original language in either interface.
  let source: String
  var plans: [DemoText] = []
  var ideas: [DemoText] = []
}

struct DemoConnection: Sendable {
  let from: String
  let to: String
  let context: DemoText

  func other(than id: String) -> String? {
    if from == id { return to }
    if to == id { return from }
    return nil
  }
}

struct DemoBirthday: Identifiable, Sendable {
  let id: String
  let personID: String
  let date: DemoText
}

enum ReminderChoice: String, CaseIterable, Identifiable, Sendable {
  case off, onDay, dayBefore, weekBefore
  var id: String { rawValue }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .off: language.text("Off", "إيقاف")
    case .onDay: language.text("On the day", "في نفس اليوم")
    case .dayBefore: language.text("One day before", "قبل يوم واحد")
    case .weekBefore: language.text("One week before", "قبل أسبوع واحد")
    }
  }
}

enum DemoDestination: Hashable {
  case record(String)
  case birthday(String)
  case personalProfile(UUID)
  case personalEntry(UUID)
  case personalSource(UUID)
}

struct DemoCatalog: Sendable {
  let records: [DemoRecord]
  let connections: [DemoConnection]
  let birthdays: [DemoBirthday]

  func record(_ id: String) -> DemoRecord? { records.first { $0.id == id } }
  func birthday(_ id: String) -> DemoBirthday? { birthdays.first { $0.id == id } }
  func birthday(for personID: String) -> DemoBirthday? {
    birthdays.first { $0.personID == personID }
  }

  func records(of kind: DemoRecordKind, matching query: String = "") -> [DemoRecord] {
    records.filter { $0.kind == kind && ($0.title.matches(query) || $0.summary.matches(query)) }
  }

  func connections(for id: String) -> [(record: DemoRecord, context: DemoText)] {
    connections.compactMap { connection in
      guard let otherID = connection.other(than: id), let record = record(otherID) else {
        return nil
      }
      return (record, connection.context)
    }
  }

  static let sample = DemoCatalog(
    records: [
      DemoRecord(
        id: "ali", kind: .person, title: DemoText("Ali Hassan", "علي حسن"),
        summary: DemoText(
          "A friend. We talked about a small website.", "صديق. تحدثنا عن موقع صغير."),
        source: "علي: خلينا نخلي الموقع بسيط. We can review the first draft together."),
      DemoRecord(
        id: "sara", kind: .person, title: DemoText("Sara Noor", "سارة نور"),
        summary: DemoText(
          "A designer with ideas for the reading room.", "مصممة لديها أفكار لغرفة القراءة."),
        source: "Sara: A quiet reading corner, with space for Arabic books. ركن بسيط ومريح."),
      DemoRecord(
        id: "omar", kind: .person, title: DemoText("Omar Salim", "عمر سالم"),
        summary: DemoText(
          "A friend helping plan the reading room.", "صديق يساعد في تخطيط غرفة القراءة."),
        source: "عمر: أشوف القياسات يوم الجمعة. The shelves can wait until we agree."),
      DemoRecord(
        id: "website", kind: .project, title: DemoText("Small website", "موقع صغير"),
        summary: DemoText(
          "A simple site for a fictional neighbourhood studio.", "موقع بسيط لاستوديو خيالي في الحي."
        ),
        source: "Sample project brief: one page, clear contact details, Arabic and English.",
        plans: [
          DemoText("Review the first page with Ali.", "مراجعة الصفحة الأولى مع علي."),
          DemoText("Prepare Arabic and English copy.", "إعداد النص بالعربية والإنجليزية."),
        ],
        ideas: [
          DemoText("We might add a small photo gallery later.", "قد نضيف معرض صور صغيراً لاحقاً.")
        ]),
      DemoRecord(
        id: "reading", kind: .project, title: DemoText("Reading room", "غرفة القراءة"),
        summary: DemoText("A calm place to read with friends.", "مكان هادئ للقراءة مع الأصدقاء."),
        source: "فكرة تجريبية: ركن للقراءة. Sara suggested warm light; Omar will check the space.",
        plans: [
          DemoText("Check the room dimensions with Omar.", "التأكد من قياسات الغرفة مع عمر.")
        ],
        ideas: [
          DemoText(
            "Maybe use movable shelves; no decision yet.", "ربما نستخدم رفوفاً متحركة؛ لم نقرر بعد.")
        ]),
      DemoRecord(
        id: "chat-ali", kind: .capture, title: DemoText("Website conversation", "حديث الموقع"),
        summary: DemoText(
          "Ali suggested keeping the first version small.", "اقترح علي أن تكون النسخة الأولى بسيطة."
        ),
        source: "Ali: Keep version 1 simple. نراجع الصفحة الأولى سوا، ويمكن نضيف الصور بعدين."),
      DemoRecord(
        id: "chat-sara", kind: .capture, title: DemoText("A reading corner", "ركن للقراءة"),
        summary: DemoText(
          "Sara suggested warm light and Arabic books.", "اقترحت سارة إضاءة دافئة وكتباً عربية."),
        source: "Sara: Warm light and a shelf for Arabic books. نريد مكان هادئ للقراءة."),
      DemoRecord(
        id: "chat-omar", kind: .capture, title: DemoText("Room measurements", "قياسات الغرفة"),
        summary: DemoText(
          "Omar offered to check the space on Friday.", "عرض عمر التأكد من المكان يوم الجمعة."),
        source: "عمر: أقيس الغرفة الجمعة. No shelves ordered; let's agree on the layout first."),
    ],
    connections: [
      DemoConnection(
        from: "ali", to: "website",
        context: DemoText("Discussed the first version", "ناقش النسخة الأولى")),
      DemoConnection(
        from: "ali", to: "chat-ali",
        context: DemoText("Said in the sample conversation", "قال في الحديث التجريبي")),
      DemoConnection(
        from: "website", to: "chat-ali", context: DemoText("Source discussion", "الحديث المصدر")),
      DemoConnection(
        from: "sara", to: "reading",
        context: DemoText("Suggested the reading corner", "اقترحت ركن القراءة")),
      DemoConnection(
        from: "sara", to: "chat-sara", context: DemoText("Shared a design idea", "شاركت فكرة تصميم")
      ),
      DemoConnection(
        from: "reading", to: "chat-sara", context: DemoText("Source idea", "الفكرة المصدر")),
      DemoConnection(
        from: "omar", to: "reading",
        context: DemoText("Helping with measurements", "يساعد في القياسات")),
      DemoConnection(
        from: "omar", to: "chat-omar",
        context: DemoText("Offered to measure the room", "عرض قياس الغرفة")),
      DemoConnection(
        from: "reading", to: "chat-omar", context: DemoText("Source plan", "الخطة المصدر")),
    ],
    birthdays: [
      DemoBirthday(id: "birthday-ali", personID: "ali", date: DemoText("12 May", "١٢ أيار")),
      DemoBirthday(id: "birthday-sara", personID: "sara", date: DemoText("24 August", "٢٤ آب")),
      DemoBirthday(
        id: "birthday-omar", personID: "omar", date: DemoText("3 December", "٣ كانون الأول")),
    ]
  )
}
