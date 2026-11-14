import SwiftUI

struct SidebarView: View {
  let session: DemoSession
  let close: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding
  private var language: AppLanguage { session.language }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("MemoryOS")
          .font(MemoryTheme.title)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 0)
        IconControl(
          symbol: "xmark", label: language.text("Close menu", "إغلاق القائمة"),
          identifier: "close-menu", action: close
        )
        .accessibilityFocused(menuFocus, equals: .sidebar)
      }
      .padding(.top, 14)
      .padding(.bottom, 42)

      ScrollView {
        VStack(spacing: 8) {
          ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
            row(section)
          }
        }
      }
      .scrollIndicators(.hidden)

      row(.settings)
        .padding(.top, 12)
      Text(language.text("A place for your thoughts.", "مساحة لأفكارك."))
        .font(MemoryTheme.caption)
        .foregroundStyle(MemoryTheme.secondary)
        .padding(.horizontal, 8)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }
    .padding(.horizontal, 22)
  }

  private func row(_ section: AppSection) -> some View {
    Button {
      session.section = section
      close()
    } label: {
      HStack(spacing: 20) {
        Image(systemName: section.symbol)
          .font(.system(size: 23, weight: .regular))
          .frame(width: 26)
          .accessibilityHidden(true)
        Text(section.title(in: language))
          .font(MemoryTheme.body)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .frame(minHeight: 52)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        session.section == section ? MemoryTheme.selection : .clear,
        in: RoundedRectangle(cornerRadius: 14)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("section-\(section.rawValue)")
    .accessibilityAddTraits(session.section == section ? [.isSelected] : [])
  }
}
