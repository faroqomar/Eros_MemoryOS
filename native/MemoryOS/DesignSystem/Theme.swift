import SwiftUI

enum MemoryTheme {
  static let canvas = Color(white: 0.04)
  static let panel = Color(white: 0.07)
  static let ink = Color(white: 0.95)
  static let secondary = Color(white: 0.68)
  static let line = Color(white: 0.38)
  static let selection = Color(white: 0.15)
  static let recordingSurface = Color(white: 0.16)
  static let onFilledControl = Color(white: 0.06)

  // System fonts scale with Dynamic Type and use native Arabic glyphs.
  static let title = Font.system(.title2, design: .default, weight: .bold)
  static let body = Font.system(.title3, design: .default)
  static let caption = Font.system(.subheadline, design: .default)
}

struct IconControl: View {
  let symbol: String
  let label: String
  var filled = false
  var identifier = ""
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 21, weight: .regular))
        .frame(width: 48, height: 48)
        .foregroundStyle(filled ? MemoryTheme.onFilledControl : MemoryTheme.ink)
        .background(filled ? MemoryTheme.ink : .clear, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityIdentifier(identifier)
  }
}

struct ScreenHeader: View {
  let title: String
  let menuLabel: String
  let openMenu: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding

  var body: some View {
    HStack(spacing: 12) {
      IconControl(
        symbol: "line.3.horizontal", label: menuLabel, identifier: "open-menu", action: openMenu
      )
      .accessibilityFocused(menuFocus, equals: .rootMenu)
      Text(title)
        .font(MemoryTheme.title)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 22)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }
}
