import ChatCore
import SwiftUI

struct ChatVoiceCard: View {
  let voice: ChatVoiceAttachment
  let transcript: String
  let language: AppLanguage
  let play: (Double) -> Void
  let stop: () -> Void
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VoicePlaybackControls(
        duration: voice.durationSeconds, language: language, play: { play(0) }, stop: stop)
      DisclosureGroup(isExpanded: $expanded) {
        VStack(alignment: .leading, spacing: 12) {
          Text(transcript).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("voice-transcript-text")
          if !voice.passages.isEmpty {
            ForEach(voice.passages, id: \.id) { passage in
              Button {
                play(passage.startSeconds)
              } label: {
                HStack(alignment: .top) {
                  Text(
                    Duration.seconds(passage.startSeconds).formatted(
                      .time(pattern: .minuteSecond))
                  )
                  .monospacedDigit()
                  Text(passage.text).lineLimit(2)
                  if passage.uncertain { Image(systemName: "questionmark.circle") }
                }.font(.caption).frame(minHeight: 44)
              }.buttonStyle(.plain)
                .accessibilityLabel(
                  language.text("Play passage", "تشغيل المقطع") + ": " + passage.text)
            }
          }
        }.padding(.top, 8)
      } label: {
        Text(language.text("Transcript", "النص المفرّغ")).font(.subheadline)
          .frame(minHeight: 44)
      }
      .accessibilityIdentifier("voice-transcript-disclosure")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 24))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("chat-voice-\(voice.recordingID)")
  }
}

struct ChatPendingVoiceCard: View {
  let pending: PendingVoice
  let processing: Bool
  let stopping: Bool
  let language: AppLanguage
  let play: (Double) -> Void
  let stop: () -> Void
  let retry: () -> Void
  let cancel: () -> Void
  let openRecordings: () -> Void
  @State private var transcriptExpanded = false
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VoicePlaybackControls(
        duration: pending.durationSeconds, language: language, play: { play(0) }, stop: stop)
      HStack(spacing: 8) {
        if processing { ProgressView().controlSize(.small).accessibilityHidden(true) }
        Text(status).font(.callout)
          .accessibilityIdentifier(
            stopping ? "voice-transcription-stopping" : "voice-transcription-message")
      }.accessibilityIdentifier("voice-transcription-status")
      if let failure = pending.failure {
        Text(failureText(failure)).font(.callout)
          .accessibilityIdentifier("voice-transcription-error")
      }
      if let transcript = pending.transcript {
        DisclosureGroup(isExpanded: $transcriptExpanded) {
          Text(transcript.text).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("voice-transcript-text")
        } label: {
          Text(language.text("Transcript", "النص المفرّغ"))
            .frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("voice-transcript-disclosure")
      }
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        : AnyLayout(HStackLayout(spacing: 16))
      layout {
        if processing && !stopping {
          Button(action: cancel) {
            Text(language.text("Cancel transcription", "إلغاء التفريغ"))
              .frame(minHeight: 44).contentShape(Rectangle())
          }.accessibilityIdentifier("voice-transcription-cancel")
        } else if !processing {
          Button(action: retry) {
            Text(language.text("Retry transcription", "إعادة التفريغ"))
              .frame(minHeight: 44).contentShape(Rectangle())
          }.accessibilityIdentifier("voice-transcription-retry")
        }
        Button(action: openRecordings) {
          Label(language.text("Open recordings", "فتح التسجيلات"), systemImage: "waveform")
            .frame(minHeight: 44, alignment: .leading)
            .multilineTextAlignment(.leading)
            .contentShape(Rectangle())
        }
      }.font(.subheadline).frame(minHeight: 44)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(MemoryTheme.selection, in: RoundedRectangle(cornerRadius: 24))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("chat-pending-voice")
  }

  private var status: String {
    if processing && stopping {
      return language.text("Stopping transcription…", "جارٍ إيقاف التفريغ…")
    }
    if processing {
      return language.text("Transcribing on this device…", "جارٍ تفريغ الصوت على الجهاز…")
    }
    return language.text("Recording saved", "حُفظ التسجيل")
  }

  private func failureText(_ failure: VoiceFailure) -> String {
    switch failure {
    case .modelUnavailable:
      language.text(
        "Speech model unavailable. Open Recordings to set it up, then retry.",
        "نموذج الصوت غير متاح. افتح التسجيلات لإعداده ثم أعد المحاولة.")
    case .recordingUnavailable:
      language.text(
        "The saved audio could not be opened. Check it in Recordings.",
        "تعذّر فتح الصوت المحفوظ. راجعه في التسجيلات.")
    case .noSpeech:
      language.text(
        "No clear speech was found. Your audio is saved; listen or try again.",
        "لم نعثر على كلام واضح. الصوت محفوظ؛ استمع إليه أو أعد المحاولة.")
    case .interrupted:
      language.text(
        "Transcription stopped. Retry when you are ready.",
        "توقف التفريغ. أعد المحاولة عندما تكون جاهزاً.")
    case .storage:
      language.text(
        "Could not save the transcript. Check free space and retry.",
        "تعذّر حفظ النص. تحقق من المساحة وأعد المحاولة.")
    default:
      language.text(
        "Could not transcribe this recording. Your original audio is saved.",
        "تعذّر تفريغ التسجيل. الصوت الأصلي محفوظ.")
    }
  }
}

private struct VoicePlaybackControls: View {
  let duration: Double
  let language: AppLanguage
  let play: () -> Void
  let stop: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(spacing: 10))
    layout {
      VStack(alignment: .leading, spacing: 4) {
        Text(language.text("Voice message", "رسالة صوتية")).font(.headline)
        Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
          .font(.caption.monospacedDigit()).foregroundStyle(MemoryTheme.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      playbackButtons
    }
  }

  private var playbackButtons: some View {
    HStack(spacing: 4) {
      Button(action: play) {
        Image(systemName: "play.fill").font(.title3).frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }.buttonStyle(.plain)
        .accessibilityLabel(language.text("Play recording", "تشغيل التسجيل"))
        .accessibilityIdentifier("voice-play")
      Button(action: stop) {
        Image(systemName: "stop.fill").frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }.buttonStyle(.plain).foregroundStyle(MemoryTheme.secondary)
        .accessibilityLabel(language.text("Stop playback", "إيقاف التشغيل"))
    }
  }
}
