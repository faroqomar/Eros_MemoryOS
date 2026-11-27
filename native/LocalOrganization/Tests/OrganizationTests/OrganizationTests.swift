import Foundation
import MemoryCore
import OrganizationCore
import OrganizationPersistence
import Testing

private actor MemoryStore: PersonalMemoryRepository {
  var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}
private actor Store: OrganizationRepository {
  var value = OrganizationSnapshot()
  var fail = false
  var saves = 0
  var failAt: Int?
  func load() -> OrganizationSnapshot { value }
  func save(_ value: OrganizationSnapshot) throws {
    saves += 1
    if fail || saves == failAt { throw OrganizationError.storage }
    self.value = value
  }
  func setFailure(_ value: Bool) { fail = value }
  func failAfter(_ savesFromNow: Int) { failAt = saves + savesFromNow }
}
private actor Scheduler: BirthdayScheduling {
  var permitted = true
  var failUpsert = false
  var failRemoval = false
  var rollbackPending = false
  var reviewConflict = false
  var installed: [UUID: BirthdaySchedule] = [:]
  var permissionCalls = 0
  var removals = 0
  var upserts = 0
  func requestPermission(for delivery: BirthdayDelivery) -> Bool {
    permissionCalls += 1
    return permitted
  }
  func validateExisting(_ value: BirthdaySchedule) throws {
    if reviewConflict, installed[value.id] != nil { throw OrganizationError.stalePreview }
  }
  func upsert(_ value: BirthdaySchedule) throws {
    upserts += 1
    if reviewConflict, installed[value.id] != nil { throw OrganizationError.stalePreview }
    if failUpsert { throw OrganizationError.schedulerUnavailable }
    installed[value.id] = value
    if rollbackPending { throw OrganizationError.cancellationPending }
  }
  func remove(_ value: BirthdaySchedule) throws {
    if failRemoval { throw OrganizationError.permissionDenied }
    installed[value.id] = nil
    removals += 1
  }
  func setPermitted(_ value: Bool) { permitted = value }
  func setUpsertFailure(_ value: Bool) { failUpsert = value }
  func setRemovalFailure(_ value: Bool) { failRemoval = value }
  func setRollbackPending(_ value: Bool) { rollbackPending = value }
  func setReviewConflict(_ value: Bool) { reviewConflict = value }
}

private func fixture() async throws -> (
  OrganizationUseCases, PersonalMemoryUseCases, Store, Scheduler, UUID
) {
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let snapshot = try await memory.createProfile(kind: .person, name: "Fictional Noor")
  let id = try #require(snapshot.profiles.first(where: { $0.kind == .person })?.id)
  let store = Store()
  let scheduler = Scheduler()
  return (
    OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory), memory, store,
    scheduler, id
  )
}

@Test func partialDatesAndLeapValidation() throws {
  try BirthdayDate(year: 1992).validate()
  try BirthdayDate(month: 2).validate()
  try BirthdayDate(month: 2, day: 29).validate()
  #expect(throws: OrganizationError.invalidDate) {
    try BirthdayDate(year: 1900, month: 2, day: 29).validate()
  }
  #expect(throws: OrganizationError.invalidDate) { try BirthdayDate(month: 4, day: 31).validate() }
  #expect(throws: OrganizationError.invalidDate) { try BirthdayDate().validate() }
}

@Test func saveNeverSchedulesAndIncompleteDateCannotPreview() async throws {
  let (useCases, _, _, scheduler, person) = try await fixture()
  let value = try await useCases.saveBirthday(personID: person, date: BirthdayDate(month: 3))
  #expect(await scheduler.permissionCalls == 0)
  #expect(await scheduler.installed.isEmpty)
  await #expect(throws: OrganizationError.invalidDate) {
    try await useCases.previewSchedule(
      birthdayID: value.birthdays[0].id, delivery: .notification, hour: 9, minute: 0,
      timeZoneID: "Asia/Baghdad")
  }
}

@Test func explicitApprovalExactDuplicateAndCorrection() async throws {
  let (useCases, _, _, scheduler, person) = try await fixture()
  let value = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  let preview = try await useCases.previewSchedule(
    birthdayID: value.birthdays[0].id,
    delivery: .notification, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  await #expect(throws: OrganizationError.approvalRequired) {
    try await useCases.approve(preview, approved: false)
  }
  let approved = try await useCases.approve(preview, approved: true)
  #expect(approved.schedules[0].state == .active)
  _ = try await useCases.approve(preview, approved: true)
  #expect(await scheduler.installed.count == 1)
  let corrected = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 13))
  #expect(corrected.birthdays[0].previousDates == [BirthdayDate(month: 3, day: 12)])
  #expect(corrected.schedules.allSatisfy { $0.state == .disabled })
  #expect(await scheduler.installed.isEmpty)
  await #expect(throws: OrganizationError.stalePreview) {
    try await useCases.approve(preview, approved: true)
  }
}

@Test func deniedPermissionAndStorageFailureProduceNoDelivery() async throws {
  let (useCases, _, store, scheduler, person) = try await fixture()
  let value = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 7, day: 1))
  let preview = try await useCases.previewSchedule(
    birthdayID: value.birthdays[0].id,
    delivery: .calendar, hour: 10, minute: 0, timeZoneID: "UTC")
  await scheduler.setPermitted(false)
  await #expect(throws: OrganizationError.permissionDenied) {
    try await useCases.approve(preview, approved: true)
  }
  #expect(try await useCases.snapshot().schedules.isEmpty)
  await scheduler.setPermitted(true)
  await store.setFailure(true)
  await #expect(throws: OrganizationError.storage) {
    try await useCases.approve(preview, approved: true)
  }
  #expect(await scheduler.installed.isEmpty)
}

@Test func failedScheduleRecoversWithoutNewPermissionOrScopeExpansion() async throws {
  let (useCases, _, _, scheduler, person) = try await fixture()
  let value = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 8, day: 1))
  let preview = try await useCases.previewSchedule(
    birthdayID: value.birthdays[0].id,
    delivery: .notification, hour: 11, minute: 30, timeZoneID: "Asia/Baghdad")
  await scheduler.setUpsertFailure(true)
  await #expect(throws: OrganizationError.schedulerUnavailable) {
    try await useCases.approve(preview, approved: true)
  }
  #expect(try await useCases.snapshot().schedules[0].state == .failed)
  await scheduler.setUpsertFailure(false)
  let repaired = try await useCases.reconcile()
  #expect(repaired.schedules[0].hour == 11 && repaired.schedules[0].minute == 30)
  #expect(repaired.schedules[0].state == .active)
  #expect(await scheduler.permissionCalls == 1)
}

