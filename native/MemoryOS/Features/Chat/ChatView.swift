import ChatCore
import ChatPresentation
import SwiftUI
import UIKit

struct ChatView: View {
  @Bindable var model: ChatViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  let menuIsOpen: Bool
  @State private var showChats = false
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
      HStack {
        Button {
          composerFocused = false
          showChats = true
        } label: {
          toolbarLabel(language.text("Chats", "المحادثات"), symbol: "bubble.left.and.bubble.right")
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityIdentifier("chat-history")
        .disabled(model.isTransitioning || model.isLoading || !model.hasLoaded)
        Spacer()
        Button {
          Task { await model.newConversation() }
        } label: {
          toolbarLabel(language.text("New", "جديدة"), symbol: "square.and.pencil")
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .disabled(
          model.isGenerating || model.isTransitioning || model.isLoading || !model.hasLoaded
        )
        .accessibilityIdentifier("new-chat")
      }
      .font(.subheadline)
      .buttonStyle(.plain)
      .frame(minHeight: 44)
      .padding(.horizontal, 22)

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 24) {
            if messages.isEmpty && model.draft.isEmpty { introduction }
            ForEach(messages) { message in
              ChatMessageRow(
                message: message, language: language,
                canRegenerate: message.id == messages.last?.id && !model.isGenerating,
                retry: { Task { await model.retry() } },
                regenerate: { Task { await model.regenerate() } },
                openSource: { source = $0 }
              )
              .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
            }
            Color.clear.frame(height: 1).id("latest")
          }
          .padding(.horizontal, 22)
          .padding(.vertical, 20)
          .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: messages.count)
        }
        .accessibilityIdentifier("chat-messages")
        .defaultScrollAnchor(messages.isEmpty ? .top : .bottom, for: .initialOffset)
        .scrollDismissesKeyboard(.interactively)
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
    .sheet(isPresented: $showChats) {
      ChatHistoryView(model: model, language: language)
        .preferredColorScheme(.dark)
    }
    .sheet(item: $source) { evidence in
      ChatSourceView(evidence: evidence, records: records, language: language)
        .preferredColorScheme(.dark)
    }
    .onChange(of: menuIsOpen) { _, open in if open { composerFocused = false } }
    .onDisappear {
      scrollMeasurement?.userScrollChanged(false)
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
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "sparkle").font(.largeTitle).accessibilityHidden(true)
      Text(language.text("Think it through.", "خلّينا نفكّر سوا."))
        .font(.title2.weight(.semibold))
      Text(
        language.text(
          "Ask a question or explore an idea. Your chats stay on this device.",
          "اسأل سؤالاً أو ناقش فكرة. تبقى محادثاتك على هذا الجهاز.")
      )
      .foregroundStyle(MemoryTheme.secondary)
      Text(
        language.text(
          "Experimental local AI can make mistakes, especially in Arabic. Check memory sources. Save original thoughts from Capture.",
          "الذكاء المحلي تجريبي وقد يخطئ، خصوصاً بالعربية. راجع مصادر الذكريات. احفظ أفكارك الأصلية من شاشة الالتقاط."
        )
      )
      .font(.callout).foregroundStyle(MemoryTheme.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 32)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 8) {
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
                Task { await model.flushDraft() }
              }.frame(minHeight: 44)
            }
            Button(language.text("Dismiss", "إخفاء")) { model.clearError() }.frame(minHeight: 44)
          }
        }.font(.callout).padding(12).background(
          MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 12))
      }
      Toggle(isOn: $model.memoryMode) {
        if typeSize.isAccessibilitySize {
          Text(language.text("Memories", "الذكريات")).font(.subheadline)
        } else {
          Label(
            language.text("Use saved memories", "استخدام الذكريات المحفوظة"),
            systemImage: "doc.text.magnifyingglass"
          ).font(.subheadline)
        }
      }
      .accessibilityLabel(language.text("Use saved memories", "استخدام الذكريات المحفوظة"))
      .disabled(model.isGenerating || model.isTransitioning || !model.hasLoaded)
      .accessibilityIdentifier("chat-memory-mode")
      .padding(.horizontal, 8)
      if model.memoryMode {
        Text(
          language.text(
            "Memory questions use current saved sources. Earlier AI replies are not evidence.",
            "نستخدم المصادر المحفوظة الحالية لأسئلة الذكريات. ردود الذكاء السابقة ليست دليلاً.")
        )
        .font(.caption).foregroundStyle(MemoryTheme.secondary).padding(.horizontal, 8)
      }

      HStack(alignment: .bottom, spacing: 8) {
        TextField(
          "", text: $model.draft,
          prompt: Text(language.text("Ask local AI…", "اسأل الذكاء المحلي…")), axis: .vertical
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
            Task { await model.send() }
          }.disabled(!model.canSend)
        }
      }
      .padding(.horizontal, 12).padding(.vertical, 5)
      .overlay(RoundedRectangle(cornerRadius: 28).stroke(MemoryTheme.line, lineWidth: 0.75))
      .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: model.isGenerating)
      HStack {
        if !typeSize.isAccessibilitySize || !composerFocused {
          Text(language.text("Local AI · Experimental", "ذكاء محلي · تجريبي"))
        }
        Spacer()
        if composerFocused {
          Button(language.text("Done", "تم")) { composerFocused = false }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("chat-keyboard-done")
        }
      }.font(.caption).foregroundStyle(MemoryTheme.secondary)
    }
    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 8)
    .background(MemoryTheme.canvas)
  }

  @ViewBuilder
  private func toolbarLabel(_ title: String, symbol: String) -> some View {
    if typeSize.isAccessibilitySize {
      Image(systemName: symbol).font(.system(size: 28)).accessibilityLabel(title)
    } else {
      Label(title, systemImage: symbol)
    }
  }
}

enum ChatCopy {
  static func error(_ error: ChatError, language: AppLanguage) -> String {
    switch error {
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
