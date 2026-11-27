import SwiftUI

struct MemorySearchView: View {
  @Bindable var model: MemorySearchViewModel
  let personal: PersonalMemoryViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  var workspaceRoot = false
  var menuIsOpen = false
  @FocusState private var queryFocused: Bool
  private var hasQuery: Bool {
    !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    List {
      Section {
        let searchLabel = language.text("Search saved memories", "ابحث في الذكريات المحفوظة")
        TextField(
          searchLabel, text: $model.query, prompt: MemoryTheme.fieldPrompt(searchLabel)
        )
        .focused($queryFocused)
        .submitLabel(.search)
        .onSubmit(runSearch)
        .accessibilityLabel(searchLabel)
        .accessibilityIdentifier("memory-search-query")
        Picker(language.text("Search method", "طريقة البحث"), selection: $model.mode) {
          ForEach(MemorySearchMode.allCases) { mode in
            Text(mode.title(language)).tag(mode)
          }
        }.accessibilityIdentifier("memory-search-mode")
        Button(language.text("Search", "بحث"), action: runSearch)
          .disabled(model.isBusy || !hasQuery)
          .accessibilityIdentifier("memory-search-submit")
        Text(model.mode.explanation(language)).font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
      if model.isBusy {
        Section {
          ProgressView(language.text("Checking saved sources…", "جارٍ فحص المصادر المحفوظة…"))
          Button(language.text("Cancel search", "إلغاء البحث")) { model.cancel() }
            .accessibilityIdentifier("memory-search-cancel")
        }
      } else if let failure = model.failure {
        Section {
          Label(failure.title(language), systemImage: "exclamationmark.circle")
          Button(language.text("Try again", "حاول مجدداً")) {
            if hasQuery { runSearch() } else { Task { await model.load() } }
          }
        }.accessibilityIdentifier("memory-search-error")
      } else if model.searched && model.results.isEmpty {
        ContentUnavailableView(
          language.text("No matching sources", "لا توجد مصادر مطابقة"),
          systemImage: "magnifyingglass",
          description: Text(
            language.text(
              "Try another wording or search method. A match alone does not establish a fact.",
              "جرّب صياغة أو طريقة بحث أخرى. التطابق وحده لا يثبت حقيقة.")))
      } else if !model.searched {
        Text(
          language.text(
            "Search for a name, a topic, or words you remember.",
            "ابحث باسم أو موضوع أو بكلمات تتذكرها."
          )
        )
        .foregroundStyle(MemoryTheme.secondary)
      }
      ForEach(model.results) { result in
        Section {
          MemorySearchPassage(
            document: result.document, passage: result.passage, language: language)
          if let connection = result.connection {
            Text(
              language.text("Connected: ", "مرتبط: ") + connection.searchConnectionTitle(language)
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
          }
          NavigationLink {
            MemorySearchDocumentView(
              id: result.id, model: model, personal: personal, records: records, language: language)
          } label: {
            Text(language.text("Open source and context", "افتح المصدر والسياق"))
          }
          .accessibilityIdentifier("memory-search-open-\(result.id)")
        }
      }
      if let elapsed = model.elapsedSeconds {
        Text(language.text("Search time: ", "زمن البحث: ") + String(format: "%.2f s", elapsed))
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .background(MemoryTheme.canvas)
    .navigationTitle(language.text("Search memories", "بحث الذكريات"))
    .toolbar(workspaceRoot ? .hidden : .visible, for: .navigationBar)
    .task { await model.load() }
    .refreshable { await model.load() }
    .onChange(of: menuIsOpen) { _, open in
      if open { queryFocused = false }
    }
    .onDisappear { if model.isBusy { model.cancel() } }
    .accessibilityIdentifier("memory-search")
  }

  private func runSearch() {
    guard hasQuery, !model.isBusy else { return }
    queryFocused = false
    Task { await model.search() }
  }
}

struct MemorySearchPassage: View {
  let document: MemorySearchDocument
  let passage: String
  let language: AppLanguage

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(document.kind.title(language)).font(.caption.weight(.semibold))
        .foregroundStyle(MemoryTheme.secondary)
      if document.detail == "historicalOriginal" {
        Text(
          language.text(
            "Original retained · later information revised", "الأصل محفوظ · عُدلت معلومات لاحقة")
        )
        .font(.caption)
      }
      Text(passage).textSelection(.enabled)
      if let date = document.date {
        Text(date, format: .dateTime.year().month().day().hour().minute())
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
    }.padding(.vertical, 5)
  }
}

struct MemorySearchDocumentView: View {
  let id: UUID
  @Bindable var model: MemorySearchViewModel
  let personal: PersonalMemoryViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage

  var body: some View {
    List {
      if let document = model.graph.document(id) {
        Section {
          MemorySearchPassage(document: document, passage: document.text, language: language)
          if let original = document.originalText, !original.utf8.elementsEqual(document.text.utf8)
          {
            DisclosureGroup(language.text("Unchanged original", "الأصل دون تغيير")) {
              Text(original).textSelection(.enabled)
            }
          }
          NavigationLink(language.text("Open saved item", "افتح العنصر المحفوظ")) {
            destination(document.destination)
          }
        }
        Section(
          language.text(
            "Supporting sources and surrounding context", "المصادر الداعمة والسياق المحيط")
        ) {
          ForEach(document.contextIDs.filter { $0 != id }, id: \.self) { contextID in
            if let context = model.graph.document(contextID) {
              NavigationLink {
                MemorySearchDocumentView(
                  id: contextID, model: model, personal: personal, records: records,
                  language: language)
              } label: {
                MemorySearchPassage(document: context, passage: context.text, language: language)
              }
            }
          }
        }
        Section(language.text("Connections", "الروابط")) {
          ForEach(model.graph.connections(to: id), id: \.0.id) { edge, target in
            NavigationLink {
              MemorySearchDocumentView(
                id: target.id, model: model, personal: personal, records: records,
                language: language)
            } label: {
              VStack(alignment: .leading, spacing: 5) {
                Text(edge.label.searchConnectionTitle(language)).font(.caption)
                Text(target.text).lineLimit(3)
              }
            }
          }
        }
      } else {
        ContentUnavailableView(
          language.text("Source changed or unavailable", "المصدر تغير أو غير متاح"),
          systemImage: "doc.questionmark",
          description: Text(
            language.text(
              "Refresh to check current sources, or return to your search.",
              "حدّث للتحقق من المصادر الحالية أو عد إلى البحث.")))
        Button(language.text("Refresh", "تحديث")) { Task { await model.load() } }
          .disabled(model.isBusy)
      }
    }
    .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
    .navigationTitle(language.text("Source and context", "المصدر والسياق"))
    .toolbar(.visible, for: .navigationBar)
    .task {
      await model.load()
      await personal.load()
      await records.load()
    }
    .refreshable {
      await model.load()
      await personal.load()
      await records.load()
    }
  }

  @ViewBuilder private func destination(_ destination: MemorySearchDestination) -> some View {
    switch destination {
    case .source(let id):
      PersonalSourceView(sourceID: id, language: language)
    case .entry(let id): PersonalEntryDetail(model: personal, entryID: id, language: language)
    case .profile(let id): PersonalProfileDetail(model: personal, profileID: id, language: language)
    case .record(let id): LocalRecordDetailView(model: records, language: language, recordID: id)
    }
  }
}

extension MemorySearchMode {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .keyword: language.text("Keyword", "كلمات")
    case .semantic: language.text("Meaning · experimental", "المعنى · تجريبي")
    case .linked: language.text("Linked records", "سجلات مرتبطة")
    }
  }
  func explanation(_ language: AppLanguage) -> String {
    switch self {
    case .keyword:
      language.text(
        "Matches words in saved sources on this device.",
        "يطابق الكلمات في المصادر المحفوظة على هذا الجهاز.")
    case .semantic:
      language.text(
        "Experimental meaning search can miss relevant sources. Compare with Keyword and review original passages.",
        "قد يفوت البحث التجريبي بالمعنى مصادر مهمة. قارنه ببحث الكلمات وراجع المقاطع الأصلية.")
    case .linked:
      language.text(
        "Finds word matches, then follows direct saved links. A link is context, not proof.",
        "يعثر على الكلمات ثم يتبع الروابط المحفوظة المباشرة. الرابط سياق وليس دليلاً.")
    }
  }
}

extension MemorySearchKind {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .original: language.text("Original statement · author report", "عبارة أصلية · قول صاحبها")
    case .extracted:
      language.text("Extracted information · unconfirmed", "معلومة مستخرجة · غير مؤكدة")
    case .confirmed: language.text("Confirmed by you", "أكدتها أنت")
    case .confirmedInterpretation:
      language.text("Interpretation confirmed by you · revisable", "تفسير أكدته أنت · قابل للتصحيح")
    case .unreviewedInterpretation:
      language.text("Interpretation · author unknown", "تفسير · صاحبه غير محدد")
    case .hypothesis:
      language.text("AI hypothesis · revisable", "فرضية ذكاء اصطناعي · قابلة للتصحيح")
    case .summary: language.text("Source-linked summary", "ملخص مرتبط بالمصادر")
    case .savedRecord: language.text("Saved record · current text", "سجل محفوظ · النص الحالي")
    case .profile: language.text("Person or project", "شخص أو مشروع")
    }
  }
}

