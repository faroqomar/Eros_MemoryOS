import AudioCore
import AudioPersistence
import Foundation
import XCTest

@testable import MemoryOS

/// Seeds only a fictional test recording, so UI tests exercise the real speech/chat engines.
final class VoiceChatFixtureTests: XCTestCase {
  func testPrepareFictionalRecordingForUI() async throws {
    let fixture = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "voice-chat", withExtension: "aiff"))
    let library = AudioLibrary(
      repository: FileAudioRepository(
        directory: URL.applicationSupportDirectory.appending(path: "AudioLibrary")))
    let modelName = await AudioComposition.speechModel.rawValue
    let title = "Voice chat UI fresh \(modelName) \(UUID().uuidString)"
    let details = try await AppleAudioFileInspector().inspect(url: fixture)
    let recording = try await library.importAudio(
      from: fixture, title: title,
      durationSeconds: details.durationSeconds)
    XCTAssertEqual(recording.state, .saved)
    XCTAssertNotNil(recording.sha256)
  }
}