@Test func nextOccurrenceKeepsTimezoneAndSkipsNonleapYear() throws {
  let schedule = BirthdaySchedule(
    birthdayID: UUID(), personID: UUID(), month: 2, day: 29,
    hour: 9, minute: 0, timeZoneID: "Asia/Baghdad", delivery: .notification, title: "Fictional")
  let now = ISO8601DateFormatter().date(from: "2026-11-19T00:00:00Z")!
  #expect(
    schedule.nextOccurrence(after: now) == ISO8601DateFormatter().date(from: "2028-02-29T06:00:00Z")
  )
}

@Test func rulePreviewApplyUndoAndCurrentSavedViews() async throws {
  let (useCases, memory, _, _, person) = try await fixture()
  let original = PersonalMemorySource(text: "Project discussion with Noor", kind: .plan)
  _ = try await memory.ingest(source: original)
  _ = try await memory.addEntry(
    text: "Project discussion with Noor", kind: .plan,
    sourceIDs: [original.id], profileIDs: [person])
  let rule = OrganizationRule(
    name: "Project notes", filter: OrganizationFilter(text: "PROJECT", profileID: person),
    category: "Work")
  _ = try await useCases.saveRule(rule)
  let preview = try await useCases.testRule(rule.id)
  #expect(preview.entryIDs.count >= 1)
  let applied = try await useCases.applyRule(preview)
  let appliedGraph = try await memory.snapshot()
  #expect(
    appliedGraph.currentEntries.filter { preview.entryIDs.contains($0.id) }.allSatisfy {
      $0.categories.contains("Work")
    })
  let restored = try await useCases.undoRule(applied.applications[0].id)
  #expect(restored.applications.isEmpty)
  #expect(try await memory.snapshot().sources.contains(original))
  let view = SavedMemoryView(
    name: "Plans", filter: OrganizationFilter(text: "Project", profileID: person, kind: .plan))
  _ = try await useCases.saveView(view)
  let matches = try await useCases.entries(in: view)
  let entry = try #require(matches.first)
  _ = try await memory.updateEntry(id: entry.id, text: "A different topic")
  #expect(try await useCases.entries(in: view).isEmpty)
}

@Test func disabledRulesStaleTestsAndUndoCannotOverwriteManualEdit() async throws {
  let (useCases, memory, _, _, _) = try await fixture()
  let original = PersonalMemorySource(text: "meeting", kind: .plan)
  _ = try await memory.ingest(source: original)
  let graph = try await memory.addEntry(text: "meeting", kind: .plan, sourceIDs: [original.id])
  let entry = try #require(graph.currentEntries.first)
  var rule = OrganizationRule(
    name: "Meetings", filter: OrganizationFilter(text: "meeting"), category: "Work")
  _ = try await useCases.saveRule(rule)
  let stale = try await useCases.testRule(rule.id)
  _ = try await memory.updateEntry(id: entry.id, text: "meeting changed")
  await #expect(throws: OrganizationError.stalePreview) { try await useCases.applyRule(stale) }
  let applied = try await useCases.applyRule(useCases.testRule(rule.id))
  let current = try await memory.snapshot().currentEntries.first { $0.id == entry.id }!
  _ = try await memory.organize(entryID: current.id, categories: ["Manual"], profileIDs: [])
  await #expect(throws: PersonalMemoryError.staleAnalysis) {
    try await useCases.undoRule(applied.applications[0].id)
  }
  rule.enabled = false
  _ = try await useCases.saveRule(rule)
  let disabled = try await useCases.testRule(rule.id)
  await #expect(throws: OrganizationError.stalePreview) { try await useCases.applyRule(disabled) }
}

@Test func fileRepositoryRoundTripAndCorruptionRefusesReset() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("organization.json")
  let repository = FileOrganizationRepository(url: url)
  var value = OrganizationSnapshot()
  value.birthdays = [BirthdayRecord(personID: UUID(), date: BirthdayDate(month: 4))]
  value.views = [SavedMemoryView(name: "أفكار", filter: OrganizationFilter(text: "مشروع"))]
  try await repository.save(value)
  #expect(try await FileOrganizationRepository(url: url).load() == value)
  try Data("bad".utf8).write(to: url)
  await #expect(throws: OrganizationError.storage) { try await repository.load() }
}

@Test func cancellationFailureStaysVisibleAndPreventsDuplicateReplacements() async throws {
  let (useCases, _, _, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 5, day: 5))
  let first = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 0, timeZoneID: "UTC")
  _ = try await useCases.approve(first, approved: true)
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await useCases.saveBirthday(personID: person, date: BirthdayDate(month: 5, day: 6))
  }
  let pending = try await useCases.snapshot()
  #expect(pending.birthdays[0].date.day == 6)
  #expect(pending.schedules[0].state == .cancellationPending)
  #expect(await scheduler.installed.count == 1)
  let replacement = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .notification, hour: 10, minute: 0, timeZoneID: "UTC")
  await #expect(throws: OrganizationError.cancellationPending) {
    try await useCases.approve(replacement, approved: true)
  }
  #expect(await scheduler.installed.count == 1)
  await scheduler.setRemovalFailure(false)
  let recovered = try await useCases.reconcile()
  #expect(recovered.schedules.allSatisfy { $0.state == .disabled })
  #expect(await scheduler.installed.isEmpty)
  let approved = try await useCases.approve(replacement, approved: true)
  #expect(approved.schedules.last?.state == .active)
  #expect(await scheduler.installed.count == 1)
}

@Test func ruleReceiptRecoversWhenFinalApplyAndUndoPersistenceFail() async throws {
  let (useCases, memory, store, _, _) = try await fixture()
  let original = PersonalMemorySource(text: "fictional meeting", kind: .plan)
  _ = try await memory.ingest(source: original)
  let rule = OrganizationRule(
    name: "Meetings", filter: OrganizationFilter(text: "meeting"), category: "Work")
  _ = try await useCases.saveRule(rule)
  let preview = try await useCases.testRule(rule.id)
  await store.failAfter(2)
  await #expect(throws: OrganizationError.storage) { try await useCases.applyRule(preview) }
  let receipt = try #require(try await useCases.snapshot().applications.first)
  #expect(receipt.applied == false)
  #expect(try await memory.snapshot().currentEntries.contains { $0.categories.contains("Work") })
  await store.failAfter(1)
  await #expect(throws: OrganizationError.storage) { try await useCases.undoRule(receipt.id) }
  #expect(try await memory.snapshot().currentEntries.allSatisfy { !$0.categories.contains("Work") })
  let recovered = try await useCases.undoRule(receipt.id)
  #expect(recovered.applications.isEmpty)
  #expect(try await memory.snapshot().sources.contains(original))
}

private actor PausedPermissionScheduler: BirthdayScheduling {
  private var permission: CheckedContinuation<Bool, Never>?
  private var reached: CheckedContinuation<Void, Never>?
  private var waiting = false
  var installed = 0
  func requestPermission(for delivery: BirthdayDelivery) async -> Bool {
    await withCheckedContinuation { continuation in
      permission = continuation
      waiting = true
      reached?.resume()
      reached = nil
    }
  }
  func waitForPrompt() async {
    if waiting { return }
    await withCheckedContinuation { reached = $0 }
  }
  func allow() {
    permission?.resume(returning: true)
    permission = nil
  }
  func validateExisting(_ schedule: BirthdaySchedule) {}
  func upsert(_ schedule: BirthdaySchedule) { installed += 1 }
  func remove(_ schedule: BirthdaySchedule) {}
}

