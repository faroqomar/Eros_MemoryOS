import SwiftUI

enum MemoryTheme {
  static let canvas = Color(white: 0.04)
  static let panel = Color(white: 0.07)
  static let ink = Color(white: 0.95)
  static let secondary = Color(white: 0.68)
  static let selection = Color(white: 0.15)
  static let onFilledControl = Color(white: 0.06)
  static let workspaceAccent = Color(red: 0.67, green: 0.86, blue: 0.81)

  // System fonts scale with Dynamic Type and use native Arabic glyphs.
  static let title = Font.system(.title2, design: .default, weight: .bold)
  static let body = Font.system(.title3, design: .default)
  static let caption = Font.system(.subheadline, design: .default)

  static func fieldPrompt(_ label: String) -> Text {
    Text(label).foregroundStyle(secondary)
  }
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
  var searchLabel: String?
  var openSearch: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      IconControl(
        symbol: "line.3.horizontal", label: menuLabel, identifier: "open-menu", action: openMenu
      )
      .memoryGlass(in: Circle(), interactive: true)
      .accessibilityFocused(menuFocus, equals: .rootMenu)
      Text(title)
        .font(MemoryTheme.title)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 0)
      if let searchLabel, let openSearch {
        IconControl(
          symbol: "magnifyingglass", label: searchLabel, identifier: "notes-open-search",
          action: openSearch)
      }
    }
    .padding(.horizontal, 22)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }
}

/// Use glass on controls, with the existing deployment target and transparency preferences intact.
extension View {
  func memoryGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
    modifier(MemoryGlass(shape: shape, interactive: interactive))
  }
}

private struct MemoryGlass<S: Shape>: ViewModifier {
  let shape: S
  let interactive: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  @ViewBuilder func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(MemoryTheme.selection, in: shape)
    } else if #available(iOS 26, *) {
      content.glassEffect(.regular.interactive(interactive), in: shape)
    } else {
      content.background(.ultraThinMaterial, in: shape)
    }
  }
}

struct MemoryGlassGroup<Content: View>: View {
  @ViewBuilder let content: () -> Content
  @ViewBuilder var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: 12, content: content)
    } else {
      content()
    }
  }
}
