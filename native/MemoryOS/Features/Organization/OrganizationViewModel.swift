import Foundation
import MemoryCore
import Observation
import OrganizationCore

@MainActor @Observable final class OrganizationViewModel {
  private(set) var snapshot = OrganizationSnapshot()
  private(set) var memory = PersonalMemorySnapshot()
  private(set) var isBusy = false
  private(set) var error: OrganizationError?
  private(set) var schedulePreview: BirthdaySchedule?
  private(set) var rulePreview: RulePreview?
  private(set) var selectedView: SavedMemoryView?
  private(set) var exportedArchive: Data?
  private(set) var mergedBirthdayReviews: [MergedBirthdayReview] = []
  @ObservationIgnored private let useCases: OrganizationUseCases
  @ObservationIgnored private let personal: PersonalMemoryUseCases
  @ObservationIgnored private let archiveRestore: RestoreOrganizationArchive?
  init(
    useCases: OrganizationUseCases, personal: PersonalMemoryUseCases,
    archiveRestore: RestoreOrganizationArchive? = nil
  ) {
    self.useCases = useCases
    self.personal = personal
    self.archiveRestore = archiveRestore
  }
  var canRestore: Bool {
    snapshot.birthdays.isEmpty && snapshot.schedules.isEmpty && snapshot.rules.isEmpty
      && snapshot.views.isEmpty && snapshot.applications.isEmpty
  }
  var people: [PersonalProfile] {
    memory.profiles.filter { $0.kind != .project && $0.mergedIntoID == nil }
  }
  var selectedEntries: [PersonalMemoryEntry] {
    guard let selectedView else { return [] }
    return memory.currentEntries.filter(selectedView.filter.matches)
  }
  func load() async {
    await run {
      let current = try await useCases.refreshReferences()
      let currentMemory = try await personal.snapshot()
      updateCurrentState(current, memory: currentMemory)
      mergedBirthdayReviews = try await useCases.mergedBirthdayReviews()
    }
  }
  private func updateCurrentState(
    _ current: OrganizationSnapshot, memory currentMemory: PersonalMemorySnapshot
  ) {
    if current.revision != snapshot.revision {
      schedulePreview = nil
      rulePreview = nil
    } else if currentMemory.revision != memory.revision {
      rulePreview = nil
    }
    snapshot = current
    memory = currentMemory
    if let id = selectedView?.id { selectedView = current.views.first { $0.id == id } }
  }
  private func run(_ action: () async throws -> Void) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await action()
      error = nil
    } catch let value as OrganizationError {
      error = value
      await refreshAfterFailure()
    } catch LocalMemoryError.archiveTooLarge {
      error = .limitReached
    } catch PersonalMemoryError.staleAnalysis {
      error = .stalePreview
      await refreshAfterFailure()
    } catch {
      self.error = .storage
      await refreshAfterFailure()
    }
  }
  private func refreshAfterFailure() async {
    let current = (try? await useCases.snapshot()) ?? snapshot
    let currentMemory = (try? await personal.snapshot()) ?? memory
    updateCurrentState(current, memory: currentMemory)
    if let reviews = try? await useCases.mergedBirthdayReviews() { mergedBirthdayReviews = reviews }
  }
  func resolveMergedBirthday(_ review: MergedBirthdayReview, date: BirthdayDate) async -> Bool {
    var success = false
    await run {
      let current = try await useCases.resolveMergedBirthday(review, date: date, confirmed: true)
      updateCurrentState(current, memory: try await personal.snapshot())
      mergedBirthdayReviews = try await useCases.mergedBirthdayReviews()
      success = true
    }
    return success
  }
  func saveBirthday(personID: UUID, year: String, month: String, day: String) async -> Bool {
    var success = false
    await run {
      func optional(_ text: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.compactMap(\.wholeNumberValue)
        guard digits.count == trimmed.count, !digits.isEmpty,
          let value = Int(digits.map(String.init).joined())
        else { throw OrganizationError.invalidDate }
        return value
      }
      snapshot = try await useCases.saveBirthday(
        personID: personID,
        date: BirthdayDate(year: optional(year), month: optional(month), day: optional(day)))
      success = true
    }
    return success
  }
  func previewBirthday(_ id: UUID, delivery: BirthdayDelivery, hour: Int, minute: Int, zone: String)
    async
  {
    await run {
      schedulePreview = try await useCases.previewSchedule(
        birthdayID: id, delivery: delivery,
        hour: hour, minute: minute, timeZoneID: zone)
    }
  }
  func approveSchedule() async {
    guard let schedulePreview else { return }
    await run {
      snapshot = try await useCases.approve(schedulePreview, approved: true)
      self.schedulePreview = nil
    }
  }
  func disableBirthday(_ id: UUID) async {
    await run { snapshot = try await useCases.disableBirthday(id) }
  }
  func reconcile() async { await run { snapshot = try await useCases.reconcile() } }
  func saveRule(
    id: UUID = UUID(), name: String, text: String, category: String,
    profileID: UUID? = nil, kind: PersonalMemoryKind? = nil, enabled: Bool = true
  ) async -> Bool {
    var success = false
    await run {
      snapshot = try await useCases.saveRule(
        OrganizationRule(
          id: id, name: name,
          filter: OrganizationFilter(text: text, profileID: profileID, kind: kind),
          category: category, enabled: enabled))
      rulePreview = nil
      success = true
    }
    return success
  }
  func toggleRule(_ rule: OrganizationRule) async {
    var changed = rule
    changed.enabled.toggle()
    await run {
      snapshot = try await useCases.saveRule(changed)
      rulePreview = nil
    }
  }
  func testRule(_ id: UUID) async {
    await run {
      rulePreview = try await useCases.testRule(id)
      memory = try await personal.snapshot()
    }
  }
  func applyRule() async {
    guard let rulePreview else { return }
    await run {
      snapshot = try await useCases.applyRule(rulePreview)
      memory = try await personal.snapshot()
      self.rulePreview = nil
    }
  }
  func undoRule(_ id: UUID) async {
    await run {
      snapshot = try await useCases.undoRule(id)
      memory = try await personal.snapshot()
    }
  }
  func saveView(
    id: UUID = UUID(), name: String, text: String, profileID: UUID? = nil,
    kind: PersonalMemoryKind? = nil
  ) async -> Bool {
    var success = false
    await run {
      snapshot = try await useCases.saveView(
        SavedMemoryView(
          id: id, name: name,
          filter: OrganizationFilter(text: text, profileID: profileID, kind: kind)))
      if selectedView?.id == id { selectedView = snapshot.views.first { $0.id == id } }
      success = true
    }
    return success
  }
  func deleteView(_ id: UUID) async {
    await run {
      snapshot = try await useCases.deleteView(id)
      if selectedView?.id == id { selectedView = nil }
    }
  }
  func openView(_ value: SavedMemoryView) async {
    await run {
      let current = try await useCases.refreshReferences()
      updateCurrentState(current, memory: try await personal.snapshot())
      selectedView = current.views.first { $0.id == value.id }
      guard selectedView != nil else { throw OrganizationError.missingView }
    }
  }
  func exportArchive() async -> Bool {
    var success = false
    await run {
      exportedArchive = try await useCases.exportArchive()
      success = true
    }
    return success
  }
  func finishExport(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      exportedArchive = nil
      error = nil
    case .failure(let failure):
      if isFileCancellation(failure) { exportedArchive = nil } else { error = .storage }
    }
  }
  func restoreArchive(_ url: URL) async -> Bool {
    guard let archiveRestore else {
      error = .storage
      return false
    }
    var success = false
    await run {
      snapshot = try await archiveRestore.execute(url)
      memory = try await personal.snapshot()
      schedulePreview = nil
      rulePreview = nil
      selectedView = nil
      success = true
    }
    return success
  }
  func fileOperationFailed(_ failure: Error) {
    if !isFileCancellation(failure) { error = .storage }
  }
  private func isFileCancellation(_ failure: Error) -> Bool {
    let cocoa = failure as NSError
    return cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError
  }
  func clearError() { error = nil }
  func dismissSchedule() { schedulePreview = nil }
  func dismissRule() { rulePreview = nil }
}
