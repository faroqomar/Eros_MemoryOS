import XCTest

@MainActor
final class ChatExtendedFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testMemorySourcesReflectCorrectionsAndTrashWithoutChangingOriginals() {
    let app = XCUIApplication()
    app.launch()
    let name =
      "FictionalZain" + String(UUID().uuidString.prefix(8)).replacingOccurrences(of: "-", with: "")
    let original = "\(name) meets on Monday."
    let corrected = "\(name) meets on Friday."
    let question = "What about \(name)?"
    let capture = field("capture-composer", in: app)
    XCTAssertTrue(capture.waitForExistence(timeout: 5))
    capture.tap()
    capture.typeText(original)
    app.buttons["send-memory"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons["OK"].tap()

    route("memories", in: app)
    let record = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'local-record-' AND label CONTAINS %@", name)
    ).firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    let recordID = record.identifier
    let sourceID = recordID.replacingOccurrences(of: "local-record-", with: "chat-source-")

    route("chat", in: app)
    app.buttons["new-chat"].tap()
    setMemoryMode(true, in: app)
    send(question, in: app)
    waitForReply(in: app)
    let firstSource = app.buttons[sourceID]
    XCTAssertTrue(firstSource.waitForExistence(timeout: 5))
    firstSource.tap()
    XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
    attach("Original app-owned source opened from chat", app)
    app.buttons["chat-source-done"].tap()

