import XCTest

@MainActor
final class ChatFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testHomeStartsSeparateChatsAndHistoryKeepsFollowups() {
    let app = XCUIApplication()
    app.launch()
    let marker = String(UUID().uuidString.prefix(8))
    let first = "Orchid \(marker). Reply with OK."
    let followup = "Continue Orchid \(marker). Reply with OK."
    let second = "Cedar \(marker). Reply with OK."

    sendFromHome(first, app)
    waitForReply(app)
    send(followup, app)
    waitForReply(app)
    XCTAssertTrue(app.staticTexts[first].exists)
    XCTAssertTrue(app.staticTexts[followup].exists)

    // Home must reset even while this conversation is embedded in Capture.
    route("capture", app)
    XCTAssertTrue(homeComposer(app).waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts[first].exists)
    sendFromHome(second, app)
    waitForReply(app)
    XCTAssertTrue(app.staticTexts[second].exists)
    XCTAssertFalse(app.staticTexts[first].exists)
    XCTAssertFalse(app.staticTexts[followup].exists)

    app.buttons["open-menu"].tap()
    let search = app.textFields["sidebar-chat-search"]
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("Orchid \(marker)")
    let oldChat = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "sidebar-chat-",
        "Orchid \(marker)"
      )
    ).firstMatch
    XCTAssertTrue(oldChat.waitForExistence(timeout: 5))
    oldChat.tap()
    XCTAssertTrue(app.staticTexts[first].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[followup].exists)
    XCTAssertFalse(app.staticTexts[second].exists)
    send("Reopened Orchid \(marker). Reply with OK.", app)
    waitForReply(app)
    XCTAssertTrue(app.staticTexts[first].exists)
    XCTAssertTrue(app.staticTexts[followup].exists)
    attach("Separate Home chats and reopened follow-ups", app)
  }

  func testRealReplyFollowupAndDraftRelaunch() {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    XCTAssertTrue(app.buttons["new-chat"].waitForExistence(timeout: 5))
    app.buttons["new-chat"].tap()
    send("My fictional name is Mira. Reply with only my name.", app)
    waitForReply(app)
    XCTAssertTrue(
      latestReply(app).staticTexts.matching(
        NSPredicate(format: "label CONTAINS[c] %@", "Mira")
      ).firstMatch.exists)
    send("What is my name? Reply with just the name.", app)
    waitForReply(app)
    XCTAssertTrue(app.buttons["chat-regenerate"].exists)
    XCTAssertTrue(
      latestReply(app).staticTexts.matching(
        NSPredicate(format: "label CONTAINS[c] %@", "Mira")
      ).firstMatch.exists)
    let field = composer(app)
    field.tap()
    field.typeText("A draft kept after relaunch\nSecond line")
    app.scrollViews["chat-messages"].tap()
    app.terminate()
    app.launch()
    app.buttons["open-menu"].tap()
    let saved = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "sidebar-chat-",
        "My fictional name is Mira"
      )
    ).firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    saved.tap()
    XCTAssertTrue(composer(app).waitForExistence(timeout: 5))
    XCTAssertEqual(composer(app).value as? String, "A draft kept after relaunch\nSecond line")
    attach("English conversation and restored draft", app)
  }

  func testStopPreservesPartialAndRegenerateDoesNotDuplicate() {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    app.buttons["new-chat"].tap()
    send("Write a long numbered list of 100 simple English words, one on each line.", app)
    XCTAssertTrue(app.buttons["chat-stop"].waitForExistence(timeout: 5))
    // Copy appears only when the assistant has emitted nonempty text.
    XCTAssertTrue(app.buttons["chat-copy"].waitForExistence(timeout: 5))
    app.buttons["chat-stop"].tap()
    XCTAssertTrue(app.buttons["chat-send"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.buttons["chat-retry"].exists)
    XCTAssertTrue(app.buttons["chat-copy"].exists)
    XCTAssertTrue(app.staticTexts["Stopped · Partial reply retained"].exists)
    let replyID = app.otherElements.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "chat-message-")
    ).allElementsBoundByIndex.last?.identifier
    XCTAssertNotNil(replyID)
    app.buttons["chat-retry"].tap()
    waitForReply(app, allowsOutputLimit: true)
    XCTAssertEqual(
      app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chat-message-"))
        .allElementsBoundByIndex.last?.identifier, replyID)
    attach("Stopped and retried reply", app)
  }

  func testArabicChatAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    route("settings", app)
    app.buttons["language-picker"].tap()
    app.buttons["العربية"].tap()
    route("chat", app)
    app.buttons["new-chat"].tap()
    send("اسمي علي من بغداد. رد باسمي فقط.", app)
    waitForReply(app)
    attach("Arabic RTL local conversation", app)
    try app.performAccessibilityAudit(for: [
      .contrast, .dynamicType, .textClipped, .hitRegion, .sufficientElementDescription, .trait,
    ]) { issue in
      print(
        "CHAT-AUDIT: \(issue.detailedDescription) | \(issue.element?.label ?? "unknown") | \(issue.element?.frame.debugDescription ?? "unavailable")"
      )
      return false
    }
  }

  @available(iOS 27.0, *)
  func testVoiceOverChatControls() throws {
    let app = XCUIApplication()
    app.launch()
    route("chat", app)
    app.buttons["new-chat"].tap()
    let voiceOver = XCUIDevice.shared.voiceOverService
    let wasEnabled = voiceOver.isEnabled
    defer { if !wasEnabled { try? voiceOver.disable() } }
    try voiceOver.enable()
    var utterances: [String] = []
    for _ in 0..<24 {
      utterances.append(try voiceOver.moveForward().utterance)
      if utterances.contains(where: { $0.contains("Message local AI") }) { break }
    }
    XCTAssertTrue(
      utterances.contains(where: { $0.contains("Message local AI") }),
      utterances.joined(separator: " | "))
    let evidence = XCTAttachment(string: utterances.joined(separator: "\n"))
    evidence.name = "VoiceOver chat navigation speech"
    evidence.lifetime = .keepAlways
    add(evidence)
  }

  private func latestReply(_ app: XCUIApplication) -> XCUIElement {
    app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chat-message-"))
      .allElementsBoundByIndex.last!
  }

  private func route(_ section: String, _ app: XCUIApplication) {
    app.buttons["open-menu"].tap()
    app.buttons[section == "chat" ? "sidebar-new-chat" : "section-\(section)"].tap()
  }
  private func homeComposer(_ app: XCUIApplication) -> XCUIElement {
    app.textFields["capture-composer"].exists
      ? app.textFields["capture-composer"] : app.textViews["capture-composer"]
  }
  private func sendFromHome(_ text: String, _ app: XCUIApplication) {
    let field = homeComposer(app)
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(text)
    app.buttons["capture-send"].tap()
    XCTAssertTrue(app.buttons["capture-return-to-recording"].waitForExistence(timeout: 5))
  }
  private func composer(_ app: XCUIApplication) -> XCUIElement {
    app.textFields["chat-composer"].exists
      ? app.textFields["chat-composer"] : app.textViews["chat-composer"]
  }
  private func send(_ text: String, _ app: XCUIApplication) {
    let field = composer(app)
    field.tap()
    field.typeText(text)
    app.buttons["chat-send"].tap()
    if app.keyboards.firstMatch.exists { app.scrollViews["chat-messages"].tap() }
  }
  private func waitForReply(_ app: XCUIApplication, allowsOutputLimit: Bool = false) {
    XCTAssertTrue(app.buttons["chat-send"].waitForExistence(timeout: 30))
    if allowsOutputLimit && app.staticTexts["chat-error"].exists {
      XCTAssertTrue(app.staticTexts["chat-error"].label.contains("256"))
    } else {
      XCTAssertFalse(app.staticTexts["chat-error"].exists, app.staticTexts["chat-error"].label)
    }
  }
  private func attach(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
