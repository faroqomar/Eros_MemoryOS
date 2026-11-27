import Foundation
import MemoryCore

public enum OrganizationError: Error, Equatable, Sendable {
  case invalidDate, invalidSchedule, approvalRequired, missingPerson, missingBirthday
  case permissionDenied, cancellationPending, storage, invalidArchive, limitReached, stalePreview,
    nothingToUndo
  case missingRule, missingView, schedulerUnavailable, conflictingArchive, missingReferences
}

/// A missing component stays unknown. The app does not invent a birth year or day.
public struct BirthdayDate: Codable, Equatable, Sendable {
  public var year: Int?
  public var month: Int?
  public var day: Int?
  public init(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
    self.year = year
    self.month = month
    self.day = day
  }
  public func validate() throws {
    guard year != nil || month != nil || day != nil,
      year.map({ (1...9999).contains($0) }) ?? true,
      month.map({ (1...12).contains($0) }) ?? true,
      day.map({ (1...31).contains($0) }) ?? true
    else { throw OrganizationError.invalidDate }
    if let month, let day {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(secondsFromGMT: 0)!
      let parts = DateComponents(year: year ?? 2000, month: month, day: day)
      guard let date = calendar.date(from: parts), calendar.component(.month, from: date) == month,
        calendar.component(.day, from: date) == day
      else { throw OrganizationError.invalidDate }
    }
  }
}

public struct BirthdayRecord: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let personID: UUID
  public var date: BirthdayDate
  public var previousDates: [BirthdayDate]
  public var resolvedIntoBirthdayID: UUID?
  public init(
    id: UUID = UUID(), personID: UUID, date: BirthdayDate, previousDates: [BirthdayDate] = []
  ) {
    self.id = id
    self.personID = personID
    self.date = date
    self.previousDates = previousDates
  }
}

public enum BirthdayDelivery: String, Codable, CaseIterable, Sendable {
  case notification, calendar
}
public enum BirthdayScheduleState: String, Codable, Sendable {
  /// An exact enabled approval whose OS installation outcome is not confirmed.
  /// Recovery must clear the stable delivery identifier before retrying it.
  case pending
  case active, cancellationPending, disabled, failed, reviewRequired
}

/// Exact annual Gregorian schedule, fixed to the chosen timezone. Feb 29 skips nonleap years.
public struct BirthdaySchedule: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let birthdayID: UUID
  public let personID: UUID
  public let month: Int
  public let day: Int
  public let hour: Int
  public let minute: Int
  public let timeZoneID: String
  public let delivery: BirthdayDelivery
  public let title: String
  public var state: BirthdayScheduleState
  public var stateBeforeRestore: BirthdayScheduleState?
  public let reviewedRevision: UInt64?
  public init(
    id: UUID = UUID(), birthdayID: UUID, personID: UUID, month: Int, day: Int,
    hour: Int, minute: Int, timeZoneID: String, delivery: BirthdayDelivery, title: String,
    state: BirthdayScheduleState = .pending, reviewedRevision: UInt64? = nil
  ) {
    self.id = id
    self.birthdayID = birthdayID
    self.personID = personID
    self.month = month
    self.day = day
    self.hour = hour
    self.minute = minute
    self.timeZoneID = timeZoneID
    self.delivery = delivery
    self.title = title
    self.state = state
    self.reviewedRevision = reviewedRevision
  }
  public func validate() throws {
    try BirthdayDate(month: month, day: day).validate()
    guard (0...23).contains(hour), (0...59).contains(minute),
      TimeZone(identifier: timeZoneID) != nil,
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.utf8.count <= 512
    else { throw OrganizationError.invalidSchedule }
  }
  public var identifier: String { "memoryos.birthday." + id.uuidString }
  public func nextOccurrence(after now: Date) -> Date? {
    guard let zone = TimeZone(identifier: timeZoneID) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let year = calendar.component(.year, from: now)
    for candidate in year...(year + 8) {
      let parts = DateComponents(
        timeZone: zone, year: candidate, month: month, day: day, hour: hour, minute: minute)
      guard let date = calendar.date(from: parts), date > now,
        calendar.component(.month, from: date) == month,
        calendar.component(.day, from: date) == day,
        calendar.component(.hour, from: date) == hour,
        calendar.component(.minute, from: date) == minute
      else { continue }
      return date
    }
    return nil
  }
}

public protocol BirthdayScheduling: Sendable {
  /// Called only after explicit approval. Implementations replace by stable identifier.
  func requestPermission(for delivery: BirthdayDelivery) async throws -> Bool
  /// Read-only check. Throw stalePreview when a stored delivery differs from its exact approval.
  func validateExisting(_ schedule: BirthdaySchedule) async throws
  func upsert(_ schedule: BirthdaySchedule) async throws
  func remove(_ schedule: BirthdaySchedule) async throws
}

