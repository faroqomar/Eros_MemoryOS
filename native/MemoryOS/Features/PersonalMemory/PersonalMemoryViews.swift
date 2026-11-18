import MemoryCore
import SwiftUI
import UniformTypeIdentifiers

struct PersonalMemoryHomeView: View {
  @Bindable var model: PersonalMemoryViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  let openCapture: () -> Void
  @State private var originals = false
  @State private var adding = false
  @State private var exporting = false
  @State private var restoring = false

  var body: some View {
    VStack(spacing: 0) {
      Picker(language.text("Memory collection", "مجموعة الذكريات"), selection: $originals) {
        Text(language.text("Organized", "منظمة")).tag(false)
        Text(language.text("Saved records", "السجلات المحفوظة")).tag(true)
      }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
      if originals {
        LocalRecordsListView(model: records, language: language, openCapture: openCapture)
      } else {
        List {
          PersonalMemoryStatus(model: model, language: language)
          if !model.snapshot.pendingSources.isEmpty {
            Section(language.text("A quick question", "سؤال قصير")) {
              ForEach(model.snapshot.pendingSources.reversed()) { source in
                PersonalClarificationCard(model: model, source: source, language: language)
              }
            }
          }
          Section(language.text("Lasting memory", "الذاكرة الدائمة")) {
            if model.snapshot.currentEntries.isEmpty {
              Text(
                language.text(
                  model.automaticMemoryUnavailable
                    ? "Your original messages stay saved. You can add and correct information here."
                    : "Chat as usual. Your originals stay here while MemoryOS organizes useful information.",
                  model.automaticMemoryUnavailable
                    ? "تبقى رسائلك الأصلية محفوظة. يمكنك إضافة المعلومات وتصحيحها هنا."
                    : "تحدث كالمعتاد. يبقى كلامك الأصلي هنا بينما ينظم MemoryOS المعلومات المفيدة.")
              )
              .foregroundStyle(MemoryTheme.secondary)
            }
            ForEach(model.snapshot.currentEntries.reversed()) { entry in
              NavigationLink(value: DemoDestination.personalEntry(entry.id)) {
                PersonalEntryRow(entry: entry, language: language)
              }
            }
          }
          Section(language.text("Original sources", "المصادر الأصلية")) {
            ForEach(model.snapshot.sources.reversed()) { source in
              NavigationLink(value: DemoDestination.personalSource(source.id)) {
                VStack(alignment: .leading, spacing: 5) {
                  Text(source.text).lineLimit(2)
                  Text(source.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(MemoryTheme.secondary)
                }
              }
            }
          }
          PersonalHistorySection(model: model, language: language)
          Section(language.text("Organized memory backup", "نسخة الذاكرة المنظمة")) {
            Text(
              language.text(
                "Export a readable copy, including sources and images. Saved records and audio have separate storage.",
                "صدّر نسخة مقروءة تشمل المصادر والصور. السجلات المحفوظة والصوت في تخزين منفصل.")
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
            Button(language.text("Export organized memory", "تصدير الذاكرة المنظمة")) {
              Task { if await model.exportArchive() { exporting = true } }
            }.disabled(model.isBusy).accessibilityIdentifier("export-personal-memory")
            Button(language.text("Restore into an empty memory", "استعادة إلى ذاكرة فارغة")) {
              restoring = true
            }
            .disabled(model.isBusy || !model.snapshot.sources.isEmpty)
          }
        }.scrollContentBackground(.hidden)
          .refreshable { await model.load() }
          .accessibilityIdentifier("personal-memory-list")
      }
    }
    .safeAreaInset(edge: .bottom) {
      if !originals {
        HStack {
          Button(language.text("Add information", "إضافة معلومة")) { adding = true }
            .accessibilityIdentifier("add-personal-information")
          Spacer()
          Button(language.text("Undo", "تراجع")) { Task { await model.undo() } }
            .disabled(model.isBusy || model.snapshot.events.isEmpty)
            .accessibilityIdentifier("personal-undo")
        }.padding().background(MemoryTheme.canvas)
      }
    }
    .sheet(isPresented: $adding) {
      PersonalInformationEditor(model: model, profileID: nil, language: language)
    }
    .fileExporter(
      isPresented: $exporting,
      document: model.exportedArchive.map { PersonalMemoryDocument(data: $0) },
      contentType: .json, defaultFilename: "MemoryOS-organized-memory"
    ) { result in model.finishExport(result) }
    .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url): Task { await model.restoreArchive(url) }
      case .failure(let error): model.fileOperationFailed(error)
      }
    }
    .task { await model.load() }
  }
}

private struct PersonalMemoryDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  let data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

struct PersonalClarificationCard: View {
  let model: PersonalMemoryViewModel
  let source: PersonalMemorySource
  let language: AppLanguage
  @State private var answer = ""

