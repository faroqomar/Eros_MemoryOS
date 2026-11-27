import MemoryCore
import SwiftUI
import UniformTypeIdentifiers

struct PersonalMemoryHomeView: View {
  @Bindable var model: PersonalMemoryViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  let openCapture: () -> Void
  let openCollection: (AppSection) -> Void
  @Binding var originals: Bool
  @State private var adding = false
  @State private var exporting = false
  @State private var restoring = false
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(spacing: 0) {
      Picker(language.text("Memory collection", "مجموعة الذكريات"), selection: $originals) {
        Text(language.text("Organized", "منظمة")).tag(false)
        Text(language.text("Saved records", "السجلات المحفوظة")).tag(true)
      }
      .modifier(NotesCollectionPickerStyle(usesMenu: typeSize.isAccessibilitySize))
      .padding(.horizontal).padding(.vertical, 8)
      if originals {
        LocalRecordsListView(model: records, language: language, openCapture: openCapture)
      } else {
        List {
          Section {
            editingActions
          }
          Section(language.text("Collections", "المجموعات")) {
            collectionRow(
              .profiles, symbol: "person.2",
              subtitle: language.text(
                "Profiles and what you remember about them", "الملفات وما تتذكره عن أصحابها"))
            collectionRow(
              .projects, symbol: "folder",
              subtitle: language.text(
                "Project notes, plans and ideas", "ملاحظات المشاريع والخطط والأفكار"))
          }
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
          if !model.snapshot.sources.isEmpty {
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

  private var editingActions: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(spacing: 12))
    return layout {
      Button {
        adding = true
      } label: {
        Label(language.text("Add information", "إضافة معلومة"), systemImage: "plus")
          .font(.body.weight(.semibold))
          .frame(minHeight: 44, alignment: .leading)
      }
      .buttonStyle(.borderless)
      .foregroundStyle(MemoryTheme.workspaceAccent)
      .accessibilityIdentifier("add-personal-information")
      if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
      Button {
        Task { await model.undo() }
      } label: {
        Label(language.text("Undo", "تراجع"), systemImage: "arrow.uturn.backward")
          .frame(minWidth: 44, minHeight: 44)
      }
      .buttonStyle(.borderless)
      .accessibilityHint(
        language.text("Reverses the last memory change", "يلغي آخر تغيير في الذاكرة")
      )
      .disabled(model.isBusy || model.snapshot.events.isEmpty)
      .accessibilityIdentifier("personal-undo")
    }
  }

  private func collectionRow(_ section: AppSection, symbol: String, subtitle: String) -> some View {
    Button {
      openCollection(section)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: symbol)
          .font(.title3)
          .frame(width: 44, height: 44)
          .foregroundStyle(MemoryTheme.workspaceAccent)
          .background(
            MemoryTheme.workspaceAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)
          )
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(section.title(in: language)).font(.body.weight(.semibold))
          Text(subtitle).font(.subheadline).foregroundStyle(MemoryTheme.secondary)
        }
        .accessibilityElement(children: .combine)
        Spacer(minLength: 8)
        Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
          .foregroundStyle(MemoryTheme.secondary)
          .accessibilityHidden(true)
      }
      .foregroundStyle(MemoryTheme.ink)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("notes-collection-\(section.rawValue)")
  }
}

private struct NotesCollectionPickerStyle: ViewModifier {
  let usesMenu: Bool

