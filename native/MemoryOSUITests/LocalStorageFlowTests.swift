import XCTest

@MainActor
final class LocalStorageFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testCorrectionLinkAndTrashSurviveRelaunch() throws {
    let app = XCUIApplication()
    app.launch()
    let suffix = String(UUID().uuidString.prefix(6))
    let original = "Local source \(suffix)"
    let corrected = "Corrected source \(suffix)"
    let person = "Fictional person \(suffix)"
    let composer =
      app.textFields["capture-composer"].exists
      ? app.textFields["capture-composer"] : app.textViews["capture-composer"]
    XCTAssertTrue(composer.waitForExistence(timeout: 5))
    composer.tap()
    composer.typeText(original)
    app.buttons["send-memory"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons["OK"].tap()
    app.buttons["your-memories"].tap()
    app.buttons["add-local-record"].tap()
    let editor = app.textViews["local-record-editor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap()
    editor.typeText(person)
    app.buttons["save-local-edit"].tap()
    XCTAssertTrue(app.staticTexts[person].waitForExistence(timeout: 5))
    app.staticTexts[original].tap()
    app.buttons["correct-local-record"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap()
    editor.press(forDuration: 1.2)
    if app.menuItems["Select All"].waitForExistence(timeout: 2) {
      app.menuItems["Select All"].tap()
    } else {
      editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
    }
    editor.typeText(corrected)
    app.buttons["save-local-edit"].tap()
    XCTAssertTrue(app.staticTexts["local-record-text"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["local-record-text"].label, corrected)
    XCTAssertEqual(app.staticTexts["local-record-original"].label, original)
    app.swipeUp()
    app.buttons["link-local-record"].tap()
    app.buttons[person].tap()
    XCTAssertTrue(app.buttons[person].waitForExistence(timeout: 5))
    app.swipeUp()
    app.buttons["trash-local-record"].tap()
    XCTAssertTrue(app.switches["show-trash"].waitForExistence(timeout: 5))
    toggleTrash(in: app)
    XCTAssertTrue(app.staticTexts[corrected].waitForExistence(timeout: 3))
    app.terminate()
    app.launch()
    app.buttons["your-memories"].tap()
    toggleTrash(in: app)
    app.staticTexts[corrected].tap()
    XCTAssertEqual(app.staticTexts["local-record-original"].label, original)
    app.swipeUp()
    app.buttons["recover-local-record"].tap()
    toggleTrash(in: app)
    app.staticTexts[corrected].tap()
    app.swipeUp()
    XCTAssertTrue(app.buttons[person].waitForExistence(timeout: 3))
  }

  private func toggleTrash(in app: XCUIApplication) {
    let row = app.switches["show-trash"]
    let initial = row.value as? String
    let control = row.switches.firstMatch
    if control.exists { control.tap() } else { row.tap() }
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in (row.value as? String) != initial }, object: row)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
  }

}
