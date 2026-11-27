import Foundation
import MemoryCore

public actor OrganizationUseCases {
  private let repository: any OrganizationRepository
  private let scheduler: any BirthdayScheduling
  private let memory: PersonalMemoryUseCases
  private var state: OrganizationSnapshot?
  private var busy = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  public init(
    repository: any OrganizationRepository, scheduler: any BirthdayScheduling,
    memory: PersonalMemoryUseCases
  ) {
    self.repository = repository
    self.scheduler = scheduler
    self.memory = memory
  }
  private func acquire() async {
    if !busy {
      busy = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }
  private func release() {
    if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
  }
  private func loaded() async throws -> OrganizationSnapshot {
    if let state { return state }
    let value = try await repository.load().upgradedToCurrentFormat()
    state = value
    return value
  }
  private func commit(_ proposed: OrganizationSnapshot) async throws -> OrganizationSnapshot {
    var next = proposed
    guard next.revision < UInt64.max - 1 else { throw OrganizationError.limitReached }
    next.revision += 1
    if let unavailable = next.unavailableProfileIDs {
      let referenced = next.referencedProfileIDs
      let retained = unavailable.filter(referenced.contains)
      next.unavailableProfileIDs = retained.isEmpty ? nil : retained
    }
    try next.validate()
    try await repository.save(next)
    state = next
    return next
  }
  /// Propagate explicit erasure and merges without generating new information or delivery approvals.
  public func refreshReferences() async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    return try await refreshReferencesLocked(cancelReminders: true)
  }
  private func refreshReferencesLocked(cancelReminders: Bool = false) async throws
    -> OrganizationSnapshot
  {
    let old = try await loaded()
    let graph = try await memory.snapshot()
    let profiles = Dictionary(uniqueKeysWithValues: graph.profiles.map { ($0.id, $0) })
    func canonical(_ id: UUID) -> UUID { profiles[id]?.mergedIntoID ?? id }
    func ids(_ values: [UUID]) -> [UUID] {
      let mapped = values.map(canonical).filter { profiles[$0] != nil }
      guard mapped != values else { return values }
      return Array(Set(mapped)).sorted { $0.uuidString < $1.uuidString }
    }
    let entries = Set(graph.entries.map(\.id))
    var next = old
    next.applications = old.applications.compactMap { application in
      let originals = (application.originalChanges ?? application.changes).filter {
        entries.contains($0.entryID)
      }
      let changes = originals.map {
        PersonalMemoryOrganizationChange(
          entryID: $0.entryID, categories: $0.categories,
          profileIDs: ids($0.profileIDs), expectedCategories: $0.expectedCategories,
          expectedProfileIDs: ids($0.expectedProfileIDs))
      }
      guard !changes.isEmpty else { return nil }
      var result = RuleApplication(
        id: application.id, ruleID: application.ruleID, changes: changes,
        applied: application.applied)
      if application.originalChanges != nil || changes != originals {
        result.originalChanges = originals
      }
      return result
    }
    func filter(_ original: OrganizationFilter) -> OrganizationFilter {
      var current = original
      if let id = original.originalProfileID ?? original.profileID {
        let target = canonical(id)
        if target != id || original.originalProfileID != nil { current.originalProfileID = id }
        current.profileID = target
      }
      return current
    }
    for index in next.rules.indices { next.rules[index].filter = filter(next.rules[index].filter) }
    for index in next.views.indices { next.views[index].filter = filter(next.views[index].filter) }
    for index in next.schedules.indices {
      if profiles[next.schedules[index].personID] == nil
        || canonical(next.schedules[index].personID) != next.schedules[index].personID,
        next.schedules[index].state != .disabled,
        next.schedules[index].state != .cancellationPending
      {
        next.schedules[index].state = .cancellationPending
      }
    }
    let missing = next.referencedProfileIDs.subtracting(profiles.keys).sorted {
      $0.uuidString < $1.uuidString
    }
    next.unavailableProfileIDs = missing.isEmpty ? nil : missing
    if next != old { next = try await commit(next) }
    return cancelReminders ? try await cancelPending(next) : next
  }
  public func mergedBirthdayReviews() async throws -> [MergedBirthdayReview] {
    let value = try await snapshot()
    return Self.birthdayReviews(value, graph: try await memory.snapshot())
  }
  private static func birthdayReviews(_ value: OrganizationSnapshot, graph: PersonalMemorySnapshot)
    -> [MergedBirthdayReview]
  {
    value.birthdays.compactMap { birthday in
      guard birthday.resolvedIntoBirthdayID == nil,
        let target = graph.profiles.first(where: { $0.id == birthday.personID })?.mergedIntoID
      else { return nil }
      let existing = value.birthdays.first { $0.personID == target }
      return MergedBirthdayReview(
        birthdayID: birthday.id, previousPersonID: birthday.personID,
        personID: target, date: birthday.date, existingBirthdayID: existing?.id,
        existingBirthdayDate: existing?.date, organizationRevision: value.revision,
        memoryRevision: graph.revision)
    }
  }
  /// The owner chooses the date after reviewing both people. Never transfer an old schedule approval.
  public func resolveMergedBirthday(
    _ review: MergedBirthdayReview, date: BirthdayDate, confirmed: Bool
  )
    async throws -> OrganizationSnapshot
  {
    guard confirmed else { throw OrganizationError.approvalRequired }
    try date.validate()
    await acquire()
    defer { release() }
    var next = try await loaded()
    let graph = try await memory.snapshot()
    guard Self.birthdayReviews(next, graph: graph).contains(review),
      let source = next.birthdays.firstIndex(where: { $0.id == review.birthdayID }),
      graph.profiles.contains(where: {
        $0.id == review.personID && $0.mergedIntoID == nil && $0.kind == .person
      })
    else { throw OrganizationError.stalePreview }
    let target = review.personID
    for i in next.schedules.indices
    where next.schedules[i].birthdayID == review.birthdayID && next.schedules[i].state != .disabled
    {
      next.schedules[i].state = .cancellationPending
    }
    let targetID: UUID
    if let index = next.birthdays.firstIndex(where: { $0.personID == target }) {
      targetID = next.birthdays[index].id
      if next.birthdays[index].date != date {
        next.birthdays[index].previousDates.append(next.birthdays[index].date)
        next.birthdays[index].previousDates = Array(next.birthdays[index].previousDates.suffix(50))
        next.birthdays[index].date = date
        for i in next.schedules.indices
        where next.schedules[i].birthdayID == targetID && next.schedules[i].state != .disabled {
          next.schedules[i].state = .cancellationPending
        }
      }
    } else {
      let birthday = BirthdayRecord(personID: target, date: date)
      targetID = birthday.id
      next.birthdays.append(birthday)
    }
    next.birthdays[source].resolvedIntoBirthdayID = targetID
    next = try await commit(next)
    return try await cancelPending(next)
  }

  public func snapshot() async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    return try await refreshReferencesLocked()
  }
  /// Readable, versioned app-owned data. Export does not change schedules on the source device.
  public func exportArchive() async throws -> Data {
    let value = try await snapshot()
    try value.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    guard data.count <= OrganizationSnapshot.maximumArchiveBytes else {
      throw OrganizationError.limitReached
    }
    return data
  }

  /// Restore personal memory first so stable references can be checked. No live data is replaced.
  /// Old approvals remain inspectable; delivery stays off until a new exact approval.
  public func restoreArchive(_ data: Data) async throws -> OrganizationSnapshot {
    guard data.count <= OrganizationSnapshot.maximumArchiveBytes else {
      throw OrganizationError.limitReached
    }
    var restored: OrganizationSnapshot
    do { restored = try JSONDecoder().decode(OrganizationSnapshot.self, from: data) } catch {
      throw OrganizationError.invalidArchive
    }
    restored = try restored.upgradedToCurrentFormat()
    await acquire()
    defer { release() }
    let old = try await loaded()
    guard old.birthdays.isEmpty, old.schedules.isEmpty, old.rules.isEmpty, old.views.isEmpty,
      old.applications.isEmpty
    else { throw OrganizationError.conflictingArchive }
    let personal = try await memory.snapshot()
    let profileIDs = Set(personal.profiles.map(\.id))
    let personIDs = Set(personal.profiles.filter { $0.kind != .project }.map(\.id))
    let entryIDs = Set(personal.entries.map(\.id))
    let allowedUnavailable = Set(restored.unavailableProfileIDs ?? []).subtracting(profileIDs)
    let allowedProfiles = profileIDs.union(allowedUnavailable)
    guard Set(restored.birthdays.map(\.personID)).isSubset(of: personIDs.union(allowedUnavailable)),
      Set(
        restored.rules.flatMap {
          [$0.filter.profileID, $0.filter.originalProfileID].compactMap { $0 }
        }
      ).isSubset(of: allowedProfiles),
      Set(
        restored.views.flatMap {
          [$0.filter.profileID, $0.filter.originalProfileID].compactMap { $0 }
        }
      ).isSubset(of: allowedProfiles),
      restored.applications.allSatisfy({ application in
        Set(application.changes.map(\.entryID)).isSubset(of: entryIDs)
          && Set(
            (application.changes + (application.originalChanges ?? [])).flatMap {
              $0.profileIDs + $0.expectedProfileIDs
            }
          ).isSubset(
            of: allowedProfiles)
      })
    else { throw OrganizationError.missingReferences }
    for index in restored.schedules.indices {
      let state = restored.schedules[index].state
      if state != .disabled {
        restored.schedules[index].stateBeforeRestore =
          restored.schedules[index].stateBeforeRestore ?? state
        // Remove stale same-device deliveries before claiming disabled. Never request permission here.
        restored.schedules[index].state = .cancellationPending
      }
    }
    restored.revision = old.revision
    let saved = try await commit(restored)
    return try await cancelPending(saved)
  }

  public func saveBirthday(personID: UUID, date: BirthdayDate) async throws -> OrganizationSnapshot
  {
    try date.validate()
    await acquire()
    defer { release() }
    let people = try await memory.snapshot().profiles
    guard
      people.contains(where: { $0.id == personID && $0.kind != .project && $0.mergedIntoID == nil })
    else { throw OrganizationError.missingPerson }
    var next = try await loaded()
    if let index = next.birthdays.firstIndex(where: { $0.personID == personID }) {
      guard next.birthdays[index].date != date else { return next }
      next.birthdays[index].previousDates.append(next.birthdays[index].date)
      next.birthdays[index].previousDates = Array(next.birthdays[index].previousDates.suffix(50))
      next.birthdays[index].date = date
      let birthdayID = next.birthdays[index].id
      // Save the cancellation intent first. A correction never inherits approval for a new date.
      for index in next.schedules.indices
      where next.schedules[index].birthdayID == birthdayID
        && next.schedules[index].state != .disabled
      {
        next.schedules[index].state = .cancellationPending
      }
    } else {
      next.birthdays.append(BirthdayRecord(personID: personID, date: date))
    }
    next = try await commit(next)
    return try await cancelPending(next)
  }
  public func previewSchedule(
    birthdayID: UUID, delivery: BirthdayDelivery, hour: Int, minute: Int,
    timeZoneID: String
  ) async throws -> BirthdaySchedule {
    let value = try await snapshot()
    guard let birthday = value.birthdays.first(where: { $0.id == birthdayID }),
      let month = birthday.date.month, let day = birthday.date.day
    else { throw OrganizationError.invalidDate }
    let people = try await memory.snapshot().profiles
    guard let person = people.first(where: { $0.id == birthday.personID && $0.mergedIntoID == nil })
    else { throw OrganizationError.missingPerson }
    let result = BirthdaySchedule(
      birthdayID: birthdayID, personID: person.id, month: month, day: day,
      hour: hour, minute: minute, timeZoneID: timeZoneID, delivery: delivery, title: person.name,
      reviewedRevision: value.revision)
    try result.validate()
    return result
  }
  public func approve(_ proposal: BirthdaySchedule, approved: Bool) async throws
    -> OrganizationSnapshot
  {
    guard approved else { throw OrganizationError.approvalRequired }
    try proposal.validate()
    await acquire()
    defer { release() }
    var next = try await loaded()
    guard let birthday = next.birthdays.first(where: { $0.id == proposal.birthdayID }),
      birthday.personID == proposal.personID, birthday.date.month == proposal.month,
      birthday.date.day == proposal.day,
      proposal.state == .pending
    else { throw OrganizationError.stalePreview }
    if next.schedules.contains(where: {
      $0.birthdayID == proposal.birthdayID && $0.state == .reviewRequired
    }) {
      guard proposal.reviewedRevision == next.revision,
        !next.schedules.contains(where: { $0.id == proposal.id })
      else { throw OrganizationError.stalePreview }
    }
    let people = try await memory.snapshot().profiles
    guard
      people.contains(where: {
        $0.id == proposal.personID && $0.name == proposal.title && $0.mergedIntoID == nil
      })
    else { throw OrganizationError.stalePreview }
    guard try await scheduler.requestPermission(for: proposal.delivery) else {
      throw OrganizationError.permissionDenied
    }
    // The permission sheet can outlive a correction or merge in the personal graph.
    let currentPeople = try await memory.snapshot().profiles
    guard
      currentPeople.contains(where: {
        $0.id == proposal.personID && $0.name == proposal.title && $0.mergedIntoID == nil
          && $0.kind != .project
      })
    else { throw OrganizationError.stalePreview }
    next = try await cancelPending(next)
    next = try await recoverUnconfirmedInstallations(next)
    // Identical approval is idempotent and does not replace an existing schedule.
    if let existing = next.schedules.first(where: {
      $0.birthdayID == proposal.birthdayID && $0.state != .disabled
        && $0.state != .cancellationPending && $0.state != .reviewRequired
        && $0.month == proposal.month
        && $0.day == proposal.day && $0.hour == proposal.hour && $0.minute == proposal.minute
        && $0.timeZoneID == proposal.timeZoneID && $0.delivery == proposal.delivery
        && $0.title == proposal.title
    }) {
      return try await installApprovedSchedule(existing.id, in: next)
    }
    for index in next.schedules.indices
    where next.schedules[index].birthdayID == proposal.birthdayID
      && next.schedules[index].state != .disabled
    {
      next.schedules[index].state = .cancellationPending
    }
    next.schedules.append(proposal)
    next = try await commit(next)
    next = try await cancelPending(next)
    return try await installApprovedSchedule(proposal.id, in: next)
  }

  /// A pending receipt precedes the OS call. An interrupted outcome cannot reopen as active.
  private func installApprovedSchedule(_ id: UUID, in value: OrganizationSnapshot) async throws
    -> OrganizationSnapshot
  {
    var next = value
    guard let index = next.schedules.firstIndex(where: { $0.id == id }),
      next.schedules[index].state != .disabled,
      next.schedules[index].state != .cancellationPending,
      next.schedules[index].state != .reviewRequired
    else { throw OrganizationError.invalidSchedule }
    if next.schedules[index].state != .pending {
      next.schedules[index].state = .pending
      next = try await commit(next)
    }
    do { try await scheduler.upsert(next.schedules[index]) } catch {
      switch error as? OrganizationError {
      case .cancellationPending: next.schedules[index].state = .cancellationPending
      case .stalePreview: next.schedules[index].state = .reviewRequired
      default: next.schedules[index].state = .failed
      }
      _ = try await commit(next)
      throw error
    }
    next.schedules[index].state = .active
    return try await commit(next)
  }

  /// A previous OS call may have completed even when its outcome receipt did not save.
  /// Clear that stable identifier before retrying the unchanged enabled approval.
  private func recoverUnconfirmedInstallations(_ value: OrganizationSnapshot) async throws
    -> OrganizationSnapshot
  {
    var next = value
    for index in next.schedules.indices
    where next.schedules[index].state == .pending || next.schedules[index].state == .failed {
      do { try await scheduler.validateExisting(next.schedules[index]) } catch {
        if (error as? OrganizationError) == .stalePreview {
          next.schedules[index].state = .reviewRequired
          _ = try await commit(next)
        }
        throw error
      }
      do { try await scheduler.remove(next.schedules[index]) } catch {
        throw OrganizationError.cancellationPending
      }
      // The next install persists pending again before touching the OS. A crash here repeats removal.
      next.schedules[index].state = .failed
    }
    return next
  }

  public func disableBirthday(_ birthdayID: UUID) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await loaded()
    for index in next.schedules.indices
    where next.schedules[index].birthdayID == birthdayID && next.schedules[index].state != .disabled
    {
      next.schedules[index].state = .cancellationPending
    }
    next = try await commit(next)
    return try await cancelPending(next)
  }
  private func cancelPending(_ value: OrganizationSnapshot) async throws -> OrganizationSnapshot {
    var next = value
    for index in next.schedules.indices where next.schedules[index].state == .cancellationPending {
      do { try await scheduler.remove(next.schedules[index]) } catch {
        throw OrganizationError.cancellationPending
      }
      next.schedules[index].state = .disabled
      next = try await commit(next)
    }
    return next
  }
  /// Replays only previously approved intents. It never requests permission on app launch.
  public func reconcile() async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await refreshReferencesLocked(cancelReminders: true)
    next = try await cancelPending(next)
    next = try await recoverUnconfirmedInstallations(next)
    let people = try await memory.snapshot().profiles
    for index in next.schedules.indices where next.schedules[index].state != .disabled {
      let schedule = next.schedules[index]
      guard schedule.state != .reviewRequired else { throw OrganizationError.stalePreview }
      guard people.contains(where: { $0.id == schedule.personID && $0.mergedIntoID == nil }) else {
        next.schedules[index].state = .cancellationPending
        next = try await commit(next)
        next = try await cancelPending(next)
        continue
      }
      next = try await installApprovedSchedule(schedule.id, in: next)
    }
    return next
  }
  public func saveRule(_ rule: OrganizationRule) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await loaded()
    if let index = next.rules.firstIndex(where: { $0.id == rule.id }) {
      var edited = rule
      if edited.filter.profileID != next.rules[index].filter.profileID {
        edited.filter.originalProfileID = nil
      }
      if edited.filter.profileID == next.rules[index].filter.profileID,
        edited.filter.originalProfileID == nil
      {
        edited.filter.originalProfileID = next.rules[index].filter.originalProfileID
      }
      next.rules[index] = edited
    } else {
      next.rules.append(rule)
    }
    return try await commit(next)
  }
  public func testRule(_ id: UUID) async throws -> RulePreview {
    let value = try await snapshot()
    guard let rule = value.rules.first(where: { $0.id == id }) else {
      throw OrganizationError.missingRule
    }
    let graph = try await memory.snapshot()
    return RulePreview(
      rule: rule, memoryRevision: graph.revision,
      entryIDs: graph.currentEntries.filter(rule.filter.matches).map(\.id))
  }
  public func applyRule(_ preview: RulePreview) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await refreshReferencesLocked()
    guard next.rules.contains(where: { $0 == preview.rule && $0.enabled }) else {
      throw OrganizationError.stalePreview
    }
    let graph = try await memory.snapshot()
    guard graph.revision == preview.memoryRevision,
      graph.currentEntries.filter(preview.rule.filter.matches).map(\.id) == preview.entryIDs
    else { throw OrganizationError.stalePreview }
    let changes = graph.currentEntries.filter { preview.entryIDs.contains($0.id) }.compactMap {
      entry -> PersonalMemoryOrganizationChange? in
      let categories = Array(Set(entry.categories + [preview.rule.category])).sorted()
      guard categories != entry.categories else { return nil }
      return PersonalMemoryOrganizationChange(
        entryID: entry.id, categories: categories, profileIDs: entry.profileIDs,
        expectedCategories: entry.categories, expectedProfileIDs: entry.profileIDs)
    }
    guard !changes.isEmpty else { return next }
    // Durable recovery receipt precedes graph editing. Compare-and-swap makes undo safe after interruptions.
    let application = RuleApplication(
      id: UUID(), ruleID: preview.rule.id, changes: changes, applied: false)
    next.applications.append(application)
    next.applications = Array(next.applications.suffix(50))
    next = try await commit(next)
    _ = try await memory.organizeBatch(changes, expectedRevision: graph.revision)
    if let index = next.applications.firstIndex(where: { $0.id == application.id }) {
      next.applications[index].applied = true
    }
    return try await commit(next)
  }
  public func undoRule(_ applicationID: UUID) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await refreshReferencesLocked()
    guard let index = next.applications.firstIndex(where: { $0.id == applicationID }) else {
      throw OrganizationError.nothingToUndo
    }
    let graph = try await memory.snapshot()
    let application = next.applications[index]
    // A failed graph write can leave a pending receipt. Dismiss it without touching graph data.
    if application.changes.allSatisfy({ change in
      graph.currentEntries.contains {
        $0.id == change.entryID && $0.categories == change.expectedCategories
          && $0.profileIDs == change.expectedProfileIDs
      }
    }) {
      next.applications.remove(at: index)
      return try await commit(next)
    }
    _ = try await memory.organizeBatch(
      application.changes.map(\.reversed), expectedRevision: graph.revision)
    next.applications.remove(at: index)
    return try await commit(next)
  }
  public func saveView(_ view: SavedMemoryView) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await loaded()
    if let index = next.views.firstIndex(where: { $0.id == view.id }) {
      var edited = view
      if edited.filter.profileID != next.views[index].filter.profileID {
        edited.filter.originalProfileID = nil
      }
      if edited.filter.profileID == next.views[index].filter.profileID,
        edited.filter.originalProfileID == nil
      {
        edited.filter.originalProfileID = next.views[index].filter.originalProfileID
      }
      next.views[index] = edited
    } else {
      next.views.append(view)
    }
    return try await commit(next)
  }
  public func deleteView(_ id: UUID) async throws -> OrganizationSnapshot {
    await acquire()
    defer { release() }
    var next = try await loaded()
    next.views.removeAll { $0.id == id }
    return try await commit(next)
  }
  public func entries(in view: SavedMemoryView) async throws -> [PersonalMemoryEntry] {
    let current = try await snapshot().views.first { $0.id == view.id }
    guard let current else { throw OrganizationError.missingView }
    return try await memory.snapshot().currentEntries.filter(current.filter.matches)
  }
}