@Test func approvalRejectsPersonChangedWhilePermissionPromptIsOpen() async throws {
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let graph = try await memory.createProfile(kind: .person, name: "Fictional Noor")
  let person = try #require(graph.profiles.first { $0.kind == .person })
  let scheduler = PausedPermissionScheduler()
  let useCases = OrganizationUseCases(repository: Store(), scheduler: scheduler, memory: memory)
  let saved = try await useCases.saveBirthday(
    personID: person.id, date: BirthdayDate(month: 3, day: 12))
  let preview = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .notification, hour: 9, minute: 0, timeZoneID: "UTC")
  let approval = Task { try await useCases.approve(preview, approved: true) }
  await scheduler.waitForPrompt()
  _ = try await memory.updateProfile(id: person.id, name: "Corrected fictional name", aliases: [])
  await scheduler.allow()
  await #expect(throws: OrganizationError.stalePreview) { try await approval.value }
  #expect(await scheduler.installed == 0)
  #expect(try await useCases.snapshot().schedules.isEmpty)
}

@Test func archiveRoundTripPreservesOrganizationAndDisablesTransferredApprovals() async throws {
  let (original, memory, _, scheduler, person) = try await fixture()
  var saved = try await original.saveBirthday(personID: person, date: BirthdayDate(month: 3))
  saved = try await original.saveBirthday(personID: person, date: BirthdayDate(month: 3, day: 12))
  let preview = try await original.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .notification, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  let approved = try await original.approve(preview, approved: true)
  let source = PersonalMemorySource(text: "Fictional project note", kind: .plan)
  _ = try await memory.ingest(source: source)
  let rule = OrganizationRule(
    name: "Project", filter: OrganizationFilter(text: "project"), category: "Work")
  _ = try await original.saveRule(rule)
  _ = try await original.applyRule(original.testRule(rule.id))
  _ = try await original.saveView(
    SavedMemoryView(name: "Plans", filter: OrganizationFilter(kind: .plan)))
  let before = try await original.snapshot()
  let data = try await original.exportArchive()
  #expect(try JSONDecoder().decode(OrganizationSnapshot.self, from: data) == before)
  #expect(await scheduler.installed.count == 1)
  let restoreScheduler = Scheduler()
  let restoredUseCases = OrganizationUseCases(
    repository: Store(), scheduler: restoreScheduler, memory: memory)
  let restored = try await restoredUseCases.restoreArchive(data)
  #expect(restored.birthdays == before.birthdays)
  #expect(restored.rules == before.rules && restored.views == before.views)
  #expect(restored.applications == before.applications)
  #expect(restored.schedules[0].id == approved.schedules[0].id)
  #expect(restored.schedules[0].state == .disabled)
  #expect(restored.schedules[0].stateBeforeRestore == .active)
  #expect(await restoreScheduler.permissionCalls == 0)
  #expect(await restoreScheduler.installed.isEmpty)
  #expect(await restoreScheduler.removals == 1)
  _ = try await restoredUseCases.reconcile()
  #expect(await restoreScheduler.installed.isEmpty)
  await #expect(throws: OrganizationError.conflictingArchive) {
    try await restoredUseCases.restoreArchive(data)
  }
  #expect(try await restoredUseCases.snapshot().birthdays == restored.birthdays)
}

@Test func archiveMissingReferencesMalformedVersionAndOversizeDoNotResetStorage() async throws {
  let (original, memory, _, _, person) = try await fixture()
  _ = try await original.saveBirthday(personID: person, date: BirthdayDate(month: 3))
  let data = try await original.exportArchive()
  let missingMemory = PersonalMemoryUseCases(repository: MemoryStore())
  let store = Store()
  let useCases = OrganizationUseCases(
    repository: store, scheduler: Scheduler(), memory: missingMemory)
  await #expect(throws: OrganizationError.missingReferences) {
    try await useCases.restoreArchive(data)
  }
  #expect(await store.saves == 0)
  await #expect(throws: OrganizationError.invalidArchive) {
    try await useCases.restoreArchive(Data("bad".utf8))
  }
  var future = OrganizationSnapshot()
  future.formatVersion = OrganizationSnapshot.currentFormatVersion + 1
  let futureData = try JSONEncoder().encode(future)
  await #expect(throws: OrganizationError.invalidArchive) {
    try await useCases.restoreArchive(futureData)
  }
  await #expect(throws: OrganizationError.limitReached) {
    try await useCases.restoreArchive(
      Data(repeating: 0, count: OrganizationSnapshot.maximumArchiveBytes + 1))
  }
  #expect(await store.saves == 0)
  #expect(try await memory.snapshot().profiles.contains { $0.id == person })
}

@Test func restoreCancellationFailureRetainsIntentAndNeverReactivatesSchedule() async throws {
  let (original, memory, _, _, person) = try await fixture()
  let saved = try await original.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  let preview = try await original.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  _ = try await original.approve(preview, approved: true)
  let data = try await original.exportArchive()
  let scheduler = Scheduler()
  await scheduler.setRemovalFailure(true)
  let restored = OrganizationUseCases(repository: Store(), scheduler: scheduler, memory: memory)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await restored.restoreArchive(data)
  }
  #expect(try await restored.snapshot().birthdays == saved.birthdays)
  #expect(try await restored.snapshot().schedules[0].state == .cancellationPending)
  #expect(await scheduler.permissionCalls == 0)
  #expect(await scheduler.installed.isEmpty)
  await scheduler.setRemovalFailure(false)
  let recovered = try await restored.reconcile()
  #expect(recovered.schedules[0].state == .disabled)
  #expect(await scheduler.permissionCalls == 0)
  #expect(await scheduler.installed.isEmpty)
}

@Test(arguments: [false, true])
func failedAdapterRollbackStaysPendingUntilCancellationFinishes(alreadyApproved: Bool) async throws
{
  let (useCases, _, _, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 2, day: 29))
  let proposal = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  if alreadyApproved { _ = try await useCases.approve(proposal, approved: true) }
  await scheduler.setRollbackPending(true)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await useCases.approve(proposal, approved: true)
  }
  #expect(try await useCases.snapshot().schedules[0].state == .cancellationPending)
  #expect(await scheduler.installed.count == 1)
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await useCases.reconcile() }
  #expect(try await useCases.snapshot().schedules[0].state == .cancellationPending)
  await scheduler.setRemovalFailure(false)
  let disabled = try await useCases.reconcile()
  #expect(disabled.schedules[0].state == .disabled)
  #expect(await scheduler.installed.isEmpty)
}

