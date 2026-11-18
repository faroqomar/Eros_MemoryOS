import XCTest

@MainActor
final class DemoFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testPeopleToProjectAndSourceWithBackNavigation() {
    let app = XCUIApplication()
    app.launch()
    route("profiles", in: app)
    XCTAssertTrue(app.staticTexts["You"].exists)
    openSamplePerson(in: app)
    XCTAssertTrue(app.staticTexts["Original sample"].exists)
    app.swipeUp()
    app.buttons["record-website"].tap()
    XCTAssertTrue(app.staticTexts["Current plans"].exists)
    XCTAssertTrue(app.staticTexts["Tentative ideas"].exists)
    app.swipeUp()
    app.buttons["record-chat-ali"].tap()
    XCTAssertTrue(app.staticTexts["original-source"].label.contains("Keep version 1 simple"))
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["Tentative ideas"].exists)
  }

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

  func testBirthdayChoicesSurviveNavigationAndReset() {
    let app = XCUIApplication()
    app.launch()
    route("birthdays", in: app)
    app.buttons["birthday-birthday-ali"].tap()
    for (choice, title) in [
      ("onDay", "On the day"), ("dayBefore", "One day before"), ("weekBefore", "One week before"),
      ("off", "Off"), ("weekBefore", "One week before"),
    ] {
      app.buttons["reminder-\(choice)"].tap()
      XCTAssertEqual(app.staticTexts["reminder-current"].label, title)
    }
    route("projects", in: app)
    route("birthdays", in: app)
    XCTAssertEqual(app.staticTexts["reminder-current"].label, "One week before")
    app.terminate()
    app.launch()
    route("birthdays", in: app)
    app.buttons["birthday-birthday-ali"].tap()
    XCTAssertEqual(app.staticTexts["reminder-current"].label, "Off")
  }

  func testMapExplorationOpensLinkedProject() {
    let app = XCUIApplication()
    app.launch()
    route("brainMap", in: app)
    app.buttons["map-focus-website"].tap()
    XCTAssertTrue(app.buttons["map-open-website"].exists)
    app.buttons["map-open-website"].tap()
    XCTAssertTrue(app.staticTexts["Current plans"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    app.segmentedControls.buttons["List"].tap()
    XCTAssertTrue(app.buttons["record-ali"].exists)
    app.buttons["record-ali"].tap()
    XCTAssertTrue(app.staticTexts["original-source"].label.contains("علي"))
  }

  func testArabicPeopleBirthdayAndMixedSource() {
    let app = XCUIApplication()
    app.launch()
    route("settings", in: app)
    app.buttons["language-picker"].tap()
    app.buttons["العربية"].tap()
    route("profiles", in: app)
    XCTAssertTrue(app.staticTexts["أنت"].exists)
    openSamplePerson(in: app)
    XCTAssertTrue(app.staticTexts["original-source"].label.contains("We can review"))
    XCTAssertTrue(app.staticTexts["النص التجريبي الأصلي"].exists)
    app.buttons["birthday-birthday-ali"].tap()
    app.buttons["reminder-dayBefore"].tap()
    XCTAssertEqual(app.staticTexts["reminder-current"].label, "قبل يوم واحد")
    openSampleProject(in: app)
    XCTAssertTrue(app.staticTexts["الخطط الحالية"].exists)
  }

  func testLargeTextKeepsMapAndBirthdayActionsReachable() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    route("brainMap", in: app)
    XCTAssertTrue(app.descendants(matching: .any)["map-choose"].isHittable)
    XCTAssertTrue(app.staticTexts["map-large-text-presentation"].exists)
    XCTAssertFalse(app.segmentedControls["map-presentation"].exists)
    app.swipeUp()
    XCTAssertTrue(app.buttons["map-focus-website"].exists)
    route("birthdays", in: app)
    app.buttons["birthday-birthday-ali"].tap()
    app.swipeUp()
    app.buttons["reminder-onDay"].tap()
    app.swipeUp()
    XCTAssertEqual(app.staticTexts["reminder-current"].label, "On the day")
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

  func testLinkedTextScalesInBothLanguages() {
    for arabic in [false, true] {
      let regular = linkedTextHeights(arabic: arabic, category: "UICTContentSizeCategoryL")
      let large = linkedTextHeights(
        arabic: arabic, category: "UICTContentSizeCategoryAccessibilityXXXL")
      for (text, height) in regular {
        XCTAssertGreaterThan(large[text] ?? 0, height * 1.8, text)
      }
    }
  }

  private func linkedTextHeights(arabic: Bool, category: String) -> [String: CGFloat] {
    let app = XCUIApplication()
    app.launchArguments = ["-UIPreferredContentSizeCategoryName", category]
    app.launch()
    if arabic {
      route("settings", in: app)
      app.buttons["language-picker"].tap()
      app.buttons["العربية"].tap()
    }
    openSamplePerson(in: app)
    var heights: [String: CGFloat] = [:]
    measure(
      arabic ? ["١٢ أيار", "عرض خيارات التذكير"] : ["12 May", "View reminder choices"])
    openSampleProject(in: app)
    measure(
      arabic
        ? ["قد نضيف معرض صور صغيراً لاحقاً.", "هذه احتمالات ولم نتفق عليها كخطط."]
        : [
          "We might add a small photo gallery later.", "Ideas are possibilities, not agreed plans.",
        ])
    route("birthdays", in: app)
    app.buttons["birthday-birthday-ali"].tap()
    measure(
      arabic
        ? [
          "معاينة فقط. لن ينشئ التطبيق إشعاراً أو حدث تقويم. تُمسح الخيارات عند إغلاق التطبيق.",
          "الخيار الحالي",
        ]
        : [
          "Preview only. No notification or calendar event will be created. Choices reset when the app closes.",
          "Current choice",
        ])

    func measure(_ texts: [String]) {
      for text in texts {
        let element = app.staticTexts[text]
        for _ in 0..<8 {
          if element.isHittable { break }
          app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, text)
        heights[text] = element.frame.height
        print("TEXT-SIZE \(category) \(text): \(element.frame)")
      }
    }
    app.terminate()
    return heights
  }

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
    route("projects", in: app)
    try auditCategories(in: app)
    openSampleProject(in: app)
    try auditCategories(in: app)
    route("birthdays", in: app)
    app.buttons["birthday-birthday-ali"].tap()
    try auditCategories(in: app)
    route("brainMap", in: app)
    try auditCategories(in: app)
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

  // Original sample links still belong to the explicitly fictional BrainMap demo.
  private func sampleMapRoot(in app: XCUIApplication) {
    route("brainMap", in: app)
    for _ in 0..<5 {
      if app.buttons["map-choose"].exists { return }
      app.navigationBars.buttons.firstMatch.tap()
    }
  }

  private func openSamplePerson(in app: XCUIApplication) {
    sampleMapRoot(in: app)
    app.buttons["map-choose"].tap()
    let person = app.buttons["Ali Hassan"]
    if person.exists { person.tap() } else { app.buttons["علي حسن"].tap() }
    app.buttons["map-open-ali"].tap()
  }

  private func openSampleProject(in app: XCUIApplication) {
    sampleMapRoot(in: app)
    app.buttons["map-choose"].tap()
    let project = app.buttons["Small website"]
    if project.exists { project.tap() } else { app.buttons["موقع صغير"].tap() }
    app.buttons["map-open-website"].tap()
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
