import SwiftUI

struct BirthdaysView: View {
  let session: DemoSession
  private var language: AppLanguage { session.language }

  var body: some View {
    List {
      Section {
        ForEach(session.catalog.birthdays) { birthday in
          if let person = session.catalog.record(birthday.personID) {
            NavigationLink(value: DemoDestination.birthday(birthday.id)) {
              DemoRow(
                title: person.title.value(in: language),
                subtitle: birthday.date.value(in: language), symbol: "gift")
            }
            .accessibilityIdentifier("birthday-\(birthday.id)")
          }
        }
      } header: {
        Text(language.text("Sample birthdays", "أعياد ميلاد تجريبية"))
      } footer: {
        Text(
          language.text(
            "Dates repeat each year. Choose a birthday to preview reminders. Nothing is scheduled.",
            "تتكرر التواريخ كل سنة. اختر عيد ميلاد لمعاينة التذكير. لن يجدول التطبيق أي شيء."))
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }
}

struct BirthdayDetailView: View {
  let session: DemoSession
  let birthdayID: String
  private var language: AppLanguage { session.language }

  var body: some View {
    Group {
      if let birthday = session.catalog.birthday(birthdayID),
        let person = session.catalog.record(birthday.personID)
      {
        List {
          Section {
            Text(birthday.date.value(in: language)).font(.title2).padding(.vertical, 10)
            RecordLink(record: person, language: language)
          } header: {
            Text(language.text("Every year", "كل سنة"))
          }

          Section {
            ForEach(ReminderChoice.allCases) { choice in
              Button {
                session.chooseReminder(choice, for: birthday.id)
              } label: {
                HStack(alignment: .firstTextBaseline) {
                  Text(choice.title(in: language))
                  Spacer()
                  if session.reminder(for: birthday.id) == choice {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                  }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("reminder-\(choice.rawValue)")
              .accessibilityAddTraits(
                session.reminder(for: birthday.id) == choice ? [.isSelected] : [])
            }
          } header: {
            Text(language.text("Reminder preview", "معاينة التذكير"))
          } footer: {
            Text(
              language.text(
                "Preview only. No notification or calendar event will be created. Choices reset when the app closes.",
                "معاينة فقط. لن ينشئ التطبيق إشعاراً أو حدث تقويم. تُمسح الخيارات عند إغلاق التطبيق.")
            )
          }

          Section(language.text("Current choice", "الخيار الحالي")) {
            Text(session.reminder(for: birthday.id).title(in: language))
              .accessibilityIdentifier("reminder-current")
          }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(person.title.value(in: language))
        .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView(
          language.text("Birthday unavailable", "عيد الميلاد غير متاح"), systemImage: "gift")
      }
    }
    .background(MemoryTheme.canvas)
    .toolbar(.visible, for: .navigationBar)
  }
}
