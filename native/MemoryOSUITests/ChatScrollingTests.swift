import XCTest

@MainActor
final class ChatScrollingTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testManualReadingAndJumpToLatest() {
    let (app, marker) = openLongReply()
    let scroll = app.scrollViews["chat-messages"]
    scroll.swipeDown(velocity: .slow)
    let latest = app.buttons["jump-to-latest"]
    XCTAssertTrue(latest.waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Reading older messages with Latest control"
    attachment.lifetime = .keepAlways
    add(attachment)
    latest.tap()
    XCTAssertTrue(app.buttons["chat-retry"].isHittable || app.buttons["chat-regenerate"].isHittable)
    app.buttons["open-menu"].tap()
    app.buttons["section-capture"].tap()
    app.descendants(matching: .any).matching(identifier: "chat-header-options").firstMatch.tap()
    app.buttons["open-chat-history"].tap()
    let savedChat = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH 'saved-chat-' AND label CONTAINS %@",
        marker)
    ).firstMatch
    XCTAssertTrue(savedChat.waitForExistence(timeout: 5))
    savedChat.tap()
    XCTAssertTrue(app.buttons["chat-retry"].isHittable || app.buttons["chat-regenerate"].isHittable)
  }

  func testNativeScrollPerformance() {
    let (app, _) = openLongReply()
    let options = XCTMeasureOptions()
    options.iterationCount = 3
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
      app.scrollViews["chat-messages"].swipeDown(velocity: .slow)
      app.scrollViews["chat-messages"].swipeUp(velocity: .slow)
    }
  }

  private func openLongReply() -> (XCUIApplication, String) {
    let app = XCUIApplication()
    let marker = "Scroll \(String(UUID().uuidString.prefix(8)))"
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["sidebar-new-chat"].tap()
    let composer =
      app.textFields["chat-composer"].exists
      ? app.textFields["chat-composer"] : app.textViews["chat-composer"]
    composer.tap()
    composer.typeText(
      "\(marker). Give a numbered list of 100 single English words, one word on each line.")
    app.buttons["chat-send"].tap()
    if app.keyboards.firstMatch.exists { app.scrollViews["chat-messages"].tap() }
    XCTAssertTrue(app.buttons["chat-send"].waitForExistence(timeout: 45))
    if app.staticTexts["chat-error"].exists {
      XCTAssertTrue(app.staticTexts["chat-error"].label.contains("256"))
      app.buttons["Dismiss"].tap()
    }
    return (app, marker)
  }
}
