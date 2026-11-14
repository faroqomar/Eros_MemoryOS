import SwiftUI

struct RecordDetailView: View {
  let session: DemoSession
  let recordID: String
  private var language: AppLanguage { session.language }

  var body: some View {
    Group {
      if let record = session.catalog.record(recordID) {
        List {
          Section {
            Text(record.summary.value(in: language)).font(.body).padding(.vertical, 6)
          } header: {
            Text(record.kind.title(in: language))
          }

          Section(language.text("Original sample", "النص التجريبي الأصلي")) {
            Text(record.source)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
              .accessibilityIdentifier("original-source")
          }
          if !record.plans.isEmpty {
            Section(language.text("Current plans", "الخطط الحالية")) {
              ForEach(record.plans, id: \.english) { plan in
                Label(plan.value(in: language), systemImage: "checklist").padding(.vertical, 6)
              }
            }
          }
          if !record.ideas.isEmpty {
            Section {
              ForEach(record.ideas, id: \.english) { idea in
                Label(idea.value(in: language), systemImage: "lightbulb").padding(.vertical, 6)
              }
            } header: {
              Text(language.text("Tentative ideas", "أفكار مبدئية"))
            } footer: {
              Text(
                language.text(
                  "Ideas are possibilities, not agreed plans.", "هذه احتمالات ولم نتفق عليها كخطط.")
              )
            }
          }
          if let birthday = session.catalog.birthday(for: record.id) {
            Section(language.text("Birthday", "عيد الميلاد")) {
              NavigationLink(value: DemoDestination.birthday(birthday.id)) {
                DemoRow(
                  title: birthday.date.value(in: language),
                  subtitle: language.text("View reminder choices", "عرض خيارات التذكير"),
                  symbol: "gift")
              }
              .accessibilityIdentifier("birthday-\(birthday.id)")
            }
          }
          Section(language.text("Connections", "الروابط")) {
            ForEach(session.catalog.connections(for: record.id), id: \.record.id) { item in
              RecordLink(
                record: item.record, language: language, context: item.context.value(in: language))
            }
          }
          Section { DemoFootnote(language: language) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(record.title.value(in: language))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("record-detail-\(record.id)")
      } else {
        ContentUnavailableView(
          language.text("Sample unavailable", "العينة غير متاحة"), systemImage: "doc.questionmark",
          description: Text(
            language.text("Go back and choose another sample.", "ارجع واختر عينة أخرى.")))
      }
    }
    .background(MemoryTheme.canvas)
    .toolbar(.visible, for: .navigationBar)
  }
}
