import SwiftUI

struct CatalogListView: View {
  let session: DemoSession
  @Bindable var state: DemoSectionState
  let kind: DemoRecordKind
  let menuIsOpen: Bool
  @FocusState private var searchFocused: Bool
  @Environment(\.dynamicTypeSize) private var typeSize
  private var language: AppLanguage { session.language }
  private var records: [DemoRecord] { session.catalog.records(of: kind, matching: state.query) }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 20))
          .accessibilityHidden(true)
        TextField(
          "", text: $state.query,
          prompt: Text(
            typeSize.isAccessibilitySize
              ? language.text("Search", "بحث")
              : kind == .person
                ? language.text("Search people", "ابحث عن شخص")
                : language.text("Search projects", "ابحث عن مشروع")
          ).foregroundStyle(MemoryTheme.secondary), axis: .vertical
        )
        .lineLimit(1...3)
        .padding(.vertical, 12)
        .focused($searchFocused)
        .submitLabel(.search)
        .onSubmit { searchFocused = false }
        .accessibilityLabel(
          language.text("Search sample names or topics", "ابحث في الأسماء أو المواضيع التجريبية")
        )
        .accessibilityIdentifier("catalog-search")
        if !state.query.isEmpty {
          IconControl(
            symbol: "xmark", label: language.text("Clear search", "مسح البحث"),
            identifier: "clear-search"
          ) { state.query = "" }
        }
      }
      .padding(.leading, 14)
      .frame(minHeight: 52)
      .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 14))
      .padding(.horizontal, 22)
      .padding(.vertical, 12)

      if records.isEmpty {
        ContentUnavailableView {
          Label(language.text("No matches", "لا توجد نتائج"), systemImage: "magnifyingglass")
        } description: {
          Text(
            language.text(
              "Try a different name or clear the search.", "جرّب اسماً آخر أو امسح البحث."))
        } actions: {
          Button(language.text("Clear search", "مسح البحث")) {
            state.query = ""
            searchFocused = false
          }
          .frame(minHeight: 44)
          .accessibilityIdentifier("clear-empty-search")
        }
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(records) { record in
              VStack(spacing: 0) {
                HStack {
                  RecordLink(record: record, language: language)
                  Image(systemName: "chevron.forward")
                    .font(.caption).foregroundStyle(MemoryTheme.secondary)
                    .accessibilityHidden(true)
                }
                .padding(.horizontal, 22)
                Divider().padding(.leading, 22)
              }
              .id(record.id)
            }
          }
          .scrollTargetLayout()
          DemoFootnote(language: language).padding(22)
        }
        .scrollPosition(id: $state.topRecordID)
        .scrollDismissesKeyboard(.interactively)
      }
    }
    .onChange(of: menuIsOpen) { _, open in
      if open { searchFocused = false }
    }
    .onChange(of: session.section) { _, _ in searchFocused = false }
  }
}
