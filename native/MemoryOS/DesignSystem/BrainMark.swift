import SwiftUI

enum BrainMark: String, CaseIterable, Identifiable {
  case constellation, ripple, orbit, branches, aperture

  static let preferenceKey = "memoryos.brainMark"
  var id: String { rawValue }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .constellation: language.text("Constellation", "كوكبة")
    case .ripple: language.text("Ripple", "تموّج")
    case .orbit: language.text("Orbit", "مدار")
    case .branches: language.text("Branches", "أغصان")
    case .aperture: language.text("Aperture", "فتحة العدسة")
    }
  }
}

struct BrainMarkView: View {
  let mark: BrainMark

  var body: some View {
    Canvas { context, size in
      let unit = min(size.width, size.height) / 32
      let origin = CGPoint(x: (size.width - unit * 32) / 2, y: (size.height - unit * 32) / 2)
      var geometry = markGeometry
      let transform = CGAffineTransform(
        a: unit, b: 0, c: 0, d: unit, tx: origin.x, ty: origin.y)
      geometry.lines = geometry.lines.applying(transform)
      geometry.dots = geometry.dots.applying(transform)
      context.stroke(
        geometry.lines, with: .foreground,
        style: StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round, lineJoin: .round))
      context.fill(geometry.dots, with: .foreground)
    }
    .accessibilityHidden(true)
  }

  private var markGeometry: (lines: Path, dots: Path) {
    var lines = Path()
    var dots = Path()

    func trace(_ points: CGPoint...) {
      lines.addLines(points)
    }

    func circle(_ center: CGPoint, radius: CGFloat) -> CGRect {
      CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    switch mark {
    case .constellation:
      let top = CGPoint(x: 15, y: 4)
      let left = CGPoint(x: 5, y: 12)
      let center = CGPoint(x: 15, y: 16)
      let right = CGPoint(x: 27, y: 10)
      let lower = CGPoint(x: 23, y: 21)
      let tip = CGPoint(x: 19, y: 28)
      let back = CGPoint(x: 8, y: 22)
      trace(top, left, back, center, top, right, lower, tip, back)
      trace(center, lower, back)
      for point in [top, left, center, right, lower, tip, back] {
        dots.addEllipse(in: circle(point, radius: 1.85))
      }
    case .ripple:
      for radius in [CGFloat(8), 13] {
        lines.move(to: CGPoint(x: 16 + radius, y: 16))
        lines.addArc(
          center: CGPoint(x: 16, y: 16), radius: radius,
          startAngle: .degrees(0), endAngle: .degrees(310), clockwise: false)
      }
      dots.addEllipse(in: circle(CGPoint(x: 16, y: 16), radius: 3.15))
    case .orbit:
      let ellipse = Path(ellipseIn: CGRect(x: -13, y: -7, width: 26, height: 14))
      for angle in [-Double.pi / 4, Double.pi / 4] {
        lines.addPath(
          ellipse,
          transform: CGAffineTransform(translationX: 16, y: 16).rotated(by: angle))
      }
      dots.addEllipse(in: circle(CGPoint(x: 16, y: 16), radius: 2.45))
    case .branches:
      let base = CGPoint(x: 16, y: 28)
      let fork = CGPoint(x: 16, y: 17)
      let left = CGPoint(x: 5, y: 9)
      let top = CGPoint(x: 16, y: 4)
      let right = CGPoint(x: 27, y: 9)
      trace(base, fork, top)
      lines.move(to: fork)
      lines.addQuadCurve(to: left, control: CGPoint(x: 7, y: 19))
      lines.move(to: fork)
      lines.addQuadCurve(to: right, control: CGPoint(x: 25, y: 19))
      for point in [left, top, right] {
        dots.addEllipse(in: circle(point, radius: 2.4))
      }
    case .aperture:
      let corners = [
        CGPoint(x: 16, y: 3), CGPoint(x: 27, y: 9), CGPoint(x: 27, y: 22),
        CGPoint(x: 16, y: 29), CGPoint(x: 5, y: 22), CGPoint(x: 5, y: 9),
      ]
      lines.addLines(corners)
      lines.closeSubpath()
      for index in corners.indices {
        let end = corners[(index + 2) % corners.count]
        trace(corners[index], CGPoint(x: (end.x + 16) / 2, y: (end.y + 16) / 2))
      }
    }
    return (lines, dots)
  }
}

struct BrainMarkSettingsSection: View {
  let language: AppLanguage
  @AppStorage(BrainMark.preferenceKey) private var selected: BrainMark = .constellation
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Section(language.text("Brain mark", "رمز الذاكرة")) {
      if typeSize >= .xxxLarge {
        ForEach(BrainMark.allCases) { mark in choice(mark, stacked: false) }
      } else {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8
        ) {
          ForEach(BrainMark.allCases) { mark in choice(mark, stacked: true) }
        }
        .padding(.vertical, 6)
      }
    }
  }

  private func choice(_ mark: BrainMark, stacked: Bool) -> some View {
    let isSelected = selected == mark
    let layout =
      stacked
      ? AnyLayout(VStackLayout(spacing: 9)) : AnyLayout(HStackLayout(spacing: 12))
    return Button {
      selected = mark
    } label: {
      layout {
        BrainMarkView(mark: mark).frame(width: 26, height: 26)
          .foregroundStyle(MemoryTheme.workspaceAccent)
        Text(mark.title(in: language))
          .font(stacked ? .caption.weight(.semibold) : .body)
          .multilineTextAlignment(stacked ? .center : .leading)
        if !stacked { Spacer(minLength: 4) }
      }
      .frame(maxWidth: .infinity, minHeight: stacked ? 78 : 48)
      .padding(.horizontal, 8)
      .foregroundStyle(MemoryTheme.ink)
      .background(
        isSelected ? MemoryTheme.workspaceAccent.opacity(0.12) : MemoryTheme.canvas.opacity(0.58),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay(alignment: .topTrailing) {
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MemoryTheme.workspaceAccent)
            .padding(5)
            .accessibilityHidden(true)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(mark.title(in: language))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("brain-mark-\(mark.rawValue)")
  }
}
