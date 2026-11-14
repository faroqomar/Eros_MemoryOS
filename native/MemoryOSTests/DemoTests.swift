import Testing

@testable import MemoryOS

struct CatalogTests {
  @Test func allLinksAndBirthdaysResolveToOriginalRecords() throws {
    let catalog = DemoCatalog.sample
    #expect(Set(catalog.records.map(\.id)).count == catalog.records.count)
    #expect(Set(catalog.birthdays.map(\.id)).count == catalog.birthdays.count)
    for connection in catalog.connections {
      let from = try #require(catalog.record(connection.from))
      let to = try #require(catalog.record(connection.to))
      #expect(from.id != to.id)
      #expect(catalog.connections(for: to.id).contains { $0.record.id == from.id })
    }
    for birthday in catalog.birthdays {
      #expect(catalog.record(birthday.personID)?.kind == .person)
    }
    #expect(catalog.record("missing") == nil)
    #expect(catalog.connections(for: "missing").isEmpty)
  }

  @Test(arguments: ["Ali Hassan", "علي", "  Ali Hassan  "])
  func bilingualSearchFindsTheSamePerson(query: String) {
    #expect(DemoCatalog.sample.records(of: .person, matching: query).map(\.id) == ["ali"])
  }

  @Test func whitespaceAndNoResults() {
    let catalog = DemoCatalog.sample
    #expect(catalog.records(of: .person, matching: " \n ").count == 3)
    #expect(catalog.records(of: .project, matching: "no such project").isEmpty)
    #expect(catalog.records(of: .person, matching: "website").map(\.id) == ["ali"])
  }

  @Test func connectedFlowPreservesSourceAndTentativeWording() throws {
    let catalog = DemoCatalog.sample
    let person = try #require(catalog.record("ali"))
    #expect(catalog.connections(for: person.id).map(\.record.id) == ["website", "chat-ali"])
    let project = try #require(catalog.record("website"))
    #expect(!project.plans.isEmpty)
    #expect(project.ideas.first?.english.contains("might") == true)
    let source = try #require(catalog.record("chat-ali"))
    #expect(source.source.contains("Keep version 1 simple"))
    #expect(source.source.contains("نراجع"))
  }
}

@MainActor
struct SessionTests {
  @Test func blankCaptureCannotSubmitAndAcceptedCaptureClearsDraft() {
    let session = DemoSession()
    session.draft = "  \n "
    #expect(!session.canSubmit)
    session.submit()
    #expect(session.memories.isEmpty)
    session.draft = "  فكرة عن Reading room  "
    session.submit()
    #expect(session.draft.isEmpty)
    #expect(session.memories.first?.text == "فكرة عن Reading room")
    let id = session.memories.first?.id
    session.draft = "Second thought"
    session.submit()
    #expect(session.memories.count == 2)
    #expect(session.memories.last?.id == id)
    #expect(DemoSession().memories.isEmpty)
  }

  @Test func remindersRemainIndependentAndResetWithSession() {
    let session = DemoSession()
    #expect(session.reminder(for: "birthday-ali") == .off)
    session.chooseReminder(.weekBefore, for: "birthday-ali")
    session.section = .projects
    session.language = .arabic
    #expect(session.reminder(for: "birthday-ali") == .weekBefore)
    #expect(session.reminder(for: "birthday-sara") == .off)
    session.chooseReminder(.dayBefore, for: "missing")
    #expect(session.reminderChoices["missing"] == nil)
    session.chooseReminder(.off, for: "birthday-ali")
    #expect(session.reminder(for: "birthday-ali") == .off)
    #expect(DemoSession().reminderChoices.isEmpty)
  }

  @Test(arguments: ReminderChoice.allCases)
  func reminderSelectionHasBilingualLabels(choice: ReminderChoice) {
    let session = DemoSession()
    session.chooseReminder(choice, for: "birthday-ali")
    #expect(session.reminder(for: "birthday-ali") == choice)
    #expect(!choice.title(in: .english).isEmpty)
    #expect(!choice.title(in: .arabic).isEmpty)
  }
}