    route("memories", in: app)
    app.buttons[recordID].tap()
    reveal(app.buttons["correct-local-record"], in: app)
    app.buttons["correct-local-record"].tap()
    let editor = app.textViews["local-record-editor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    replaceText(in: editor, with: corrected, app: app)
    app.buttons["save-local-edit"].tap()
    XCTAssertTrue(app.staticTexts["local-record-text"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["local-record-text"].label, corrected)
    XCTAssertEqual(app.staticTexts["local-record-original"].label, original)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    route("chat", in: app)
    app.buttons[sourceID].tap()
    XCTAssertTrue(app.staticTexts[corrected].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[original].exists)
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "You corrected this record after this reply.")
      ).firstMatch.exists)
    app.buttons["chat-source-done"].tap()
    send(question, in: app)
    waitForReply(in: app)
    let currentSource = app.buttons.matching(
      NSPredicate(format: "identifier == %@ AND label CONTAINS %@", sourceID, corrected)
    ).firstMatch
    XCTAssertTrue(currentSource.waitForExistence(timeout: 5))
    attach("Later reply retrieves corrected source", app)

    route("memories", in: app)
    app.buttons[recordID].tap()
    XCTAssertEqual(app.staticTexts["local-record-original"].label, original)
    reveal(app.buttons["trash-local-record"], in: app)
    app.buttons["trash-local-record"].tap()
    XCTAssertTrue(app.switches["show-trash"].waitForExistence(timeout: 5))
    route("chat", in: app)
    currentSource.tap()
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "This source is in Trash or is unavailable.")
      ).firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.scrollViews["chat-current-source"].staticTexts[corrected].exists)
    app.buttons["chat-source-done"].tap()
    send(question, in: app)
    let error = app.staticTexts["chat-error"]
    XCTAssertTrue(error.waitForExistence(timeout: 5))
    XCTAssertTrue(error.label.contains("No matching saved memory was found"), error.label)
    XCTAssertTrue(error.label.contains("No memory answer was generated"), error.label)
    XCTAssertEqual(field("chat-composer", in: app).value as? String, question)
    XCTAssertFalse(app.buttons["chat-stop"].exists)
    attach("Trash exclusion preserves the unsent memory question", app)
  }

  func testSavedChatRenameReopenAndDeleteSurviveRelaunch() {
    let app = XCUIApplication()
    app.launch()
    route("chat", in: app)
    app.buttons["new-chat"].tap()
    let suffix = String(UUID().uuidString.prefix(8))
    let prompt = "Fictional \(suffix). Say OK."
    let title = "Saved fictional chat \(suffix)"
    let draft = "Unsent thought \(suffix)\nSecond line"
    send(prompt, in: app)
    waitForReply(in: app)
    let composer = field("chat-composer", in: app)
    composer.tap()
    composer.typeText(draft)
    dismissKeyboard(in: app)
    app.buttons["chat-history"].tap()
    let row = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'saved-chat-' AND label CONTAINS %@", suffix)
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    let chatID = row.identifier
    app.buttons["Chat actions: \(prompt)"].tap()
    app.buttons["Rename"].tap()
    let nameField = app.textFields["chat-rename-title"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 3))
    app.buttons["clear-chat-name"].tap()
    nameField.tap()
    nameField.typeText(title)
    XCTAssertEqual(nameField.value as? String, title)
    app.buttons["save-chat-name"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", chatID, title))
        .firstMatch.waitForExistence(timeout: 5))
    app.buttons["chat-history-done"].tap()
    app.buttons["new-chat"].tap()
    let otherDraft = "Keep this other draft \(suffix)"
    field("chat-composer", in: app).tap()
    field("chat-composer", in: app).typeText(otherDraft)
    dismissKeyboard(in: app)
    app.buttons["chat-history"].tap()
    app.buttons[chatID].tap()
    XCTAssertEqual(field("chat-composer", in: app).value as? String, draft)
    XCTAssertTrue(app.staticTexts[prompt].exists)
    app.terminate()
    app.launch()
    route("chat", in: app)
    XCTAssertEqual(field("chat-composer", in: app).value as? String, draft)
    app.buttons["chat-history"].tap()
    XCTAssertTrue(app.buttons[chatID].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons[chatID].label, title)
    app.buttons["Chat actions: \(title)"].tap()
    app.buttons["Delete"].tap()
    app.buttons["Delete chat"].tap()
    waitForDisappearance(app.buttons[chatID])
    attach("Renamed conversation deleted while other chat remains", app)
    app.buttons["chat-history-done"].tap()
    XCTAssertEqual(field("chat-composer", in: app).value as? String, otherDraft)
    app.terminate()
    app.launch()
    route("chat", in: app)
    app.buttons["chat-history"].tap()
    XCTAssertFalse(app.buttons[chatID].exists)
    app.buttons["chat-history-done"].tap()
    XCTAssertEqual(field("chat-composer", in: app).value as? String, otherDraft)
  }

  func testEnglishLargeTextKeyboardAndNavigationPreserveDraft() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    route("chat", in: app)
    app.buttons["new-chat"].tap()
    let draft = "Fictional draft \(String(UUID().uuidString.prefix(8)))\nA second line"
    let composer = field("chat-composer", in: app)
    XCTAssertTrue(composer.waitForExistence(timeout: 5))
    composer.tap()
    composer.typeText(draft)
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["chat-send"].isHittable)
    XCTAssertLessThanOrEqual(
      app.buttons["chat-send"].frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
    attach("Large text composer remains above keyboard", app)
    route("capture", in: app)
    XCTAssertFalse(app.buttons["chat-send"].exists)
    route("chat", in: app)
    XCTAssertEqual(field("chat-composer", in: app).value as? String, draft)
    XCTAssertTrue(app.buttons["chat-send"].isEnabled)
    field("chat-composer", in: app).tap()
    dismissKeyboard(in: app)
    XCTAssertTrue(app.buttons["chat-history"].isHittable)
    XCTAssertTrue(app.buttons["new-chat"].isHittable)
    attach("English large text draft restored after navigation", app)
    try app.performAccessibilityAudit(for: [
      .contrast, .dynamicType, .textClipped, .hitRegion, .sufficientElementDescription, .trait,
    ]) { issue in
      print(
        "CHAT-EXTENDED-AUDIT: \(issue.detailedDescription) | \(issue.element?.label ?? "unknown") | \(issue.element?.frame.debugDescription ?? "unavailable")"
      )
      return false
    }
  }

  private func route(_ section: String, in app: XCUIApplication) {
    XCTAssertTrue(app.buttons["open-menu"].waitForExistence(timeout: 5))
    app.buttons["open-menu"].tap()
    app.buttons["section-\(section)"].tap()
  }

  private func field(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.textFields[identifier].exists ? app.textFields[identifier] : app.textViews[identifier]
  }

  private func send(_ text: String, in app: XCUIApplication) {
    let composer = field("chat-composer", in: app)
    composer.tap()
    composer.typeText(text)
    app.buttons["chat-send"].tap()
    dismissKeyboard(in: app)
  }

  private func waitForReply(in app: XCUIApplication) {
    XCTAssertTrue(app.buttons["chat-send"].waitForExistence(timeout: 45))
    XCTAssertFalse(app.staticTexts["chat-error"].exists, app.staticTexts["chat-error"].label)
  }

  private func dismissKeyboard(in app: XCUIApplication) {
    if app.buttons["chat-keyboard-done"].exists { app.buttons["chat-keyboard-done"].tap() }
  }

  private func setMemoryMode(_ enabled: Bool, in app: XCUIApplication) {
    let toggle = app.switches["chat-memory-mode"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    if (toggle.value as? String == "1") != enabled {
      let control = toggle.switches.firstMatch
      if control.exists { control.tap() } else { toggle.tap() }
    }
    XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
  }

  private func replaceText(in editor: XCUIElement, with text: String, app: XCUIApplication) {
    editor.tap()
    let current = editor.value as? String ?? ""
    editor.press(forDuration: 1.2)
    if app.menuItems["Select All"].waitForExistence(timeout: 2) {
      app.menuItems["Select All"].tap()
    } else {
      editor.tap()
      editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
    editor.typeText(text)
  }

  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<5 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable)
  }

  private func waitForDisappearance(_ element: XCUIElement) {
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
  }

  private func attach(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
