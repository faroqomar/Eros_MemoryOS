import ChatPresentation
import MemoryCore
import SwiftUI
import UIKit

@main
struct MemoryOSApp: App {
  private let organizer: any PersonalMemoryOrganizing
  @State private var session = DemoSession()
  @State private var personal: PersonalMemoryViewModel
  @State private var audio: AudioViewModel
  @State private var records: LocalRecordsViewModel
  @State private var chat: ChatViewModel
  @State private var preparation = ChatComposition.makePreparationViewModel()
  @State private var responsiveness = ChatResponsivenessProbe()
  @State private var lifecycleRevision: UInt64 = 0
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let provider = LocalStoreProvider(
      directory: URL.applicationSupportDirectory.appending(path: "LocalRecords"))
    let personalUseCases = PersonalMemoryComposition.makeUseCases()
    let inference = LocalInferenceCoordinator(model: ChatComposition.makeModel())
    let organizer = PersonalMemoryComposition.makeOrganizer(personalUseCases, model: inference)
    self.organizer = organizer
    _personal = State(
      initialValue: PersonalMemoryComposition.makeViewModel(personalUseCases, organizer: organizer))
    let audioFeature = AudioComposition.makeFeature(inference: inference)
    _audio = State(initialValue: audioFeature.viewModel)
    _records = State(initialValue: LocalStoreComposition.makeViewModel(provider: provider))
    _chat = State(
      initialValue: ChatComposition.makeViewModel(
        provider: provider, voiceTranscriber: audioFeature.voiceTranscriber, model: inference,
        personalMemory: personalUseCases, organizer: organizer,
        relevance: ChatComposition.makeRelevanceFilter(coordinator: inference)))
  }

  var body: some Scene {
    WindowGroup {
      RootView(
        session: session, audio: audio, records: records, chat: chat, preparation: preparation
      )
      .task {
        await personal.load()
        await records.load()
        await audio.load()
        await chat.load()
        await organizer.setAvailable(scenePhase == .active && !chat.isTemporary)
        await organizer.resume(conversationID: nil)
      }
      .onChange(of: scenePhase) { _, phase in
        lifecycleRevision &+= 1
        let revision = lifecycleRevision
        if phase != .active {
          responsiveness.suspend()
          Task {
            guard revision == lifecycleRevision else { return }
            await organizer.setAvailable(false)
            guard revision == lifecycleRevision else { return }
            if phase == .background || audio.captureState.state == .recording
              || audio.captureState.state == .paused || audio.isProcessing
            {
              await audio.interrupt()
            }
            guard revision == lifecycleRevision else { return }
            await chat.interrupt()
          }
        } else {
          if chat.isGenerating { responsiveness.start() }
          Task {
            guard revision == lifecycleRevision else { return }
            await organizer.setAvailable(!chat.isTemporary)
            guard revision == lifecycleRevision else { return }
            if !chat.isTemporary && !chat.isGenerating {
              await organizer.resume(conversationID: nil)
            }
          }
        }
      }
      .onChange(of: chat.isGenerating) { _, generating in
        if generating {
          let revision = lifecycleRevision
          Task {
            guard revision == lifecycleRevision, scenePhase == .active else { return }
            await organizer.setAvailable(!chat.isTemporary)
          }
          responsiveness.start()
        } else {
          responsiveness.finish(
            cancellationSeconds: chat.lastCancellationSeconds,
            firstUsableTextSeconds: chat.firstUsableTextSeconds)
        }
      }
      .onChange(of: audio.isProcessing) { _, processing in
        if !processing && scenePhase == .active && !chat.isGenerating && !chat.isTemporary {
          Task { await organizer.resume(conversationID: nil) }
        }
      }
      .onChange(of: chat.isTemporary) { _, temporary in
        let revision = lifecycleRevision
        Task {
          guard revision == lifecycleRevision, temporary == chat.isTemporary else { return }
          await organizer.setAvailable(scenePhase == .active && !chat.isTemporary)
          guard revision == lifecycleRevision, temporary == chat.isTemporary else { return }
          if !chat.isTemporary && scenePhase == .active {
            await organizer.resume(conversationID: nil)
          }
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: UIApplication.didReceiveMemoryWarningNotification)
      ) { _ in
        lifecycleRevision &+= 1
        let revision = lifecycleRevision
        Task {
          guard revision == lifecycleRevision else { return }
          await organizer.setAvailable(false)
          await audio.interrupt()
          await chat.interrupt()
        }
      }
      .environment(personal)
      .environment(\.layoutDirection, session.language == .arabic ? .rightToLeft : .leftToRight)
      .environment(\.locale, Locale(identifier: session.language.rawValue))
      .environment(\.chatScrollMeasurement, responsiveness)
      .preferredColorScheme(.dark)
      .tint(MemoryTheme.ink)
    }
  }
}