  @ViewBuilder func body(content: Content) -> some View {
    if usesMenu {
      content.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
    } else {
      content.pickerStyle(.segmented)
    }
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
      Text(entry.statusTitle(language)).font(.caption).foregroundStyle(MemoryTheme.secondary)
      if let confirmation = entry.confirmationTitle(language) {
        Text(confirmation).font(.caption).foregroundStyle(MemoryTheme.secondary)
      }
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
  @Environment(\.dismiss) private var dismiss
  @State private var confirmingForget = false
  let sourceID: UUID
  let language: AppLanguage
  private var entries: [PersonalMemoryEntry] {
    model.snapshot.entries.filter { $0.sourceIDs.contains(sourceID) }
      .sorted { $0.createdAt > $1.createdAt }
  }

  var body: some View {
    Group {
      if let context = model.sourceContext(sourceID) {
        let source = context.source
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
              NavigationLink {
                PersonalSourceView(sourceID: context.parentSourceID, language: language)
              } label: {
                Text(language.text("Original conversation source", "المصدر الأصلي للمحادثة"))
              }
            }
          }
          if source.analysis?.status == .needsClarification {
            Section(language.text("A quick question", "سؤال قصير")) {
              PersonalClarificationCard(model: model, source: source, language: language)
            }
          }
          if let answerID = source.analysis?.answerSourceID,
            let answer = model.snapshot.sources.first(where: { $0.id == answerID })
          {
            Section(language.text("Your clarification", "توضيحك")) {
              if let context = answer.clarificationContext { Text(context.question) }
              NavigationLink {
                PersonalSourceView(sourceID: answer.id, language: language)
              } label: {
                Text(answer.text).lineLimit(4)
              }
            }
          }
          if source.conversationID != nil {
            Section(language.text("Adjacent saved messages", "الرسائل المحفوظة المجاورة")) {
              if context.adjacent.isEmpty {
                Text(
                  language.text(
                    "No adjacent saved message is available.", "لا تتوفر رسالة محفوظة مجاورة.")
                )
                .foregroundStyle(MemoryTheme.secondary)
              }
              ForEach(context.adjacent) { adjacent in
                originalLink(adjacent)
              }
            }
          }
          if !context.linked.isEmpty {
            Section(language.text("Linked originals", "الأصول المرتبطة")) {
              ForEach(context.linked, id: \.0.id) { connection, original in
                VStack(alignment: .leading, spacing: 5) {
                  Text(connection.label.searchConnectionTitle(language))
                    .font(.caption).foregroundStyle(MemoryTheme.secondary)
                  originalLink(original)
                }
              }
            }
          }
          Section(
            language.text("Memory and history from this source", "الذكريات والسجل من هذا المصدر")
          ) {
            if entries.isEmpty {
              Text(
                language.text(
                  "No derived memory from this source.", "لا توجد ذكرى مشتقة من هذا المصدر.")
              )
              .foregroundStyle(MemoryTheme.secondary)
            }
            ForEach(entries) { entry in
              NavigationLink {
                PersonalEntryDetail(model: model, entryID: entry.id, language: language)
              } label: {
                PersonalEntryRow(entry: entry, language: language)
              }
            }
          }
          PersonalHistorySection(model: model, language: language)
          Section {
            Button(
              language.text("Forget this memory source", "نسيان هذا المصدر من الذاكرة"),
              role: .destructive
            ) {
              confirmingForget = true
            }.disabled(model.isBusy).accessibilityIdentifier("forget-personal-source")
            Text(
              language.text(
                "This removes this source and dependent information from personal memory. Separate chat history, saved records, recordings and exported copies remain.",
                "يزيل هذا المصدر والمعلومات التابعة من الذاكرة الشخصية. يبقى سجل المحادثات والسجلات والتسجيلات والنسخ المصدرة المنفصلة."
              )
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
          }
        }
      } else {
        ContentUnavailableView {
          Label(
            language.text("Source unavailable", "المصدر غير متاح"), systemImage: "doc.questionmark")
        } description: {
          Text(
            language.text(
              "This source may have been removed or could not be loaded. Refresh to check again, or go back.",
              "قد يكون هذا المصدر أزيل أو تعذر تحميله. حدّث للتحقق مجدداً أو ارجع."))
        } actions: {
          Button(language.text("Refresh", "تحديث")) { Task { await model.load() } }.disabled(
            model.isBusy)
          Button(language.text("Go back", "رجوع")) { dismiss() }
        }.accessibilityIdentifier("personal-source-unavailable")
      }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle(language.text("Source", "المصدر"))
    .toolbar(.visible, for: .navigationBar)
    .background(MemoryTheme.canvas)
    .task { await model.load() }
    .refreshable { await model.load() }
    .alert(
      language.text("Forget source and dependent memories?", "نسيان المصدر والذكريات التابعة؟"),
      isPresented: $confirmingForget
    ) {
      Button(language.text("Cancel", "إلغاء"), role: .cancel) {}
        .accessibilityIdentifier("cancel-forget-personal-source")
      Button(language.text("Forget source", "نسيان المصدر"), role: .destructive) {
        Task { if await model.forgetSource(sourceID) { dismiss() } }
      }
      .accessibilityIdentifier("confirm-forget-personal-source")
    } message: {
      Text(
        language.text(
          "This permanently removes this source and dependent memories, and clears ALL personal-memory undo history, including unrelated changes. You cannot undo this. Other app collections and exported copies remain.",
          "يحذف هذا المصدر والذكريات التابعة نهائياً ويمسح سجل التراجع الكامل للذاكرة الشخصية، بما فيه التغييرات غير المرتبطة. لا يمكنك التراجع عن ذلك. تبقى مجموعات التطبيق الأخرى والنسخ المصدرة."
        ))
    }
  }

  private func originalLink(_ original: PersonalMemorySource) -> some View {
    NavigationLink {
      PersonalSourceView(sourceID: original.id, language: language)
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        Text(original.text).lineLimit(4)
        Text(original.createdAt, format: .dateTime.year().month().day().hour().minute())
          .font(.caption)
        Text(original.origin).font(.caption).foregroundStyle(MemoryTheme.secondary)
      }.frame(minHeight: 44)
    }.accessibilityIdentifier("personal-source-context-" + original.id.uuidString)
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
