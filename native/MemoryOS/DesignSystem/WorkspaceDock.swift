import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
  case record, brain, calendar, notes

  var id: String { rawValue }

  var section: AppSection {
    switch self {
    case .record: .capture
    case .brain: .brainMap
    case .calendar: .calendar
    case .notes: .memories
    }
  }

  func title(in language: AppLanguage) -> String {
    switch self {
    case .record: language.text("Record", "تسجيل")
    case .brain: language.text("Brain", "الذاكرة")
    case .calendar, .notes: section.title(in: language)
    }
  }

  var symbol: String {
    switch self {
    case .record: "waveform"
    case .brain: "brain"
    case .calendar: "calendar"
    case .notes: "folder"
    }
  }
}

struct WorkspaceDock: View {
  let session: DemoSession
  @AppStorage(BrainMark.preferenceKey) private var brainMark: BrainMark = .constellation
  @Environment(\.dynamicTypeSize) private var typeSize

  private var current: WorkspaceTab? {
    switch session.section {
    case .chat, .recordings: .record
    case .birthdays: .calendar
    case .profiles, .projects, .organization: .notes
    case .search, .understanding: .brain
    default: WorkspaceTab.allCases.first { $0.section == session.section }
    }
  }

  var body: some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: 3), count: typeSize.isAccessibilitySize ? 2 : 4)
    LazyVGrid(columns: columns, spacing: 3) {
      ForEach(WorkspaceTab.allCases) { tab in
        let label = tab.title(in: session.language)
        let isCurrent = current == tab
        Button {
          session.section = tab.section
        } label: {
          tabLabel(tab, label: label)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(isCurrent ? MemoryTheme.workspaceAccent : MemoryTheme.secondary)
            .background(
              isCurrent ? MemoryTheme.workspaceAccent.opacity(0.1) : .clear,
              in: RoundedRectangle(cornerRadius: 15)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityValue(tab == .brain ? brainMark.title(in: session.language) : "")
        .accessibilityIdentifier("workspace-tab-\(tab.id)")
      }
    }
    .padding(4)
    .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 21))
    .overlay {
      RoundedRectangle(cornerRadius: 21)
        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        .allowsHitTesting(false)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
    .background(MemoryTheme.canvas)
  }

  private func tabLabel(_ tab: WorkspaceTab, label: String) -> some View {
    Group {
      if typeSize.isAccessibilitySize {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) {
            tabIcon(tab)
            tabTitle(label).fixedSize(horizontal: true, vertical: false)
          }
          VStack(spacing: 4) {
            tabIcon(tab)
            tabTitle(label)
          }
        }
      } else {
        VStack(spacing: 4) {
          tabIcon(tab)
          tabTitle(label)
        }
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 5)
    .accessibilityHidden(true)
  }

  @ViewBuilder private func tabIcon(_ tab: WorkspaceTab) -> some View {
    if tab == .brain {
      BrainMarkView(mark: brainMark).frame(width: 20, height: 20)
    } else {
      Image(systemName: tab.symbol).font(.system(size: 18, weight: .medium))
        .frame(height: 20)
    }
  }

  private func tabTitle(_ label: String) -> some View {
    Text(label).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
  }
}
