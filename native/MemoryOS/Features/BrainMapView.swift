import SwiftUI

struct BrainMapView: View {
  let session: DemoSession
  @Bindable var state: DemoSectionState
  @Environment(\.dynamicTypeSize) private var typeSize
  private var language: AppLanguage { session.language }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 12) {
            Text(language.text("Explore connections", "استكشف الروابط")).font(.headline)
            focusPicker
          }
        } else {
          HStack {
            Text(language.text("Explore connections", "استكشف الروابط")).font(.headline)
            Spacer(minLength: 12)
            focusPicker
          }
        }
        if typeSize.isAccessibilitySize {
          Text(language.text("List view for larger text", "عرض القائمة للنص الكبير"))
            .font(.subheadline)
            .foregroundStyle(MemoryTheme.secondary)
            .accessibilityIdentifier("map-large-text-presentation")
        } else {
          Picker(language.text("Presentation", "طريقة العرض"), selection: $state.mapListMode) {
            Text(language.text("Map", "الخريطة")).tag(false)
            Text(language.text("List", "القائمة")).tag(true)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("map-presentation")
        }

        if let focused = session.catalog.record(state.focusedRecordID) {
          VStack(alignment: .leading, spacing: 10) {
            Text(language.text("Focus", "التركيز")).font(.caption).foregroundStyle(
              MemoryTheme.secondary)
            RecordLink(record: focused, language: language)
              .accessibilityIdentifier("map-open-\(focused.id)")
          }
          .padding(18)
          .background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 20))

          Text(language.text("Direct connections", "الروابط المباشرة"))
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
          ForEach(session.catalog.connections(for: focused.id), id: \.record.id) { item in
            if state.mapListMode || typeSize.isAccessibilitySize {
              VStack(alignment: .leading, spacing: 4) {
                RecordLink(
                  record: item.record, language: language, context: item.context.value(in: language)
                )
                focusButton(item.record)
              }
            } else {
              HStack(alignment: .top, spacing: 14) {
                // A branch joins the focused record to each direct connection.
                HStack(spacing: 0) {
                  Rectangle().frame(width: 1)
                  Rectangle().frame(width: 14, height: 1)
                  Circle().stroke(lineWidth: 1).frame(width: 8, height: 8)
                }
                .frame(width: 24, height: 66)
                .foregroundStyle(MemoryTheme.line)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                  RecordLink(
                    record: item.record, language: language,
                    context: item.context.value(in: language)
                  )
                  .accessibilityIdentifier("map-open-\(item.record.id)")
                  focusButton(item.record)
                }
              }
            }
          }
          Text(
            language.text(
              "Open a card for its details. Explore from a connection to follow another branch.",
              "افتح بطاقة لعرض تفاصيلها. استكشف من أحد الروابط لتتبع فرع آخر.")
          )
          .font(.footnote).foregroundStyle(MemoryTheme.secondary)
        }
        DemoFootnote(language: language)
      }
      .padding(22)
    }
    .accessibilityIdentifier("brain-map")
  }

  private var focusPicker: some View {
    Menu {
      Picker(language.text("Focus", "التركيز"), selection: $state.focusedRecordID) {
        ForEach(session.catalog.records) { record in
          Text(record.title.value(in: language)).tag(record.id)
        }
      }
    } label: {
      Label(language.text("Choose", "اختر"), systemImage: "arrow.triangle.branch")
        .frame(minHeight: 44)
    }
    .accessibilityIdentifier("map-choose")
  }

  private func focusButton(_ record: DemoRecord) -> some View {
    Button {
      state.focusedRecordID = record.id
    } label: {
      Label(
        language.text("Explore from here", "استكشف من هنا"), systemImage: "arrow.triangle.branch"
      )
      .font(.subheadline)
      .frame(minHeight: 44)
    }
    .accessibilityLabel(
      language.text(
        "Explore connections for \(record.title.english)", "استكشف روابط \(record.title.arabic)")
    )
    .accessibilityIdentifier("map-focus-\(record.id)")
  }
}