@Test func reconcilePersistsFailedAdapterRollbackBeforeReturning() async throws {
  let (useCases, _, _, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 2, day: 29))
  let proposal = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  _ = try await useCases.approve(proposal, approved: true)
  await scheduler.setRollbackPending(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await useCases.reconcile() }
  #expect(try await useCases.snapshot().schedules[0].state == .cancellationPending)
  let disabled = try await useCases.reconcile()
  #expect(disabled.schedules[0].state == .disabled)
  #expect(await scheduler.installed.isEmpty)
  #expect(await scheduler.permissionCalls == 1)
}

@Test(arguments: ["new", "idempotent", "reconcile"])
func failedOutcomeReceiptRequiresCancellationBeforeAnyReopenedUpsert(operation: String) async throws
{
  let (useCases, memory, store, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 2, day: 29))
  let proposal = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  if operation != "new" { _ = try await useCases.approve(proposal, approved: true) }
  await scheduler.setRollbackPending(true)
  // First write persists the pre-call pending intent; the failed second write is the OS outcome.
  await store.failAfter(2)
  await #expect(throws: OrganizationError.storage) {
    if operation == "reconcile" { return try await useCases.reconcile() }
    return try await useCases.approve(proposal, approved: true)
  }
  #expect(await store.value.schedules[0].state == .pending)
  #expect(await scheduler.installed.count == 1)
  let attemptedBeforeReopen = await scheduler.upserts
  let permissionsBeforeReopen = await scheduler.permissionCalls
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  await scheduler.setRollbackPending(false)
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await reopened.reconcile() }
  #expect(await scheduler.upserts == attemptedBeforeReopen)
  #expect(await store.value.schedules[0].state == .pending)
  #expect(await scheduler.installed.count == 1)
  await scheduler.setRemovalFailure(false)
  let recovered = try await reopened.reconcile()
  #expect(await scheduler.removals == 1)
  #expect(await scheduler.upserts == attemptedBeforeReopen + 1)
  #expect(await scheduler.permissionCalls == permissionsBeforeReopen)
  let current = try #require(recovered.schedules.first)
  #expect(current.state == .active)
  #expect(current.id == proposal.id && current.month == 2 && current.day == 29)
  #expect(current.hour == 9 && current.minute == 15 && current.timeZoneID == "Asia/Baghdad")
  #expect(current.title == proposal.title && current.delivery == .calendar)
}

@Test func successfulOSWriteWithFailedOutcomeReceiptAlsoCancelsBeforeReopenRetry() async throws {
  let (useCases, memory, store, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  let proposal = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .notification, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  await store.failAfter(2)
  await #expect(throws: OrganizationError.storage) {
    try await useCases.approve(proposal, approved: true)
  }
  #expect(await store.value.schedules[0].state == .pending)
  #expect(await scheduler.installed.count == 1)
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await reopened.reconcile() }
  #expect(await scheduler.upserts == 1)
  await scheduler.setRemovalFailure(false)
  let recovered = try await reopened.reconcile()
  #expect(recovered.schedules[0].state == .active)
  #expect(await scheduler.removals == 1)
  #expect(await scheduler.upserts == 2)
}

@Test(arguments: ["newReview", "disableThenReview"])
func externalCalendarConflictSurvivesRetriesReopenAndOldApprovalReplay(resolution: String)
  async throws
{
  let (useCases, memory, store, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  let original = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  _ = try await useCases.approve(original, approved: true)
  let oldIdempotentPreview = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  _ = try await useCases.approve(oldIdempotentPreview, approved: true)
  await scheduler.setReviewConflict(true)
  await #expect(throws: OrganizationError.stalePreview) { try await useCases.reconcile() }
  #expect(try await useCases.snapshot().schedules[0].state == .reviewRequired)
  let upsertsAfterConflict = await scheduler.upserts
  await #expect(throws: OrganizationError.stalePreview) { try await useCases.reconcile() }
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  await #expect(throws: OrganizationError.stalePreview) { try await reopened.reconcile() }
  await #expect(throws: OrganizationError.stalePreview) {
    try await reopened.approve(original, approved: true)
  }
  // This old preview has another UUID because identical approvals coalesce into the original schedule.
  await #expect(throws: OrganizationError.stalePreview) {
    try await reopened.approve(oldIdempotentPreview, approved: true)
  }
  #expect(await scheduler.upserts == upsertsAfterConflict)
  #expect(await scheduler.removals == 0)
  #expect(await scheduler.installed.count == 1)
  if resolution == "disableThenReview" {
    _ = try await reopened.disableBirthday(saved.birthdays[0].id)
    #expect(await scheduler.installed.isEmpty)
  }
  let fresh = try await reopened.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  let replaced = try await reopened.approve(fresh, approved: true)
  #expect(replaced.schedules.first { $0.id == original.id }?.state == .disabled)
  #expect(replaced.schedules.first { $0.id == fresh.id }?.state == .active)
  #expect(await scheduler.upserts == upsertsAfterConflict + 1)
  #expect(await scheduler.removals == 1)
}

