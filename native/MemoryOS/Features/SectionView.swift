import ChatPresentation
import SwiftUI

/// The session retains paths; only the current section renders controls.
struct SectionHostView: View {
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
                durationSeconds: recording.durationSeconds ?? 0)
            else { return false }
            session.section = .chat
            Task { await chat.processVoice() }
            return true
          })
      case .profiles:
        CatalogListView(
          session: session, state: session.state(for: section), kind: .person,
          menuIsOpen: menuIsOpen)
      case .projects:
        CatalogListView(
          session: session, state: session.state(for: section), kind: .project,
          menuIsOpen: menuIsOpen)
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
              "Typed memories stay on this device. Sample profiles and reminder choices remain a demo.",
              "تبقى الذكريات المكتوبة على هذا الجهاز. الملفات التجريبية وخيارات التذكير للعرض فقط.")
          )
          .foregroundStyle(MemoryTheme.secondary)
        }
        .scrollContentBackground(.hidden)
      case .memories:
        LocalRecordsListView(
          model: records, language: language, openCapture: { session.openHome() })
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MemoryTheme.canvas)
  }
}
