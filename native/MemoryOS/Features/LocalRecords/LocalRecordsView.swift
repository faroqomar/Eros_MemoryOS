import MemoryCore
import SwiftUI
import UniformTypeIdentifiers

extension RecordKind {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .capture: language.text("Thought", "فكرة مكتوبة")
    case .person: language.text("Person", "شخص")
    case .project: language.text("Project", "مشروع")
    case .idea: language.text("Idea", "فكرة")
    }
  }
}

struct LocalStorageStatus: View {
  @Bindable var model: LocalRecordsViewModel
  let language: AppLanguage
  var body: some View {
    if model.failure {
      VStack(alignment: .leading, spacing: 8) {
        Text(errorMessage)
        Button(language.text("Reload records", "إعادة تحميل السجلات")) {
          Task { await model.load() }
        }
        .frame(minHeight: 44)
      }
      .font(.callout)
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MemoryTheme.panel)
      .accessibilityIdentifier("local-storage-error")
    } else if model.isBusy {
      ProgressView(language.text("Saving or loading records…", "حفظ أو تحميل السجلات…"))
        .padding()
    }
  }

  private var errorMessage: String {
    switch model.error {
    case .conflictingRecord:
      language.text(
        "This backup conflicts with current records. Restore stopped without changing them. Keep both copies.",
        "تتعارض هذه النسخة مع السجلات الحالية. توقفت الاستعادة دون تغييرها. احتفظ بالنسختين.")
    case .unsupportedArchiveVersion, .invalidArchive:
      language.text(
        "This backup is damaged or uses an unsupported version. Choose another MemoryOS backup.",
        "هذه النسخة تالفة أو بإصدار غير مدعوم. اختر نسخة MemoryOS أخرى.")
    case .archiveTooLarge, .textTooLarge, .limitReached:
      language.text(
        "This operation exceeds the current storage or backup limit. Keep your text and backup files.",
        "تتجاوز هذه العملية الحد الحالي للتخزين أو النسخ الاحتياطي. احتفظ بالنص وملفات النسخ.")
    case .blankText:
      language.text("Write some text before saving.", "اكتب نصاً قبل الحفظ.")
    default:
      language.text(
        "Could not complete the local operation. Reload records before retrying. Unlock the device and check free space. If needed, reopen the app; keep your files.",
        "تعذّر إكمال العملية المحلية. أعد تحميل السجلات قبل المحاولة. افتح قفل الجهاز وتحقق من المساحة. أعد فتح التطبيق عند الحاجة واحتفظ بملفاتك."
      )
    }
  }

}

struct LocalRecordsListView: View {
  @Bindable var model: LocalRecordsViewModel
  let language: AppLanguage
  let openCapture: () -> Void
  @State private var showTrash = false
  @State private var showCreate = false
  @State private var showExport = false
  @State private var showImport = false
  @State private var confirmExport = false
  @State private var confirmRestore = false
  @State private var restoreCompleted = false

  private var visible: [LocalRecord] { showTrash ? model.trashedRecords : model.activeRecords }