  private var protectedEntry: PersonalMemoryEntry? {
    guard let id = source.analysis?.protectedEntryID else { return nil }
    return model.snapshot.entries.first { $0.id == id }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(source.analysis?.quote ?? source.text).lineLimit(4)
        .foregroundStyle(MemoryTheme.secondary)
      Text(
        source.analysis?.question ?? language.text("Can you clarify this?", "هل يمكنك توضيح هذا؟")
      )
      .font(.headline).accessibilityIdentifier("personal-clarification-question")
      if let protectedEntry {
        Text(
          language.text(
            "Review the saved memory. Confirm any correction before saving.",
            "راجع الذكرى المحفوظة وأكد أي تصحيح قبل حفظه.")
        )
        .font(.caption).foregroundStyle(MemoryTheme.secondary)
        NavigationLink(value: DemoDestination.personalEntry(protectedEntry.id)) {
          Label(
            language.text("Review saved memory", "مراجعة الذكرى المحفوظة"), systemImage: "doc.text"
          )
          .frame(minHeight: 44)
        }.accessibilityIdentifier("review-protected-memory")
      } else {
        TextField(language.text("Your answer", "إجابتك"), text: $answer, axis: .vertical)
          .lineLimit(1...5)
          .accessibilityIdentifier("personal-clarification-answer")
        Button(language.text("Save answer", "حفظ الإجابة")) {
          Task {
            if await model.answerClarification(source.id, answer: answer) { answer = "" }
          }
        }
        .frame(minHeight: 44)
        .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("save-personal-clarification")
      }
      Button(language.text("Skip · keep original", "تجاوز مع الاحتفاظ بالأصل")) {
        Task { await model.skipClarification(source.id) }
      }
      .frame(minHeight: 44).accessibilityIdentifier("skip-personal-clarification")
      Text(
        language.text(
          "Your original stays saved. The unclear part does not become memory.",
          "يبقى كلامك الأصلي محفوظاً. لا نضيف الجزء غير الواضح إلى الذاكرة.")
      )
      .font(.caption).foregroundStyle(MemoryTheme.secondary)
    }
    .padding(.vertical, 8)
    .disabled(model.isBusy || !model.hasLoaded)
    .accessibilityIdentifier("clarify-\(source.id)")
    .onChange(of: source.id) { _, _ in answer = "" }
  }
}

struct PersonalEntryRow: View {
  let entry: PersonalMemoryEntry
  let language: AppLanguage
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.text).lineLimit(3)
      Text(entry.kind.title(language)).font(.caption).foregroundStyle(MemoryTheme.secondary)
      if entry.supersededByID != nil {
        Text(language.text("Earlier report", "معلومة سابقة"))
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
      if entry.isEpisode == true {
        Text(language.text("Event", "حدث") + (entry.eventTimeExpression.map { " · " + $0 } ?? ""))
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
      let categories = entry.categories.filter { $0 != entry.kind.rawValue }
      if !categories.isEmpty {
        Text(categories.joined(separator: " · ")).font(.caption)
      }
    }.padding(.vertical, 4)
  }
}

struct PersonalSourceView: View {
  @Environment(PersonalMemoryViewModel.self) private var model
  let source: PersonalMemorySource
  let language: AppLanguage
  private var current: PersonalMemorySource {
    model.snapshot.sources.first { $0.id == source.id } ?? source
  }
  private var entries: [PersonalMemoryEntry] {
    model.snapshot.entries.filter { $0.sourceIDs.contains(source.id) }
      .sorted { $0.createdAt > $1.createdAt }
  }

  var body: some View {
    List {
      PersonalMemoryStatus(model: model, language: language)
      Section(language.text("Unchanged original", "الأصل دون تعديل")) {
        Text(source.text).textSelection(.enabled).accessibilityIdentifier("personal-original")
        Text(source.createdAt, format: .dateTime.year().month().day().hour().minute())
        Text(source.origin).foregroundStyle(MemoryTheme.secondary)
      }
      if let context = source.clarificationContext {
        Section(language.text("Question you answered", "السؤال الذي أجبت عنه")) {
          Text(context.question)
          Text(context.quote).foregroundStyle(MemoryTheme.secondary)
          NavigationLink(value: DemoDestination.personalSource(context.parentSourceID)) {
            Text(language.text("Original conversation source", "المصدر الأصلي للمحادثة"))
          }
        }
      }
      if current.analysis?.status == .needsClarification {
        Section(language.text("A quick question", "سؤال قصير")) {
          PersonalClarificationCard(model: model, source: current, language: language)
        }
      }
      if let answerID = current.analysis?.answerSourceID,
        let answer = model.snapshot.sources.first(where: { $0.id == answerID })
      {
        Section(language.text("Your clarification", "توضيحك")) {
          if let context = answer.clarificationContext { Text(context.question) }
          NavigationLink(value: DemoDestination.personalSource(answer.id)) {
            Text(answer.text).lineLimit(4)
          }
        }
      }
      Section(language.text("Memory and history from this source", "الذكريات والسجل من هذا المصدر"))
      {
        if entries.isEmpty {
          Text(
            language.text(
              "No derived memory from this source.", "لا توجد ذكرى مشتقة من هذا المصدر.")
          )
          .foregroundStyle(MemoryTheme.secondary)
        }
        ForEach(entries) { entry in
          NavigationLink(value: DemoDestination.personalEntry(entry.id)) {
            PersonalEntryRow(entry: entry, language: language)
          }
        }
      }
      PersonalHistorySection(model: model, language: language)
    }
    .scrollContentBackground(.hidden)
    .navigationTitle(language.text("Source", "المصدر"))
    .toolbar(.visible, for: .navigationBar)
    .background(MemoryTheme.canvas)
  }
}