@Test func conflictOutcomeSaveFailureCannotTurnRecoveryIntoAnOverwrite() async throws {
  let (useCases, memory, store, scheduler, person) = try await fixture()
  let saved = try await useCases.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  let proposal = try await useCases.previewSchedule(
    birthdayID: saved.birthdays[0].id,
    delivery: .calendar, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad")
  _ = try await useCases.approve(proposal, approved: true)
  await scheduler.setReviewConflict(true)
  await store.failAfter(2)
  await #expect(throws: OrganizationError.storage) { try await useCases.reconcile() }
  #expect(await store.value.schedules[0].state == .pending)
  let upsertsAfterConflict = await scheduler.upserts
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  await #expect(throws: OrganizationError.stalePreview) { try await reopened.reconcile() }
  #expect(try await reopened.snapshot().schedules[0].state == .reviewRequired)
  await #expect(throws: OrganizationError.stalePreview) { try await reopened.reconcile() }
  #expect(await scheduler.removals == 0)
  #expect(await scheduler.upserts == upsertsAfterConflict)
}

@Test func versionOneOrganizationStorageAndArchiveUpgradeWithoutChangingStableData() async throws {
  let (original, memory, _, scheduler, person) = try await fixture()
  let saved = try await original.saveBirthday(
    personID: person, date: BirthdayDate(month: 3, day: 12))
  var old = OrganizationSnapshot()
  old.formatVersion = 1
  old.revision = 7
  old.birthdays = saved.birthdays
  old.schedules = [
    BirthdaySchedule(
      birthdayID: saved.birthdays[0].id, personID: person,
      month: 3, day: 12, hour: 9, minute: 15, timeZoneID: "Asia/Baghdad", delivery: .calendar,
      title: "Fictional Noor", state: .active)
  ]
  let bytes = try JSONEncoder().encode(old)
  let directory = URL.temporaryDirectory.appending(
    path: "memoryos-organization-migration-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let path = directory.appending(path: "organization.json")
  try bytes.write(to: path)
  let loaded = try await FileOrganizationRepository(url: path).load()
  #expect(loaded.formatVersion == OrganizationSnapshot.currentFormatVersion)
  #expect(
    loaded.revision == 7 && loaded.birthdays == old.birthdays && loaded.schedules == old.schedules)
  let restored = OrganizationUseCases(repository: Store(), scheduler: scheduler, memory: memory)
  let result = try await restored.restoreArchive(bytes)
  #expect(result.schedules[0].id == old.schedules[0].id && result.schedules[0].state == .disabled)
  #expect(result.schedules[0].stateBeforeRestore == .active)
  old.schedules[0].state = .reviewRequired
  #expect(throws: OrganizationError.invalidArchive) { try old.upgradedToCurrentFormat() }
}

@Test func erasedRuleReferencesExportRestoreAndUndoOnlySurvivingMetadata() async throws {
  let (organization, memory, _, _, _) = try await fixture()
  let erased = PersonalMemorySource(text: "meeting erased", kind: .plan)
  let retained = PersonalMemorySource(text: "meeting retained", kind: .plan)
  _ = try await memory.ingest(source: erased)
  _ = try await memory.ingest(source: retained)
  let rule = OrganizationRule(
    name: "Meetings", filter: OrganizationFilter(text: "meeting"), category: "Work")
  _ = try await organization.saveRule(rule)
  _ = try await organization.applyRule(organization.testRule(rule.id))
  _ = try await memory.forgetSource(sourceID: erased.id, confirmed: true)
  let personalBytes = try await memory.exportArchive()
  let organizationBytes = try await organization.exportArchive()
  let restoredMemory = PersonalMemoryUseCases(repository: MemoryStore())
  _ = try await restoredMemory.restoreArchive(personalBytes)
  let restored = OrganizationUseCases(
    repository: Store(), scheduler: Scheduler(), memory: restoredMemory)
  let snapshot = try await restored.restoreArchive(organizationBytes)
  let receipt = try #require(snapshot.applications.first)
  #expect(receipt.changes.count == 1)
  _ = try await restored.undoRule(receipt.id)
  let graph = try await restoredMemory.snapshot()
  #expect(!graph.sources.contains { $0.id == erased.id })
  #expect(graph.sources.contains(retained))
  #expect(graph.currentEntries.allSatisfy { !$0.categories.contains("Work") })
  // A manually changed survivor must still reject undo after pruning another erased reference.
  let applied = try await restored.applyRule(restored.testRule(rule.id))
  let entry = try #require(try await restoredMemory.snapshot().currentEntries.first)
  _ = try await restoredMemory.organize(
    entryID: entry.id, categories: ["Manual"], profileIDs: entry.profileIDs)
  await #expect(throws: PersonalMemoryError.staleAnalysis) {
    try await restored.undoRule(applied.applications[0].id)
  }
}

@Test func explicitPersonMergeCanonicalizesFiltersReceiptsAndRequiresBirthdayDateReview()
  async throws
{
  let (organization, memory, store, scheduler, from) = try await fixture()
  let people = try await memory.createProfile(kind: .person, name: "Fictional survivor")
  let into = try #require(people.profiles.first { $0.kind == .person && $0.id != from }?.id)
  let source = PersonalMemorySource(text: "meeting with Noor", kind: .plan)
  _ = try await memory.ingest(source: source)
  _ = try await memory.addEntry(
    text: "meeting with Noor", kind: .plan, sourceIDs: [source.id], profileIDs: [from])
  let rule = OrganizationRule(
    name: "Person meetings", filter: OrganizationFilter(profileID: from), category: "Work")
  _ = try await organization.saveRule(rule)
  let applied = try await organization.applyRule(organization.testRule(rule.id))
  let view = SavedMemoryView(name: "Person", filter: OrganizationFilter(profileID: from))
  _ = try await organization.saveView(view)
  var dates = try await organization.saveBirthday(
    personID: from, date: BirthdayDate(month: 3, day: 12))
  let retiredBirthday = dates.birthdays[0]
  let oldApproval = try await organization.previewSchedule(
    birthdayID: retiredBirthday.id, delivery: .notification, hour: 9, minute: 0, timeZoneID: "UTC")
  _ = try await organization.approve(oldApproval, approved: true)
  dates = try await organization.saveBirthday(personID: into, date: BirthdayDate(month: 5, day: 6))
  let survivorBirthday = try #require(dates.birthdays.first { $0.personID == into })
  let survivorApproval = try await organization.previewSchedule(
    birthdayID: survivorBirthday.id, delivery: .notification, hour: 10, minute: 0, timeZoneID: "UTC"
  )
  _ = try await organization.approve(survivorApproval, approved: true)
  let staleRulePreview = try await organization.testRule(rule.id)
  let upsertsBeforeMerge = await scheduler.upserts
  _ = try await memory.mergePeople(from: from, into: into, confirmed: true)
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await organization.refreshReferences()
  }
  #expect(
    try await organization.snapshot().schedules.first { $0.id == oldApproval.id }?.state
      == .cancellationPending)
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  await scheduler.setRemovalFailure(false)
  let refreshed = try await reopened.refreshReferences()
  #expect(
    refreshed.rules[0].filter.profileID == into && refreshed.views[0].filter.profileID == into)
  #expect(try await reopened.entries(in: view).count == 1)
  #expect(await scheduler.upserts == upsertsBeforeMerge)
  await #expect(throws: OrganizationError.stalePreview) {
    try await reopened.applyRule(staleRulePreview)
  }
  await #expect(throws: OrganizationError.stalePreview) {
    try await reopened.approve(oldApproval, approved: true)
  }
  _ = try await reopened.undoRule(applied.applications[0].id)
  #expect(
    try await memory.snapshot().currentEntries.allSatisfy {
      !$0.categories.contains("Work") && ($0.profileIDs.isEmpty || $0.profileIDs == [into])
    })
  let review = try #require(try await reopened.mergedBirthdayReviews().first)
  #expect(review.personID == into && review.existingBirthdayID == survivorBirthday.id)
  #expect(
    try await reopened.snapshot().birthdays.first { $0.id == survivorBirthday.id }?.date
      == BirthdayDate(month: 5, day: 6))
  await #expect(throws: OrganizationError.approvalRequired) {
    try await reopened.resolveMergedBirthday(
      review, date: retiredBirthday.date, confirmed: false)
  }
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await reopened.resolveMergedBirthday(
      review, date: retiredBirthday.date, confirmed: true)
  }
  let interrupted = try await reopened.snapshot()
  #expect(
    interrupted.birthdays.first { $0.id == retiredBirthday.id }?.resolvedIntoBirthdayID
      == survivorBirthday.id)
  #expect(
    interrupted.schedules.first { $0.id == survivorApproval.id }?.state == .cancellationPending)
  await scheduler.setRemovalFailure(false)
  let afterResolutionReopen = OrganizationUseCases(
    repository: store, scheduler: scheduler, memory: memory)
  let resolved = try await afterResolutionReopen.refreshReferences()
  #expect(
    resolved.birthdays.first { $0.id == retiredBirthday.id }?.resolvedIntoBirthdayID
      == survivorBirthday.id)
  #expect(
    resolved.birthdays.first { $0.id == survivorBirthday.id }?.previousDates == [
      BirthdayDate(month: 5, day: 6)
    ])
  #expect(resolved.schedules.allSatisfy { $0.state == .disabled })
  #expect(await scheduler.installed.isEmpty)
  #expect(await scheduler.upserts == upsertsBeforeMerge)
  #expect(try await reopened.mergedBirthdayReviews().isEmpty)
}

