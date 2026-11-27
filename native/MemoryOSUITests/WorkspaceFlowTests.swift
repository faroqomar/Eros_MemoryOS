import XCTest

@MainActor
final class WorkspaceFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testWorkspaceRoutesReachExistingFeatures() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["record-audio"].waitForExistence(timeout: 5))
    app.buttons["workspace-tab-brain"].tap()
    XCTAssertTrue(app.staticTexts["Brain"].firstMatch.waitForExistence(timeout: 3))
    app.buttons["workspace-tab-calendar"].tap()
    let period = app.staticTexts["calendar-period"]
    XCTAssertTrue(period.waitForExistence(timeout: 3))
    let originalPeriod = period.label
    app.buttons["calendar-next"].tap()
    XCTAssertNotEqual(period.label, originalPeriod)
    app.buttons["calendar-previous"].tap()
    XCTAssertEqual(period.label, originalPeriod)
    let week = app.segmentedControls.buttons["Week"]
    XCTAssertTrue(week.exists)
    week.tap()
    XCTAssertTrue(week.isSelected)
    let originalWeek = period.label
    app.buttons["calendar-next"].tap()
    XCTAssertNotEqual(period.label, originalWeek)
    app.buttons["calendar-previous"].tap()
    XCTAssertEqual(period.label, originalWeek)

    app.buttons["workspace-tab-notes"].tap()
    XCTAssertTrue(app.buttons["notes-collection-projects"].waitForExistence(timeout: 3))
    app.buttons["notes-collection-projects"].tap()
    XCTAssertTrue(app.staticTexts["Projects"].firstMatch.waitForExistence(timeout: 3))

    app.buttons["workspace-tab-notes"].tap()
    app.segmentedControls.buttons["Saved records"].tap()
    XCTAssertTrue(app.segmentedControls.buttons["Saved records"].isSelected)
    app.buttons["notes-open-search"].tap()
    XCTAssertTrue(app.staticTexts["Search memory"].firstMatch.waitForExistence(timeout: 3))
    app.buttons["workspace-tab-calendar"].tap()
    XCTAssertTrue(week.isSelected)
    app.buttons["workspace-tab-notes"].tap()
    XCTAssertTrue(app.segmentedControls.buttons["Saved records"].isSelected)
    app.buttons["workspace-tab-record"].tap()
    XCTAssertTrue(app.buttons["record-audio"].waitForExistence(timeout: 3))
    app.buttons["new-chat"].tap()
    let returnToRecording = app.buttons["capture-return-to-recording"]
    XCTAssertTrue(returnToRecording.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Chat"].exists)
    app.buttons["workspace-tab-brain"].tap()
    app.buttons["workspace-tab-record"].tap()
    XCTAssertTrue(returnToRecording.waitForExistence(timeout: 3))
    returnToRecording.tap()
    XCTAssertTrue(app.buttons["record-audio"].waitForExistence(timeout: 3))
  }

  func testAllFiveBrainMarksApplyAndSelectionSurvivesRelaunch() {
    let app = XCUIApplication()
    app.launch()
    let brainTab = app.buttons["workspace-tab-brain"]
    let originalMark = brainTab.value as? String ?? "Constellation"
    openSettings(in: app)

    let marks = [
      ("constellation", "Constellation"), ("ripple", "Ripple"), ("orbit", "Orbit"),
      ("branches", "Branches"), ("aperture", "Aperture"),
    ]
    for (id, title) in marks {
      let choice = app.buttons["brain-mark-\(id)"]
      XCTAssertTrue(choice.waitForExistence(timeout: 3), "Missing \(title) choice")
      if !choice.isHittable { app.swipeUp() }
      choice.tap()
      XCTAssertEqual(brainTab.value as? String, title)
    }

    app.terminate()
    app.launch()
    XCTAssertEqual(brainTab.value as? String, "Aperture")
    openSettings(in: app)
    if let (id, _) = marks.first(where: { $0.1 == originalMark }) {
      let original = app.buttons["brain-mark-\(id)"]
      if !original.isHittable { app.swipeUp() }
      original.tap()
    }
  }

  private func openSettings(in app: XCUIApplication) {
    app.buttons["open-menu"].tap()
    app.buttons["section-settings"].tap()
    XCTAssertTrue(app.buttons["brain-mark-constellation"].waitForExistence(timeout: 3))
  }
}