/// Shared status for the existing memory panel and ordinary chat; private chats omit it.
struct PersonalOrganizationStatus: View {
  let model: PersonalMemoryViewModel
  let language: AppLanguage
  var conversationID: UUID? = nil
  var canRetry = true
  private var pending: Bool {
    model.snapshot.analysisPendingSources.contains {
      conversationID == nil || $0.conversationID == conversationID
    }
  }
  private var deferred: Bool {
    model.snapshot.deferredSources.contains {
      conversationID == nil || $0.conversationID == conversationID
    }
      || (conversationID == nil && model.organizationFailed)
  }

  var body: some View {
    if model.automaticMemoryUnavailable {
      Label(
        language.text(
          "Automatic memory is not ready in this build. Your original messages stay saved.",
          "الذاكرة التلقائية غير جاهزة في هذا الإصدار. تبقى رسائلك الأصلية محفوظة."),
        systemImage: "info.circle"
      )
      .font(.caption).foregroundStyle(MemoryTheme.secondary)
      .accessibilityIdentifier("automatic-memory-unavailable")
    } else if pending || deferred {
      VStack(alignment: .leading, spacing: 6) {
        if pending {
          if model.isOrganizing {
            ProgressView(language.text("Organizing saved chats…", "جارٍ تنظيم المحادثات المحفوظة…"))
          } else {
            Label(
              language.text("Memory organization queued", "تنظيم الذاكرة قيد الانتظار"),
              systemImage: "clock")
          }
        }
        if deferred {
          Text(
            language.text(
              "Your originals are saved. Some information still needs organizing.",
              "حفظنا كلامك الأصلي. ما زالت بعض المعلومات بحاجة إلى تنظيم."))
          Button(language.text("Retry organization", "إعادة محاولة التنظيم")) {
            Task { await model.retryOrganization() }
          }
          .frame(minHeight: 44)
          .disabled(!canRetry || model.isBusy || model.isOrganizing || !model.hasLoaded)
          .accessibilityIdentifier("retry-personal-organization")
        }
      }
      .font(.caption).foregroundStyle(MemoryTheme.secondary)
      .accessibilityIdentifier("personal-organization-status")
    }
  }
}

struct PersonalMemoryStatus: View {
  let model: PersonalMemoryViewModel
  let language: AppLanguage
  var body: some View {
    PersonalOrganizationStatus(model: model, language: language)
    if model.isBusy { ProgressView(language.text("Saving…", "جارٍ الحفظ…")) }
    if let failure = model.failure {
      Section {
        Text(message(failure)).foregroundStyle(MemoryTheme.secondary)
        Button(language.text("Reload", "إعادة التحميل")) { Task { await model.load() } }
      }.accessibilityIdentifier("personal-memory-error")
    }
  }
  private func message(_ failure: PersonalMemoryViewModel.Failure) -> String {
    switch failure {
    case .imageTooLarge:
      language.text("Choose an image under 2 MB.", "اختر صورة أقل من ٢ ميغابايت.")
    case .invalidImage:
      language.text(
        "This image could not open. Choose another image.", "تعذر فتح الصورة. اختر صورة أخرى.")
    case .storage:
      language.text(
        "Could not read or save memory. Unlock the device, check storage, then reload.",
        "تعذر فتح أو حفظ الذاكرة. افتح قفل الجهاز وتحقق من المساحة ثم أعد التحميل.")
    case .capacity:
      language.text(
        "Memory reached its size limit. Export a copy before making more changes.",
        "وصلت الذاكرة إلى حد حجمها. صدّر نسخة قبل إجراء تغييرات أخرى.")
    case .invalidAction:
      language.text(
        "This change could not save. Your input stays here. Check its sources and try again.",
        "تعذر حفظ التغيير. يبقى إدخالك هنا. راجع المصادر وحاول مجدداً.")
    }
  }
}

struct PersonalHistorySection: View {
  let model: PersonalMemoryViewModel
  let language: AppLanguage
  var body: some View {
    if !model.snapshot.events.isEmpty {
      Section(language.text("Recent changes · undo available", "تغييرات حديثة قابلة للتراجع")) {
        ForEach(model.snapshot.events.reversed().prefix(10)) { event in
          VStack(alignment: .leading, spacing: 4) {
            Text(event.summary)
            Text(event.createdAt, format: .dateTime.month().day().hour().minute()).font(.caption)
          }
        }
      }
    }
  }
}
