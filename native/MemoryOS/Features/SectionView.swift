import ChatPresentation
import SwiftUI

/// The session retains paths; only the current section renders controls.
struct SectionHostView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  @Bindable var session: DemoSession
  let audio: AudioViewModel
  let records: LocalRecordsViewModel
  let chat: ChatViewModel
  let preparation: ChatModelPreparationViewModel
  let section: AppSection
  let menuIsOpen: Bool
  let openMenu: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding

  @State private var showHistory = false
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    @Bindable var state = session.state(for: section)
    let captureConversation = session.captureConversationBinding()
    NavigationStack(path: $state.path) {
      VStack(spacing: 0) {
        if section == .chat || section == .capture {
          recordHeader
        } else {
          ScreenHeader(
            title: section.title(in: session.language),
            menuLabel: session.language.text("Open menu", "فتح القائمة"), openMenu: openMenu,
            menuFocus: menuFocus,
            searchLabel: section == .memories ? AppSection.search.title(in: session.language) : nil,
            openSearch: section == .memories ? { session.section = .search } : nil)
        }
        SectionView(
          session: session, audio: audio, records: records, chat: chat, preparation: preparation,
          section: section, menuIsOpen: menuIsOpen)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        WorkspaceDock(session: session)
      }
      .sheet(isPresented: $showHistory) {
        ChatHistoryView(
          model: chat, language: session.language,
          onOpen: {
            if section == .capture { captureConversation.wrappedValue = true }
          })
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: DemoDestination.self) { destination in
        Group {
          switch destination {
          case .personalProfile(let id):
            PersonalProfileDetail(model: personal, profileID: id, language: session.language)
          case .personalEntry(let id):
            PersonalEntryDetail(model: personal, entryID: id, language: session.language)
          case .personalSource(let id):
            PersonalSourceView(sourceID: id, language: session.language)
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
  private var showsChat: Bool {
    section == .chat || session.captureShowsConversation
  }

  private var recordTitle: String {
    if showsChat {
      return chat.isTemporary
        ? session.language.text("Temporary chat", "محادثة مؤقتة")
        : AppSection.chat.title(in: session.language)
    }
    return WorkspaceTab.record.title(in: session.language)
  }

  private var recordMenu: some View {
    IconControl(
      symbol: "line.3.horizontal",
      label: session.language.text("Open menu", "فتح القائمة"),
      identifier: "open-menu", action: openMenu
    )
    .memoryGlass(in: Circle(), interactive: true)
    .accessibilityFocused(menuFocus, equals: .rootMenu)
  }

  private var recordHeading: some View {
    Text(recordTitle)
      .font(MemoryTheme.title)
      .accessibilityAddTraits(.isHeader)
  }

  private var recordHeader: some View {
    MemoryGlassGroup {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 12) {
            recordMenu
            recordHeading
          }
          HStack(spacing: 12) { recordActions }.frame(maxWidth: .infinity, alignment: .trailing)
        }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) {
            recordMenu
            recordHeading.fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            recordActions
          }
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
              recordMenu
              recordHeading
            }
            HStack(spacing: 12) { recordActions }.frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 8)
    .background(MemoryTheme.canvas)
  }

  @ViewBuilder private var recordActions: some View {
    let captureConversation = session.captureConversationBinding()
    if showsChat {
      Button {
        session.openHome()
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
          if section == .capture { captureConversation.wrappedValue = true }
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

}

struct SectionView: View {
  @Environment(PersonalMemoryViewModel.self) private var personal
  @Environment(MemorySearchViewModel.self) private var search
  @Environment(RelationshipViewModel.self) private var relationship
  @Bindable var session: DemoSession
  let audio: AudioViewModel
  let records: LocalRecordsViewModel
  let chat: ChatViewModel
  let preparation: ChatModelPreparationViewModel
  let section: AppSection
  let menuIsOpen: Bool
  private var language: AppLanguage { session.language }

  var body: some View {
    Group {
      switch section {
      case .capture:
        CaptureView(
          session: session, records: records, audio: audio, chat: chat, menuIsOpen: menuIsOpen,
          showConversation: session.captureConversationBinding())
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
      case .calendar:
        CalendarOverviewView(session: session)
      case .brainMap:
        BrainMapView(
          model: search, personal: personal, records: records, language: language,
          openCapture: { session.openHome() }, focusedID: $session.brainFocusID)
      case .search:
        MemorySearchView(
          model: search, personal: personal, records: records, language: language,
          workspaceRoot: true, menuIsOpen: menuIsOpen)
      case .understanding:
        RelationshipView(model: relationship, language: language)
      case .organization:
        OrganizationView(language: language)
      case .settings:
        Form {
          Picker(language.text("Language", "اللغة"), selection: $session.language) {
            ForEach(AppLanguage.allCases) { item in
              Text(item.name).tag(item)
            }
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("language-picker")
          BrainMarkSettingsSection(language: language)
          Section(language.text("Local AI", "الذكاء المحلي")) {
            ChatModelSettingsView(language: language, model: preparation)
          }
          Section(language.text("Privacy", "الخصوصية")) {
            Label(
              language.text(
                "Saved chats keep your original messages on this device.",
                "تحتفظ المحادثات المحفوظة برسائلك الأصلية على هذا الجهاز."),
              systemImage: "lock")
            Label(
              language.text(
                "Temporary chats leave no saved history.",
                "لا تترك المحادثات المؤقتة سجلاً محفوظاً."),
              systemImage: "eye.slash")
          }
          .font(.subheadline)
          .foregroundStyle(MemoryTheme.secondary)
        }
        .scrollContentBackground(.hidden)
      case .memories:
        PersonalMemoryHomeView(
          model: personal, records: records, language: language,
          openCapture: { session.openHome() },
          openCollection: { session.section = $0 }, originals: $session.notesShowOriginals)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MemoryTheme.canvas)
  }
}
