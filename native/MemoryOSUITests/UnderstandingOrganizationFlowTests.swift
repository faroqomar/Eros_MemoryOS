import XCTest

/// Uses only fictional records created through public controls. Never opens a microphone or model.
@MainActor final class UnderstandingOrganizationFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testCalendarProjectsSavedBirthdayWithoutScheduling() {
    let app = XCUIApplication()
    app.launch()
    let name = "Fictional Calendar " + String(UUID().uuidString.prefix(6))
    createPerson(name, app)
    app.buttons["workspace-tab-calendar"].tap()
    app.segmentedControls.buttons["Week"].tap()
    let add = app.buttons["calendar-add-birthday"]
    reveal(add, app)
    add.tap()
    let person = app.buttons["birthday-person"]
    XCTAssertTrue(person.waitForExistence(timeout: 5))
    person.tap()
    reveal(app.buttons[name], app)
    app.buttons[name].tap()
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()
    fill("birthday-month", String(calendar.component(.month, from: today)), app)
    fill("birthday-day", String(calendar.component(.day, from: today)), app)
    app.buttons["birthday-save"].tap()
    let result = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "calendar-birthday-", name)
    ).firstMatch
    reveal(result, app)
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    result.tap()
    XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Scheduled annually"].exists)
  }

  func testBirthdayPartialCorrectionExactApprovalAndDisable() {
    let app = XCUIApplication()
    app.launch()
    let name = "Fictional Birthday " + String(UUID().uuidString.prefix(6))
    createPerson(name, app)
    route("birthdays", app)
    app.buttons["birthday-add"].tap()
    app.buttons["birthday-person"].tap()
    // The native picker scrolls when prior fictional people remain in the app.
    reveal(app.buttons[name], app)
    app.buttons[name].tap()
    fill("birthday-month", "3", app)
    app.buttons["birthday-save"].tap()
    let birthday = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "birthday-", name)
    ).firstMatch
    XCTAssertTrue(birthday.waitForExistence(timeout: 5))
    birthday.tap()
    XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["birthday-preview"].isEnabled)
    app.buttons["birthday-correct"].tap()
    fill("birthday-day", "12", app)
    app.buttons["birthday-save"].tap()
    let preview = app.buttons["birthday-preview"]
    reveal(preview, app)
    XCTAssertTrue(preview.isEnabled)
    fill("birthday-zone", "Asia/Baghdad", app)
    preview.tap()
    let approval = app.buttons["birthday-approve"]
    XCTAssertTrue(approval.waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Asia/Baghdad")).firstMatch
        .exists)
    let permissionHandler = addUIInterruptionMonitor(
      withDescription: "Fictional birthday notification permission"
    ) { alert in
      let allow = alert.buttons["Allow"]
      if allow.exists {
        allow.tap()
        return true
      }
      return false
    }
    defer { removeUIInterruptionMonitor(permissionHandler) }
    approval.tap()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allow = springboard.alerts.buttons["Allow"]
    if allow.waitForExistence(timeout: 3) { allow.tap() }
    let status = app.staticTexts["Scheduled annually"]
    XCTAssertTrue(status.waitForExistence(timeout: 8))
    let off = app.buttons["birthday-disable"]
    reveal(off, app)
    off.tap()
    XCTAssertFalse(status.waitForExistence(timeout: 2))
    app.terminate()
    app.launch()
    route("birthdays", app)
    XCTAssertTrue(birthday.waitForExistence(timeout: 5))
    birthday.tap()
    XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Scheduled annually"].exists)
  }

  func testRuleTestApplyUndoAndCustomTabUseRealSources() {
    let app = XCUIApplication()
    app.launch()
    let token = "Fictional Cedar " + String(UUID().uuidString.prefix(6))
    createPerson(token, app)
    app.staticTexts[token].tap()
    app.buttons["profile-add-information"].tap()
    fill("personal-information-text", token + " prefers email", app)
    app.buttons["save-personal-information"].tap()
    XCTAssertTrue(app.staticTexts[token + " prefers email"].waitForExistence(timeout: 5))
    route("organization", app)
    let addRule = app.buttons["organization-rule-add"]
    reveal(addRule, app)
    addRule.tap()
    fill("organization-name", token + " rule", app)
    fill("organization-text", token, app)
    fill("organization-category", "Fictional work", app)
    app.buttons["organization-save"].tap()
    let test = app.buttons["Test " + token + " rule"]
    reveal(test, app)
    XCTAssertTrue(test.waitForExistence(timeout: 5))
    test.tap()
    let apply = app.buttons["organization-apply"]
    XCTAssertTrue(apply.waitForExistence(timeout: 5))
    XCTAssertTrue(apply.isEnabled)
    apply.tap()
    reveal(addRule, app)
    XCTAssertTrue(addRule.waitForExistence(timeout: 5))
    let addView = app.buttons["custom-tab-add"]
    for _ in 0..<8 where !addView.isHittable { app.swipeDown() }
    addView.tap()
    fill("organization-name", token + " tab", app)
    fill("organization-text", token, app)
    app.buttons["organization-save"].tap()
    let tab = app.buttons[token + " tab"]
    XCTAssertTrue(tab.waitForExistence(timeout: 5))
    tab.tap()
    XCTAssertTrue(app.staticTexts[token + " prefers email"].waitForExistence(timeout: 5))
    XCTAssertFalse(
      app.textFields["organization-name"].exists, "Opening a view must not also edit it.")
    XCTAssertTrue(tab.exists, "Opening a view must not also delete it.")
    let undo = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "organization-undo-")
    ).firstMatch
    reveal(undo, app)
    XCTAssertTrue(undo.waitForExistence(timeout: 5))
    XCTAssertTrue(undo.label.contains(token + " rule"))
    let appliedUndo = app.buttons[undo.identifier]
    appliedUndo.tap()
    let removed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: appliedUndo)
    XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
    route("brainMap", app)
    XCTAssertTrue(app.buttons["map-search"].waitForExistence(timeout: 5))
    app.buttons["map-search"].tap()
    fill("memory-search-query", token, app)
    app.buttons["memory-search-submit"].tap()
    let source = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "memory-search-open-")
    ).firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", token)).firstMatch
        .waitForExistence(timeout: 5))
  }

  func testCancelForgettingPreservesSourceAndUndoAfterRelaunch() {
    let app = XCUIApplication()
    app.launch()
    let text = "Fictional cancellation " + String(UUID().uuidString.prefix(8))
    route("memories", app)
    app.buttons["add-personal-information"].tap()
    fill("personal-information-text", text, app)
    app.buttons["save-personal-information"].tap()
    let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    reveal(entry, app)
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    entry.tap()
    XCTAssertTrue(app.staticTexts["personal-entry-text"].waitForExistence(timeout: 5))
    let source = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    source.tap()
    let forget = app.buttons["forget-personal-source"]
    reveal(forget, app)
    forget.tap()
    let cancel = app.alerts.firstMatch.buttons["cancel-forget-personal-source"].firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(
          format: "label CONTAINS %@", "ALL personal-memory undo history"
        )
      ).firstMatch.exists)
    cancel.tap()
    XCTAssertTrue(forget.waitForExistence(timeout: 5))
    app.terminate()
    app.launch()
    route("memories", app)
    reveal(entry, app)
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["personal-undo"].isEnabled)
    // Keep the fictional source. Cleanup must never invoke permanent forgetting.
  }

  private func createPerson(_ name: String, _ app: XCUIApplication) {
    route("profiles", app)
    let add = app.buttons["add-personal-profile"]
    reveal(add, app)
    add.tap()
    fill("personal-profile-name", name, app)
    // Existing-person suggestions can place the form's Save row below the keyboard.
    reveal(app.buttons["save-personal-profile"], app)
    app.buttons["save-personal-profile"].tap()
    let profile = app.staticTexts[name]
    reveal(profile, app)
    XCTAssertTrue(profile.isHittable)
  }
  private func route(_ section: String, _ app: XCUIApplication) {
    let open = app.buttons["open-menu"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()
    let destination = app.buttons["section-" + section]
    reveal(destination, app)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.tap()
  }
  private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
    let dock = app.buttons["workspace-tab-record"]
    for _ in 0..<12 {
      if element.exists && element.isHittable,
        !dock.isHittable || element.frame.midY < dock.frame.minY
      {
        return
      }
      app.swipeUp()
    }
  }
  private func fill(_ id: String, _ value: String, _ app: XCUIApplication) {
    let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    if let current = field.value as? String, !current.isEmpty,
      current != field.placeholderValue
    {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
    field.typeText(value)
  }
}
