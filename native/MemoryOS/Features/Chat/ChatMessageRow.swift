import ChatCore
import SwiftUI
import UIKit

struct ChatMessageRow: View {
  let message: ChatMessage
  let language: AppLanguage
  let canRegenerate: Bool
  let retry: () -> Void
  let regenerate: () -> Void
  let openSource: (ChatEvidence) -> Void
  let playVoice: (UUID, Double) -> Void
  let stopVoice: () -> Void
  @State private var copied = false
  @AppStorage(BrainMark.preferenceKey) private var brainMark: BrainMark = .constellation
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if message.role == .user {
        Text(language.text("You", "أنت"))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(MemoryTheme.secondary)
          .accessibilityAddTraits(.isHeader)
        if let voice = message.voice {
          ChatVoiceCard(
            voice: voice, transcript: message.text, language: language,
            play: { seconds in playVoice(voice.recordingID, seconds) }, stop: stopVoice)
        } else {
          Text(message.text)
            .font(.body)
            .lineSpacing(4)
            .textSelection(.enabled)
        }
      } else {
        HStack(spacing: 6) {
          BrainMarkView(mark: brainMark).frame(width: 18, height: 18)
          Text("MemoryOS").font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(MemoryTheme.workspaceAccent)
        assistantReply
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("chat-message-\(message.id)")
  }

  private var assistantReply: some View {
    VStack(alignment: .leading, spacing: 10) {
      if message.text.isEmpty && message.status == .generating {
        HStack(spacing: 8) {
          if !reduceMotion { ProgressView().controlSize(.small).accessibilityHidden(true) }
          Text(language.text("Preparing local reply…", "تحضير الرد المحلي…"))
        }
        .font(.callout).frame(minHeight: 28)
        .accessibilityIdentifier("chat-generating")
      } else {
        // Preserve block identity while the reply streams.
        ChatReplyBlocks(text: message.text).equatable()
      }
      if message.role == .assistant {
        if message.status == .generating && !message.text.isEmpty {
          Text(language.text("Generating…", "جارٍ التوليد…"))
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
        }
        if !message.sources.isEmpty {
          Text(
            language.text(
              "Sources to check", "مصادر للتحقّق")
          )
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(MemoryTheme.secondary)
          .accessibilityAddTraits(.isHeader)
          ForEach(message.sources) { evidence in
            let preview = sourcePreview(evidence)
            Button {
              openSource(evidence)
            } label: {
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(preview, systemImage: "doc.text")
                  .font(.callout)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(MemoryTheme.secondary)
                  .accessibilityHidden(true)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .frame(minHeight: 44)
              .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 12))
              .contentShape(Rectangle())
            }.buttonStyle(.plain)
              .accessibilityLabel(
                language.text("Open source", "فتح المصدر") + ": " + preview
              )
              .accessibilityIdentifier("chat-source-\(evidence.id)")
          }
        }
        if message.status != .complete && message.status != .generating {
          Text(statusText).font(.caption).foregroundStyle(MemoryTheme.secondary)
        }
        HStack(spacing: 2) {
          if !message.text.isEmpty {
            Button {
              UIPasteboard.general.setItems(
                [[UIPasteboard.typeAutomatic: message.text]],
                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
              copied = true
            } label: {
              Label(
                language.text(copied ? "Copied" : "Copy", copied ? "نُسخ" : "نسخ"),
                systemImage: copied ? "checkmark" : "doc.on.doc"
              )
              .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("chat-copy")
          }
          if canRegenerate {
            if message.status == .failed || message.status == .interrupted
              || message.status == .stopped
            {
              Button(action: retry) {
                Label(language.text("Retry", "إعادة المحاولة"), systemImage: "arrow.clockwise")
                  .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
              }
              .frame(minHeight: 44).accessibilityIdentifier("chat-retry")
            } else {
              Button(action: regenerate) {
                Label(language.text("Regenerate", "إعادة التوليد"), systemImage: "arrow.clockwise")
                  .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
              }
              .frame(minHeight: 44).accessibilityIdentifier("chat-regenerate")
            }
          }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 18))
        .buttonStyle(.plain)
        .foregroundStyle(MemoryTheme.secondary)
      }
    }
    .font(.body).lineSpacing(4)
    .frame(maxWidth: .infinity, alignment: .leading)

  }

  private func sourcePreview(_ evidence: ChatEvidence) -> String {
    var text = evidence.text[...]
    if evidence.sourceDigest != nil {
      // Retrieval annotations belong in the source detail; the button previews the passage.
      for _ in 0..<2 where text.first == "[" {
        guard let end = text.firstIndex(of: "]") else { break }
        text = text[text.index(after: end)...].drop(while: { $0.isWhitespace })
      }
    }
    return String(text.prefix(70))
  }

  private var statusText: String {
    switch message.status {
    case .stopped: language.text("Stopped · Partial reply retained", "متوقف · النص الجزئي موجود")
    case .interrupted:
      language.text("Interrupted · Retry when ready", "انقطع الرد · أعد المحاولة عندما تكون جاهزاً")
    default:
      language.text("Reply incomplete · You can retry", "الرد غير مكتمل · يمكنك إعادة المحاولة")
    }
  }
}

/// Value-only boundaries keep unchanged blocks out of Markdown parsing and text layout updates.
private struct ChatReplyBlocks: View, Equatable {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(ChatFormatting.blocks(text)) { block in
        ChatReplyBlock(block: block).equatable()
      }
    }
  }
}

private struct ChatReplyBlock: View, Equatable {
  let block: ChatFormatting.Block

  var body: some View {
    switch block.kind {
    case .code(let name):
      VStack(alignment: .leading, spacing: 8) {
        if !name.isEmpty {
          Text(name).font(.caption).foregroundStyle(MemoryTheme.secondary)
        }
        ScrollView(.horizontal) {
          Text(verbatim: block.text).font(.system(.body, design: .monospaced))
            .fixedSize(horizontal: true, vertical: false)
            .environment(\.layoutDirection, .leftToRight)
        }
      }.padding(12).background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    case .list(let bullet):
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(bullet)
        Text(ChatFormatting.inline(block.text))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    case .heading:
      Text(ChatFormatting.inline(block.text)).font(.headline)
    case .paragraph:
      Text(ChatFormatting.inline(block.text))
    }
  }
}
