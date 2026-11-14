import SwiftUI

struct DemoRow: View {
  let title: String
  let subtitle: String
  let symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 23))
        .foregroundStyle(MemoryTheme.secondary)
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        Text(subtitle).font(.subheadline).foregroundStyle(MemoryTheme.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 10)
    .frame(minHeight: 44)
    .accessibilityElement(children: .combine)
  }
}

struct DemoFootnote: View {
  let language: AppLanguage
  var body: some View {
    Text(
      language.text(
        "Fictional sample data. Changes last for this session.",
        "بيانات خيالية للتجربة. تبقى التغييرات لهذه الجلسة.")
    )
    .font(.footnote)
    .foregroundStyle(MemoryTheme.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct RecordLink: View {
  let record: DemoRecord
  let language: AppLanguage
  var context: String? = nil

  var body: some View {
    NavigationLink(value: DemoDestination.record(record.id)) {
      DemoRow(
        title: record.title.value(in: language),
        subtitle: context ?? record.summary.value(in: language), symbol: record.kind.symbol)
    }
    .accessibilityIdentifier("record-\(record.id)")
  }
}
