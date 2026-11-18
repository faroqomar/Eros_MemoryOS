import ChatCore
import ChatPresentation
import SwiftUI
import UIKit

struct ChatView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  @Bindable var model: ChatViewModel
  let records: LocalRecordsViewModel
  let audio: AudioViewModel
  var openRecordings: () -> Void = {}
  let language: AppLanguage
  let menuIsOpen: Bool
  @State private var source: ChatEvidence?
  @State private var followsLatest = true
  @State private var nearBottom = true
  @State private var userScrolling = false
  @FocusState private var composerFocused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.chatScrollMeasurement) private var scrollMeasurement

  private var messages: [ChatMessage] { model.currentConversation?.messages ?? [] }
  private var updateKey: String {
    let last = messages.last
    return "\(messages.count)-\(last?.text.utf8.count ?? 0)-\(last?.status.rawValue ?? "")"
  }

  var body: some View {
    VStack(spacing: 0) {
      if model.isTemporary {
        HStack(alignment: .top) {
          Label(
            language.text("Temporary · nothing new saved", "مؤقتة · لا نحفظ شيئاً جديداً"),
            systemImage: "eye.slash"
          )
          .font(.caption).accessibilityIdentifier("temporary-chat-banner")
          Spacer()
          Button(language.text("End", "إنهاء")) { Task { await model.endTemporary() } }
            .accessibilityIdentifier("end-temporary-chat").frame(minHeight: 44)
        }.padding(.horizontal, 20).background(MemoryTheme.panel)
      }
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 24) {
            if messages.isEmpty && model.currentConversation?.pendingVoice == nil { introduction }
            if let first = messages.first {
              Text(first.createdAt, format: .dateTime.weekday(.wide).hour().minute())
                .font(.caption.weight(.medium))
                .foregroundStyle(MemoryTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            }
            if let pending = model.currentConversation?.pendingVoice {
              ChatPendingVoiceCard(
                pending: pending, processing: model.isTranscribing, stopping: model.isStopping,
                language: language,
                play: { seconds in
                  Task { await audio.play(id: pending.recordingID, seconds: seconds) }
                },
                stop: { audio.stopPlayback() },
                retry: { Task { await model.retryVoice() } },
                cancel: { model.cancelVoice() }, openRecordings: openRecordings)
            }
            ForEach(messages) { message in
              ChatMessageRow(
                message: message, language: language,
                canRegenerate: message.id == messages.last?.id && !model.isGenerating
                  && !model.isTranscribing,
                retry: { Task { await model.retry() } },
                regenerate: { Task { await model.regenerate() } },
                openSource: { source = $0 },
                playVoice: { id, seconds in Task { await audio.play(id: id, seconds: seconds) } },
                stopVoice: { audio.stopPlayback() }
              )
              .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
            }
            if !model.isTemporary, let conversationID = model.currentConversation?.id,
              personal.snapshot.analysisPendingSources.contains(where: {
                $0.conversationID == conversationID
              })
                || personal.snapshot.deferredSources.contains(where: {
                  $0.conversationID == conversationID
                })
            {
              PersonalOrganizationStatus(
                model: personal, language: language, conversationID: conversationID,
                canRetry: !model.isGenerating && !model.isTranscribing && !model.isTransitioning
              )
              .padding(14).background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 16))
            }
            if !model.isTemporary,
              let pending = personal.snapshot.pendingSources.last(where: { source in
                source.conversationID == model.currentConversation?.id
              })
            {
              PersonalClarificationCard(model: personal, source: pending, language: language)
                .id(pending.id)
                .padding(14).background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 16))
            }
            Color.clear.frame(height: 1).id("latest")
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 24)
          .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: messages.count)
        }
        .accessibilityIdentifier("chat-messages")
        .defaultScrollAnchor(messages.isEmpty ? .top : .bottom, for: .initialOffset)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { composerFocused = false }
        .onScrollGeometryChange(for: Bool.self) { geometry in
          geometry.contentSize.height - geometry.visibleRect.maxY < 80
        } action: { _, bottom in
          nearBottom = bottom
          if userScrolling { followsLatest = bottom }
        }
        .onScrollPhaseChange { _, phase in
          userScrolling = phase == .interacting || phase == .tracking || phase == .decelerating
          scrollMeasurement?.userScrollChanged(userScrolling)
          if userScrolling { followsLatest = nearBottom }
        }
        .onChange(of: updateKey) { _, _ in
          if followsLatest && !userScrolling { proxy.scrollTo("latest", anchor: .bottom) }
        }
        .onChange(
          of: personal.snapshot.pendingSources.last(where: {
            $0.conversationID == model.currentConversation?.id
          })?.id
        ) { _, _ in
          if followsLatest && !userScrolling { proxy.scrollTo("latest", anchor: .bottom) }
        }
        .onChange(of: messages.count) { _, _ in Task { await personal.load() } }
        .onChange(of: model.isGenerating) { _, generating in
          if !generating { Task { await personal.load() } }
        }
        .onChange(of: model.currentConversation?.id) { _, _ in
          followsLatest = true
          proxy.scrollTo("latest", anchor: .bottom)
        }
        .overlay(alignment: .bottom) {
          if !followsLatest {
            Button {
              followsLatest = true
              withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                proxy.scrollTo("latest", anchor: .bottom)
              }
            } label: {
              Label(language.text("Latest", "الأحدث"), systemImage: "arrow.down")
                .padding(.horizontal, 18).frame(minHeight: 44)
                .background(MemoryTheme.selection, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            .accessibilityIdentifier("jump-to-latest")
          }
        }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { composer }
    .sheet(item: $source) { evidence in
      ChatSourceView(evidence: evidence, records: records, language: language)
        .preferredColorScheme(.dark)
    }
    .onChange(of: menuIsOpen) { _, open in if open { composerFocused = false } }
    .onDisappear {
      scrollMeasurement?.userScrollChanged(false)
      audio.stopPlayback()
      Task { await model.flushDraft() }
    }
    .onChange(of: model.isGenerating) { wasGenerating, generating in
      if wasGenerating && !generating && UIAccessibility.isVoiceOverRunning {
        UIAccessibility.post(
          notification: .announcement,
          argument: language.text(
            "Local reply finished. Review the reply and its status.",
            "انتهى الرد المحلي. راجع الرد وحالته."))
      }
    }
  }

  private var introduction: some View {
    VStack(spacing: 12) {
      Text(language.text("What’s on your mind?", "شنو ببالك؟"))
        .font(.title2.weight(.semibold))
      Text(language.text("Chats stay on this device.", "تبقى المحادثات على هذا الجهاز."))
        .font(.subheadline)
        .foregroundStyle(MemoryTheme.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 64)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let failure = audio.failure {
        HStack(alignment: .top) {
          Text(audioMessage(failure, language: language)).font(.callout)
          Button(language.text("Dismiss", "إخفاء")) { audio.dismissFailure() }.frame(minHeight: 44)
        }.padding(12).background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 12))
      }
      if let error = model.error {
        VStack(alignment: .leading, spacing: 6) {
          Text(ChatCopy.error(error, language: language))
            .accessibilityIdentifier("chat-error")
          HStack {
            if !model.hasLoaded {
              Button(language.text("Reload chats", "إعادة تحميل المحادثات")) {
                Task { await model.load() }
              }.frame(minHeight: 44)
            } else if error == .storage {
              Button(language.text("Retry saving", "إعادة الحفظ")) {
                audio.stopPlayback()
                Task { await model.flushDraft() }
              }.frame(minHeight: 44)
            }
            Button(language.text("Dismiss", "إخفاء")) { model.clearError() }.frame(minHeight: 44)
          }
        }.font(.callout).padding(12).background(
          MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 12))
      }
      if model.memoryMode {
        HStack(spacing: 6) {
          Label(
            language.text("Using saved memories", "استخدام الذكريات المحفوظة"),
            systemImage: "doc.text.magnifyingglass")
          Spacer(minLength: 0)
          Button {
            model.memoryMode = false
          } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
          }
          .accessibilityLabel(language.text("Turn off saved memories", "إيقاف استخدام الذكريات"))
          .disabled(
            model.isGenerating || model.isTranscribing || model.isTransitioning || !model.hasLoaded)
        }
        .font(.caption)
        .foregroundStyle(MemoryTheme.secondary)
        .padding(.leading, 14)
        .background(MemoryTheme.panel, in: Capsule())
        .accessibilityIdentifier("chat-memory-active")
      }

      HStack(alignment: .bottom, spacing: 4) {
        Menu {
          Button(action: openRecordings) {
            Label(language.text("Recordings", "التسجيلات"), systemImage: "waveform")
          }.disabled(model.isTemporary)
          if !model.isTemporary {
            Button(language.text("Start temporary chat", "بدء محادثة مؤقتة")) {
              Task { await model.startTemporary() }
            }.disabled(model.isGenerating || model.isTranscribing || model.isTransitioning)
          }
          Toggle(isOn: $model.memoryMode) {
            Label(
              language.text("Use saved memories", "استخدام الذكريات المحفوظة"),
              systemImage: "doc.text.magnifyingglass")
          }
          .disabled(
            model.isGenerating || model.isTranscribing || model.isTransitioning || !model.hasLoaded
          )
          .accessibilityIdentifier("chat-memory-mode")
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 24, weight: .regular))
            .frame(width: 44, height: 48)
        }
        .accessibilityLabel(language.text("Chat options", "خيارات المحادثة"))
        .accessibilityIdentifier("chat-options")

        TextField(
          "", text: $model.draft,
          prompt: Text(language.text("Message MemoryOS…", "راسل MemoryOS…")), axis: .vertical
        )
        .lineLimit(1...(typeSize.isAccessibilitySize ? 3 : 6)).font(.body).padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
        .focused($composerFocused)
        .accessibilityLabel(language.text("Message local AI", "رسالة إلى الذكاء المحلي"))
        .accessibilityIdentifier("chat-composer")
        .disabled(model.isTransitioning || model.isLoading || !model.hasLoaded)
        if model.isGenerating {
          IconControl(
            symbol: "stop.fill", label: language.text("Stop reply", "إيقاف الرد"),
            filled: true, identifier: "chat-stop"
          ) { model.stop() }
          .disabled(model.isStopping)
        } else {
          IconControl(
            symbol: "arrow.up", label: language.text("Send to local AI", "إرسال إلى الذكاء المحلي"),
            filled: true, identifier: "chat-send"
          ) {
            followsLatest = true
            composerFocused = false
            Task { await model.send() }
          }.disabled(!model.canSend)
        }
      }
      .padding(.horizontal, 6).padding(.vertical, 5)
      .memoryGlass(in: RoundedRectangle(cornerRadius: 30), interactive: true)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: model.isGenerating)

    }
    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 8)
    .background(MemoryTheme.canvas)
  }
}

