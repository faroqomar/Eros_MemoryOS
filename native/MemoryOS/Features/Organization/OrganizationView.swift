import MemoryCore
import OrganizationCore
import SwiftUI
import UniformTypeIdentifiers

struct OrganizationView: View {
  @Environment(OrganizationViewModel.self) private var model
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let language: AppLanguage
  @State private var editingRule: OrganizationRule?
  @State private var addingRule = false
  @State private var editingView: SavedMemoryView?
  @State private var addingView = false
  @State private var confirmExport = false
  @State private var confirmRestore = false
  @State private var exporting = false
  @State private var restoring = false
  @State private var restored = false
  var body: some View {
    List {
      OrganizationErrorRow(model: model, language: language)
      if model.isBusy {
        ProgressView(language.text("Updating organization…", "جارٍ تحديث التنظيم…"))
      }
      Section {
        Button {
          addingView = true
        } label: {
          Label(language.text("Create custom tab", "إنشاء تبويب مخصص"), systemImage: "plus")
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("custom-tab-add").disabled(model.isBusy)
        ForEach(model.snapshot.views) { view in
          let selected = model.selectedView?.id == view.id
          let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
          layout {
            Button {
              Task { await model.openView(view) }
            } label: {
              HStack {
                Text(view.name).frame(minHeight: 44, alignment: .leading)
                if selected {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MemoryTheme.workspaceAccent)
                    .accessibilityHidden(true)
                }
              }
            }
            .accessibilityIdentifier("custom-tab-" + view.id.uuidString)
            .accessibilityAddTraits(selected ? .isSelected : [])
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 4) {
              Button {
                editingView = view
              } label: {
                Image(systemName: "pencil").frame(width: 44, height: 44)
              }
              .accessibilityLabel(language.text("Edit ", "تعديل ") + view.name)
              Button(role: .destructive) {
                Task { await model.deleteView(view.id) }
              } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
              }
              .accessibilityLabel(language.text("Delete ", "حذف ") + view.name)
            }
          }.buttonStyle(.borderless).disabled(model.isBusy)
        }
      } header: {
        Text(language.text("Your tabs", "تبويباتك"))
      } footer: {
        Text(
          language.text(
            "Named views filter current saved information. Corrections appear when you open a view; deleted records disappear.",
            "تصفّي العروض المسماة المعلومات المحفوظة الحالية. تظهر التصحيحات عند فتح العرض وتختفي السجلات المحذوفة."
          ))
      }
      if let selected = model.selectedView {
        Section(selected.name) {
          if model.selectedEntries.isEmpty {
            Text(language.text("No matching memories", "لا توجد ذكريات مطابقة"))
            Text(
              language.text(
                "Change this tab's filters or save information that matches them.",
                "غيّر مرشحات هذا التبويب أو احفظ معلومات تطابقها.")
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
          }
          filterDetails(selected.filter)
          Button(language.text("Edit filters", "تعديل المرشحات")) { editingView = selected }
            .disabled(model.isBusy)
          ForEach(model.selectedEntries) { entry in
            NavigationLink(value: DemoDestination.personalEntry(entry.id)) {
              VStack(alignment: .leading) {
                Text(entry.text).lineLimit(4)
                Text(entry.kind.title(language)).font(.caption).foregroundStyle(
                  MemoryTheme.secondary)
              }
            }
          }
        }.accessibilityIdentifier("custom-tab-results")
      }
      Section {
        Button {
          addingRule = true
        } label: {
          Label(language.text("Create organization rule", "إنشاء قاعدة تنظيم"), systemImage: "plus")
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("organization-rule-add").disabled(model.isBusy)
        ForEach(model.snapshot.rules) { rule in
          VStack(alignment: .leading, spacing: 8) {
            let actionLayout =
              dynamicTypeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            actionLayout {
              Text(rule.name).font(.headline)
              if !dynamicTypeSize.isAccessibilitySize { Spacer() }
              Text(
                rule.enabled
                  ? language.text("Enabled", "مفعلة") : language.text("Disabled", "معطلة")
              ).font(.caption)
            }
            Text(
              language.text(
                "Contains: \(rule.filter.text.isEmpty ? "Any text" : rule.filter.text) · Add category: \(rule.category)",
                "يتضمن: \(rule.filter.text.isEmpty ? "أي نص" : rule.filter.text) · إضافة تصنيف: \(rule.category)"
              )
            )
            .font(.subheadline).foregroundStyle(MemoryTheme.secondary)
            filterDetails(rule.filter, includeText: false)
            actionLayout {
              Button(language.text("Edit", "تعديل")) { editingRule = rule }
                .accessibilityLabel(language.text("Edit ", "تعديل ") + rule.name)
              Button(
                rule.enabled ? language.text("Disable", "تعطيل") : language.text("Enable", "تفعيل")
              ) { Task { await model.toggleRule(rule) } }
              .accessibilityLabel(
                language.text(
                  rule.enabled ? "Disable " : "Enable ", rule.enabled ? "تعطيل " : "تفعيل ")
                  + rule.name)
              Button(language.text("Test", "اختبار")) { Task { await model.testRule(rule.id) } }
                .accessibilityIdentifier("organization-rule-test-" + rule.id.uuidString)
                .accessibilityLabel(language.text("Test ", "اختبار ") + rule.name)
            }.buttonStyle(.bordered).controlSize(.large).disabled(model.isBusy)
          }.padding(.vertical, 6).accessibilityIdentifier("organization-rule-" + rule.id.uuidString)
        }
      } header: {
        Text(language.text("Organization rules", "قواعد التنظيم"))
      } footer: {
        Text(
          language.text(
            "Supported action: add a category to matching memories. Test and apply explicitly. Rules cannot change claims, permissions, people or send messages.",
            "الإجراء المدعوم: إضافة تصنيف إلى الذكريات المطابقة. اختبر وطبّق باختيارك. لا تغيّر القواعد الحقائق أو الأذونات أو الأشخاص ولا ترسل رسائل."
          ))
      }
      if !model.snapshot.applications.isEmpty {
        Section(language.text("Undo rule applications", "التراجع عن تطبيق القواعد")) {
          ForEach(model.snapshot.applications.reversed()) { application in
            let name =
              model.snapshot.rules.first { $0.id == application.ruleID }?.name
              ?? language.text("Organization rule", "قاعدة تنظيم")
            Button(
              language.text(
                "Undo \(name) · \(application.changes.count) category changes",
                "التراجع عن \(name) · \(application.changes.count) تغييرات تصنيف")
            ) {
              Task { await model.undoRule(application.id) }
            }.disabled(model.isBusy).accessibilityIdentifier(
              "organization-undo-" + application.id.uuidString)
          }
        }
      }
      Section(language.text("Organization backup", "نسخة التنظيم")) {
        Text(
          language.text(
            "Back up birthdays, reminder approvals, rules, tabs and undo receipts. Keep your organized-memory backup too; restore it first to preserve person and source links.",
            "احتفظ بنسخة من أعياد الميلاد وموافقات التذكير والقواعد والتبويبات وسجلات التراجع. احتفظ أيضاً بنسخة الذاكرة المنظمة واستعدها أولاً للحفاظ على روابط الأشخاص والمصادر."
          )
        ).font(.caption).foregroundStyle(MemoryTheme.secondary)
        Button(language.text("Export organization backup…", "تصدير نسخة التنظيم…")) {
          confirmExport = true
        }.disabled(model.isBusy).accessibilityIdentifier("organization-export")
        Button(language.text("Restore into empty organization…", "استعادة إلى تنظيم فارغ…")) {
          confirmRestore = true
        }.disabled(model.isBusy || !model.canRestore).accessibilityIdentifier(
          "organization-restore")
      }
    }.scrollContentBackground(.hidden).task { await model.load() }
      .refreshable { await model.load() }
      .confirmationDialog(
        language.text("Export readable backup?", "تصدير نسخة مقروءة؟"),
        isPresented: $confirmExport, titleVisibility: .visible
      ) {
        Button(language.text("Choose backup location", "اختيار مكان النسخة")) {
          Task { if await model.exportArchive() { exporting = true } }
        }
      } message: {
        Text(
          language.text(
            "Anyone with the file can read names, dates and rule details. Choose a private location. Export does not turn off reminders on this device.",
            "يمكن لأي شخص يملك الملف قراءة الأسماء والتواريخ وتفاصيل القواعد. اختر مكاناً خاصاً. لا يوقف التصدير التذكيرات على هذا الجهاز."
          ))
      }
      .confirmationDialog(
        language.text("Restore organization backup?", "استعادة نسخة التنظيم؟"),
        isPresented: $confirmRestore, titleVisibility: .visible
      ) {
        Button(language.text("Choose backup file", "اختيار ملف النسخة")) { restoring = true }
      } message: {
        Text(
          language.text(
            "Restore your organized memory first. Current organization must be empty. Restored reminders stay off; review and approve each exact schedule to enable it. A failed cancellation remains visible for retry.",
            "استعد الذاكرة المنظمة أولاً. يجب أن يكون التنظيم الحالي فارغاً. تبقى التذكيرات المستعادة متوقفة؛ راجع كل جدول محدد ووافق عليه لتفعيله. يبقى أي إلغاء غير مكتمل ظاهراً لإعادة المحاولة."
          ))
      }
      .fileExporter(
        isPresented: $exporting,
        document: model.exportedArchive.map { OrganizationArchiveDocument(data: $0) },
        contentType: .json, defaultFilename: "MemoryOS-organization"
      ) { model.finishExport($0) }
      .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { result in
        switch result {
        case .success(let url): Task { restored = await model.restoreArchive(url) }
        case .failure(let error): model.fileOperationFailed(error)
        }
      }
      .alert(language.text("Organization restored", "تمت استعادة التنظيم"), isPresented: $restored)
    {
      Button(language.text("Done", "تم"), role: .cancel) {}
    } message: {
      Text(
        language.text(
          "Restored reminders are off. Review each birthday to approve a schedule.",
          "التذكيرات المستعادة متوقفة. راجع كل عيد ميلاد للموافقة على جدول."))
    }
      .sheet(isPresented: $addingRule) {
        OrganizationEditor(model: model, language: language, isRule: true)
      }
      .sheet(item: $editingRule) { rule in
        OrganizationEditor(model: model, language: language, isRule: true, rule: rule)
      }
      .sheet(isPresented: $addingView) {
        OrganizationEditor(model: model, language: language, isRule: false)
      }
      .sheet(item: $editingView) { view in
        OrganizationEditor(model: model, language: language, isRule: false, savedView: view)
      }
      .sheet(
        isPresented: Binding(
          get: { model.rulePreview != nil }, set: { if !$0 { model.dismissRule() } })
      ) {
        if let preview = model.rulePreview {
          NavigationStack {
            List {
              Text(
                language.text(
                  "\(preview.entryIDs.count) matches · Category: \(preview.rule.category)",
                  "\(preview.entryIDs.count) نتائج · التصنيف: \(preview.rule.category)"))
              ForEach(model.memory.currentEntries.filter { preview.entryIDs.contains($0.id) }) {
                Text($0.text).lineLimit(6)
              }
              OrganizationErrorRow(model: model, language: language)
              Button(language.text("Apply these changes", "تطبيق هذه التغييرات")) {
                Task { await model.applyRule() }
              }
              .disabled(model.isBusy || !preview.rule.enabled || preview.entryIDs.isEmpty)
              .accessibilityIdentifier("organization-apply")
            }.navigationTitle(language.text("Test results", "نتائج الاختبار"))
              .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                  Button(language.text("Close", "إغلاق")) { model.dismissRule() }
                }
              }
          }.preferredColorScheme(.dark)
        }
      }
  }
  @ViewBuilder private func filterDetails(_ filter: OrganizationFilter, includeText: Bool = true)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      if includeText, !filter.text.isEmpty {
        Text(language.text("Contains: \(filter.text)", "يتضمن: \(filter.text)"))
      }
      if let profileID = filter.profileID {
        let name =
          model.memory.profiles.first { $0.id == profileID }?.name
          ?? language.text("Unavailable", "غير متاح")
        Text(language.text("Person or project: \(name)", "الشخص أو المشروع: \(name)"))
      }
      if let kind = filter.kind {
        Text(language.text("Memory type: ", "نوع الذاكرة: ") + kind.title(language))
      }
    }.font(.subheadline).foregroundStyle(MemoryTheme.secondary)
  }
}

