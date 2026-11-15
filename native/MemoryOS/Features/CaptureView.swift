import SwiftUI

struct CaptureView: View {
  @Bindable var session: DemoSession
  @Bindable var records: LocalRecordsViewModel
  let menuIsOpen: Bool
  @State private var notice: Notice?
  @FocusState private var composerFocused: Bool
  private var language: AppLanguage { session.language }

  private enum Notice {
    case recording, attachment, saved
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 24) {
          Spacer(minLength: 0)
          Button {
            notice = .recording
          } label: {
            Image(systemName: "mic")
              .font(.system(size: 62, weight: .light))
              .foregroundStyle(.white)
              .frame(width: 166, height: 166)
              .background(MemoryTheme.recordingSurface, in: Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(language.text("Preview voice capture", "معاينة التسجيل الصوتي"))
          .accessibilityHint(
            language.text("Demo only. The microphone stays off.", "عرض تجريبي. الميكروفون لا يعمل.")
          )
          .accessibilityIdentifier("record-preview")

          Text(language.text("Tap to record", "اضغط للتسجيل"))
            .font(MemoryTheme.body)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(280, geometry.size.height))
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 18) {
        Button {
          composerFocused = false
          session.section = .chat
        } label: {
          Label(language.text("Ask local AI", "اسأل الذكاء المحلي"), systemImage: "bubble.left")
            .font(.subheadline).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("capture-open-chat")
        if records.draftTooLarge {
          Text(
            language.text(
              "This thought is too long. Keep a copy and split it into smaller thoughts.",
              "هذا النص طويل جداً. احتفظ بنسخة وقسّمه إلى نصوص أصغر.")
          )
          .font(.caption)
        }
        Button {
          composerFocused = false
          session.section = .memories
        } label: {
          HStack(spacing: 10) {
            Text(language.text("Your memories", "ذكرياتك"))
            Image(systemName: "chevron.forward")
          }
          .font(MemoryTheme.caption)
          .foregroundStyle(MemoryTheme.secondary)
          .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("your-memories")

        HStack(alignment: .bottom, spacing: 6) {
          IconControl(symbol: "plus", label: language.text("Add attachment", "إضافة مرفق")) {
            notice = .attachment
          }

          TextField(
            "", text: $records.draft,
            prompt: Text(language.text("Write anything...", "اكتب أي شيء...")).foregroundStyle(
              MemoryTheme.secondary), axis: .vertical
          )
          .font(.body)
          .lineLimit(1...5)
          .padding(.vertical, 14)
          .focused($composerFocused)
          .accessibilityLabel(language.text("Write a thought", "اكتب فكرة"))
          .accessibilityIdentifier("capture-composer")

          IconControl(
            symbol: "arrow.up", label: language.text("Save thought", "حفظ الفكرة"),
            filled: true, identifier: "send-memory"
          ) {
            Task {
              if await records.saveCapture() {
                composerFocused = false
                notice = .saved
              }
            }
          }
          .disabled(!records.canSave)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(MemoryTheme.line, lineWidth: 0.75))
      }
      .padding(.horizontal, 18)
      .padding(.bottom, 18)
      .background(MemoryTheme.canvas)
    }
    .overlay(alignment: .top) {
      LocalStorageStatus(model: records, language: language)
    }
    .onChange(of: menuIsOpen) { _, open in
      if open { composerFocused = false }
    }
    .alert(
      noticeTitle, isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })
    ) {
      Button(language.text("OK", "حسناً"), role: .cancel) { notice = nil }
    } message: {
      Text(noticeMessage)
    }
  }

  private var noticeTitle: String {
    language.text("MemoryOS demo", "عرض MemoryOS التجريبي")
  }

  private var noticeMessage: String {
    switch notice {
    case .recording:
      language.text(
        "Voice capture comes in a later step. This preview does not use your microphone.",
        "التسجيل الصوتي يأتي في خطوة لاحقة. هذه المعاينة لا تستخدم الميكروفون.")
    case .attachment:
      language.text(
        "Attachments come in a later step. This demo does not open your files.",
        "المرفقات تأتي في خطوة لاحقة. هذا العرض لا يفتح ملفاتك.")
    case .saved:
      language.text(
        "Saved on this device. Open Your memories to read or correct it.",
        "حُفظت على هذا الجهاز. افتح ذكرياتك لقراءتها أو تصحيحها.")
    case nil: ""
    }
  }
}