@Test func versionTwoBirthdayHistoryMigratesAndResolutionReferencesRemainBounded() throws {
  var old = OrganizationSnapshot()
  old.formatVersion = 2
  let person = UUID()
  let birthday = BirthdayRecord(
    personID: person, date: BirthdayDate(month: 3), previousDates: [BirthdayDate(year: 1990)])
  old.birthdays = [birthday]
  old.views = [SavedMemoryView(name: "Person", filter: OrganizationFilter(profileID: person))]
  let migrated = try old.upgradedToCurrentFormat()
  #expect(migrated.birthdays == old.birthdays && migrated.views == old.views)
  #expect(migrated.formatVersion == OrganizationSnapshot.currentFormatVersion)
  var invalid = migrated
  invalid.birthdays[0].resolvedIntoBirthdayID = UUID()
  #expect(throws: OrganizationError.invalidArchive) { try invalid.validate() }
  invalid.birthdays[0].resolvedIntoBirthdayID = birthday.id
  #expect(throws: OrganizationError.invalidArchive) { try invalid.validate() }
}

@Test func mergePropagationReversesAfterUndoReopenAndTransitiveMerges() async throws {
  let (org, memory, store, scheduler, a) = try await fixture()
  var people = try await memory.createProfile(kind: .person, name: "B")
  let b = try #require(people.profiles.first { $0.kind == .person && $0.id != a }?.id)
  people = try await memory.createProfile(kind: .person, name: "C")
  let c = try #require(people.profiles.first { $0.kind == .person && $0.id != a && $0.id != b }?.id)
  let source = PersonalMemorySource(text: "meeting", kind: .plan)
  _ = try await memory.ingest(source: source)
  _ = try await memory.addEntry(
    text: "meeting", kind: .plan, sourceIDs: [source.id], profileIDs: [a])
  let rule = OrganizationRule(name: "A", filter: OrganizationFilter(profileID: a), category: "Work")
  _ = try await org.saveRule(rule)
  let receipt = try await org.applyRule(org.testRule(rule.id)).applications[0]
  _ = try await org.saveView(SavedMemoryView(name: "A", filter: OrganizationFilter(profileID: a)))
  _ = try await memory.mergePeople(from: a, into: b, confirmed: true)
  await store.setFailure(true)
  await #expect(throws: OrganizationError.storage) { try await org.refreshReferences() }
  #expect(await store.value.rules[0].filter.profileID == a)
  #expect(await store.value.rules[0].filter.originalProfileID == nil)
  await store.setFailure(false)
  var value = try await org.refreshReferences()
  #expect(value.rules[0].filter.profileID == b)
  _ = try await memory.mergePeople(from: b, into: c, confirmed: true)
  value = try await org.refreshReferences()
  #expect(value.rules[0].filter.profileID == c)
  _ = try await memory.undo()
  value = try await org.refreshReferences()
  #expect(value.rules[0].filter.profileID == b)
  var edited = value.views[0]
  edited.filter.profileID = c
  _ = try await org.saveView(edited)
  _ = try await memory.undo()
  let reopened = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  value = try await reopened.refreshReferences()
  #expect(value.rules[0].filter.profileID == a && value.views[0].filter.profileID == c)
  #expect(value.applications[0].changes[0].profileIDs == [a])
  _ = try await reopened.undoRule(receipt.id)
  #expect(try await memory.snapshot().currentEntries.allSatisfy { !$0.categories.contains("Work") })
}

@Test func birthdayReviewBindsBothRevisionsTargetAndBothDateChoices() async throws {
  let (org, memory, _, scheduler, a) = try await fixture()
  var people = try await memory.createProfile(kind: .person, name: "B")
  let b = try #require(people.profiles.first { $0.kind == .person && $0.id != a }?.id)
  people = try await memory.createProfile(kind: .person, name: "C")
  let c = try #require(people.profiles.first { $0.kind == .person && $0.id != a && $0.id != b }?.id)
  _ = try await org.saveBirthday(personID: a, date: BirthdayDate(month: 3, day: 12))
  _ = try await org.saveBirthday(personID: b, date: BirthdayDate(month: 5, day: 6))
  _ = try await memory.mergePeople(from: a, into: b, confirmed: true)
  let old = try #require(try await org.mergedBirthdayReviews().first)
  _ = try await org.saveBirthday(personID: b, date: BirthdayDate(month: 5, day: 7))
  let afterDate = try await org.snapshot()
  await #expect(throws: OrganizationError.stalePreview) {
    try await org.resolveMergedBirthday(old, date: old.date, confirmed: true)
  }
  #expect(try await org.snapshot() == afterDate)
  let newer = try #require(try await org.mergedBirthdayReviews().first)
  _ = try await memory.mergePeople(from: b, into: c, confirmed: true)
  let afterTarget = try await org.snapshot()
  await #expect(throws: OrganizationError.stalePreview) {
    try await org.resolveMergedBirthday(newer, date: newer.date, confirmed: true)
  }
  #expect(try await org.snapshot() == afterTarget)
  #expect(await scheduler.upserts == 0)
  #expect(await scheduler.removals == 0)
}

private actor HeldRemovalScheduler: BirthdayScheduling {
  var installed: [UUID: BirthdaySchedule] = [:]
  private var hold = false
  private var gate: CheckedContinuation<Void, Never>?
  private var observer: CheckedContinuation<Void, Never>?
  func requestPermission(for delivery: BirthdayDelivery) -> Bool { true }
  func validateExisting(_ schedule: BirthdaySchedule) {}
  func upsert(_ schedule: BirthdaySchedule) { installed[schedule.id] = schedule }
  func pauseNextRemoval() { hold = true }
  func waitForRemoval() async {
    if gate != nil { return }
    await withCheckedContinuation { observer = $0 }
  }
  func resumeRemoval() {
    gate?.resume()
    gate = nil
  }
  func remove(_ schedule: BirthdaySchedule) async {
    if hold {
      hold = false
      await withCheckedContinuation {
        gate = $0
        observer?.resume()
        observer = nil
      }
    }
    installed[schedule.id] = nil
  }
}

