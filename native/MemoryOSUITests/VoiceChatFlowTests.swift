import XCTest

@MainActor
final class VoiceChatFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testRecordingStartsChatShowsTranscriptAndKeepsFollowup() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["section-recordings"].tap()
    let row = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH 'audio-recording-' AND label CONTAINS %@",
        "Voice chat UI fresh"
      )
    ).firstMatch
    for _ in 0..<5 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    let recordingID = row.identifier.replacingOccurrences(of: "audio-recording-", with: "")
    let start = app.buttons["audio-start-chat-\(recordingID)"]
    XCTAssertTrue(start.isHittable)
    start.tap()
    XCTAssertTrue(app.otherElements["chat-pending-voice"].waitForExistence(timeout: 5))
    let disclosure = app.descendants(matching: .any)
      .matching(identifier: "voice-transcript-disclosure").firstMatch
    XCTAssertTrue(disclosure.waitForExistence(timeout: 45))
    for _ in 0..<6 where !disclosure.isHittable { app.scrollViews["chat-messages"].swipeDown() }
    XCTAssertTrue(app.buttons["chat-regenerate"].waitForExistence(timeout: 45))
    let voiceMessage = app.otherElements.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chat-message-'")
    ).containing(.button, identifier: "voice-play").firstMatch
    XCTAssertTrue(voiceMessage.exists)
    let voiceMessageID = voiceMessage.identifier
    XCTAssertEqual(app.buttons.matching(identifier: "voice-play").count, 1)
    XCTAssertFalse(app.staticTexts["Local AI can make mistakes."].exists)
    XCTAssertFalse(app.buttons["chat-keyboard-done"].exists)
    let transcript = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "please help me organize my study notes")
    ).firstMatch
    XCTAssertFalse(transcript.exists)
    disclosure.tap()
    XCTAssertTrue(transcript.waitForExistence(timeout: 5))
    XCTAssertTrue(transcript.isHittable)
    XCTAssertTrue(transcript.label.lowercased().contains("study"), transcript.label)
    XCTAssertTrue(app.buttons["voice-play"].exists)
    XCTAssertTrue(app.buttons["chat-copy"].firstMatch.exists)
    attach("Voice card with real local transcript and reply", app)

    let input =
      app.textFields["chat-composer"].exists
      ? app.textFields["chat-composer"] : app.textViews["chat-composer"]
    input.tap()
    let followup = "Summarize that in one short sentence. Ref \(UUID().uuidString.prefix(6))."
    input.typeText(followup)
    app.buttons["chat-send"].tap()
    if app.keyboards.firstMatch.exists { app.scrollViews["chat-messages"].tap() }
    XCTAssertTrue(app.buttons["chat-regenerate"].waitForExistence(timeout: 45))
    XCTAssertFalse(app.staticTexts["chat-error"].exists)
    XCTAssertTrue(app.staticTexts[followup].exists)
    app.terminate()
    app.launch()
    app.buttons["open-menu"].tap()
    let saved = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'sidebar-chat-' AND label CONTAINS[c] %@", "study")
    ).firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    saved.tap()
    XCTAssertTrue(
      app.staticTexts[followup].waitForExistence(timeout: 5))
    for _ in 0..<5 where !app.otherElements[voiceMessageID].exists {
      app.scrollViews["chat-messages"].swipeDown()
    }
    XCTAssertTrue(app.otherElements[voiceMessageID].exists)
    attach("Reopened voice conversation retains follow-up", app)
  }

  private func attach(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
