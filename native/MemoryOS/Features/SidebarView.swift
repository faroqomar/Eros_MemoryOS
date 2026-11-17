import ChatPresentation
import SwiftUI

struct SidebarView: View {
  let session: DemoSession
  let chat: ChatViewModel
  let close: () -> Void
  let menuFocus: AccessibilityFocusState<MenuFocusTarget?>.Binding
  @State private var search = ""
  @State private var showHistory = false
  private var language: AppLanguage { session.language }

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
      }.padding(.top, 14).padding(.bottom, 18)

      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(MemoryTheme.secondary)
        TextField(language.text("Search chats", "بحث في المحادثات"), text: $search)
          .accessibilityIdentifier("sidebar-chat-search")
      }.padding(12).background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 14)

      ScrollView {
        VStack(alignment: .leading, spacing: 4) {
          if search.isEmpty {
            ForEach(AppSection.allCases.filter { $0 != .settings && $0 != .chat }) { section in
              row(section)
            }
            Divider().padding(.vertical, 18)
          }
          Text(language.text("Chats", "المحادثات")).font(.caption).foregroundStyle(
            MemoryTheme.secondary
          )
          .padding(.horizontal, 12).padding(.bottom, 8)
          let conversations = chat.conversations.filter {
            ($0.pendingVoice != nil || !$0.messages.isEmpty || !$0.draft.isEmpty
              || $0.title != "New chat" || $0.memoryMode)
              && (search.isEmpty || $0.title.localizedStandardContains(search))
          }
          if conversations.isEmpty {
            Text(
              language.text(
                search.isEmpty ? "Your conversations appear here." : "No matching chats.",
                search.isEmpty ? "تظهر محادثاتك هنا." : "لا توجد محادثات مطابقة.")
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
      HStack {
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
            .font(.headline).padding(.horizontal, 20).frame(height: 48)
            .foregroundStyle(MemoryTheme.canvas).background(MemoryTheme.ink, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("sidebar-new-chat")
          .disabled(
            chat.isGenerating || chat.isTranscribing || chat.isTransitioning || !chat.hasLoaded)
        Spacer(minLength: 0)
        IconControl(
          symbol: "gearshape", label: language.text("Settings", "الإعدادات"),
          identifier: "section-settings"
        ) {
          session.section = .settings
          close()
        }
      }.padding(.vertical, 16)
    }
    .padding(.horizontal, 18)
    .sheet(isPresented: $showHistory) {
      ChatHistoryView(
        model: chat, language: language,
        onOpen: {
          session.section = .chat
          close()
        })
    }
  }

  private func row(_ section: AppSection) -> some View {
    Button {
      if section == .capture { session.openHome() } else { session.section = section }
      close()
    } label: {
      HStack(spacing: 16) {
        Image(systemName: section.symbol).font(.system(size: 21)).frame(width: 26)
          .accessibilityHidden(true)
        Text(section == .capture ? language.text("Home", "الرئيسية") : section.title(in: language))
          .font(.body).multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      }.padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 46)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier("section-\(section.rawValue)")
  }
}
