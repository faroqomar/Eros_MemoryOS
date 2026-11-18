import XCTest

@MainActor
final class LocalStorageAccessibilityTests: XCTestCase {
  func testEnglishLocalRecordAccessibility() throws { try audit(arabic: false) }
  func testArabicLocalRecordAccessibility() throws { try audit(arabic: true) }

  private func audit(arabic: Bool) throws {
    continueAfterFailure = true
    let app = XCUIApplication()
    app.launch()
    if arabic {
      route("settings", in: app)
      app.buttons["language-picker"].tap()
      app.buttons["العربية"].tap()
      route("capture", in: app)
    }
    let source = "Fictional source \(UUID().uuidString.prefix(5))"
    let composer =
      app.textFields["capture-composer"].exists
      ? app.textFields["capture-composer"] : app.textViews["capture-composer"]
    composer.tap()
    composer.typeText(source)
    app.buttons["send-memory"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons[arabic ? "حسناً" : "OK"].tap()
    app.buttons["your-memories"].tap()
    app.segmentedControls.buttons["Saved records"].tap()
    try screenAudit("Local records", in: app)
    app.staticTexts[source].tap()
    try screenAudit("Local record source", in: app)
    app.buttons["correct-local-record"].tap()
    XCTAssertTrue(app.textViews["local-record-editor"].waitForExistence(timeout: 3))
    try screenAudit("Correction editor", in: app)
  }

  private func screenAudit(_ screen: String, in app: XCUIApplication) throws {
    for (name, type): (String, XCUIAccessibilityAuditType) in [
      ("Contrast", .contrast), ("Dynamic Type", .dynamicType), ("Clipping", .textClipped),
      ("Hit regions", .hitRegion), ("Descriptions", .sufficientElementDescription),
      ("Traits", .trait), ("Detection", .elementDetection),
    ] {
      try XCTContext.runActivity(named: "\(screen): \(name)") { _ in
        try app.performAccessibilityAudit(for: type) { issue in
          let element = issue.element
          let target =
            element?.exists == true
            ? "\(element!.identifier) | \(element!.label) | \(element!.frame)"
            : "unresolved element"
          print("LOCAL-AUDIT \(screen) \(name): \(issue.detailedDescription) | \(target)")
          return false
        }
      }
    }
  }

  private func route(_ section: String, in app: XCUIApplication) {
    app.buttons["open-menu"].tap()
    app.buttons["section-\(section)"].tap()
  }
}