@Test func mergeDuringHeldBirthdayCancellationCannotRetargetTheReviewedDateOrApproval() async throws
{
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let scheduler = HeldRemovalScheduler()
  let org = OrganizationUseCases(repository: Store(), scheduler: scheduler, memory: memory)
  var ids: [UUID] = []
  for name in ["A", "B", "C"] {
    let graph = try await memory.createProfile(kind: .person, name: name)
    ids.append(try #require(graph.profiles.first { $0.name == name }?.id))
  }
  var birthdays: [BirthdayRecord] = []
  var approvals: [BirthdaySchedule] = []
  for (index, id) in ids.enumerated() {
    let value = try await org.saveBirthday(
      personID: id, date: BirthdayDate(month: index + 3, day: index + 10))
    let birthday = try #require(value.birthdays.first { $0.personID == id })
    birthdays.append(birthday)
    let approval = try await org.previewSchedule(
      birthdayID: birthday.id, delivery: .notification, hour: 9, minute: 0, timeZoneID: "UTC")
    approvals.append(approval)
    _ = try await org.approve(approval, approved: true)
  }
  _ = try await memory.mergePeople(from: ids[0], into: ids[1], confirmed: true)
  let review = try #require(try await org.mergedBirthdayReviews().first)
  await scheduler.pauseNextRemoval()
  let resolution = Task {
    try await org.resolveMergedBirthday(review, date: review.date, confirmed: true)
  }
  await scheduler.waitForRemoval()
  _ = try await memory.mergePeople(from: ids[1], into: ids[2], confirmed: true)
  await scheduler.resumeRemoval()
  let result = try await resolution.value
  // B was the reviewed target before any OS await. C never inherits B's chosen date or cancellation.
  #expect(result.birthdays.first { $0.personID == ids[1] }?.date == review.date)
  #expect(result.birthdays.first { $0.personID == ids[2] }?.date == birthdays[2].date)
  #expect(result.schedules.first { $0.id == approvals[2].id }?.state == .active)
  #expect(await scheduler.installed[approvals[2].id] != nil)
  #expect(
    result.birthdays.first { $0.id == birthdays[0].id }?.resolvedIntoBirthdayID == birthdays[1].id)
}

@Test func removedPersonBirthdayIsAnInertRestorableReferenceAndApprovalNeverReturns() async throws {
  let (org, memory, store, scheduler, person) = try await fixture()
  let beforeUndoPersonal = try await memory.exportArchive()
  let saved = try await org.saveBirthday(personID: person, date: BirthdayDate(month: 3, day: 12))
  let approval = try await org.previewSchedule(
    birthdayID: saved.birthdays[0].id, delivery: .calendar, hour: 9, minute: 0, timeZoneID: "UTC")
  _ = try await org.approve(approval, approved: true)
  // Person creation belongs to personal memory; birthday data belongs to organization.
  _ = try await memory.undo()
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await org.refreshReferences() }
  let pending = try await org.snapshot()
  #expect(pending.unavailableProfileIDs == [person])
  #expect(pending.schedules[0].state == .cancellationPending)
  let personalBytes = try await memory.exportArchive()
  let bytes = try await org.exportArchive()
  let restoredMemory = PersonalMemoryUseCases(repository: MemoryStore())
  _ = try await restoredMemory.restoreArchive(personalBytes)
  let restoredStore = Store()
  let restoredScheduler = Scheduler()
  let restored = OrganizationUseCases(
    repository: restoredStore, scheduler: restoredScheduler, memory: restoredMemory)
  let snapshot = try await restored.restoreArchive(bytes)
  #expect(snapshot.birthdays == saved.birthdays && snapshot.schedules[0].state == .disabled)
  #expect(try await restoredMemory.snapshot().profiles.allSatisfy { $0.id != person })
  #expect(await restoredScheduler.upserts == 0)
  var malformed = snapshot
  malformed.schedules[0].state = .active
  #expect(throws: OrganizationError.invalidArchive) { try malformed.validate() }
  malformed = snapshot
  malformed.unavailableProfileIDs = nil
  let invalidBytes = try JSONEncoder().encode(malformed)
  let empty = OrganizationUseCases(
    repository: Store(), scheduler: Scheduler(), memory: restoredMemory)
  await #expect(throws: OrganizationError.missingReferences) {
    try await empty.restoreArchive(invalidBytes)
  }
  malformed = snapshot
  malformed.unavailableProfileIDs = [UUID()]
  #expect(throws: OrganizationError.invalidArchive) { try malformed.validate() }
  // Restoring the exact old person ID later does not restore an OS delivery approval.
  let personRestored = PersonalMemoryUseCases(repository: MemoryStore())
  _ = try await personRestored.restoreArchive(beforeUndoPersonal)
  let reopened = OrganizationUseCases(
    repository: restoredStore, scheduler: restoredScheduler, memory: personRestored)
  let reappeared = try await reopened.refreshReferences()
  #expect(reappeared.unavailableProfileIDs == nil && reappeared.schedules[0].state == .disabled)
  #expect(await restoredScheduler.upserts == 0)
  // Original device retains its cancellation intent until removal can finish.
  await scheduler.setRemovalFailure(false)
  let originalReopen = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  #expect(try await originalReopen.refreshReferences().schedules[0].state == .disabled)
}

@Test func removedPersonFiltersStayNarrowAndReceiptProvenanceNeverRecreatesThePerson() async throws
{
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let source = PersonalMemorySource(text: "retained original", kind: .plan)
  _ = try await memory.ingest(source: source)
  let entry = try #require(try await memory.snapshot().currentEntries.first)
  let people = try await memory.createProfile(kind: .person, name: "Fictional removed")
  let person = try #require(people.profiles.first { $0.kind == .person }?.id)
  _ = try await memory.organize(entryID: entry.id, categories: [], profileIDs: [person])
  let org = OrganizationUseCases(repository: Store(), scheduler: Scheduler(), memory: memory)
  let rule = OrganizationRule(
    name: "Person only", filter: OrganizationFilter(profileID: person), category: "Work")
  _ = try await org.saveRule(rule)
  let applied = try await org.applyRule(org.testRule(rule.id))
  let view = SavedMemoryView(name: "Person only", filter: OrganizationFilter(profileID: person))
  _ = try await org.saveView(view)
  _ = try await memory.undo()  // rule metadata
  _ = try await memory.undo()  // profile attachment
  _ = try await memory.undo()  // person creation
  let current = try await org.refreshReferences()
  #expect(current.unavailableProfileIDs == [person])
  #expect(
    current.rules[0].filter.profileID == person && current.views[0].filter.profileID == person)
  #expect(try await org.testRule(rule.id).entryIDs.isEmpty)
  #expect(try await org.entries(in: view).isEmpty)
  #expect(current.applications[0].changes[0].profileIDs.isEmpty)
  #expect(current.applications[0].originalChanges?.first?.profileIDs == [person])
  _ = try await memory.organize(entryID: entry.id, categories: ["Manual"], profileIDs: [])
  let restoredMemory = PersonalMemoryUseCases(repository: MemoryStore())
  _ = try await restoredMemory.restoreArchive(memory.exportArchive())
  let restored = OrganizationUseCases(
    repository: Store(), scheduler: Scheduler(), memory: restoredMemory)
  _ = try await restored.restoreArchive(org.exportArchive())
  await #expect(throws: PersonalMemoryError.staleAnalysis) {
    try await restored.undoRule(applied.applications[0].id)
  }
  #expect(try await restoredMemory.snapshot().sources.contains(source))
  #expect(
    try await restoredMemory.snapshot().currentEntries.allSatisfy {
      $0.profileIDs.isEmpty && $0.categories == ["Manual"]
    })
  var invalid = current
  invalid.rules[0].filter.originalProfileID = person
  invalid.rules[0].filter.profileID = nil
  #expect(throws: OrganizationError.invalidArchive) { try invalid.validate() }
}

