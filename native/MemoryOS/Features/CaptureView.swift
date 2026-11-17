import ChatPresentation
import SwiftUI

struct CaptureView: View {
  @Bindable var session: DemoSession
  @Bindable var records: LocalRecordsViewModel
  @Bindable var audio: AudioViewModel
  @Bindable var chat: ChatViewModel
  let menuIsOpen: Bool
  @Binding var showConversation: Bool
  @State private var showAudio = false
  @State private var notice: Notice?
  @FocusState private var composerFocused: Bool
  private var language: AppLanguage { session.language }

  private enum Notice {
    case saved
  }

  var body: some View {
    Group {
      if showConversation {
        ChatView(
          model: chat, records: records, audio: audio,
          openRecordings: { session.section = .recordings }, language: language,
          menuIsOpen: menuIsOpen)
      } else {
        captureContent
      }
    }
  }

  private var captureContent: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 24) {
          Spacer(minLength: 0)
          Button {
            composerFocused = false
            Task {
              if audio.captureState.state == .recording {
                await audio.pause()
              } else if audio.captureState.state == .paused {
                await audio.resume()
              } else if audio.draftID == nil {
                await audio.start(defaultTitle: language.text("Voice note", "ملاحظة صوتية"))
              }
            }
          } label: {
            Image(systemName: audio.captureState.state == .recording ? "pause.fill" : "mic")
              .font(.system(size: 62, weight: .light))
              .foregroundStyle(.white)
              .frame(width: 166, height: 166)
              .memoryGlass(in: Circle(), interactive: true)
          }
          .buttonStyle(.plain)
          .disabled(
            audio.busy || chat.isGenerating || chat.isTranscribing
              || !(audio.canStart || audio.captureState.state == .recording
                || audio.captureState.state == .paused)
          )
          .accessibilityLabel(recordingAction)
          .accessibilityIdentifier("record-audio")

          Text(recordingAction)
            .font(MemoryTheme.body)
          if audio.busy { ProgressView().accessibilityIdentifier("capture-audio-progress") }
          if audio.draftID != nil {
            Text(
              Duration.seconds(audio.captureState.elapsedSeconds).formatted(
                .time(pattern: .minuteSecond))
            )
            .font(.title.monospacedDigit())
            .accessibilityIdentifier("capture-audio-elapsed")
            Button(language.text("Finish and send", "إنهاء وإرسال")) {
              composerFocused = false
              Task {
                guard let recording = await audio.saveForChat() else { return }
                if await chat.prepareVoiceChat(
                  recordingID: recording.id,
                  durationSeconds: recording.durationSeconds ?? 0)
                {
                  showConversation = true
                  await chat.processVoice()
                }
              }
            }
            .frame(minHeight: 44)
            .disabled(
              audio.busy || chat.isGenerating || chat.isTranscribing || chat.isTransitioning
                || !chat.hasLoaded
            )
            .accessibilityIdentifier("capture-audio-save")
          }
          if let failure = audio.failure {
            Text(audioMessage(failure, language: language))
              .font(.callout)
              .accessibilityIdentifier("capture-audio-error")
          }
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
          if chat.isGenerating || chat.isTranscribing {
            showConversation = true
          } else {
            Task {
              if await chat.prepareHomeConversation() { showConversation = true }
            }
          }
        } label: {
          Label(
            language.text(
              (chat.isGenerating || chat.isTranscribing) ? "Return to reply" : "Ask local AI",
              (chat.isGenerating || chat.isTranscribing) ? "العودة إلى الرد" : "اسأل الذكاء المحلي"),
            systemImage: "bubble.left"
          )
          .font(.subheadline).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("capture-open-chat")
          .disabled(chat.isTransitioning || !chat.hasLoaded)
        if let error = chat.error {
          Text(ChatCopy.error(error, language: language)).font(.callout)
          if !chat.hasLoaded {
            Button(language.text("Reload chats", "إعادة تحميل المحادثات")) {
              Task { await chat.load() }
            }.frame(minHeight: 44).accessibilityIdentifier("capture-reload-chats")
          } else if error == .storage {
            Button(language.text("Retry saving", "إعادة الحفظ")) {
              Task { await chat.flushDraft() }
            }.frame(minHeight: 44)
          }
        }
        if !chat.homeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button(language.text("Save as memory", "حفظ كذكرى")) {
            let submitted = chat.homeDraft
            Task {
              if await records.create(kind: .capture, text: submitted) {
                if chat.homeDraft.utf8.elementsEqual(submitted.utf8) { chat.homeDraft = "" }
                notice = .saved
              }
            }
          }
          .disabled(records.isBusy || !records.hasLoaded)
          .frame(minHeight: 44)
          .accessibilityIdentifier("save-thought")
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
          IconControl(
            symbol: "plus",
            label: language.text("Audio library and import", "مكتبة الصوت والاستيراد"),
            identifier: "capture-audio-library"
          ) {
            showAudio = true
          }

          TextField(
            "", text: $chat.homeDraft,
            prompt: Text(language.text("Write anything...", "اكتب أي شيء...")).foregroundStyle(
              MemoryTheme.secondary), axis: .vertical
          )
          .font(.body)
          .lineLimit(1...5)
          .padding(.vertical, 14)
          .focused($composerFocused)
          .accessibilityLabel(language.text("Message local AI", "رسالة إلى الذكاء المحلي"))
          .accessibilityIdentifier("capture-composer")
          .disabled(chat.isTransitioning || chat.isLoading || !chat.hasLoaded)

          IconControl(
            symbol: "arrow.up", label: language.text("Send to local AI", "إرسال إلى الذكاء المحلي"),
            filled: true, identifier: "capture-send"
          ) {
            composerFocused = false
            Task {
              if await chat.prepareHomeConversation() {
                showConversation = true
                await chat.send()
              }
            }
          }
          .disabled(
            chat.homeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || chat.isGenerating || chat.isTranscribing || chat.isTransitioning || !chat.hasLoaded
          )
        }
        .padding(8)
        .memoryGlass(in: RoundedRectangle(cornerRadius: 30), interactive: true)
      }
      .padding(.horizontal, 18)
      .padding(.bottom, 18)
      .background(MemoryTheme.canvas)
    }
    .overlay(alignment: .top) {
      LocalStorageStatus(model: records, language: language)
    }
    .sheet(isPresented: $showAudio) {
      AudioLibraryView(
        model: audio, records: records, language: language,
        chatBusy: chat.isGenerating || chat.isTranscribing || chat.isTransitioning,
        startChat: { recording in
          guard
            await chat.prepareVoiceChat(
              recordingID: recording.id,
              durationSeconds: recording.durationSeconds ?? 0)
          else { return false }
          showAudio = false
          showConversation = true
          Task { await chat.processVoice() }
          return true
        })
    }
    .onChange(of: menuIsOpen) { _, open in
      if open { composerFocused = false }
    }
    .onDisappear {
      Task { await audio.leaveCapture() }
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
    language.text("MemoryOS", "MemoryOS")
  }

  private var recordingAction: String {
    guard audio.draftID != nil else { return language.text("Tap to record", "اضغط للتسجيل") }
    return switch audio.captureState.state {
    case .recording: language.text("Pause recording", "إيقاف التسجيل مؤقتاً")
    case .paused: language.text("Resume recording", "متابعة التسجيل")
    case .interrupted, .failed:
      language.text("Recording stopped · finish below", "توقف التسجيل · احفظه أدناه")
    default: language.text("Finish recording below", "احفظ التسجيل أدناه")
    }
  }

  private var noticeMessage: String {
    switch notice {
    case .saved:
      language.text(
        "Saved as a memory on this device.",
        "حُفظت كذكرى على هذا الجهاز.")
    case nil: ""
    }
  }
}
