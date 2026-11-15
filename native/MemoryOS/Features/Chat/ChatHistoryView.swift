import ChatCore
import ChatPresentation
import SwiftUI

struct ChatHistoryView: View {
  let model: ChatViewModel
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var renaming: ChatConversation?
  @State private var deleting: ChatConversation?

  var body: some View {
    NavigationStack {
      List(model.conversations) { conversation in
        HStack {
          Button {
            Task {
              await model.open(conversation.id)
              if model.error == nil { dismiss() }
            }
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              Text(conversation.title).font(.headline)
              Text(
                conversation.messages.last?.text
                  ?? language.text("No messages yet", "لا توجد رسائل بعد")
              )
              .font(.caption).foregroundStyle(MemoryTheme.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 52)
          }.buttonStyle(.plain).accessibilityIdentifier("saved-chat-\(conversation.id)")
            .accessibilityLabel(conversation.title)
            .accessibilityValue(String((conversation.messages.last?.text ?? "").prefix(100)))
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
        }.disabled(model.isGenerating || model.isTransitioning || model.isLoading)
      }
      .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
      .navigationTitle(language.text("Saved chats", "المحادثات المحفوظة"))
      .safeAreaInset(edge: .bottom) {
        if let error = model.error {
          VStack(alignment: .leading, spacing: 8) {
            Text(ChatCopy.error(error, language: language))
            Text(
              language.text(
                "Your chat is still here. Resolve the problem, then try the action again.",
                "تبقى محادثتك هنا. عالج المشكلة ثم أعد المحاولة."))
            Button(language.text("Dismiss", "إخفاء")) { model.clearError() }
              .frame(minHeight: 44)
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
            "This removes its messages and draft from this device.",
            "سيحذف هذا رسائلها ومسودتها من هذا الجهاز."))
      }
    }
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
            Text(language.text("Loading current source…", "تحميل المصدر الحالي…"))
          } else if records.failure {
            LocalStorageStatus(model: records, language: language)
          } else if let record = records.record(evidence.id), record.deletedAt == nil {
            if record.text != evidence.text {
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
          Text(evidence.id.uuidString).font(.caption.monospaced()).textSelection(.enabled)
            .foregroundStyle(MemoryTheme.secondary)
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
        refreshing = false
      }
    }
  }
}
