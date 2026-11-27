import SwiftUI

/// Real app-owned graph. Connections stay reachable with larger text and VoiceOver.
struct BrainMapView: View {
  @Bindable var model: MemorySearchViewModel
  let personal: PersonalMemoryViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  let openCapture: () -> Void
  @AppStorage(BrainMark.preferenceKey) private var brainMark: BrainMark = .constellation
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var focusedID: UUID?
  @State private var choosingFocus = false

  private var focus: MemorySearchDocument? {
    focusedID.flatMap { model.graph.document($0) } ?? model.graph.documents.first
  }

  var body: some View {
    List {
      Section {
        NavigationLink {
          MemorySearchView(model: model, personal: personal, records: records, language: language)
        } label: {
          Label(language.text("Search memories", "بحث الذكريات"), systemImage: "magnifyingglass")
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("map-search")
      }
      if model.isBusy { ProgressView(language.text("Loading connections…", "تحميل الروابط…")) }
      if let failure = model.failure {
        Section {
          Text(failure.title(language))
          Button(language.text("Try again", "أعد المحاولة")) { Task { await model.load() } }
            .disabled(model.isBusy)
        }
      }
      if let focus {
        let connections = model.graph.connections(to: focus.id)
        Section(language.text("Focus", "التركيز")) {
          Button {
            choosingFocus = true
          } label: {
            Label(
              language.text("Change focus", "تغيير العنصر"),
              systemImage: "arrow.triangle.branch"
            )
            .frame(minHeight: 44)
          }.accessibilityIdentifier("map-choose")
          NavigationLink {
            MemorySearchDocumentView(
              id: focus.id, model: model, personal: personal, records: records, language: language)
          } label: {
            MemorySearchPassage(document: focus, passage: focus.text, language: language)
          }.accessibilityIdentifier("map-open-\(focus.id)")
        }
        if !connections.isEmpty && dynamicTypeSize <= .xxLarge {
          Section {
            BrainConnectionMap(
              focus: focus, connections: connections, language: language, brainMark: brainMark,
              choose: { focusedID = $0 }
            )
            .accessibilityHidden(true)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
          }
        }
        Section(language.text("Direct connections", "الروابط المباشرة")) {
          if connections.isEmpty {
            Text(
              language.text(
                "No saved connection for this item. Link information from a memory detail, or choose another item.",
                "لا توجد روابط محفوظة لهذا العنصر. اربط المعلومات من تفاصيل الذكرى أو اختر عنصراً آخر."
              )
            )
            .foregroundStyle(MemoryTheme.secondary)
          } else {
            Text(
              language.text(
                "These links show saved context. Check the source before drawing conclusions.",
                "تعرض هذه الروابط سياقاً محفوظاً. تحقق من المصدر قبل استخلاص النتائج."
              )
            )
            .font(.callout).foregroundStyle(MemoryTheme.secondary)
          }
          ForEach(connections, id: \.0.id) { edge, target in
            VStack(alignment: .leading, spacing: 8) {
              Text(edge.label.searchConnectionTitle(language)).font(.caption).foregroundStyle(
                MemoryTheme.secondary)
              NavigationLink {
                MemorySearchDocumentView(
                  id: target.id, model: model, personal: personal, records: records,
                  language: language)
              } label: {
                MemorySearchPassage(document: target, passage: target.text, language: language)
              }.accessibilityIdentifier("map-open-\(target.id)")
              Button {
                focusedID = target.id
              } label: {
                Label(
                  language.text("Explore from here", "استكشف من هنا"),
                  systemImage: "arrow.triangle.branch"
                )
                .frame(minHeight: 44)
              }
              .buttonStyle(.borderless)
              .accessibilityIdentifier("map-focus-\(target.id)")
            }.padding(.vertical, 5)
          }
        }
      } else if !model.isBusy && model.failure == nil {
        ContentUnavailableView {
          Label {
            Text(language.text("Your saved connections", "روابطك المحفوظة"))
          } icon: {
            BrainMarkView(mark: brainMark).frame(width: 34, height: 34)
          }
        } description: {
          Text(
            language.text(
              "Save a thought to start exploring your memories.",
              "احفظ فكرة لتبدأ استكشاف ذكرياتك."))
        } actions: {
          Button(action: openCapture) {
            Label(language.text("Record a thought", "تسجيل فكرة"), systemImage: "mic")
              .frame(minHeight: 44)
          }
          .buttonStyle(.bordered)
          .accessibilityIdentifier("brain-open-capture")
        }
      }
    }
    .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $choosingFocus) {
      BrainMapFocusPicker(documents: model.graph.documents, language: language) { id in
        focusedID = id
        choosingFocus = false
      }
    }
    .accessibilityIdentifier("brain-map")
  }
}

private struct BrainConnectionMap: View {
  let focus: MemorySearchDocument
  let connections: [(MemorySearchConnection, MemorySearchDocument)]
  let language: AppLanguage
  let brainMark: BrainMark
  let choose: (UUID) -> Void
  @Environment(\.layoutDirection) private var layoutDirection

