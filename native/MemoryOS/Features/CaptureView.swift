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
  @AppStorage(BrainMark.preferenceKey) private var brainMark: BrainMark = .constellation
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var recordingControlSize = 144.0
  @FocusState private var composerFocused: Bool
  private var language: AppLanguage { session.language }
  private var recording: Bool { audio.captureState.state == .recording }

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
      let controlSize = min(recordingControlSize, max(44, geometry.size.width - 36), 184)
      ScrollView {
        VStack(spacing: 16) {
          if chat.hasTemporarySession {
            VStack(spacing: 6) {
              Text(language.text("Home saves normal captures", "الرئيسية تحفظ الملاحظات العادية"))
                .font(.caption).foregroundStyle(MemoryTheme.secondary)
              Button(language.text("Resume temporary chat", "متابعة محادثة مؤقتة")) {
                Task {
                  await chat.startTemporary()
                  if chat.error == nil { showConversation = true }
                }
              }.frame(minHeight: 44)
            }
          }
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
            ZStack {
              Circle().fill(MemoryTheme.workspaceAccent.opacity(0.07))
              Circle().strokeBorder(MemoryTheme.workspaceAccent.opacity(0.36), lineWidth: 1)
              if audio.draftID != nil {
                Image(systemName: recording ? "pause.fill" : "mic")
                  .font(.system(size: 42, weight: .light))
              } else {
                VStack(spacing: 8) {
                  BrainMarkView(mark: brainMark).frame(width: 55, height: 55)
                  Image(systemName: "mic").font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MemoryTheme.secondary)
                }
              }
            }
            .foregroundStyle(recording ? MemoryTheme.ink : MemoryTheme.workspaceAccent)
            .frame(width: controlSize, height: controlSize)
            .overlay {
              if recording {
                Circle().strokeBorder(.red, lineWidth: 2).allowsHitTesting(false)
              }
            }
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
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
          if audio.busy {
            ProgressView(language.text("Preparing audio…", "جارٍ تجهيز الصوت…"))
              .font(.callout)
              .accessibilityIdentifier("capture-audio-progress")
          }
          if audio.draftID != nil {
            Label {
              Text(
                Duration.seconds(audio.captureState.elapsedSeconds).formatted(
                  .time(pattern: .minuteSecond))
              )
              .font(.title3.monospacedDigit())
            } icon: {
              Image(systemName: recording ? "record.circle.fill" : "waveform")
                .foregroundStyle(recording ? Color.red : MemoryTheme.secondary)
                .accessibilityHidden(true)
            }
            .accessibilityIdentifier("capture-audio-elapsed")
            Button(language.text("Finish and send", "إنهاء وإرسال")) {
              composerFocused = false
              Task {
                guard let recording = await audio.saveForChat() else { return }
                if await chat.prepareVoiceChat(
                  recordingID: recording.id,
                  durationSeconds: recording.durationSeconds ?? 0, asNormalCapture: true)
                {
                  showConversation = true
                  await chat.processVoice()
                }
              }
            }
            .buttonStyle(.borderedProminent)
            .tint(MemoryTheme.workspaceAccent)
            .foregroundStyle(MemoryTheme.onFilledControl)
            .frame(minHeight: 44)
            .disabled(
              audio.busy || chat.isGenerating || chat.isTranscribing || chat.isTransitioning
                || !chat.hasLoaded
            )
            .accessibilityIdentifier("capture-audio-save")
          }
          if let failure = audio.failure {
            Label(
              audioMessage(failure, language: language),
              systemImage: "exclamationmark.circle"
            )
            .font(.callout)
            .multilineTextAlignment(.leading)
            .padding(12)
            .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("capture-audio-error")
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(280, geometry.size.height))
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 6) {
        if let error = chat.error {
          VStack(alignment: .leading, spacing: 6) {
            Text(ChatCopy.error(error, language: language))
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
          .font(.callout)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
        if typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 0) {
            openChat
            openNotes
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
              openChat.fixedSize(horizontal: true, vertical: false)
              Spacer(minLength: 0)
              openNotes.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 0) {
              openChat
              openNotes
            }
          }
        }
        if !chat.homeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button {
            let submitted = chat.homeDraft
            Task {
              if await records.create(kind: .capture, text: submitted) {
                chat.clearSavedHomeDraft(submitted)
                notice = .saved
              }
            }
          } label: {
            Text(language.text("Save as memory", "حفظ كذكرى"))
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
          .disabled(records.isBusy || !records.hasLoaded)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .foregroundStyle(MemoryTheme.workspaceAccent)
          .accessibilityIdentifier("save-thought")
        }

        HStack(alignment: .bottom, spacing: 6) {
          IconControl(
            symbol: "waveform",
            label: language.text("Audio library and import", "مكتبة الصوت والاستيراد"),
            identifier: "capture-audio-library"
          ) {
            showAudio = true
          }

          TextField(
            "", text: $chat.homeDraft,
            prompt: Text(language.text("Write a thought…", "اكتب فكرة…")).foregroundStyle(
              MemoryTheme.secondary), axis: .vertical
          )
          .font(.body)
          .lineLimit(1...(typeSize.isAccessibilitySize ? 3 : 5))
          .padding(.vertical, 14)
          .focused($composerFocused)
          .accessibilityLabel(language.text("Write a thought", "اكتب فكرة"))
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
      .padding(.bottom, 10)
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
              durationSeconds: recording.durationSeconds ?? 0, asNormalCapture: true)
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

  private var openChat: some View {
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
      .font(.subheadline.weight(.medium))
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("capture-open-chat")
    .disabled(chat.isTransitioning || !chat.hasLoaded)
  }

  private var openNotes: some View {
    Button {
      composerFocused = false
      session.section = .memories
    } label: {
      Label(language.text("Saved notes", "الملاحظات المحفوظة"), systemImage: "folder")
        .font(.subheadline)
        .foregroundStyle(MemoryTheme.secondary)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("your-memories")
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