private struct OrganizationArchiveDocument: FileDocument {
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

private struct OrganizationEditor: View {
  let model: OrganizationViewModel
  let language: AppLanguage
  let isRule: Bool
  var rule: OrganizationRule?
  var savedView: SavedMemoryView?
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var text = ""
  @State private var category = ""
  @State private var profileID: UUID?
  @State private var kind: PersonalMemoryKind?
  var body: some View {
    NavigationStack {
      Form {
        OrganizationErrorRow(model: model, language: language)
        TextField(language.text("Name", "الاسم"), text: $name).accessibilityIdentifier(
          "organization-name")
        TextField(language.text("Text contains (optional)", "النص يتضمن (اختياري)"), text: $text)
          .accessibilityIdentifier("organization-text")
        Picker(language.text("Person or project", "الشخص أو المشروع"), selection: $profileID) {
          Text(language.text("Any", "أي")).tag(nil as UUID?)
          if let profileID,
            !model.memory.profiles.contains(where: { $0.id == profileID && $0.mergedIntoID == nil })
          {
            Text(
              language.text(
                "Unavailable saved person or project", "الشخص أو المشروع المحفوظ غير متاح")
            )
            .tag(Optional(profileID))
          }
          ForEach(model.memory.profiles.filter { $0.mergedIntoID == nil }) { profile in
            Text(profile.name).tag(Optional(profile.id))
          }
        }
        Picker(language.text("Memory type", "نوع الذاكرة"), selection: $kind) {
          Text(language.text("Any", "أي")).tag(nil as PersonalMemoryKind?)
          ForEach(PersonalMemoryKind.allCases, id: \.rawValue) { value in
            Text(value.title(language)).tag(Optional(value))
          }
        }
        if isRule {
          TextField(language.text("Add category", "إضافة تصنيف"), text: $category)
            .accessibilityIdentifier("organization-category")
        }
      }.navigationTitle(
        isRule
          ? language.text("Organization rule", "قاعدة تنظيم")
          : language.text("Custom tab", "تبويب مخصص")
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Save", "حفظ")) {
            Task {
              let success: Bool
              if isRule {
                success = await model.saveRule(
                  id: rule?.id ?? UUID(), name: name, text: text,
                  category: category, profileID: profileID, kind: kind,
                  enabled: rule?.enabled ?? true)
              } else {
                success = await model.saveView(
                  id: savedView?.id ?? UUID(), name: name, text: text, profileID: profileID,
                  kind: kind)
              }
              if success { dismiss() }
            }
          }.disabled(
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || (isRule && category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              || model.isBusy
          )
          .accessibilityIdentifier("organization-save")
        }
      }
      .onAppear {
        name = rule?.name ?? savedView?.name ?? ""
        text = rule?.filter.text ?? savedView?.filter.text ?? ""
        category = rule?.category ?? ""
        profileID = rule?.filter.profileID ?? savedView?.filter.profileID
        kind = rule?.filter.kind ?? savedView?.filter.kind
      }
    }.preferredColorScheme(.dark)
  }
}

