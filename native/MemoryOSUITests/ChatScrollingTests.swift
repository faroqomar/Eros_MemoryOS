import XCTest

@MainActor
final class ChatScrollingTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testManualReadingAndJumpToLatest() {
    let app = openLongReply()
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
    app.buttons["open-menu"].tap()
    app.buttons["section-chat"].tap()
    XCTAssertTrue(app.buttons["chat-retry"].isHittable || app.buttons["chat-regenerate"].isHittable)
  }

  func testNativeScrollPerformance() {
    let app = openLongReply()
    let options = XCTMeasureOptions()
    options.iterationCount = 3
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
      app.scrollViews["chat-messages"].swipeDown(velocity: .slow)
      app.scrollViews["chat-messages"].swipeUp(velocity: .slow)
    }
  }

  private func openLongReply() -> XCUIApplication {
    let app = XCUIApplication()
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["section-chat"].tap()
    app.buttons["new-chat"].tap()
    let composer =
      app.textFields["chat-composer"].exists
      ? app.textFields["chat-composer"] : app.textViews["chat-composer"]
    composer.tap()
    composer.typeText("Give a numbered list of 100 single English words, one word on each line.")
    app.buttons["chat-send"].tap()
    if app.buttons["chat-keyboard-done"].exists { app.buttons["chat-keyboard-done"].tap() }
    XCTAssertTrue(app.buttons["chat-send"].waitForExistence(timeout: 45))
    if app.staticTexts["chat-error"].exists {
      XCTAssertTrue(app.staticTexts["chat-error"].label.contains("256"))
      app.buttons["Dismiss"].tap()
    }
    return app
  }
}
