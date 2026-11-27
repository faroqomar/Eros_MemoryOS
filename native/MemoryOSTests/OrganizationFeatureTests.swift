import Foundation
import MemoryCore
import OrganizationCore
import Testing

@testable import MemoryOS

private actor OrganizationFeatureMemory: PersonalMemoryRepository {
  var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}
private actor OrganizationFeatureStore: OrganizationRepository {
  var value = OrganizationSnapshot()
  func load() -> OrganizationSnapshot { value }
  func save(_ value: OrganizationSnapshot) { self.value = value }
}
private actor OrganizationFeatureScheduler: BirthdayScheduling {
  var failedRemoval = false
  private(set) var upserts = 0
  func requestPermission(for delivery: BirthdayDelivery) -> Bool { true }
  func validateExisting(_ schedule: BirthdaySchedule) {}
  func upsert(_ schedule: BirthdaySchedule) { upserts += 1 }
  func remove(_ schedule: BirthdaySchedule) throws {
    if failedRemoval { throw OrganizationError.permissionDenied }
  }
  func failRemoval() { failedRemoval = true }
}

private struct OrganizationArchiveReader: ArchiveDataReader {
  let data: Data
  func readArchive(at url: URL) async throws -> Data { data }
}

@MainActor struct OrganizationFeatureTests {
  @Test func organizationFeatureParsesArabicDatesAndReviewsExactSchedule() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let graph = try await personal.createProfile(kind: .person, name: "Fictional Noor")
    let person = try #require(graph.profiles.first { $0.kind == .person })
    let scheduler = OrganizationFeatureScheduler()
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: scheduler, memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    await model.load()
    #expect(await model.saveBirthday(personID: person.id, year: "", month: "٣", day: "١٢"))
    #expect(model.snapshot.birthdays[0].date == BirthdayDate(month: 3, day: 12))
    await model.previewBirthday(
      model.snapshot.birthdays[0].id, delivery: .notification, hour: 9, minute: 15,
      zone: "Asia/Baghdad")
    #expect(model.schedulePreview?.hour == 9)
    #expect(model.snapshot.schedules.isEmpty)
    await model.approveSchedule()
    #expect(model.schedulePreview == nil)
    #expect(model.snapshot.schedules[0].state == .active)
    await scheduler.failRemoval()
    #expect(!(await model.saveBirthday(personID: person.id, year: "", month: "3", day: "13")))
    #expect(model.error == .cancellationPending)
    // The date write completed before OS cancellation failed; display the saved intent and error together.
    #expect(model.snapshot.birthdays[0].date.day == 13)
    #expect(model.snapshot.schedules[0].state == .cancellationPending)
    #expect(!model.isBusy)
  }

  @Test func organizationFeatureRuleAndSavedTabUseCurrentRecords() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let source = PersonalMemorySource(text: "مشروع تجريبي", kind: .plan)
    _ = try await personal.ingest(source: source)
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: OrganizationFeatureScheduler(),
      memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    await model.load()
    #expect(await model.saveRule(name: "المشاريع", text: "مشروع", category: "عمل"))
    let rule = try #require(model.snapshot.rules.first)
    await model.testRule(rule.id)
    #expect(model.rulePreview?.entryIDs.isEmpty == false)
    await model.applyRule()
    #expect(model.memory.currentEntries.contains { $0.categories.contains("عمل") })
    #expect(await model.saveView(name: "خطط", text: "مشروع", kind: .plan))
    let view = try #require(model.snapshot.views.first)
    await model.openView(view)
    #expect(model.selectedEntries.isEmpty == false)
    let application = try #require(model.snapshot.applications.first)
    await model.undoRule(application.id)
    #expect(model.memory.currentEntries.allSatisfy { !$0.categories.contains("عمل") })
    await model.toggleRule(rule)
    #expect(model.snapshot.rules[0].enabled == false)
  }

  @Test func organizationFeatureExportsAndRestoresThroughInjectedFileBoundary()
    async throws
  {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let graph = try await personal.createProfile(kind: .person, name: "Fictional Noor")
    let person = try #require(graph.profiles.first { $0.kind == .person })
    let original = OrganizationUseCases(
      repository: OrganizationFeatureStore(),
      scheduler: OrganizationFeatureScheduler(), memory: personal)
    _ = try await original.saveBirthday(personID: person.id, date: BirthdayDate(month: 3, day: 12))
    let archive = try await original.exportArchive()
    let restoring = OrganizationUseCases(
      repository: OrganizationFeatureStore(),
      scheduler: OrganizationFeatureScheduler(), memory: personal)
    let model = OrganizationViewModel(
      useCases: restoring, personal: personal,
      archiveRestore: RestoreOrganizationArchive(
        useCases: restoring,
        reader: OrganizationArchiveReader(data: archive)))
    await model.load()
    #expect(model.canRestore)
    let beforePersonal = try await personal.snapshot()
    #expect(await model.restoreArchive(URL(filePath: "/fictional/organization.json")))
    #expect(model.snapshot.birthdays.count == 1)
    #expect(!model.canRestore)
    #expect(model.error == nil && !model.isBusy)
    #expect(try await personal.snapshot() == beforePersonal)
    #expect(await model.exportArchive())
    #expect(model.exportedArchive != nil)
    model.finishExport(.failure(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
    #expect(model.exportedArchive == nil && model.error == nil)
    #expect(!(await model.restoreArchive(URL(filePath: "/fictional/organization.json"))))
    #expect(model.error == .conflictingArchive)
    #expect(model.snapshot.birthdays.count == 1)
  }

  @Test func editingAnOpenCustomViewUsesTheNewFilter() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    _ = try await personal.ingest(
      source: PersonalMemorySource(text: "fictional project", kind: .plan))
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(),
      scheduler: OrganizationFeatureScheduler(), memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    await model.load()
    #expect(await model.saveView(name: "Plans", text: "project"))
    let view = try #require(model.snapshot.views.first)
    await model.openView(view)
    #expect(!model.selectedEntries.isEmpty)
    #expect(await model.saveView(id: view.id, name: "Changed", text: "unrelated"))
    #expect(model.selectedView?.name == "Changed")
    #expect(model.selectedEntries.isEmpty)
  }

  @Test func reloadRefreshesAnOpenTabAndRejectsADeletedTab() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    _ = try await personal.ingest(
      source: PersonalMemorySource(text: "fictional project", kind: .plan))
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: OrganizationFeatureScheduler(),
      memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    #expect(await model.saveView(name: "Plans", text: "project"))
    let original = try #require(model.snapshot.views.first)
    await model.openView(original)
    #expect(!model.selectedEntries.isEmpty)
    _ = try await useCases.saveView(
      SavedMemoryView(id: original.id, name: "Changed elsewhere", filter: .init(text: "absent")))
    await model.load()
    #expect(model.selectedView?.name == "Changed elsewhere")
    #expect(model.selectedEntries.isEmpty)
    _ = try await useCases.deleteView(original.id)
    await model.openView(original)
    #expect(model.selectedView == nil)
    #expect(model.error == .missingView)
  }

  @Test func mergeRefreshShowsDateChoicesAndRequiresExplicitBirthdayResolution() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let first = try await personal.createProfile(kind: .person, name: "Fictional Earlier")
    let earlier = try #require(first.profiles.first { $0.name == "Fictional Earlier" })
    let second = try await personal.createProfile(kind: .person, name: "Fictional Current")
    let current = try #require(second.profiles.first { $0.name == "Fictional Current" })
    let scheduler = OrganizationFeatureScheduler()
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: scheduler, memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    #expect(await model.saveBirthday(personID: earlier.id, year: "", month: "3", day: "12"))
    let oldBirthday = try #require(model.snapshot.birthdays.first)
    #expect(await model.saveBirthday(personID: current.id, year: "", month: "4", day: "15"))
    let survivor = try #require(model.snapshot.birthdays.first { $0.personID == current.id })
    #expect(await model.saveView(name: "Earlier person", text: "", profileID: earlier.id))
    await model.openView(try #require(model.snapshot.views.first))
    #expect(
      await model.saveRule(
        name: "Earlier rule", text: "", category: "Fictional", profileID: earlier.id))
    await model.testRule(try #require(model.snapshot.rules.first).id)
    await model.previewBirthday(
      oldBirthday.id, delivery: .notification, hour: 9, minute: 0, zone: "Asia/Baghdad")
    await model.approveSchedule()
    await model.previewBirthday(
      oldBirthday.id, delivery: .notification, hour: 10, minute: 0, zone: "Asia/Baghdad")
    _ = try await personal.mergePeople(from: earlier.id, into: current.id, confirmed: true)
    await model.load()
    #expect(model.error == nil)
    #expect(model.selectedView?.filter.profileID == current.id)
    #expect(model.schedulePreview == nil && model.rulePreview == nil)
    let review = try #require(model.mergedBirthdayReviews.first)
    #expect(review.date == oldBirthday.date && review.existingBirthdayID == survivor.id)
    #expect(model.snapshot.birthdays.first { $0.id == survivor.id }?.date == survivor.date)
    #expect(model.snapshot.schedules.allSatisfy { $0.state == .disabled })
    #expect(await scheduler.upserts == 1)
    #expect(await model.resolveMergedBirthday(review, date: survivor.date))
    #expect(model.mergedBirthdayReviews.isEmpty)
    #expect(
      model.snapshot.birthdays.first { $0.id == oldBirthday.id }?.resolvedIntoBirthdayID
        == survivor.id)
    #expect(model.snapshot.birthdays.first { $0.id == oldBirthday.id }?.date == oldBirthday.date)
    #expect(await scheduler.upserts == 1)
  }

  @Test func reloadingChangedMemoriesInvalidatesRulePreview() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: OrganizationFeatureScheduler(),
      memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    #expect(await model.saveRule(name: "Plans", text: "project", category: "Work"))
    await model.testRule(try #require(model.snapshot.rules.first).id)
    #expect(model.rulePreview != nil)
    _ = try await personal.ingest(
      source: PersonalMemorySource(text: "fictional project", kind: .plan))
    await model.load()
    #expect(model.rulePreview == nil)
  }

  @Test func changedBirthdayReviewKeepsTheSheetContextUnapproved() async throws {
    let personal = PersonalMemoryUseCases(repository: OrganizationFeatureMemory())
    let first = try await personal.createProfile(kind: .person, name: "Fictional Earlier")
    let earlier = try #require(first.profiles.first { $0.name == "Fictional Earlier" })
    let second = try await personal.createProfile(kind: .person, name: "Fictional Current")
    let current = try #require(second.profiles.first { $0.name == "Fictional Current" })
    let scheduler = OrganizationFeatureScheduler()
    let useCases = OrganizationUseCases(
      repository: OrganizationFeatureStore(), scheduler: scheduler, memory: personal)
    let model = OrganizationViewModel(useCases: useCases, personal: personal)
    #expect(await model.saveBirthday(personID: earlier.id, year: "", month: "3", day: "12"))
    #expect(await model.saveBirthday(personID: current.id, year: "", month: "4", day: "15"))
    _ = try await personal.mergePeople(from: earlier.id, into: current.id, confirmed: true)
    await model.load()
    let presented = try #require(model.mergedBirthdayReviews.first)
    _ = try await useCases.saveBirthday(personID: current.id, date: .init(month: 5, day: 16))
    #expect(!(await model.resolveMergedBirthday(presented, date: presented.date)))
    #expect(model.error == .stalePreview)
    #expect(!model.mergedBirthdayReviews.contains(presented))
    #expect(
      model.mergedBirthdayReviews.first?.existingBirthdayDate == BirthdayDate(month: 5, day: 16))
    #expect(
      model.snapshot.birthdays.first { $0.personID == earlier.id }?.resolvedIntoBirthdayID == nil)
    #expect(await scheduler.upserts == 0)
  }

}
