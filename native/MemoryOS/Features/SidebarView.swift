import ChatPresentation
import SwiftUI

struct SidebarView: View {
  @Environment(OrganizationViewModel.self) private var organization
  let session: DemoSession
  let chat: ChatViewModel
  let isOpen: Bool
  let close: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding
  @State private var search = ""
  @State private var showHistory = false
  @FocusState private var searchFocused: Bool
  @AppStorage(BrainMark.preferenceKey) private var brainMark: BrainMark = .constellation
  private var language: AppLanguage { session.language }
  private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("MemoryOS").font(.title2.bold()).accessibilityAddTraits(.isHeader)
        Spacer(minLength: 0)
        IconControl(
          symbol: "xmark", label: language.text("Close menu", "إغلاق القائمة"),
          identifier: "close-menu", action: close
        )
        .accessibilityFocused(menuFocus, equals: .sidebar)
      }.padding(.top, 10).padding(.bottom, 12)

      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(MemoryTheme.secondary)
          .accessibilityHidden(true)
        let searchLabel = language.text("Search chats", "بحث في المحادثات")
        TextField(searchLabel, text: $search, prompt: MemoryTheme.fieldPrompt(searchLabel))
          .focused($searchFocused)
          .submitLabel(.search)
          .onSubmit { searchFocused = false }
          .accessibilityIdentifier("sidebar-chat-search")
        if !search.isEmpty {
          Button {
            search = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .frame(width: 44, height: 44)
          }
          .buttonStyle(.plain)
          .foregroundStyle(MemoryTheme.secondary)
          .accessibilityLabel(language.text("Clear chat search", "مسح بحث المحادثات"))
          .accessibilityIdentifier("sidebar-clear-chat-search")
        }
      }.padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 48)
        .background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 14)

      ScrollView {
        VStack(alignment: .leading, spacing: 4) {
          if query.isEmpty {
            ForEach(
              AppSection.allCases.filter { $0 != .settings && $0 != .chat && $0 != .calendar }
            ) { section in
              row(section)
            }
            if !organization.snapshot.views.isEmpty {
              heading(language.text("Your views", "عروضك"))
            }
            ForEach(organization.snapshot.views) { view in
              Button {
                Task {
                  await organization.openView(view)
                  session.section = .organization
                  close()
                }
              } label: {
                Label(view.name, systemImage: "line.3.horizontal.decrease")
                  .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                  .padding(.horizontal, 12)
              }.buttonStyle(.plain).accessibilityIdentifier("sidebar-custom-tab-\(view.id)")
            }
            Divider().padding(.vertical, 10)
          }
          if chat.hasTemporarySession {
            Button {
              Task {
                await chat.startTemporary()
                if chat.error == nil {
                  session.section = .chat
                  close()
                }
              }
            } label: {
              Label(
                language.text("Resume temporary chat", "متابعة محادثة مؤقتة"),
                systemImage: "eye.slash"
              )
              .frame(minHeight: 44)
            }.accessibilityIdentifier("resume-temporary-chat")
          }
          heading(language.text("Saved chats", "المحادثات المحفوظة"))
          let conversations = chat.conversations.filter {
            !$0.isTemporary
              && ($0.pendingVoice != nil || !$0.messages.isEmpty || !$0.draft.isEmpty
                || $0.title != "New chat" || $0.memoryMode)
              && (query.isEmpty || $0.title.localizedStandardContains(query))
          }
          if !chat.hasLoaded && chat.error == nil {
            ProgressView(language.text("Loading chats…", "جارٍ تحميل المحادثات…"))
              .padding(12)
          } else if conversations.isEmpty && chat.hasLoaded {
            Text(
              language.text(
                query.isEmpty ? "Chats you save appear here." : "No chats match that title.",
                query.isEmpty ? "تظهر محادثاتك المحفوظة هنا." : "لا توجد محادثات بهذا العنوان.")
            )
            .font(.callout).foregroundStyle(MemoryTheme.secondary).padding(12)
          }
          ForEach(Array(conversations.prefix(20))) { conversation in
            Button {
              Task {
                if (chat.isGenerating || chat.isTranscribing)
                  && chat.currentConversation?.id == conversation.id
                {
                  session.section = .chat
                  close()
                  return
                }
                await chat.open(conversation.id)
                if chat.error == nil {
                  session.section = .chat
                  close()
                }
              }
            } label: {
              Text(conversation.title).lineLimit(2).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 12)
                .background(
                  chat.currentConversation?.id == conversation.id && session.section == .chat
                    ? MemoryTheme.selection : .clear, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
              .disabled(
                ((chat.isGenerating || chat.isTranscribing)
                  && chat.currentConversation?.id != conversation.id)
                  || chat.isTransitioning || !chat.hasLoaded
              )
              .accessibilityIdentifier("sidebar-chat-\(conversation.id)")
          }
          Button(language.text("See all chats…", "كل المحادثات…")) { showHistory = true }
            .foregroundStyle(MemoryTheme.secondary).frame(minHeight: 44).padding(.horizontal, 12)
            .accessibilityIdentifier("open-chat-history")
        }
      }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)

      if let error = chat.error {
        Text(ChatCopy.error(error, language: language)).font(.caption).padding(.vertical, 8)
      }
      ViewThatFits(in: .horizontal) {
        HStack {
          newChatButton
          Spacer(minLength: 8)
          settingsButton
        }
        VStack(alignment: .leading, spacing: 6) {
          newChatButton
          settingsButton
        }
      }.padding(.vertical, 12)
    }
    .padding(.horizontal, 18)
    .onChange(of: isOpen) { _, open in
      if !open {
        searchFocused = false
        search = ""
      }
    }
    .sheet(isPresented: $showHistory) {
      ChatHistoryView(
        model: chat, language: language,
        onOpen: {
          session.section = .chat
          close()
        })
    }
  }

  private func heading(_ title: String) -> some View {
    Text(title).font(.subheadline.weight(.semibold))
      .foregroundStyle(MemoryTheme.secondary)
      .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
      .accessibilityAddTraits(.isHeader)
  }

  private var newChatButton: some View {
    Button {
      Task {
        await chat.newConversation()
        if chat.error == nil {
          session.section = .chat
          close()
        }
      }
    } label: {
      Label(language.text("New chat", "محادثة جديدة"), systemImage: "square.and.pencil")
        .font(.subheadline.weight(.semibold)).padding(.horizontal, 15)
        .padding(.vertical, 8).frame(minHeight: 48)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(MemoryTheme.canvas).background(MemoryTheme.ink, in: Capsule())
    }.buttonStyle(.plain).accessibilityIdentifier("sidebar-new-chat")
      .disabled(
        chat.isGenerating || chat.isTranscribing || chat.isTransitioning || !chat.hasLoaded)
  }

  private var settingsButton: some View {
    Button {
      session.section = .settings
      close()
    } label: {
      Label(language.text("Settings", "الإعدادات"), systemImage: "gearshape")
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.leading)
        .frame(minWidth: 44, minHeight: 48)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("section-settings")
  }

  private func row(_ section: AppSection) -> some View {
    let selected = section == session.section
    return Button {
      if section == .capture { session.openHome() } else { session.section = section }
      close()
    } label: {
      HStack(spacing: 16) {
        if section == .brainMap {
          BrainMarkView(mark: brainMark).frame(width: 23, height: 23).frame(width: 26)
            .foregroundStyle(MemoryTheme.workspaceAccent)
        } else {
          Image(systemName: section.symbol).font(.system(size: 21)).frame(width: 26)
            .accessibilityHidden(true)
        }
        Text(section == .capture ? language.text("Home", "الرئيسية") : section.title(in: language))
          .font(.body).multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      }.padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 46)
        .foregroundStyle(selected ? MemoryTheme.workspaceAccent : MemoryTheme.ink)
        .background(
          selected ? MemoryTheme.workspaceAccent.opacity(0.1) : Color.clear,
          in: RoundedRectangle(cornerRadius: 13)
        )
        .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("section-\(section.rawValue)")
  }
}
