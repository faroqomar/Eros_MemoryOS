import ChatPresentation
import SwiftUI
import UIKit

@main
struct MemoryOSApp: App {
  @State private var session = DemoSession()
  @State private var audio: AudioViewModel
  @State private var records: LocalRecordsViewModel
  @State private var chat: ChatViewModel
  @State private var preparation = ChatComposition.makePreparationViewModel()
  @State private var responsiveness = ChatResponsivenessProbe()
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let provider = LocalStoreProvider(
      directory: URL.applicationSupportDirectory.appending(path: "LocalRecords"))
    let inference = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let audioFeature = AudioComposition.makeFeature(inference: inference)
    _audio = State(initialValue: audioFeature.viewModel)
    _records = State(initialValue: LocalStoreComposition.makeViewModel(provider: provider))
    _chat = State(
      initialValue: ChatComposition.makeViewModel(
        provider: provider, voiceTranscriber: audioFeature.voiceTranscriber, model: inference))
  }

  var body: some Scene {
    WindowGroup {
      RootView(
        session: session, audio: audio, records: records, chat: chat, preparation: preparation
      )
      .task {
        await records.load()
        await audio.load()
        await chat.load()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active {
          responsiveness.suspend()
          Task {
            if phase == .background || audio.captureState.state == .recording
              || audio.captureState.state == .paused || audio.isProcessing
            {
              await audio.interrupt()
            }
            await chat.interrupt()
          }
        } else if chat.isGenerating {
          responsiveness.start()
        }
      }
      .onChange(of: chat.isGenerating) { _, generating in
        if generating {
          responsiveness.start()
        } else {
          responsiveness.finish(
            cancellationSeconds: chat.lastCancellationSeconds,
            firstUsableTextSeconds: chat.firstUsableTextSeconds)
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: UIApplication.didReceiveMemoryWarningNotification)
      ) { _ in
        Task {
          await audio.interrupt()
          await chat.interrupt()
        }
      }
      .environment(\.layoutDirection, session.language == .arabic ? .rightToLeft : .leftToRight)
      .environment(\.locale, Locale(identifier: session.language.rawValue))
      .environment(\.chatScrollMeasurement, responsiveness)
      .preferredColorScheme(.dark)
      .tint(MemoryTheme.ink)
    }
  }
}
