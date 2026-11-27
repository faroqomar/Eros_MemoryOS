import ChatCore
import ChatPresentation
import SwiftUI

struct ChatHistoryView: View {
  let model: ChatViewModel
  let language: AppLanguage
  var onOpen: () -> Void = {}
  @State private var search = ""
  @Environment(\.dismiss) private var dismiss
  @State private var renaming: ChatConversation?
  @State private var deleting: ChatConversation?

  private var visibleConversations: [ChatConversation] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return model.conversations.filter { conversation in
      !conversation.isTemporary
        && (conversation.pendingVoice != nil || !conversation.messages.isEmpty
          || !conversation.draft.isEmpty
          || conversation.title != "New chat" || conversation.memoryMode)
        && (query.isEmpty || conversation.title.localizedStandardContains(query))
    }
  }

  var body: some View {
    NavigationStack {
      let conversations = visibleConversations
      List {
        if model.isLoading {
          ProgressView(language.text("Loading chats…", "جارٍ تحميل المحادثات…"))
        } else if conversations.isEmpty && model.error == nil {
          emptyHistory
            .listRowBackground(Color.clear)
        }
        ForEach(conversations) { conversation in
          HStack {
            Button {
              Task {
                await model.open(conversation.id)
                if model.error == nil {
                  onOpen()
                  dismiss()
                }
              }
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                  .font(.headline)
                  .multilineTextAlignment(.leading)
                Text(preview(conversation))
                  .font(.callout)
                  .foregroundStyle(MemoryTheme.secondary)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 6)
              .frame(minHeight: 52)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-chat-\(conversation.id)")
            .accessibilityLabel(conversation.title)
            .accessibilityValue(String(preview(conversation).prefix(100)))
            Menu {
              Button(language.text("Rename", "تغيير الاسم")) {
                model.clearError()
                renaming = conversation
              }
              Button(language.text("Delete", "حذف"), role: .destructive) { deleting = conversation }
            } label: {
              Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }
            .accessibilityLabel(
              language.text("Chat actions", "خيارات المحادثة") + ": " + conversation.title)
          }
          .disabled(
            model.isGenerating || model.isTranscribing || model.isTransitioning || model.isLoading)
        }
      }
      .searchable(text: $search, prompt: language.text("Search chats", "بحث في المحادثات"))
      .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
      .navigationTitle(language.text("Saved chats", "المحادثات المحفوظة"))
      .safeAreaInset(edge: .bottom) {
        if let error = model.error {
          VStack(alignment: .leading, spacing: 8) {
            Text(ChatCopy.error(error, language: language))
            if model.hasLoaded {
              Button(language.text("Dismiss", "إخفاء")) { model.clearError() }
                .frame(minHeight: 44)
            } else {
              Button(language.text("Reload chats", "إعادة تحميل المحادثات")) {
                Task { await model.load() }
              }
              .frame(minHeight: 44)
              .disabled(model.isLoading)
            }
          }.font(.callout).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoryTheme.panel)
            .accessibilityIdentifier("chat-history-error")
        }
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Done", "تم")) { dismiss() }.frame(minHeight: 44)
            .accessibilityIdentifier("chat-history-done")
        }
      }
      .sheet(item: $renaming) { chat in
        ChatRenameView(model: model, conversation: chat, language: language)
      }
      .confirmationDialog(
        language.text("Delete this chat?", "حذف هذه المحادثة؟"),
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        titleVisibility: .visible, presenting: deleting
      ) { chat in
        Button(language.text("Delete chat", "حذف المحادثة"), role: .destructive) {
          Task { await model.delete(chat.id) }
          deleting = nil
        }
      } message: { _ in
        Text(
          language.text(
            "This removes the chat and draft from chat history. Saved originals and organized memories remain searchable in Notes.",
            "يحذف هذا المحادثة ومسودتها من سجل المحادثات. تبقى النصوص الأصلية المحفوظة والذكريات المنظمة قابلة للبحث في الملاحظات."
          ))
      }
    }
  }

  private var emptyHistory: some View {
    Group {
      if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        ContentUnavailableView(
          language.text("No saved chats", "لا توجد محادثات محفوظة"),
          systemImage: "bubble.left.and.bubble.right",
          description: Text(
            language.text(
              "Start a regular chat to see it here.",
              "ابدأ محادثة عادية لتظهر هنا."))
        )
      } else {
        ContentUnavailableView {
          Label(
            language.text("No matching chats", "لا توجد محادثات مطابقة"),
            systemImage: "magnifyingglass")
        } description: {
          Text(language.text("Try another chat name.", "جرّب اسم محادثة آخر."))
        } actions: {
          Button(language.text("Clear search", "مسح البحث")) { search = "" }
            .frame(minHeight: 44)
        }
      }
    }
  }

  private func preview(_ conversation: ChatConversation) -> String {
    if let message = conversation.messages.last, !message.text.isEmpty { return message.text }
    if conversation.pendingVoice != nil {
      return language.text("Voice transcript pending", "بانتظار تفريغ الصوت")
    }
    if !conversation.draft.isEmpty { return language.text("Draft", "مسودة") }
    return language.text("No messages yet", "لا توجد رسائل بعد")
  }
}

private struct ChatRenameView: View {
  let model: ChatViewModel
  let conversation: ChatConversation
  let language: AppLanguage
  @State private var name: String
  @Environment(\.dismiss) private var dismiss

  init(model: ChatViewModel, conversation: ChatConversation, language: AppLanguage) {
    self.model = model
    self.conversation = conversation
    self.language = language
    _name = State(initialValue: conversation.title)
  }

