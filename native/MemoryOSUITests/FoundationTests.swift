import XCTest

@MainActor
final class FoundationTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testSidebarRoutesAndCloses() {
    let app = XCUIApplication()
    app.launch()
    for (section, title) in [
      ("brainMap", "BrainMap"), ("profiles", "People"), ("projects", "Projects"),
      ("memories", "Memories"), ("birthdays", "Birthdays"), ("settings", "Settings"),
      ("capture", "MemoryOS"),
    ] {
      app.buttons["open-menu"].tap()
      XCTAssertTrue(app.buttons["close-menu"].waitForExistence(timeout: 3))
      app.buttons["section-\(section)"].tap()
      assertNotHittable(app.buttons["close-menu"])
      XCTAssertTrue(app.buttons["open-menu"].isHittable)
      XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
    }
    app.buttons["open-menu"].tap()
    XCTAssertTrue(app.buttons["close-menu"].waitForExistence(timeout: 3))
    app.buttons["close-menu"].tap()
    assertNotHittable(app.buttons["close-menu"])
    XCTAssertTrue(app.buttons["record-preview"].exists)
  }

  func testDemoCaptureAndSessionReset() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertFalse(app.buttons["send-memory"].isEnabled)
    let composer =
      app.textFields["capture-composer"].exists
      ? app.textFields["capture-composer"] : app.textViews["capture-composer"]
    composer.tap()
    composer.typeText("A fictional project thought")
    app.buttons["send-memory"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    app.alerts.buttons["OK"].tap()
    app.buttons["your-memories"].tap()
    XCTAssertTrue(app.staticTexts["A fictional project thought"].waitForExistence(timeout: 3))
    app.terminate()
    app.launch()
    app.buttons["your-memories"].tap()
    XCTAssertFalse(app.staticTexts["A fictional project thought"].exists)
  }

  func testArabicDrawerClosesFullyOutsideTheScreen() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["section-settings"].tap()
    app.buttons["language-picker"].tap()
    app.buttons["العربية"].tap()
    app.buttons["open-menu"].tap()
    app.buttons["section-capture"].tap()
    assertNotHittable(app.buttons["close-menu"])
    XCTAssertTrue(app.buttons["open-menu"].isHittable)
    XCTAssertTrue(app.staticTexts["اضغط للتسجيل"].exists)
    let fullyOutside = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        !app.buttons["section-settings"].frame.intersects(app.frame)
      }, object: nil
    )
    XCTAssertEqual(XCTWaiter.wait(for: [fullyOutside], timeout: 3), .completed)
  }

  func testRecordingExplainsDemoBoundary() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["record-preview"].tap()
    XCTAssertTrue(
      app.alerts.staticTexts[
        "Voice capture comes in a later step. This preview does not use your microphone."
      ].exists)
    app.alerts.buttons["OK"].tap()
    XCTAssertTrue(app.buttons["record-preview"].exists)
  }

  private func assertNotHittable(
    _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
  ) {
    let hidden = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed, file: file, line: line)
  }
}