extension MemorySearchFailure {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .changed:
      language.text(
        "Your sources changed during search. Search again for current results.",
        "تغيرت المصادر أثناء البحث. ابحث مجدداً للنتائج الحالية.")
    case .invalidQuery: language.text("Enter a search under 4 KB.", "اكتب بحثاً أقل من 4 كيلوبايت.")
    case .invalidResult:
      language.text(
        "The search returned an invalid passage. No result was shown.",
        "أعاد البحث مقطعاً غير صالح. لم نعرض نتيجة.")
    case .ambiguousSubject:
      language.text(
        "Name the person or project more clearly, or use keyword search.",
        "وضّح اسم الشخص أو المشروع، أو استخدم البحث بالكلمات.")
    case .unavailable:
      language.text(
        "Local search could not finish. Check available storage and local model assets, then retry.",
        "تعذر إكمال البحث المحلي. تحقق من المساحة وملفات النموذج المحلي ثم أعد المحاولة.")
    }
  }
}

extension String {
  func searchConnectionTitle(_ language: AppLanguage) -> String {
    switch self {
    case "source": language.text("Supporting original", "الأصل الداعم")
    case "profile": language.text("Linked person or project", "شخص أو مشروع مرتبط")
    case "linkedRecord": language.text("Linked record", "سجل مرتبط")
    default: self
    }
  }
}