  private var validName: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && name.utf8.count <= ChatLimits.titleBytes
  }

  var body: some View {
    NavigationStack {
      Form {
        HStack {
          TextField(language.text("Chat name", "اسم المحادثة"), text: $name)
            .accessibilityIdentifier("chat-rename-title")
          Button {
            name = ""
          } label: {
            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
          }.buttonStyle(.plain).accessibilityLabel(language.text("Clear name", "مسح الاسم"))
            .accessibilityIdentifier("clear-chat-name")
            .disabled(name.isEmpty)
        }.disabled(model.isTransitioning)
        if name.utf8.count > ChatLimits.titleBytes {
          Text(language.text("Choose a shorter name.", "اختر اسماً أقصر."))
        }
        if let error = model.error { Text(ChatCopy.error(error, language: language)) }
      }
      .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
      .navigationTitle(language.text("Rename chat", "تغيير اسم المحادثة"))
      .navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(model.isTransitioning)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }.disabled(model.isTransitioning)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Save", "حفظ")) {
            let submitted = name
            Task {
              await model.rename(conversation.id, title: submitted)
              if model.error == nil { dismiss() }
            }
          }.disabled(!validName || model.isTransitioning).accessibilityIdentifier("save-chat-name")
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}

struct ChatSourceView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  let evidence: ChatEvidence
  let records: LocalRecordsViewModel
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var refreshing = true

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if refreshing {
            ProgressView(language.text("Loading current source…", "جارٍ تحميل المصدر الحالي…"))
          } else if personal.failure != nil {
            PersonalMemoryStatus(model: personal, language: language)
          } else if let entry = personal.snapshot.entries.first(where: { $0.id == evidence.id }) {
            if entry.supersededByID != nil {
              Text(
                language.text(
                  "This is an earlier version. Check the current information below.",
                  "هذه نسخة سابقة. راجع المعلومات الحالية أدناه."))
              if let current = personal.currentReplacement(for: entry.id) {
                Text(language.text("Current information", "المعلومات الحالية")).font(.headline)
                  .accessibilityAddTraits(.isHeader)
                Text(current.statusTitle(language)).font(.caption)
                if let confirmation = current.confirmationTitle(language) {
                  Text(confirmation).font(.caption)
                }
                Text(current.text).textSelection(.enabled)
              }
              Text(language.text("Earlier information", "المعلومات السابقة")).font(.headline)
                .accessibilityAddTraits(.isHeader)
            } else if !evidence.matchesCurrentText(entry.text) {
              Text(
                language.text(
                  "This information changed after the reply. Read the current text below.",
                  "تغيّرت هذه المعلومات بعد الرد. اقرأ النص الحالي أدناه."))
            }
            Text(entry.statusTitle(language)).font(.headline)
            if let confirmation = entry.confirmationTitle(language) {
              Text(confirmation).font(.caption)
            }
            Text(entry.text).textSelection(.enabled)
            ForEach(personal.snapshot.sources.filter { entry.sourceIDs.contains($0.id) }) {
              source in
              NavigationLink {
                PersonalSourceView(sourceID: source.id, language: language)
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  Text(source.text).lineLimit(4)
                  Text(source.createdAt, format: .dateTime.month().day().year()).font(.caption)
                }
              }
            }
          } else if let source = personal.snapshot.sources.first(where: { $0.id == evidence.id }) {
            Text(language.text("Original statement", "النص الأصلي")).font(.headline)
              .accessibilityAddTraits(.isHeader)
            Text(source.text).textSelection(.enabled)
              .accessibilityIdentifier("chat-personal-original")
            Text(source.createdAt, format: .dateTime.month().day().year())
              .font(.caption)
            NavigationLink {
              PersonalSourceView(sourceID: source.id, language: language)
            } label: {
              Text(language.text("View source and organization", "عرض المصدر وتنظيمه"))
            }
          } else if records.failure {
            LocalStorageStatus(model: records, language: language)
          } else if let record = records.record(evidence.id), record.deletedAt == nil {
            if !evidence.matchesCurrentText(record.text) {
              Text(
                language.text(
                  "You corrected this record after this reply. Read the current text below and ask again.",
                  "صحّحت هذا السجل بعد الرد. اقرأ النص الحالي أدناه واسأل مجدداً."))
            }
            Text(language.text("Current record", "السجل الحالي")).font(.headline)
            Text(record.text).textSelection(.enabled)
            if record.originalText != record.text {
              Text(language.text("Original record", "السجل الأصلي")).font(.headline)
              Text(record.originalText).textSelection(.enabled)
            }
          } else {
            Text(
              language.text(
                "This source is in Trash or is unavailable. It will not enter later memory answers.",
                "هذا المصدر في المحذوفات أو غير متاح. لن يدخل في أجوبة الذكريات اللاحقة."))
          }
          DisclosureGroup(language.text("Source ID", "معرّف المصدر")) {
            Text(evidence.id.uuidString)
              .font(.caption.monospaced()).textSelection(.enabled)
              .foregroundStyle(MemoryTheme.secondary)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
      }
      .accessibilityIdentifier("chat-current-source")
      .background(MemoryTheme.canvas).navigationTitle(language.text("Memory source", "مصدر الذكرى"))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Done", "تم")) { dismiss() }
            .accessibilityIdentifier("chat-source-done")
        }
      }
      .task {
        await records.load()
        await personal.load()
        refreshing = false
      }
    }
  }

}