public struct OrganizationFilter: Codable, Equatable, Sendable {
  public var text: String
  public var profileID: UUID?
  public var originalProfileID: UUID?
  public var kind: PersonalMemoryKind?
  public init(text: String = "", profileID: UUID? = nil, kind: PersonalMemoryKind? = nil) {
    self.text = text
    self.profileID = profileID
    self.kind = kind
  }
  public func matches(_ entry: PersonalMemoryEntry) -> Bool {
    entry.supersededByID == nil
      && (profileID.map(entry.profileIDs.contains) ?? true)
      && (kind.map { entry.kind == $0 } ?? true)
      && (text.isEmpty
        || entry.text.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
  }
}

public struct OrganizationRule: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public var name: String
  public var filter: OrganizationFilter
  public var category: String
  public var enabled: Bool
  public init(
    id: UUID = UUID(), name: String, filter: OrganizationFilter, category: String,
    enabled: Bool = true
  ) {
    self.id = id
    self.name = name
    self.filter = filter
    self.category = category
    self.enabled = enabled
  }
}

public struct SavedMemoryView: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public var name: String
  public var filter: OrganizationFilter
  public init(id: UUID = UUID(), name: String, filter: OrganizationFilter) {
    self.id = id
    self.name = name
    self.filter = filter
  }
}

public struct RulePreview: Equatable, Sendable {
  public let rule: OrganizationRule
  public let memoryRevision: UInt64
  public let entryIDs: [UUID]
}

public struct RuleApplication: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let ruleID: UUID
  public let changes: [PersonalMemoryOrganizationChange]
  public var applied: Bool
  public var originalChanges: [PersonalMemoryOrganizationChange]?
}