struct OrganizationErrorRow: View {
  let model: OrganizationViewModel
  let language: AppLanguage
  var body: some View {
    if let error = model.error {
      Section {
        Text(error.message(language)).foregroundStyle(.red).accessibilityIdentifier(
          "organization-error")
        Button(language.text("Dismiss", "إغلاق")) { model.clearError() }
      }
    }
  }
}
extension OrganizationError {
  func message(_ language: AppLanguage) -> String {
    switch self {
    case .cancellationPending:
      language.text(
        "Cancellation has not finished. An earlier reminder may still run. Restore calendar permission if needed, then check approved schedules.",
        "لم يكتمل الإلغاء. قد يستمر تذكير سابق. أعد إذن التقويم عند الحاجة ثم افحص الجداول المعتمدة."
      )
    case .permissionDenied:
      language.text(
        "Permission denied. Enable the selected permission in Settings, then retry your approved schedule.",
        "رفض الإذن. فعّل الإذن المحدد في الإعدادات ثم أعد محاولة الجدول المعتمد.")
    case .invalidDate:
      language.text(
        "Use a valid date. A reminder needs both month and day.",
        "استخدم تاريخاً صالحاً. يتطلب التذكير الشهر واليوم.")
    case .invalidSchedule:
      language.text("Check the timezone and time.", "تحقق من المنطقة الزمنية والوقت.")
    case .schedulerUnavailable:
      language.text(
        "No writable on-device calendar exists. Use notifications or create a local calendar first.",
        "لا يوجد تقويم محلي قابل للكتابة على الجهاز. استخدم الإشعارات أو أنشئ تقويماً محلياً أولاً.")
    case .approvalRequired:
      language.text(
        "Review and approve the exact schedule first.", "راجع الجدول المحدد ووافق عليه أولاً.")
    case .stalePreview:
      language.text(
        "Information changed. Test or review again before applying.",
        "تغيرت المعلومات. أعد الاختبار أو المراجعة قبل التطبيق.")
    case .invalidArchive:
      language.text(
        "This organization backup is damaged or uses an unsupported version. Choose another backup.",
        "نسخة التنظيم تالفة أو تستخدم إصداراً غير مدعوم. اختر نسخة أخرى.")
    case .conflictingArchive:
      language.text(
        "Organization already contains data. Restore stopped without replacing it.",
        "يحتوي التنظيم على بيانات. توقفت الاستعادة دون استبدالها.")
    case .missingReferences:
      language.text(
        "Restore the matching organized-memory backup first. Required people or records are missing.",
        "استعد نسخة الذاكرة المنظمة المطابقة أولاً. بعض الأشخاص أو السجلات المطلوبة غير موجودة.")
    case .missingPerson, .missingBirthday:
      language.text(
        "The person or birthday is unavailable. Reload and choose again.",
        "الشخص أو عيد الميلاد غير متاح. أعد التحميل والاختيار.")
    case .limitReached:
      language.text(
        "This action exceeds the supported storage or schedule limit.",
        "يتجاوز هذا الإجراء حد التخزين أو الجداول المدعوم.")
    default:
      language.text(
        "The change did not finish. Reload and retry. Existing schedules may need reconciliation.",
        "لم يكتمل التغيير. أعد التحميل والمحاولة. قد تحتاج الجداول الحالية إلى فحص.")
    }
  }
}