enum ChatCopy {
  static func error(_ error: ChatError, language: AppLanguage) -> String {
    switch error {
    case .memoryPreservationFailed:
      language.text(
        "Your original is in this chat, but lasting memory could not save. Retry after unlocking the device and checking storage.",
        "يبقى الأصل في المحادثة، لكن تعذر حفظ الذاكرة الدائمة. افتح القفل وتحقق من المساحة ثم أعد المحاولة."
      )
    case .temporaryVoiceUnavailable:
      language.text(
        "End temporary chat before recording audio. Recordings are lasting files.",
        "أنه المحادثة المؤقتة قبل تسجيل الصوت. التسجيلات ملفات دائمة.")
    case .contextLimit:
      language.text(
        "This chat exceeds the local model's context limit. Start a new chat; your messages remain saved.",
        "تجاوزت المحادثة حد سياق النموذج المحلي. ابدأ محادثة جديدة؛ تبقى رسائلك محفوظة.")
    case .modelUnavailable:
      language.text(
        "The local model is missing or could not load. Import the reviewed model in Settings, then retry. Your messages remain here.",
        "النموذج المحلي غير موجود أو تعذّر تحميله. استورد النموذج المعتمد من الإعدادات ثم أعد المحاولة. تبقى رسائلك هنا."
      )
    case .outputLimit:
      language.text(
        "The reply reached its 256-token limit. The partial reply is saved. Ask for a shorter answer or regenerate.",
        "وصل الرد إلى حد 256 رمزاً. حُفظ الرد الجزئي. اطلب جواباً أقصر أو أعد التوليد.")
    case .noEvidence:
      language.text(
        "No matching saved memory was found. Try a name or a specific phrase. No memory answer was generated.",
        "لم نعثر على ذكرى محفوظة مطابقة. جرّب اسماً أو عبارة محددة. لم نولّد جواباً عن الذكريات.")
    case .retrievalFailed:
      language.text(
        "Could not read saved memories. Open Memories and reload records, then retry.",
        "تعذّرت قراءة الذكريات. افتح الذكريات وأعد تحميل السجلات ثم حاول مجدداً.")
    case .messageTooLong, .blankMessage:
      language.text(
        "Keep your text and shorten this message before sending.",
        "احتفظ بالنص واختصر الرسالة قبل إرسالها.")
    case .conversationLimit:
      language.text(
        "Chat storage reached its limit. Keep copies, then delete an unneeded chat.",
        "وصل التخزين إلى حدّه. احتفظ بنسخ ثم احذف محادثة لا تحتاجها.")
    case .storage, .invalidArchive, .unsupportedVersion:
      language.text(
        "Could not save or open chats. Keep a copy of your draft, unlock the device and check free space. Reload chats before retrying.",
        "تعذّر حفظ المحادثات أو فتحها. احتفظ بنسخة من المسودة وافتح قفل الجهاز وتحقق من المساحة. أعد تحميل المحادثات قبل المحاولة."
      )
    default:
      language.text(
        "The local reply stopped. Your messages remain here. Retry the reply or start a new chat.",
        "توقف الرد المحلي. تبقى رسائلك هنا. أعد المحاولة أو ابدأ محادثة جديدة.")
    }
  }
}