public struct OrganizationSnapshot: Codable, Equatable, Sendable {
  public static let maximumArchiveBytes = 8 * 1024 * 1024
  public static let currentFormatVersion = 5
  public var formatVersion = Self.currentFormatVersion
  public var revision: UInt64 = 0
  /// Explicit inert references to people no longer present in personal memory; never person identities.
  public var unavailableProfileIDs: [UUID]?
  public var birthdays: [BirthdayRecord] = []
  public var schedules: [BirthdaySchedule] = []
  public var rules: [OrganizationRule] = []
  public var views: [SavedMemoryView] = []
  public var applications: [RuleApplication] = []
  public init() {}
  public var referencedProfileIDs: Set<UUID> {
    var result = Set(birthdays.map(\.personID))
    for filter in rules.map(\.filter) + views.map(\.filter) {
      result.formUnion([filter.profileID, filter.originalProfileID].compactMap { $0 })
    }
    for application in applications {
      for change in application.changes + (application.originalChanges ?? []) {
        result.formUnion(change.profileIDs + change.expectedProfileIDs)
      }
    }
    return result
  }
  public func upgradedToCurrentFormat() throws -> OrganizationSnapshot {
    guard (1...Self.currentFormatVersion).contains(formatVersion) else {
      throw OrganizationError.invalidArchive
    }
    if formatVersion == 1 {
      guard
        schedules.allSatisfy({
          $0.state != .reviewRequired && $0.stateBeforeRestore != .reviewRequired
            && $0.reviewedRevision == nil
        })
      else { throw OrganizationError.invalidArchive }
    }
    if formatVersion < 3, birthdays.contains(where: { $0.resolvedIntoBirthdayID != nil }) {
      throw OrganizationError.invalidArchive
    }
    if formatVersion < 4,
      rules.contains(where: { $0.filter.originalProfileID != nil })
        || views.contains(where: { $0.filter.originalProfileID != nil })
        || applications.contains(where: { $0.originalChanges != nil })
    {
      throw OrganizationError.invalidArchive
    }
    if formatVersion < 5, unavailableProfileIDs != nil { throw OrganizationError.invalidArchive }
    var current = self
    current.formatVersion = Self.currentFormatVersion
    try current.validate()
    return current
  }
  public func validate() throws {
    guard formatVersion == Self.currentFormatVersion, revision < UInt64.max,
      birthdays.count <= 2000,
      schedules.count <= 2000, rules.count <= 100, views.count <= 100, applications.count <= 50,
      Set(birthdays.map(\.id)).count == birthdays.count,
      Set(birthdays.map(\.personID)).count == birthdays.count,
      Set(schedules.map(\.id)).count == schedules.count,
      Set(rules.map(\.id)).count == rules.count, Set(views.map(\.id)).count == views.count,
      Set(applications.map(\.id)).count == applications.count
    else { throw OrganizationError.invalidArchive }
    let unavailable = Set(unavailableProfileIDs ?? [])
    guard unavailable.count <= 4_000, unavailable.count == (unavailableProfileIDs?.count ?? 0),
      unavailable.isSubset(of: referencedProfileIDs),
      schedules.allSatisfy({
        !unavailable.contains($0.personID) || $0.state == .disabled
          || $0.state == .cancellationPending
      }),
      applications.allSatisfy({ application in
        application.changes.allSatisfy {
          unavailable.isDisjoint(with: $0.profileIDs + $0.expectedProfileIDs)
        }
      })
    else { throw OrganizationError.invalidArchive }
    for filter in rules.map(\.filter) + views.map(\.filter) {
      if let original = filter.originalProfileID {
        guard filter.profileID != nil,
          !unavailable.contains(original) || filter.profileID == original
        else {
          throw OrganizationError.invalidArchive
        }
      }
    }
    let birthdayTargets = Dictionary(
      uniqueKeysWithValues: birthdays.map { ($0.id, $0.resolvedIntoBirthdayID) })
    for birthday in birthdays {
      var visited: Set<UUID> = [birthday.id]
      var target = birthday.resolvedIntoBirthdayID
      while let id = target {
        guard birthdayTargets.keys.contains(id), visited.insert(id).inserted else {
          throw OrganizationError.invalidArchive
        }
        target = birthdayTargets[id] ?? nil
      }
      try birthday.date.validate()
      guard birthday.previousDates.count <= 50 else { throw OrganizationError.limitReached }
      for date in birthday.previousDates { try date.validate() }
    }
    for schedule in schedules {
      try schedule.validate()
      guard
        birthdays.contains(where: {
          $0.id == schedule.birthdayID && $0.personID == schedule.personID
        })
      else { throw OrganizationError.invalidArchive }
      if schedule.state != .disabled && schedule.state != .cancellationPending {
        guard
          birthdays.contains(where: {
            $0.id == schedule.birthdayID && $0.date.month == schedule.month
              && $0.date.day == schedule.day
          })
        else { throw OrganizationError.invalidArchive }
      }
    }
    let enabled = schedules.filter { $0.state != .disabled && $0.state != .cancellationPending }
    guard Set(enabled.map(\.birthdayID)).count == enabled.count else {
      throw OrganizationError.invalidArchive
    }
    for rule in rules {
      try Self.validateText(rule.name)
      try Self.validateText(rule.category)
      try Self.validateFilter(rule.filter)
    }
    for view in views {
      try Self.validateText(view.name)
      try Self.validateFilter(view.filter)
    }
    var estimatedBytes =
      birthdays.count * 256 + schedules.reduce(0) { $0 + $1.title.utf8.count + 512 }
    estimatedBytes += birthdays.reduce(0) { $0 + $1.previousDates.count * 96 }
    for application in applications {
      guard rules.contains(where: { $0.id == application.ruleID }),
        application.changes.count <= 10_000,
        Set(application.changes.map(\.entryID)).count == application.changes.count
      else { throw OrganizationError.limitReached }
      if let originals = application.originalChanges {
        guard originals.count == application.changes.count,
          Set(originals.map(\.entryID)) == Set(application.changes.map(\.entryID))
        else { throw OrganizationError.invalidArchive }
      }
      for change in application.changes + (application.originalChanges ?? []) {
        guard change.categories.count <= 100, change.expectedCategories.count <= 100,
          change.profileIDs.count <= 100, change.expectedProfileIDs.count <= 100
        else { throw OrganizationError.limitReached }
        for category in change.categories + change.expectedCategories {
          try Self.validateText(category)
        }
        estimatedBytes +=
          256 + (change.profileIDs.count + change.expectedProfileIDs.count) * 40
          + (change.categories + change.expectedCategories).reduce(0) {
            $0 + $1.utf8.count * 6 + 16
          }
        guard estimatedBytes <= Self.maximumArchiveBytes else {
          throw OrganizationError.limitReached
        }
      }
    }
  }
  private static func validateText(_ value: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf8.count <= 240
    else { throw OrganizationError.limitReached }
  }
  private static func validateFilter(_ filter: OrganizationFilter) throws {
    guard filter.text.utf8.count <= 1024 else { throw OrganizationError.limitReached }
  }
}

public protocol OrganizationRepository: Sendable {
  func load() async throws -> OrganizationSnapshot
  func save(_ value: OrganizationSnapshot) async throws
}

/// The retired record stays inspectable until an explicit person/date review resolves it.
public struct MergedBirthdayReview: Equatable, Sendable, Identifiable {
  public let birthdayID: UUID
  public let previousPersonID: UUID
  public let personID: UUID
  public let date: BirthdayDate
  public let existingBirthdayID: UUID?
  public let existingBirthdayDate: BirthdayDate?
  public let organizationRevision: UInt64
  public let memoryRevision: UInt64
  public var id: UUID { birthdayID }
}