  var body: some View {
    VStack(spacing: 0) {
      LocalStorageStatus(model: model, language: language)
      List {
        Section {
          Toggle(language.text("Show Trash", "عرض المحذوفات"), isOn: $showTrash)
            .accessibilityIdentifier("show-trash")
        }
        if visible.isEmpty {
          ContentUnavailableView {
            Label(
              language.text(
                showTrash ? "Trash is empty" : "Your local records",
                showTrash ? "المحذوفات فارغة" : "سجلاتك المحلية"), systemImage: "doc.text")
          } description: {
            Text(
              language.text(
                showTrash
                  ? "Records you move to Trash remain recoverable here."
                  : "Save a thought from Capture, or add a person, project or idea to link it.",
                showTrash
                  ? "يمكنك استعادة السجلات التي تنقلها إلى المحذوفات من هنا."
                  : "احفظ نصاً من الالتقاط، أو أضف شخصاً أو مشروعاً أو فكرة لربطه."))
          } actions: {
            if !showTrash {
              Button(language.text("Write a thought", "اكتب فكرة"), action: openCapture)
            }
          }
        }
        Section {
          ForEach(visible) { record in
            NavigationLink {
              LocalRecordDetailView(model: model, language: language, recordID: record.id)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(record.text).lineLimit(3)
                Text(record.kind.title(language)).font(.caption).foregroundStyle(
                  MemoryTheme.secondary)
              }
              .padding(.vertical, 6)
            }
            .accessibilityIdentifier("local-record-\(record.id)")
          }
        } footer: {
          Text(
            language.text(
              "Stored on this device. Organized conversation memory and audio use separate storage.",
              "محفوظة على هذا الجهاز. تستخدم ذاكرة المحادثات المنظمة والصوت تخزيناً منفصلاً."))
        }
        Section {
          Button(language.text("Add linked record", "إضافة سجل للربط")) { showCreate = true }
            .accessibilityIdentifier("add-local-record")
          Button(language.text("Export backup…", "تصدير نسخة احتياطية…")) { confirmExport = true }
            .accessibilityIdentifier("export-local-records")
          Button(language.text("Restore backup…", "استعادة نسخة احتياطية…")) {
            confirmRestore = true
          }
          .accessibilityIdentifier("restore-local-records")
        }
        .disabled(model.isBusy || !model.hasLoaded)
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
    }
    .sheet(isPresented: $showCreate) {
      LocalRecordEditor(model: model, language: language, record: nil)
    }
    .confirmationDialog(
      language.text("Export readable backup?", "تصدير نسخة قابلة للقراءة؟"),
      isPresented: $confirmExport, titleVisibility: .visible
    ) {
      Button(language.text("Choose backup location", "اختيار مكان النسخة")) {
        Task {
          await model.export()
          showExport = model.archiveData != nil
        }
      }
    } message: {
      Text(
        language.text(
          "The JSON file contains all originals, corrections, links and Trash in readable form. Choose a location you trust. A cloud Files location transfers the file there.",
          "يحتوي ملف JSON على الأصول والتصحيحات والروابط والمحذوفات بنص قابل للقراءة. اختر مكاناً موثوقاً. اختيار موقع سحابي في الملفات ينقل النسخة إليه."
        ))
    }
    .confirmationDialog(
      language.text("Restore missing records?", "استعادة السجلات الناقصة؟"),
      isPresented: $confirmRestore, titleVisibility: .visible
    ) {
      Button(language.text("Choose backup file", "اختيار ملف النسخة")) { showImport = true }
    } message: {
      Text(
        language.text(
          "Restore keeps current records. A conflicting ID rejects the whole restore. Deleted records stay in Trash.",
          "تحافظ الاستعادة على سجلاتك الحالية. تعارض المعرّف يرفض الاستعادة كاملة. تبقى السجلات المحذوفة في المحذوفات."
        ))
    }
    .fileExporter(
      isPresented: $showExport, document: LocalArchiveDocument(data: model.archiveData ?? Data()),
      contentType: .json, defaultFilename: "MemoryOS-backup"
    ) { result in
      if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
        model.reportFileFailure()
      }
      model.archiveData = nil
    }
    .alert(language.text("Backup restored", "تمت استعادة النسخة"), isPresented: $restoreCompleted) {
      Button(language.text("OK", "حسناً"), role: .cancel) {}
    } message: {
      Text(
        language.text(
          "Missing records were added. Current records and Trash remain intact.",
          "أُضيفت السجلات الناقصة. تبقى السجلات الحالية والمحذوفات كما هي."))
    }
    .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
      Task {
        do {
          let url = try result.get()
          restoreCompleted = await model.importArchive(from: url)
        } catch {
          if (error as? CocoaError)?.code != .userCancelled { model.reportFileFailure() }
        }
      }
    }
  }
}

