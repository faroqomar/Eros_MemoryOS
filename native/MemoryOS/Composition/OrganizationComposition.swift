import EventKit
import Foundation
import MemoryCore
import OrganizationCore
import OrganizationPersistence
import UserNotifications

enum OrganizationComposition {
  @MainActor static func make(
    personal: PersonalMemoryUseCases,
    directory: URL = URL.applicationSupportDirectory.appending(path: "Organization")
  ) -> OrganizationViewModel {
    let useCases = OrganizationUseCases(
      repository: FileOrganizationRepository(url: directory.appending(path: "organization.json")),
      scheduler: AppleBirthdayScheduler(), memory: personal)
    return OrganizationViewModel(
      useCases: useCases, personal: personal,
      archiveRestore: RestoreOrganizationArchive(
        useCases: useCases,
        reader: LocalArchiveFileReader(maximumBytes: OrganizationSnapshot.maximumArchiveBytes)))
  }
}

/// OS-owned annual delivery works while the app is closed. No model or server runs at delivery time.
@MainActor final class AppleBirthdayScheduler: BirthdayScheduling {
  private let notifications = UNUserNotificationCenter.current()
  private let events = EKEventStore()

  func requestPermission(for delivery: BirthdayDelivery) async throws -> Bool {
    switch delivery {
    case .notification:
      return try await notifications.requestAuthorization(options: [.alert, .sound])
    case .calendar:
      return try await withCheckedThrowingContinuation { continuation in
        events.requestFullAccessToEvents { granted, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: granted)
          }
        }
      }
    }
  }

  func validateExisting(_ schedule: BirthdaySchedule) async throws {
    try schedule.validate()
    // UserNotifications requests belong to this app; Calendar permits external occurrence edits.
    guard schedule.delivery == .calendar else { return }
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
      throw OrganizationError.permissionDenied
    }
    events.reset()
    _ = try validatedCalendarSeries(for: schedule)
  }

  private func validatedCalendarSeries(for schedule: BirthdaySchedule) throws -> [EKEvent] {
    let existing = calendarEvents(for: schedule)
    guard
      existing.isEmpty
        || (Set(existing.map(\.calendarItemIdentifier)).count == 1
          && existing.allSatisfy({ Self.matchesApprovedCalendarEvent($0, schedule: schedule) }))
    else { throw OrganizationError.stalePreview }
    return existing
  }

  func upsert(_ schedule: BirthdaySchedule) async throws {
    try schedule.validate()
    switch schedule.delivery {
    case .notification:
      let settings = await notifications.notificationSettings()
      guard
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      else { throw OrganizationError.permissionDenied }
      let pending = await notifications.pendingNotificationRequests()
      guard pending.contains(where: { $0.identifier == schedule.identifier }) || pending.count < 50
      else { throw OrganizationError.limitReached }
      var parts = DateComponents()
      parts.calendar = Calendar(identifier: .gregorian)
      parts.timeZone = TimeZone(identifier: schedule.timeZoneID)
      parts.month = schedule.month
      parts.day = schedule.day
      parts.hour = schedule.hour
      parts.minute = schedule.minute
      let content = UNMutableNotificationContent()
      content.title = "Birthday reminder"
      content.body = schedule.title
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: schedule.identifier, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
      try await notifications.add(request)
    case .calendar:
      guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        throw OrganizationError.permissionDenied
      }
      // Observe edits from Calendar or another store before accepting the old approval.
      events.reset()
      // Calendar accounts can sync externally. This first local-only adapter accepts on-device calendars only.
      guard
        let calendar = events.calendars(for: .event).first(where: {
          $0.source.sourceType == .local && $0.allowsContentModifications
        })
      else { throw OrganizationError.schedulerUnavailable }
      let existing = try validatedCalendarSeries(for: schedule)
      if !existing.isEmpty { return }
      guard let start = schedule.nextOccurrence(after: Date().addingTimeInterval(-1)) else {
        throw OrganizationError.invalidSchedule
      }
      let event = EKEvent(eventStore: events)
      event.calendar = calendar
      event.title = "Birthday: " + schedule.title
      event.startDate = start
      event.endDate = start.addingTimeInterval(300)
      event.timeZone = TimeZone(identifier: schedule.timeZoneID)
      event.url = marker(schedule)
      // An implicit Feb 29 yearly rule becomes "last day of February" in EventKit.
      // Explicit month/day components retain the approved skip-nonleap-year behavior.
      event.addRecurrenceRule(
        EKRecurrenceRule(
          recurrenceWith: .yearly, interval: 1, daysOfTheWeek: nil,
          daysOfTheMonth: [NSNumber(value: schedule.day)],
          monthsOfTheYear: [NSNumber(value: schedule.month)], weeksOfTheYear: nil,
          daysOfTheYear: nil, setPositions: nil, end: nil))
      event.alarms = [EKAlarm(relativeOffset: 0)]
      try events.save(event, span: .futureEvents, commit: true)
      let createdSeriesID = event.calendarItemIdentifier
      events.reset()
      let persisted = calendarEvents(for: schedule)
      let created = persisted.filter { $0.calendarItemIdentifier == createdSeriesID }
      guard !created.isEmpty, Set(persisted.map(\.calendarItemIdentifier)) == [createdSeriesID],
        created.allSatisfy({ Self.matchesApprovedCalendarEvent($0, schedule: schedule) })
      else {
        // Roll back only this new series. Existing or externally edited series stay untouched.
        do {
          if let saved = events.calendarItem(withIdentifier: createdSeriesID) as? EKEvent {
            try events.remove(saved, span: .futureEvents, commit: true)
          }
          events.reset()
          guard
            !calendarEvents(for: schedule).contains(where: {
              $0.calendarItemIdentifier == createdSeriesID
            })
          else { throw OrganizationError.cancellationPending }
        } catch { throw OrganizationError.cancellationPending }
        throw OrganizationError.stalePreview
      }
    }
  }

  func remove(_ schedule: BirthdaySchedule) async throws {
    switch schedule.delivery {
    case .notification:
      notifications.removePendingNotificationRequests(withIdentifiers: [schedule.identifier])
      notifications.removeDeliveredNotifications(withIdentifiers: [schedule.identifier])
    case .calendar:
      guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        throw OrganizationError.permissionDenied
      }
      events.reset()
      var remaining = calendarEvents(for: schedule)
      // Removing a master can invalidate its detached exceptions. Read fresh objects after each mutation.
      for _ in 0..<64 {
        guard let first = remaining.first else { return }
        let beforeCount = remaining.count
        do { try events.remove(first, span: .futureEvents, commit: true) } catch {
          events.reset()
          // Another removal may already have removed this object. Only an empty owned query proves success.
          guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
            calendarEvents(for: schedule).isEmpty
          else { throw error }
          return
        }
        events.reset()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
          throw OrganizationError.permissionDenied
        }
        remaining = calendarEvents(for: schedule)
        guard remaining.count < beforeCount else { throw OrganizationError.cancellationPending }
      }
      guard remaining.isEmpty else { throw OrganizationError.cancellationPending }
    }
  }

  /// Detect edits that change the exact approved delivery; do not silently accept or overwrite them.
  static func matchesApprovedCalendarEvent(_ event: EKEvent, schedule: BirthdaySchedule) -> Bool {
    guard let zone = TimeZone(identifier: schedule.timeZoneID),
      let start = event.startDate, let end = event.endDate,
      let rule = event.recurrenceRules?.first, event.recurrenceRules?.count == 1,
      let alarm = event.alarms?.first, event.alarms?.count == 1
    else { return false }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: start)
    return event.title == "Birthday: " + schedule.title && !event.isAllDay
      && event.timeZone?.identifier == schedule.timeZoneID
      && parts.month == schedule.month && parts.day == schedule.day
      && parts.hour == schedule.hour && parts.minute == schedule.minute && parts.second == 0
      && end.timeIntervalSince(start) == 300
      && (event.attendees?.isEmpty ?? true)
      && rule.frequency == .yearly && rule.interval == 1 && rule.recurrenceEnd == nil
      && (rule.daysOfTheWeek?.isEmpty ?? true) && (rule.daysOfTheYear?.isEmpty ?? true)
      && (rule.weeksOfTheYear?.isEmpty ?? true) && (rule.setPositions?.isEmpty ?? true)
      && ((rule.daysOfTheMonth?.isEmpty ?? true)
        || rule.daysOfTheMonth == [NSNumber(value: schedule.day)])
      && ((rule.monthsOfTheYear?.isEmpty ?? true)
        || rule.monthsOfTheYear == [NSNumber(value: schedule.month)])
      && alarm.absoluteDate == nil && alarm.relativeOffset == 0
      && alarm.structuredLocation == nil && alarm.proximity == .none
  }

  private func marker(_ schedule: BirthdaySchedule) -> URL {
    URL(string: "memoryos-birthday://schedule/" + schedule.id.uuidString)!
  }
  private func calendarEvents(for schedule: BirthdaySchedule) -> [EKEvent] {
    let calendars = events.calendars(for: .event).filter { $0.source.sourceType == .local }
    var found: [EKEvent] = []
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: schedule.timeZoneID)!
    let now = Date()
    // EventKit bounds each query. Eight years include the next leap-day occurrence.
    for offset in stride(from: -4, through: 8, by: 3) {
      guard let start = calendar.date(byAdding: .year, value: offset, to: now),
        let end = calendar.date(byAdding: .year, value: offset + 3, to: now)
      else { continue }
      let predicate = events.predicateForEvents(withStart: start, end: end, calendars: calendars)
      found += events.events(matching: predicate).filter { $0.url == marker(schedule) }
    }
    return found.sorted { $0.startDate < $1.startDate }
  }
}
