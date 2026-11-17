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
    XCTAssertTrue(app.buttons["record-audio"].exists)
  }

  func testLocalCaptureSurvivesRelaunch() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertFalse(app.buttons["capture-send"].isEnabled)
    let composer =
      app.textFields["capture-composer"].exists
      ? app.textFields["capture-composer"] : app.textViews["capture-composer"]
    composer.tap()
    composer.typeText("A fictional project thought")
    app.buttons["save-thought"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    app.alerts.buttons["OK"].tap()
    app.buttons["your-memories"].tap()
    XCTAssertTrue(app.staticTexts["A fictional project thought"].waitForExistence(timeout: 3))
    app.terminate()
    app.launch()
    app.buttons["your-memories"].tap()
    XCTAssertTrue(app.staticTexts["A fictional project thought"].waitForExistence(timeout: 3))
  }

  func testHomeSendShowsConversationWithoutOpeningSidebarOrSavingMemory() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["capture-open-chat"].tap()
    app.buttons["new-chat"].tap()
    app.buttons["capture-return-to-recording"].tap()
    let field =
      app.textViews["capture-composer"].exists
      ? app.textViews["capture-composer"] : app.textFields["capture-composer"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("A fictional home chat greeting")
    app.buttons["capture-send"].tap()
    XCTAssertTrue(app.buttons["capture-return-to-recording"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["A fictional home chat greeting"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.alerts.firstMatch.exists)
    XCTAssertTrue(app.buttons["open-menu"].exists)
    if app.buttons["chat-stop"].exists { app.buttons["chat-stop"].tap() }
    app.buttons["capture-return-to-recording"].tap()
    app.buttons["your-memories"].tap()
    XCTAssertFalse(app.staticTexts["A fictional home chat greeting"].exists)
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

  func testVoiceLibraryOpensWithoutActivatingMicrophone() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["capture-audio-library"].tap()
    XCTAssertTrue(app.buttons["audio-start"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["audio-import"].exists)
    XCTAssertFalse(app.buttons["audio-save"].exists)
    app.navigationBars.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["record-audio"].exists)
  }

  func testArabicVoiceLibraryKeepsCaptureNavigation() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["open-menu"].tap()
    app.buttons["section-settings"].tap()
    app.buttons["language-picker"].tap()
    app.buttons["العربية"].tap()
    app.buttons["open-menu"].tap()
    app.buttons["section-capture"].tap()
    app.buttons["capture-audio-library"].tap()
    XCTAssertTrue(app.buttons["audio-start"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["audio-start"].label, "بدء التسجيل")
    XCTAssertTrue(app.staticTexts["الملاحظات الصوتية"].exists)
    let importer = app.buttons["audio-import"]
    XCTAssertGreaterThan(
      importer.images.firstMatch.frame.midX,
      importer.staticTexts["استيراد صوت"].frame.midX)
    app.navigationBars.buttons["تم"].tap()
    XCTAssertTrue(app.buttons["record-audio"].exists)
  }

  func testVoiceLibraryAccessibilityInBothLanguages() throws {
    continueAfterFailure = true
    for arabic in [false, true] {
      let app = XCUIApplication()
      app.launch()
      if arabic {
        app.buttons["open-menu"].tap()
        app.buttons["section-settings"].tap()
        app.buttons["language-picker"].tap()
        app.buttons["العربية"].tap()
        app.buttons["open-menu"].tap()
        app.buttons["section-capture"].tap()
      }
      app.buttons["capture-audio-library"].tap()
      XCTAssertTrue(app.buttons["audio-start"].waitForExistence(timeout: 5))
      let ready = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"), object: app.buttons["audio-start"])
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
      try auditVoiceScreen(app)
      let list = app.collectionViews["audio-library-list"]
      list.swipeUp()
      XCTAssertTrue(app.buttons["audio-model-import"].isHittable)
      try auditVoiceScreen(app)
      app.terminate()
    }
  }

  private func auditVoiceScreen(_ app: XCUIApplication) throws {
    try app.performAccessibilityAudit { issue in
      let element = issue.element
      let target =
        element?.exists == true
        ? "\(element!.identifier) | \(element!.label) | \(element!.frame)"
        : "unresolved element"
      print("VOICE AUDIT: \(issue.detailedDescription) | \(target)")
      return false
    }
  }

  func testVoiceLibraryLargestTextKeepsControlsReachable() {
    continueAfterFailure = true
    for arabic in [false, true] {
      var regular: [String: CGFloat] = [:]
      for category in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", category]
        app.launch()
        if arabic {
          app.buttons["open-menu"].tap()
          app.buttons["section-settings"].tap()
          for _ in 0..<8 {
            if app.buttons["language-picker"].isHittable { break }
            app.swipeUp()
          }
          app.buttons["language-picker"].tap()
          app.buttons["العربية"].tap()
          app.buttons["open-menu"].tap()
          app.buttons["section-capture"].tap()
        }
        app.buttons["capture-audio-library"].tap()
        XCTAssertTrue(app.buttons["audio-start"].waitForExistence(timeout: 5))
        measure(arabic ? "تم" : "Done")
        for identifier in [
          "audio-start", "audio-import", "audio-transcription-heading", "audio-model-import",
        ] {
          let element =
            identifier == "audio-transcription-heading"
            ? app.staticTexts[identifier] : app.buttons[identifier]
          for _ in 0..<8 {
            if element.isHittable { break }
            app.collectionViews["audio-library-list"].swipeUp()
          }
          XCTAssertTrue(element.isHittable, identifier)
          if identifier == "audio-start" {
            measure(arabic ? "بدء التسجيل" : "Start recording")
          }
          if identifier == "audio-transcription-heading" {
            measure(arabic ? "التفريغ النصي المحلي" : "Local transcription")
          }
        }
        app.terminate()

        func measure(_ label: String) {
          let text =
            app.staticTexts[label].firstMatch.exists
            ? app.staticTexts[label].firstMatch : app.buttons[label].firstMatch
          XCTAssertTrue(text.exists, label)
          let height = text.frame.height
          print("VOICE TEXT \(category) \(label): \(text.frame)")
          if label == "Done" || label == "تم" {
            XCTAssertGreaterThanOrEqual(height, 44)
          } else if category == "UICTContentSizeCategoryL" {
            regular[label] = height
          } else {
            XCTAssertGreaterThan(height, (regular[label] ?? 0) * 1.8, label)
          }
        }
      }
    }
  }

  private func assertNotHittable(
    _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
  ) {
    let hidden = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed, file: file, line: line)
  }
}
