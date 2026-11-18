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
    replaceText(composer, with: original, app: app)
    app.buttons["save-thought"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons["OK"].tap()
    app.buttons["your-memories"].tap()
    app.segmentedControls.buttons["Saved records"].tap()
    reveal(app.buttons["add-local-record"], app: app)
    app.buttons["add-local-record"].tap()
    let editor = app.textViews["local-record-editor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap()
    editor.typeText(person)
    app.buttons["save-local-edit"].tap()
    reveal(app.staticTexts[person], app: app, down: true)
    XCTAssertTrue(app.staticTexts[person].waitForExistence(timeout: 5))
    app.staticTexts[original].tap()
    app.buttons["correct-local-record"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    replaceText(editor, with: corrected, app: app)
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
    app.segmentedControls.buttons["Saved records"].tap()
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

  private func replaceText(_ editor: XCUIElement, with text: String, app: XCUIApplication) {
    editor.tap()
    editor.press(forDuration: 1.2)
    if app.menuItems["Select All"].waitForExistence(timeout: 1) {
      app.menuItems["Select All"].tap()
    } else if app.buttons["Select All"].exists {
      app.buttons["Select All"].tap()
    } else {
      editor.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    }
    editor.typeText(text)
    XCTAssertEqual(editor.value as? String, text)
  }

  private func reveal(_ element: XCUIElement, app: XCUIApplication, down: Bool = false) {
    for _ in 0..<12 where !element.isHittable { if down { app.swipeDown() } else { app.swipeUp() } }
    XCTAssertTrue(element.isHittable)
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