struct LocalRecordDetailView: View {
  @Bindable var model: LocalRecordsViewModel
  let language: AppLanguage
  let recordID: UUID
  @State private var showEdit = false
  @State private var showLinks = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if let record = model.record(recordID) {
        List {
          LocalStorageStatus(model: model, language: language)
          Section(record.kind.title(language)) {
            Text(record.text).textSelection(.enabled).accessibilityIdentifier("local-record-text")
            Text(record.createdAt, style: .date).font(.caption)
          }
          Section(language.text("Original source", "المصدر الأصلي")) {
            Text(record.originalText).textSelection(.enabled)
              .accessibilityIdentifier("local-record-original")
          }
          if !record.revisions.isEmpty {
            Section(language.text("Corrections", "التصحيحات")) {
              ForEach(record.revisions, id: \.id) { revision in
                VStack(alignment: .leading, spacing: 6) {
                  Text(revision.text).textSelection(.enabled)
                  Text(revision.createdAt, style: .date).font(.caption)
                }
              }
            }
          }
          Section(language.text("Linked records", "السجلات المرتبطة")) {
            ForEach(model.connected(to: recordID)) { linked in
              NavigationLink(linked.text) {
                LocalRecordDetailView(model: model, language: language, recordID: linked.id)
              }
            }
            if record.deletedAt == nil {
              Button(language.text("Link a record", "ربط سجل")) { showLinks = true }
                .accessibilityIdentifier("link-local-record")
            }
          }
          Section {
            if record.deletedAt == nil {
              Button(language.text("Correct text", "تصحيح النص")) { showEdit = true }
                .accessibilityIdentifier("correct-local-record")
              Button(language.text("Move to Trash", "نقل إلى المحذوفات"), role: .destructive) {
                Task { if await model.setDeleted(id: recordID, deleted: true) { dismiss() } }
              }
              .accessibilityIdentifier("trash-local-record")
            } else {
              Button(language.text("Restore record", "استعادة السجل")) {
                Task { if await model.setDeleted(id: recordID, deleted: false) { dismiss() } }
              }
              .accessibilityIdentifier("recover-local-record")
            }
          } footer: {
            Text(
              language.text(
                "Trash retains originals and history. Permanent erasure is not available in this step.",
                "تحتفظ المحذوفات بالأصول والسجل. الحذف النهائي غير متاح في هذه الخطوة."))
          }
          .disabled(model.isBusy)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showEdit) {
          LocalRecordEditor(model: model, language: language, record: record)
        }
        .sheet(isPresented: $showLinks) {
          NavigationStack {
            List(
              model.activeRecords.filter {
                $0.id != recordID && !model.connected(to: recordID).contains($0)
              }
            ) { target in
              Button {
                Task { if await model.link(from: recordID, to: target.id) { showLinks = false } }
              } label: {
                Text(target.text)
              }
              .disabled(model.isBusy)
            }
            .safeAreaInset(edge: .top) { LocalStorageStatus(model: model, language: language) }
            .overlay {
              if model.activeRecords.count < 2 {
                Text(language.text("Add another record first.", "أضف سجلاً آخر أولاً."))
              }
            }
            .navigationTitle(language.text("Link a record", "ربط سجل"))
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(language.text("Done", "تم")) { showLinks = false }
              }
            }
          }
          .preferredColorScheme(.dark)
        }
      } else {
        ContentUnavailableView(
          language.text("Record unavailable", "السجل غير متاح"), systemImage: "doc.text")
      }
    }
    .toolbar(.visible, for: .navigationBar)
    .navigationTitle(language.text("Local record", "سجل محلي"))
    .navigationBarTitleDisplayMode(.inline)
    .background(MemoryTheme.canvas)
  }
}

struct LocalRecordEditor: View {
  @Bindable var model: LocalRecordsViewModel
  let language: AppLanguage
  let record: LocalRecord?
  @State private var text = ""
  @State private var kind = RecordKind.person
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        LocalStorageStatus(model: model, language: language)
        if record == nil {
          Picker(language.text("Record type", "نوع السجل"), selection: $kind) {
            ForEach([RecordKind.person, .project, .idea], id: \.self) { item in
              Text(item.title(language)).tag(item)
            }
          }
        }
        Section(
          language.text(
            record == nil ? "Text" : "Corrected text", record == nil ? "النص" : "النص المصحح")
        ) {
          TextEditor(text: $text).frame(minHeight: 150).accessibilityIdentifier(
            "local-record-editor")
        }
        if record != nil {
          Text(
            language.text(
              "The original source remains unchanged. This adds a correction to its history.",
              "يبقى المصدر الأصلي دون تغيير. يضيف هذا تصحيحاً إلى السجل."))
        }
      }
      .navigationTitle(
        language.text(
          record == nil ? "Add record" : "Correct text", record == nil ? "إضافة سجل" : "تصحيح النص")
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
            .disabled(model.isBusy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Save", "حفظ")) {
            Task {
              let accepted: Bool
              if let record {
                accepted = await model.correct(id: record.id, text: text)
              } else {
                accepted = await model.create(kind: kind, text: text)
              }
              if accepted { dismiss() }
            }
          }
          .disabled(
            model.isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || text.utf8.count > LocalMemoryLimits.textUTF8Bytes
          )
          .accessibilityIdentifier("save-local-edit")
        }
      }
    }
    .onAppear { text = record?.text ?? "" }
    .interactiveDismissDisabled(model.isBusy)
    .preferredColorScheme(.dark)
  }
}

struct LocalArchiveDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
