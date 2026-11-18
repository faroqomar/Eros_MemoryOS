import ChatPresentation
import SwiftUI

/// The session retains paths; only the current section renders controls.
struct SectionHostView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  let session: DemoSession
  let audio: AudioViewModel
  let records: LocalRecordsViewModel
  let chat: ChatViewModel
  let preparation: ChatModelPreparationViewModel
  let section: AppSection
  let menuIsOpen: Bool
  let openMenu: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding

  @State private var captureShowsConversation = false
  @State private var showHistory = false

  var body: some View {
    @Bindable var state = session.state(for: section)
    NavigationStack(path: $state.path) {
      VStack(spacing: 0) {
        if section == .chat || section == .capture {
          MemoryGlassGroup {
            HStack(spacing: 12) {
              IconControl(
                symbol: "line.3.horizontal",
                label: session.language.text("Open menu", "فتح القائمة"),
                identifier: "open-menu", action: openMenu
              )
              .memoryGlass(in: Circle(), interactive: true)
              .accessibilityFocused(menuFocus, equals: .rootMenu)
              Spacer()
              Text("MemoryOS").font(.headline).lineLimit(1).minimumScaleFactor(0.8)
              Spacer()
              if section == .capture && captureShowsConversation {
                Button {
                  captureShowsConversation = false
                } label: {
                  Image(systemName: "mic").frame(width: 44, height: 44)
                }
                .accessibilityLabel(session.language.text("Record a thought", "تسجيل فكرة"))
                .accessibilityIdentifier("capture-return-to-recording")
                .memoryGlass(in: Circle(), interactive: true)
              }
              Menu {
                Button(
                  session.language.text(
                    chat.hasTemporarySession ? "Resume temporary chat" : "Start temporary chat",
                    chat.hasTemporarySession ? "متابعة محادثة مؤقتة" : "بدء محادثة مؤقتة")
                ) {
                  Task {
                    await chat.startTemporary()
                    if chat.error == nil {
                      captureShowsConversation = true
                      session.section = .chat
                    }
                  }
                }.accessibilityIdentifier("start-temporary-chat")
                if chat.hasTemporarySession {
                  Button(
                    session.language.text("End temporary session", "إنهاء الجلسة المؤقتة"),
                    role: .destructive
                  ) {
                    Task { await chat.endTemporary() }
                  }.accessibilityIdentifier("end-temporary-chat")
                }
                Button(session.language.text("Saved chats", "المحادثات المحفوظة")) {
                  showHistory = true
                }
                .accessibilityIdentifier("open-chat-history")
                Button(session.language.text("Home", "الرئيسية")) {
                  captureShowsConversation = false
                  session.openHome()
                }
              } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
              }.accessibilityLabel(session.language.text("Chat options", "خيارات المحادثة"))
                .accessibilityIdentifier("chat-header-options")
                .memoryGlass(in: Capsule(), interactive: true)
              Button {
                Task {
                  await chat.newConversation()
                  if chat.error == nil {
                    if section == .capture { captureShowsConversation = true }
                  }
                }
              } label: {
                Image(systemName: "square.and.pencil").font(.title3).frame(width: 44, height: 44)
              }
              .disabled(
                chat.isGenerating || chat.isTranscribing || chat.isTransitioning || !chat.hasLoaded
              )
              .accessibilityLabel(session.language.text("New chat", "محادثة جديدة"))
              .accessibilityIdentifier("new-chat")
              .memoryGlass(in: Circle(), interactive: true)
            }
          }.padding(.horizontal, 18).padding(.vertical, 10)
        } else {
          ScreenHeader(
            title: section.title(in: session.language),
            menuLabel: session.language.text("Open menu", "فتح القائمة"), openMenu: openMenu,
            menuFocus: menuFocus)
        }
        SectionView(
          session: session, audio: audio, records: records, chat: chat, preparation: preparation,
          section: section, menuIsOpen: menuIsOpen,
          captureShowsConversation: $captureShowsConversation)
      }
      .sheet(isPresented: $showHistory) {
        ChatHistoryView(
          model: chat, language: session.language,
          onOpen: {
            if section == .capture { captureShowsConversation = true }
          })
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: DemoDestination.self) { destination in
        Group {
          switch destination {
          case .record(let id): RecordDetailView(session: session, recordID: id)
          case .birthday(let id): BirthdayDetailView(session: session, birthdayID: id)
          case .personalProfile(let id):
            PersonalProfileDetail(model: personal, profileID: id, language: session.language)
          case .personalEntry(let id):
            PersonalEntryDetail(model: personal, entryID: id, language: session.language)
          case .personalSource(let id):
            if let source = personal.snapshot.sources.first(where: { $0.id == id }) {
              PersonalSourceView(source: source, language: session.language)
            }
          }
        }
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            IconControl(
              symbol: "line.3.horizontal", label: session.language.text("Open menu", "فتح القائمة"),
              identifier: "open-menu", action: openMenu
            )
            .accessibilityFocused(menuFocus, equals: .detailMenu)
          }
        }
      }
    }
  }
}

