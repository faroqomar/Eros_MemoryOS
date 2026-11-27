import XCTest

/// Exercises current personal-memory routes; historical sample-only flows were retired.
@MainActor
final class DemoFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testSearchRecoveryAndSectionState() {
    let app = XCUIApplication()
    app.launch()
    route("profiles", in: app)
    let search = app.textFields["personal-profile-search"]
    search.tap()
    search.typeText("missing person 749AF")
    XCTAssertTrue(app.buttons["clear-personal-search"].waitForExistence(timeout: 3))
    app.buttons["clear-personal-search"].tap()
    XCTAssertTrue(app.staticTexts["You"].exists)
    search.tap()
    search.typeText("You")
    app.buttons["open-menu"].tap()
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    app.buttons["section-projects"].tap()
    route("profiles", in: app)
    XCTAssertEqual(search.value as? String, "You")
    app.staticTexts["You"].tap()
    route("capture", in: app)
    route("profiles", in: app)
    XCTAssertTrue(app.buttons["profile-add-information"].exists)
  }

  func testMenuDismissalPreservesRootAndDetailControls() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["close-menu"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "open-menu").count, 1)
    assertNotHittable(app.buttons["close-menu"])
    route("profiles", in: app)
    app.staticTexts["You"].tap()
    app.buttons["open-menu"].tap()
    app.buttons["close-menu"].tap()
    XCTAssertTrue(app.buttons["profile-add-information"].exists)
    XCTAssertTrue(app.buttons["open-menu"].isHittable)
    assertNotHittable(app.buttons["close-menu"])
  }

  func testEnglishAccessibilityAudits() throws { try auditConnectedScreens(arabic: false) }

  func testArabicAccessibilityAudits() throws { try auditConnectedScreens(arabic: true) }

  private func auditConnectedScreens(arabic: Bool) throws {
    continueAfterFailure = true
    let app = XCUIApplication()
    app.launch()
    if arabic {
      route("settings", in: app)
      app.buttons["language-picker"].tap()
      app.buttons["العربية"].tap()
      route("capture", in: app)
    }
    try auditCategories(in: app)
    app.buttons["open-menu"].tap()
    try auditCategories(in: app)
    app.buttons["section-profiles"].tap()
    try auditCategories(in: app)
    app.staticTexts[arabic ? "أنت" : "You"].tap()
    try auditCategories(in: app)
    for section in ["projects", "birthdays", "brainMap"] {
      route(section, in: app)
      try auditCategories(in: app)
    }
  }

  private func auditCategories(in app: XCUIApplication) throws {
    for (name, category): (String, XCUIAccessibilityAuditType) in [
      ("Contrast", .contrast), ("Dynamic Type", .dynamicType), ("Clipped text", .textClipped),
      ("Hit regions", .hitRegion), ("Descriptions", .sufficientElementDescription),
      ("Traits", .trait), ("Element detection", .elementDetection),
    ] {
      try XCTContext.runActivity(named: name) { _ in
        try app.performAccessibilityAudit(for: category) { issue in
          let element = issue.element
          let target =
            element?.exists == true
            ? "\(element!.identifier) | \(element!.label) | \(element!.frame)"
            : "unresolved element"
          print("AUDIT \(name): \(issue.detailedDescription) | \(target)")
          return false
        }
      }
    }
  }

  private func assertNotHittable(_ element: XCUIElement) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
  }

  private func route(_ section: String, in app: XCUIApplication) {
    app.buttons["open-menu"].tap()
    let destination = app.buttons["section-\(section)"]
    if !destination.isHittable { app.swipeUp() }
    destination.tap()
  }

}
