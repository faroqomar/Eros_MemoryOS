import SwiftUI

enum MenuFocusTarget: Hashable {
  case sidebar, rootMenu, detailMenu
}

struct RootView: View {
  @Bindable var session: DemoSession
  let records: LocalRecordsViewModel
  @State private var menuIsOpen = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AccessibilityFocusState private var menuFocus: MenuFocusTarget?

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        SectionHostView(
          session: session, records: records, section: session.section, menuIsOpen: menuIsOpen,
          openMenu: { setMenu(true) }, menuFocus: $menuFocus
        )
        .id(session.section)
        .accessibilityHidden(menuIsOpen)
        .allowsHitTesting(!menuIsOpen)

        Color.black.opacity(menuIsOpen ? 0.6 : 0)
          .ignoresSafeArea(edges: .bottom)
          .contentShape(Rectangle())
          .onTapGesture { setMenu(false) }
          .allowsHitTesting(menuIsOpen)
          .accessibilityHidden(true)

        SidebarView(session: session, close: { setMenu(false) }, menuFocus: $menuFocus)
          .frame(width: geometry.size.width * 0.84)
          .frame(maxHeight: .infinity)
          .background(MemoryTheme.panel)
          // SwiftUI mirrors the horizontal offset in RTL.
          .offset(x: menuIsOpen ? 0 : -geometry.size.width * 0.84)
          .allowsHitTesting(menuIsOpen)
          .accessibilityHidden(!menuIsOpen)
          .accessibilityAddTraits(.isModal)
          .accessibilityAction(.escape) { setMenu(false) }
      }
      .background(MemoryTheme.canvas)
      .foregroundStyle(MemoryTheme.ink)
    }
  }

  private func setMenu(_ open: Bool) {
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
      menuIsOpen = open
    }
    menuFocus =
      open ? .sidebar : (session.state(for: session.section).path.isEmpty ? .rootMenu : .detailMenu)
  }
}
