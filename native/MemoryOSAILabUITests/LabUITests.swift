import XCTest

@MainActor
final class LabUITests: XCTestCase {
  private func openLab() -> XCUIApplication {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.navigationBars["Local AI Lab"].waitForExistence(timeout: 10))
    return app
  }

  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<30 {
      if element.exists && element.isHittable { return }
      app.swipeUp()
    }
    XCTFail("The expected lab control did not become reachable.")
  }

  private func audit(_ app: XCUIApplication) throws {
    try app.performAccessibilityAudit { issue in
      print("AUDIT: \(issue.compactDescription); \(issue.detailedDescription)")
      if let element = issue.element {
        print("AUDIT ELEMENT: \(element.label); \(element.identifier); \(element.frame)")
      } else {
        print("AUDIT ELEMENT: unavailable")
      }
      return false  // Report each issue. Do not suppress unresolved diagnostics.
    }
  }

  func testControlResultsAndExportPickerCancellation() {
    let app = openLab()
    let run = app.buttons["run-evaluation"]
    reveal(run, in: app)
    run.tap()
    let identity = app.staticTexts["source-identity"]
    reveal(identity, in: app)
    XCTAssertTrue(identity.label.contains("Source:"))
    let export = app.buttons["export-report"]
    reveal(export, in: app)
    export.tap()
    XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(export.waitForExistence(timeout: 10))
  }

  func testUnsupportedMLXReportsAnExplicitReason() {
    let app = openLab()
    let candidate = app.buttons["mlx-qwen"]
    reveal(candidate, in: app)
    candidate.tap()
    let run = app.buttons["run-evaluation"]
    reveal(run, in: app)
    run.tap()
    let unavailable = app.staticTexts[
      "Text generation is unavailable for this run. See the recorded issue below."]
    reveal(unavailable, in: app)
    XCTAssertTrue(unavailable.exists)
  }

  func testEnglishConfigurationAccessibility() throws {
    let app = openLab()
    try audit(app)
  }

  func testArabicConfigurationAccessibility() throws {
    let app = openLab()
    // SwiftUI exposes a labelled wrapper plus its inner native switch. Tap
    // the visible control's center instead of XCTest's inferred activation point.
    let languageSwitch = app.switches.element(boundBy: 1)
    XCTAssertTrue(languageSwitch.isHittable)
    languageSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertEqual(languageSwitch.value as? String, "1")
    XCTAssertTrue(app.navigationBars["مختبر الذكاء المحلي"].waitForExistence(timeout: 5))
    try audit(app)
  }
}