struct SectionView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  @Bindable var session: DemoSession
  let audio: AudioViewModel
  let records: LocalRecordsViewModel
  let chat: ChatViewModel
  let preparation: ChatModelPreparationViewModel
  let section: AppSection
  let menuIsOpen: Bool
  @Binding var captureShowsConversation: Bool
  private var language: AppLanguage { session.language }

  var body: some View {
    Group {
      switch section {
      case .capture:
        CaptureView(
          session: session, records: records, audio: audio, chat: chat, menuIsOpen: menuIsOpen,
          showConversation: $captureShowsConversation)
      case .chat:
        ChatView(
          model: chat, records: records, audio: audio,
          openRecordings: { session.section = .recordings }, language: language,
          menuIsOpen: menuIsOpen)
      case .recordings:
        AudioLibraryView(
          model: audio, records: records, language: language, embedded: true,
          chatBusy: chat.isGenerating || chat.isTranscribing || chat.isTransitioning,
          startChat: { recording in
            guard
              await chat.prepareVoiceChat(
                recordingID: recording.id,
                durationSeconds: recording.durationSeconds ?? 0, asNormalCapture: true)
            else { return false }
            session.section = .chat
            Task { await chat.processVoice() }
            return true
          })
      case .profiles:
        PersonalProfilesView(
          model: personal, kind: .person, language: language, menuIsOpen: menuIsOpen)
      case .projects:
        PersonalProfilesView(
          model: personal, kind: .project, language: language, menuIsOpen: menuIsOpen)
      case .birthdays:
        BirthdaysView(session: session)
      case .brainMap:
        BrainMapView(session: session, state: session.state(for: section))
      case .settings:
        Form {
          Section(language.text("Local AI", "الذكاء المحلي")) {
            ChatModelSettingsView(language: language, model: preparation)
          }
          Picker(language.text("Language", "اللغة"), selection: $session.language) {
            ForEach(AppLanguage.allCases) { item in
              Text(item.name).tag(item)
            }
          }
          .accessibilityIdentifier("language-picker")
          Text(
            language.text(
              "Normal chats preserve your original messages on this device. Temporary chats create no lasting history. Reminder choices remain a demo.",
              "تحفظ المحادثات العادية رسائلك الأصلية على الجهاز. لا تحفظ المحادثات المؤقتة تاريخاً دائماً. خيارات التذكير تجريبية."
            )
          )
          .foregroundStyle(MemoryTheme.secondary)
        }
        .scrollContentBackground(.hidden)
      case .memories:
        PersonalMemoryHomeView(
          model: personal, records: records, language: language,
          openCapture: { session.openHome() })
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MemoryTheme.canvas)
  }
}