  // The list retains all edge labels and links, including several links to one item.
  private static let positions: [CGPoint] = [
    CGPoint(x: 0.76, y: 0.20), CGPoint(x: 0.24, y: 0.73),
    CGPoint(x: 0.24, y: 0.23), CGPoint(x: 0.76, y: 0.76),
  ]
  private let captionHeight: CGFloat = 36
  private let captionSpacing: CGFloat = 7

  private var neighbors: [MemorySearchDocument] {
    var seen: Set<UUID> = [focus.id]
    var documents: [MemorySearchDocument] = []
    for (_, document) in connections where seen.insert(document.id).inserted {
      documents.append(document)
      if documents.count == Self.positions.count { break }
    }
    return documents
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let center = CGPoint(x: size.width * 0.5, y: size.height * 0.46)
      let nodes = zip(neighbors, Self.positions).map { document, position in
        let x = layoutDirection == .rightToLeft ? 1 - position.x : position.x
        let point = CGPoint(x: x * size.width, y: position.y * size.height)
        return (document: document, point: point)
      }
      let captionOffset = (captionHeight + captionSpacing) / 2
      ZStack {
        Path { path in
          for node in nodes {
            path.move(to: center)
            path.addLine(to: node.point)
          }
        }
        .stroke(MemoryTheme.secondary.opacity(0.44), style: StrokeStyle(lineWidth: 1))
        .accessibilityHidden(true)
        .allowsHitTesting(false)

        VStack(spacing: captionSpacing) {
          BrainMarkView(mark: brainMark)
            .foregroundStyle(MemoryTheme.onFilledControl)
            .frame(width: 31, height: 31)
            .frame(width: 58, height: 58)
            .background(MemoryTheme.ink, in: Circle())
            .padding(8)
            .background(MemoryTheme.selection, in: Circle())
            .overlay(Circle().strokeBorder(MemoryTheme.workspaceAccent.opacity(0.46)))
          caption(focus, width: 148)
        }
        .position(x: center.x, y: center.y + captionOffset)
        .accessibilityHidden(true)

        ForEach(nodes, id: \.document.id) { node in
          nodeButton(node.document)
            .position(x: node.point.x, y: node.point.y + captionOffset)
        }
      }
    }
    .frame(height: 302)
    .background(MemoryTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 26))
    .overlay {
      RoundedRectangle(cornerRadius: 26)
        .strokeBorder(MemoryTheme.secondary.opacity(0.17))
        .allowsHitTesting(false)
    }
  }

  private func nodeButton(_ document: MemorySearchDocument) -> some View {
    Button {
      choose(document.id)
    } label: {
      VStack(spacing: captionSpacing) {
        Image(systemName: symbol(document.destination))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(MemoryTheme.ink)
          .frame(width: 46, height: 46)
          .background(MemoryTheme.panel, in: Circle())
          .overlay(Circle().strokeBorder(MemoryTheme.secondary.opacity(0.64)))
        caption(document, width: 104)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
  }

  private func caption(_ document: MemorySearchDocument, width: CGFloat) -> some View {
    Text(preview(document))
      .font(.caption.weight(.semibold))
      .foregroundStyle(MemoryTheme.ink)
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .frame(width: width, height: captionHeight, alignment: .top)
  }

  private func preview(_ document: MemorySearchDocument) -> String {
    let text = document.text.prefix(100).split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
    return text.isEmpty ? document.kind.title(language) : text
  }

  private func symbol(_ destination: MemorySearchDestination) -> String {
    switch destination {
    case .source: "text.quote"
    case .entry: "bookmark"
    case .profile: "person"
    case .record: "doc.text"
    }
  }
}

private struct BrainMapFocusPicker: View {
  let documents: [MemorySearchDocument]
  let language: AppLanguage
  let choose: (UUID) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  private var matches: [MemorySearchDocument] {
    query.isEmpty ? documents : documents.filter { $0.text.localizedStandardContains(query) }
  }

  var body: some View {
    NavigationStack {
      List {
        if matches.isEmpty {
          ContentUnavailableView(
            language.text("No matching saved items", "لا توجد عناصر محفوظة مطابقة"),
            systemImage: "magnifyingglass",
            description: Text(
              language.text(
                "Try another word or clear the search to see all saved items.",
                "جرّب كلمة أخرى أو امسح البحث لعرض جميع العناصر المحفوظة.")))
          if !query.isEmpty {
            Button(language.text("Clear search", "مسح البحث")) { query = "" }
              .accessibilityIdentifier("map-clear-search")
          }
        }
        ForEach(matches) { document in
          Button {
            choose(document.id)
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(document.kind.title(language)).font(.caption).foregroundStyle(
                MemoryTheme.secondary)
              Text(document.text).lineLimit(3)
            }.padding(.vertical, 5).frame(minHeight: 44)
          }
        }
      }
      .searchable(text: $query, prompt: language.text("Find a saved item", "ابحث عن عنصر محفوظ"))
      .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
      .navigationTitle(language.text("Choose focus", "اختر التركيز"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
        }
      }
    }
  }
}
