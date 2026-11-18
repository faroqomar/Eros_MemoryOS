import XCTest

@MainActor final class PersonalMemoryFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testGreetingRemainsConversationWithoutClarification() {
    let app = XCUIApplication()
    app.launch()
    let openChat = app.buttons["capture-open-chat"]
    if openChat.waitForExistence(timeout: 5) { openChat.tap() } else { route("chat", app) }
    app.buttons["new-chat"].tap()
    let composer = field("chat-composer", app)
    XCTAssertTrue(composer.waitForExistence(timeout: 5))
    composer.tap()
    composer.typeText("Hi")
    app.buttons["chat-send"].tap()
    let meaning = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "clarify-"))
      .firstMatch
    XCTAssertFalse(meaning.waitForExistence(timeout: 3))
    if app.buttons["chat-stop"].exists { app.buttons["chat-stop"].tap() }
    route("memories", app)
    let original = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hi"))
      .firstMatch
    reveal(original, app)
    XCTAssertTrue(original.waitForExistence(timeout: 8))
    original.tap()
    XCTAssertTrue(app.staticTexts["personal-original"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["personal-original"].label, "Hi")
    XCTAssertTrue(app.staticTexts["No derived memory from this source."].exists)
    XCTAssertFalse(app.staticTexts["Unanswered"].exists)
  }

  func testSpecificClarificationCanBeSkippedWithOriginalPreservedOnRelaunch() throws {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    app.buttons["new-chat"].tap()
    let text = "Maybe Cedar \(UUID().uuidString.prefix(6)) should close"
    let composer = field("chat-composer", app)
    XCTAssertTrue(composer.waitForExistence(timeout: 5))
    composer.tap()
    composer.typeText(text)
    app.buttons["chat-send"].tap()
    if app.staticTexts["automatic-memory-unavailable"].waitForExistence(timeout: 3) {
      throw XCTSkip("No model/prompt has passed the independent automatic-memory quality gate.")
    }
    let question = app.staticTexts["personal-clarification-question"]
    XCTAssertTrue(question.waitForExistence(timeout: 90))
    XCTAssertFalse(question.label.isEmpty)
    XCTAssertTrue(field("personal-clarification-answer", app).exists)
    XCTAssertTrue(app.buttons["save-personal-clarification"].exists)
    app.buttons["skip-personal-clarification"].tap()
    XCTAssertFalse(question.waitForExistence(timeout: 2))
    route("memories", app)
    let original = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    reveal(original, app)
    XCTAssertTrue(original.waitForExistence(timeout: 8))
    original.tap()
    XCTAssertEqual(app.staticTexts["personal-original"].label, text)
    XCTAssertTrue(app.staticTexts["No derived memory from this source."].exists)
    app.terminate()
    app.launch()
    route("memories", app)
    reveal(original, app)
    XCTAssertTrue(original.waitForExistence(timeout: 8))
    original.tap()
    XCTAssertEqual(app.staticTexts["personal-original"].label, text)
    XCTAssertFalse(question.exists)
  }

  func testPersonProfileOptionalAnswerAndConfirmedCorrection() {
    let app = XCUIApplication()
    app.launch()
    route("profiles", app)
    app.buttons["add-personal-profile"].tap()
    let name = "Mira \(UUID().uuidString.prefix(6))"
    let nameField = app.textFields["personal-profile-name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    nameField.tap()
    nameField.typeText(name)
    app.buttons["save-personal-profile"].tap()
    XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    app.staticTexts[name].tap()
    app.buttons["profile-add-information"].tap()
    let input = field("personal-information-text", app)
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.tap()
    input.typeText("Mira prefers email")
    app.buttons["save-personal-information"].tap()
    XCTAssertTrue(app.staticTexts["Mira prefers email"].waitForExistence(timeout: 5))
    app.staticTexts["Mira prefers email"].tap()
    app.buttons["edit-personal-entry"].tap()
    let correction = field("personal-correction-text", app)
    XCTAssertTrue(correction.waitForExistence(timeout: 5))
    correction.tap()
    correction.press(forDuration: 1.2)
    let selectAll = app.menuItems["Select All"]
    if selectAll.waitForExistence(timeout: 2) {
      selectAll.tap()
    } else {
      correction.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    }
    correction.typeText("Mira prefers calls")
    XCTAssertEqual(correction.value as? String, "Mira prefers calls")
    app.buttons["save-personal-correction"].tap()
    XCTAssertTrue(app.buttons["Confirm correction"].waitForExistence(timeout: 3))
    app.buttons["Confirm correction"].tap()
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Mira prefers calls"),
      object: app.staticTexts["personal-entry-text"])
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    XCTAssertEqual(app.staticTexts["personal-entry-text"].label, "Mira prefers calls")
    XCTAssertTrue(app.staticTexts["Owner report\nMira prefers email"].exists)
  }

  func testTemporaryDraftSurvivesNavigationButNotProcessExit() {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    app.buttons["chat-header-options"].tap()
    app.buttons["start-temporary-chat"].tap()
    XCTAssertTrue(app.staticTexts["temporary-chat-banner"].waitForExistence(timeout: 5))
    let secret = "Fictional private draft \(UUID().uuidString)"
    let composer = field("chat-composer", app)
    composer.tap()
    composer.typeText(secret)
    app.scrollViews["chat-messages"].tap()
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertEqual(field("chat-composer", app).value as? String, secret)
    route("profiles", app)
    app.buttons["open-menu"].tap()
    app.buttons["resume-temporary-chat"].tap()
    XCTAssertEqual(field("chat-composer", app).value as? String, secret)
    app.terminate()
    app.launch()
    route("chat", app)
    XCTAssertFalse(app.staticTexts["temporary-chat-banner"].exists)
    XCTAssertNotEqual(field("chat-composer", app).value as? String, secret)
    app.buttons["chat-header-options"].tap()
    app.buttons["start-temporary-chat"].tap()
    XCTAssertTrue(app.buttons["end-temporary-chat"].waitForExistence(timeout: 5))
    app.buttons["end-temporary-chat"].tap()
    XCTAssertFalse(app.staticTexts["temporary-chat-banner"].exists)
  }

  func testArabicOptionalGoalAtLargeText() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
    ]
    app.launch()
    route("settings", app)
    let language = app.buttons["language-picker"]
    for _ in 0..<6 where !language.isHittable { app.swipeUp() }
    XCTAssertTrue(language.isHittable)
    language.tap()
    app.buttons["العربية"].tap()
    route("profiles", app)
    XCTAssertTrue(app.staticTexts["أنت"].waitForExistence(timeout: 5))
    app.staticTexts["أنت"].tap()
    let question = app.buttons["ما الذي يهمك الآن؟"]
    for _ in 0..<5 where !question.isHittable { app.swipeUp() }
    XCTAssertTrue(question.isHittable)
    question.tap()
    XCTAssertTrue(app.staticTexts["profile-question-priority"].waitForExistence(timeout: 5))
    let input = field("personal-information-text", app)
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.tap()
    let goal = "أريد تنظيم مشروع الأرز " + String(UUID().uuidString.prefix(6))
    input.typeText(goal)
    let save = app.buttons["save-personal-information"]
    for _ in 0..<4 where !save.isHittable { app.swipeUp() }
    save.tap()
    let saved = app.staticTexts[goal]
    for _ in 0..<5 where !saved.isHittable { app.swipeDown() }
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    saved.tap()
    XCTAssertTrue(app.staticTexts["هدف"].waitForExistence(timeout: 5))
  }

  // Requires the existing VoiceChatFixtureTests fixture; never opens the microphone.
  func testSavedFictionalAudioUsesNormalChatWhilePrivateDraftSurvives() {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    app.buttons["chat-header-options"].tap()
    app.buttons["start-temporary-chat"].tap()
    XCTAssertTrue(app.staticTexts["temporary-chat-banner"].waitForExistence(timeout: 5))
    let privateDraft = "Fictional private buffer " + String(UUID().uuidString.prefix(6))
    let composer = field("chat-composer", app)
    composer.tap()
    composer.typeText(privateDraft)
    app.scrollViews["chat-messages"].tap()
    route("recordings", app)
    let recording = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH 'audio-recording-' AND label CONTAINS %@",
        "Voice chat UI fresh")
    ).firstMatch
    for _ in 0..<6 where !recording.isHittable { app.swipeUp() }
    XCTAssertTrue(recording.isHittable)
    let id = recording.identifier.replacingOccurrences(of: "audio-recording-", with: "")
    let start = app.buttons["audio-start-chat-\(id)"]
    XCTAssertTrue(start.isHittable)
    start.tap()
    let pending = app.otherElements["chat-pending-voice"]
    if !pending.waitForExistence(timeout: 5) {
      // Reusing a saved recording reopens its existing completed voice conversation.
      // The public playback control proves the completed voice route. The package
      // regression owns exact recording IDs; nested card/text IDs are not exposed here.
      XCTAssertTrue(app.buttons["voice-play"].firstMatch.waitForExistence(timeout: 5))
    }
    XCTAssertFalse(app.staticTexts["temporary-chat-banner"].exists)
    let transcriptionCancel = app.buttons["voice-transcription-cancel"]
    if transcriptionCancel.waitForExistence(timeout: 3) {
      let cancellationStart = ContinuousClock.now
      transcriptionCancel.tap()
      let acknowledged = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == false"), object: transcriptionCancel)
      XCTAssertEqual(XCTWaiter.wait(for: [acknowledged], timeout: 10), .completed)
      let acknowledgement = cancellationStart.duration(to: .now)
      let acknowledgementSeconds =
        Double(acknowledgement.components.seconds)
        + Double(acknowledgement.components.attoseconds) / 1e18
      let finishedControl = app.buttons.matching(
        NSPredicate(format: "identifier IN %@", ["voice-transcription-retry", "chat-regenerate"])
      ).firstMatch
      let joined = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == true"), object: finishedControl)
      XCTAssertEqual(
        XCTWaiter.wait(for: [joined], timeout: max(0, 10 - acknowledgementSeconds)), .completed)
      let completion = cancellationStart.duration(to: .now)
      let completionSeconds =
        Double(completion.components.seconds)
        + Double(completion.components.attoseconds) / 1e18
      XCTAssertLessThanOrEqual(completionSeconds, 10)
      XCTAssertFalse(app.staticTexts["voice-transcription-stopping"].exists)
      XCTAssertFalse(app.buttons["chat-stop"].exists)
      if app.buttons["voice-transcription-retry"].exists {
        let failure = app.staticTexts["voice-transcription-error"].label
        XCTAssertTrue(failure.contains("stopped") || failure.contains("توقف"))
      }
      print(
        "MEMORYOS_AUDIO_CANCEL acknowledgement_s=\(acknowledgementSeconds) join_s=\(completionSeconds)"
      )
    } else {
      let stop = app.buttons["chat-stop"]
      if stop.exists {
        stop.tap()
        let cancelled = XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "exists == false"), object: stop)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 10), .completed)
      }
    }
    app.buttons["open-menu"].tap()
    let resume = app.buttons["resume-temporary-chat"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()
    XCTAssertTrue(app.staticTexts["temporary-chat-banner"].waitForExistence(timeout: 8))
    XCTAssertEqual(field("chat-composer", app).value as? String, privateDraft)
    app.buttons["end-temporary-chat"].tap()
  }

  private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
    for _ in 0..<20 {
      if element.exists && element.isHittable { return }
      app.collectionViews["personal-memory-list"].swipeUp()
    }
  }

  private func route(_ section: String, _ app: XCUIApplication) {
    let menu = app.buttons["open-menu"]
    XCTAssertTrue(menu.waitForExistence(timeout: 5))
    menu.tap()
    let destination = app.buttons["section-\(section == "chat" ? "capture" : section)"]
    XCTAssertTrue(destination.waitForExistence(timeout: 3))
    destination.tap()
    if section == "chat" {
      let open = app.buttons["capture-open-chat"]
      XCTAssertTrue(open.waitForExistence(timeout: 5))
      open.tap()
    }
  }
  private func field(_ id: String, _ app: XCUIApplication) -> XCUIElement {
    app.textFields[id].exists ? app.textFields[id] : app.textViews[id]
  }
}
