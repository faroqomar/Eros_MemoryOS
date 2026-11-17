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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if let voice = message.voice, message.role == .user {
        ChatVoiceCard(
          voice: voice, transcript: message.text, language: language,
          play: { seconds in playVoice(voice.recordingID, seconds) }, stop: stopVoice)
      } else if message.role == .user {
        HStack(alignment: .top, spacing: 0) {
          Spacer(minLength: 44)
          Text(message.text)
            .font(.body)
            .lineSpacing(4)
            .textSelection(.enabled)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 24))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      } else {
        assistantReply
      }
    }
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
              "Retrieved sources · Check the answer", "المصادر المسترجعة · تحقّق من الجواب")
          )
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
          ForEach(message.sources) { evidence in
            Button {
              openSource(evidence)
            } label: {
              Label(String(evidence.text.prefix(70)), systemImage: "doc.text")
                .font(.callout).lineLimit(2).frame(minHeight: 44)
            }.buttonStyle(.plain)
              .accessibilityLabel(
                language.text("Open source", "فتح المصدر") + ": " + String(evidence.text.prefix(70))
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