@Test func missingPersonCancellationFailureDoesNotTouchAnotherPersonsApprovedSchedule() async throws
{
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let scheduler = Scheduler()
  let store = Store()
  let org = OrganizationUseCases(repository: store, scheduler: scheduler, memory: memory)
  var approvals: [BirthdaySchedule] = []
  for name in ["Survivor", "Removed"] {
    let graph = try await memory.createProfile(kind: .person, name: name)
    let id = try #require(graph.profiles.first { $0.name == name }?.id)
    let saved = try await org.saveBirthday(personID: id, date: BirthdayDate(month: 3, day: 12))
    let birthday = try #require(saved.birthdays.first { $0.personID == id })
    let approval = try await org.previewSchedule(
      birthdayID: birthday.id, delivery: .notification, hour: 9, minute: 0, timeZoneID: "UTC")
    approvals.append(approval)
    _ = try await org.approve(approval, approved: true)
  }
  let before = await scheduler.installed[approvals[0].id]
  _ = try await memory.undo()
  await scheduler.setRemovalFailure(true)
  await #expect(throws: OrganizationError.cancellationPending) { try await org.refreshReferences() }
  #expect(try await org.snapshot().schedules.first { $0.id == approvals[0].id }?.state == .active)
  #expect(await scheduler.installed[approvals[0].id] == before)
  #expect(await scheduler.upserts == 2)
  #expect(await scheduler.permissionCalls == 2)
  let restoredMemory = PersonalMemoryUseCases(repository: MemoryStore())
  _ = try await restoredMemory.restoreArchive(memory.exportArchive())
  let restoreScheduler = Scheduler()
  await restoreScheduler.setRemovalFailure(true)
  let restored = OrganizationUseCases(
    repository: Store(), scheduler: restoreScheduler, memory: restoredMemory)
  await #expect(throws: OrganizationError.cancellationPending) {
    try await restored.restoreArchive(org.exportArchive())
  }
  #expect(await restoreScheduler.upserts == 0)
  #expect(await restoreScheduler.permissionCalls == 0)
}

@Test(arguments: ["delete", "any", "live"])
func removingTheLastUnavailableViewReferencePrunesOnlyItsLedgerEntry(action: String) async throws {
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let liveGraph = try await memory.createProfile(kind: .person, name: "Live")
  let live = try #require(liveGraph.profiles.first { $0.kind == .person }?.id)
  let graph = try await memory.createProfile(kind: .person, name: "Removed")
  let removed = try #require(graph.profiles.first { $0.name == "Removed" }?.id)
  let store = Store()
  let org = OrganizationUseCases(repository: store, scheduler: Scheduler(), memory: memory)
  let view = SavedMemoryView(name: "Person only", filter: OrganizationFilter(profileID: removed))
  _ = try await org.saveView(view)
  _ = try await memory.undo()
  #expect(try await org.refreshReferences().unavailableProfileIDs == [removed])
  let result: OrganizationSnapshot
  if action == "delete" {
    result = try await org.deleteView(view.id)
  } else {
    result = try await org.saveView(
      SavedMemoryView(
        id: view.id, name: view.name,
        filter: OrganizationFilter(profileID: action == "live" ? live : nil)))
  }
  #expect(result.unavailableProfileIDs == nil)
  #expect(await store.value.unavailableProfileIDs == nil)
  try result.validate()
  if action != "delete" {
    #expect(result.views[0].filter.profileID == (action == "live" ? live : nil))
  }
}

@Test func removingTheLastUnavailableReceiptReferenceAllowsSafeUndo() async throws {
  let memory = PersonalMemoryUseCases(repository: MemoryStore())
  let source = PersonalMemorySource(text: "retained receipt source", kind: .plan)
  _ = try await memory.ingest(source: source)
  let entry = try #require(try await memory.snapshot().currentEntries.first)
  let graph = try await memory.createProfile(kind: .person, name: "Removed")
  let person = try #require(graph.profiles.first { $0.kind == .person }?.id)
  _ = try await memory.organize(
    entryID: entry.id, categories: entry.categories, profileIDs: [person])
  let org = OrganizationUseCases(repository: Store(), scheduler: Scheduler(), memory: memory)
  let rule = OrganizationRule(
    name: "Person only", filter: OrganizationFilter(profileID: person), category: "Work")
  _ = try await org.saveRule(rule)
  let applied = try await org.applyRule(org.testRule(rule.id))
  _ = try await memory.undo()
  _ = try await memory.undo()
  _ = try await memory.undo()
  #expect(try await org.refreshReferences().unavailableProfileIDs == [person])
  // An explicit filter edit removes the rule's reference, leaving only the inert undo provenance.
  _ = try await org.saveRule(
    OrganizationRule(
      id: rule.id, name: rule.name, filter: OrganizationFilter(), category: rule.category))
  #expect(try await org.snapshot().unavailableProfileIDs == [person])
  let result = try await org.undoRule(applied.applications[0].id)
  #expect(result.applications.isEmpty && result.unavailableProfileIDs == nil)
  #expect(try await memory.snapshot().sources.contains(source))
  #expect(
    try await memory.snapshot().currentEntries.allSatisfy {
      $0.profileIDs.isEmpty && $0.categories == entry.categories
    })
}

@Test func editingTheOnlyUnavailableRuleFilterPrunesTheLedger() async throws {
  let (org, memory, _, _, person) = try await fixture()
  let rule = OrganizationRule(
    name: "Person only", filter: OrganizationFilter(profileID: person), category: "Work")
  _ = try await org.saveRule(rule)
  _ = try await memory.undo()
  #expect(try await org.refreshReferences().unavailableProfileIDs == [person])
  let result = try await org.saveRule(
    OrganizationRule(
      id: rule.id, name: rule.name, filter: OrganizationFilter(), category: rule.category))
  #expect(result.unavailableProfileIDs == nil && result.rules[0].filter.profileID == nil)
}
