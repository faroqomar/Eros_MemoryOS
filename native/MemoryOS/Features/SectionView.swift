import SwiftUI

/// The session retains paths; only the current section renders controls.
struct SectionHostView: View {
  let session: DemoSession
  let records: LocalRecordsViewModel
  let section: AppSection
  let menuIsOpen: Bool
  let openMenu: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding

  var body: some View {
    @Bindable var state = session.state(for: section)
    NavigationStack(path: $state.path) {
      VStack(spacing: 0) {
        ScreenHeader(
          title: section == .capture ? "MemoryOS" : section.title(in: session.language),
          menuLabel: session.language.text("Open menu", "فتح القائمة"), openMenu: openMenu,
          menuFocus: menuFocus
        )
        SectionView(session: session, records: records, section: section, menuIsOpen: menuIsOpen)
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: DemoDestination.self) { destination in
        Group {
          switch destination {
          case .record(let id): RecordDetailView(session: session, recordID: id)
          case .birthday(let id): BirthdayDetailView(session: session, birthdayID: id)
          }
        }
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            IconControl(
              symbol: "line.3.horizontal", label: session.language.text("Open menu", "فتح القائمة"),
              identifier: "open-menu", action: openMenu
            )
            .accessibilityFocused(menuFocus, equals: .detailMenu)
          }
        }
      }
    }
  }
}

struct SectionView: View {
  @Bindable var session: DemoSession
  let records: LocalRecordsViewModel
  let section: AppSection
  let menuIsOpen: Bool
  private var language: AppLanguage { session.language }

  var body: some View {
    Group {
      switch section {
      case .capture:
        CaptureView(session: session, records: records, menuIsOpen: menuIsOpen)
      case .profiles:
        CatalogListView(
          session: session, state: session.state(for: section), kind: .person,
          menuIsOpen: menuIsOpen)
      case .projects:
        CatalogListView(
          session: session, state: session.state(for: section), kind: .project,
          menuIsOpen: menuIsOpen)
      case .birthdays:
        BirthdaysView(session: session)
      case .brainMap:
        BrainMapView(session: session, state: session.state(for: section))
      case .settings:
        Form {
          Picker(language.text("Language", "اللغة"), selection: $session.language) {
            ForEach(AppLanguage.allCases) { item in
              Text(item.name).tag(item)
            }
          }
          .accessibilityIdentifier("language-picker")
          Text(
            language.text(
              "Typed memories stay on this device. Sample profiles and reminder choices remain a demo.",
              "تبقى الذكريات المكتوبة على هذا الجهاز. الملفات التجريبية وخيارات التذكير للعرض فقط.")
          )
          .foregroundStyle(MemoryTheme.secondary)
        }
        .scrollContentBackground(.hidden)
      case .memories:
        LocalRecordsListView(
          model: records, language: language, openCapture: { session.section = .capture })
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MemoryTheme.canvas)
  }
}
