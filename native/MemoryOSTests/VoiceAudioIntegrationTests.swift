import AVFoundation
import AudioCore
import AudioPersistence
import ChatCore
import Darwin
import Foundation
import Testing
import WhisperCppTranscription

@testable import MemoryOS

private final class VoiceAudioFixtureBundle: NSObject {}

@MainActor
struct VoiceAudioIntegrationTests {
  @Test func bundledWhisperTranscribesFixtureAndRetryReusesSource() async throws {
    let modelManifest = try #require(
      Bundle.main.url(
        forResource: "model-kind", withExtension: "txt", subdirectory: "SpeechModels"))
    let selectedModel = try String(contentsOf: modelManifest, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(selectedModel == AudioComposition.speechModel.rawValue)
    let bundle = Bundle(for: VoiceAudioFixtureBundle.self)
    let fixture = try #require(
      bundle.url(forResource: "voice-chat", withExtension: "aiff", subdirectory: "Fixtures")
        ?? bundle.url(forResource: "voice-chat", withExtension: "aiff"))
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let workflow = makeWorkflow(root)
    try await workflow.importAudio(url: fixture)
    let recording = try #require(try await workflow.library.snapshot().recordings.first)
    let signal = AudioSignalInspector()
    let bridge = AudioChatTranscriber(
      workflow: workflow, signalCheck: { try await signal.hasSignal(url: $0) })
    let clock = ContinuousClock()
    let start = clock.now
    let transcript = try await bridge.transcribe(recordingID: recording.id)
    let elapsed = start.duration(to: clock.now)
    print(
      "VOICE-FIXTURE: bundled Whisper seconds=\(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)"
    )
    #expect(transcript.recordingID == recording.id)
    #expect(!transcript.passageIDs.isEmpty)
    #expect(transcript.text.localizedCaseInsensitiveContains("study"))
    #expect(transcript.text.localizedCaseInsensitiveContains("notes"))
    let retried = try await bridge.transcribe(recordingID: recording.id)
    #expect(retried == transcript)
    let stored = try await workflow.library.snapshot()
    #expect(stored.transcripts.first?.modelID == AudioComposition.speechModel.modelID)
    #expect(stored.transcripts.count == 1)
    #expect(stored.jobs.count == 1)
    #expect(stored.recordings.first?.sha256 == recording.sha256)
    #expect(transcript.passageIDs == stored.transcripts.first?.currentPassages.map(\.id))
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    print("VOICE-FIXTURE: process peak resident bytes=\(usage.ru_maxrss)")
  }

  @Test func digitalSilenceCreatesNoSpeechJobAndRetainsRecording() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let silent = root.appending(path: "silence.caf")
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000))
    buffer.frameLength = 16_000
    let channel = try #require(buffer.floatChannelData?[0])
    channel.initialize(repeating: 0, count: 16_000)
    do {
      let output = try AVAudioFile(forWriting: silent, settings: format.settings)
      try output.write(from: buffer)
    }
    let workflow = makeWorkflow(root.appending(path: "store"))
    try await workflow.importAudio(url: silent)
    let recording = try #require(try await workflow.library.snapshot().recordings.first)
    let signal = AudioSignalInspector()
    let bridge = AudioChatTranscriber(
      workflow: workflow, signalCheck: { try await signal.hasSignal(url: $0) })
    await #expect(throws: VoiceFailure.noSpeech) {
      try await bridge.transcribe(recordingID: recording.id)
    }
    let stored = try await workflow.library.snapshot()
    #expect(stored.jobs.isEmpty)
    #expect(stored.transcripts.isEmpty)
    #expect(stored.recordings.first?.sha256 == recording.sha256)
  }

  private func makeWorkflow(_ root: URL) -> AudioWorkflow {
    AudioWorkflow(
      library: AudioLibrary(
        repository: FileAudioRepository(directory: root.appending(path: "audio"))),
      capture: AudioCaptureUseCases(
        device: AppleAudioCapture(), inspector: AppleAudioFileInspector()),
      providers: [WhisperCppTranscriber(model: AudioComposition.speechModel)],
      models: FileAudioModelStore(
        directory: root.appending(path: "models"),
        bundledDirectory: Bundle.main.resourceURL?.appending(path: "SpeechModels"),
        cppModel: AudioComposition.speechModel))
  }
}
