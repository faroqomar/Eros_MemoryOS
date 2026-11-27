import EventKit
import Foundation
import OrganizationCore
import Testing
import UserNotifications

@testable import MemoryOS

@MainActor struct BirthdayAdapterTests {
  @Test(.timeLimit(.minutes(4)))
  func annualNotificationActuallyDeliversAtApprovedLocalMinute() async throws {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    try #require(
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Baghdad")!
    let due = calendar.dateInterval(of: .minute, for: Date().addingTimeInterval(90))!.start
    let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: due)
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: parts.month!, day: parts.day!,
      hour: parts.hour!, minute: parts.minute!, timeZoneID: calendar.timeZone.identifier,
      delivery: .notification, title: "Fictional delivery verification")
    let presenter = BirthdayNotificationPresenter()
    let previous = center.delegate
    center.delegate = presenter
    defer {
      center.removePendingNotificationRequests(withIdentifiers: [schedule.identifier])
      center.removeDeliveredNotifications(withIdentifiers: [schedule.identifier])
      center.delegate = previous
    }
    try await AppleBirthdayScheduler().upsert(schedule)
    let pending = await center.pendingNotificationRequests().filter {
      $0.identifier == schedule.identifier
    }
    let trigger = try #require(pending.first?.trigger as? UNCalendarNotificationTrigger)
    let next = try #require(trigger.nextTriggerDate())
    #expect(trigger.repeats && abs(next.timeIntervalSince(due)) < 1)
    try await Task.sleep(for: .seconds(max(0, due.timeIntervalSinceNow) + 12))
    let delivered = await center.deliveredNotifications().filter {
      $0.request.identifier == schedule.identifier
    }
    let arrival = try #require(delivered.first)
    #expect(arrival.request.content.body == schedule.title)
    #expect(abs(arrival.date.timeIntervalSince(due)) <= 12)
    print(
      "MEMORYOS_ANNUAL_DELIVERY delivered=true deltaSeconds=\(arrival.date.timeIntervalSince(due))")
  }

  @Test func approvedCalendarSeriesSavesReusesRejectsExpansionAndCancels() async throws {
    try #require(EKEventStore.authorizationStatus(for: .event) == .fullAccess)
    let store = EKEventStore()
    var createdCalendar: EKCalendar?
    if !store.calendars(for: .event).contains(where: {
      $0.source.sourceType == .local && $0.allowsContentModifications
    }) {
      let local = try #require(store.sources.first { $0.sourceType == .local })
      let calendar = EKCalendar(for: .event, eventStore: store)
      calendar.source = local
      calendar.title = "Fictional MemoryOS verification"
      try store.saveCalendar(calendar, commit: true)
      createdCalendar = calendar
    }
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 3, day: 12, hour: 9, minute: 15,
      timeZoneID: "Asia/Baghdad", delivery: .calendar, title: "Fictional calendar contract")
    let scheduler = AppleBirthdayScheduler()
    let marker = URL(string: "memoryos-birthday://schedule/" + schedule.id.uuidString)!
    func matching() -> [EKEvent] {
      store.reset()
      let start = Date()
      let end = Calendar(identifier: .gregorian).date(byAdding: .year, value: 2, to: start)!
      return store.events(
        matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)
      )
      .filter { $0.url == marker }
    }
    do {
      try await scheduler.upsert(schedule)
      try await scheduler.upsert(schedule)
      let events = matching()
      #expect(Set(events.map(\.calendarItemIdentifier)).count == 1)
      let event = try #require(events.first)
      #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
      event.alarms = [EKAlarm(relativeOffset: -1800)]
      try store.save(event, span: .futureEvents, commit: true)
      await #expect(throws: OrganizationError.stalePreview) { try await scheduler.upsert(schedule) }
      #expect(matching().first?.alarms?.first?.relativeOffset == -1800)
      try await scheduler.remove(schedule)
      #expect(matching().isEmpty)
      if let createdCalendar { try store.removeCalendar(createdCalendar, commit: true) }
    } catch {
      try? await scheduler.remove(schedule)
      if let createdCalendar { try? store.removeCalendar(createdCalendar, commit: true) }
      throw error
    }
  }

  @Test func laterCalendarExceptionCannotExpandAnEarlierApprovedSeries() async throws {
    try #require(EKEventStore.authorizationStatus(for: .event) == .fullAccess)
    let store = EKEventStore()
    try #require(
      store.calendars(for: .event).contains {
        $0.source.sourceType == .local && $0.allowsContentModifications
      })
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 3, day: 12, hour: 9, minute: 15,
      timeZoneID: "Asia/Baghdad", delivery: .calendar, title: "Fictional later exception")
    let scheduler = AppleBirthdayScheduler()
    let marker = URL(string: "memoryos-birthday://schedule/" + schedule.id.uuidString)!
    func matching() -> [EKEvent] {
      store.reset()
      let start = Date()
      let end = Calendar(identifier: .gregorian).date(byAdding: .year, value: 3, to: start)!
      return store.events(
        matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)
      ).filter { $0.url == marker }.sorted { $0.startDate < $1.startDate }
    }
    do {
      try await scheduler.upsert(schedule)
      let original = matching()
      let first = try #require(original.first)
      let later = try #require(original.last)
      let firstDate = try #require(first.startDate)
      let laterDate = try #require(later.startDate)
      try #require(laterDate > firstDate)
      let originalSeriesID = first.calendarItemIdentifier
      #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(first, schedule: schedule))
      later.alarms = [EKAlarm(relativeOffset: -2700)]
      try store.save(later, span: .thisEvent, commit: true)
      let changed = matching()
      let unchangedFirst = try #require(changed.first { $0.startDate == firstDate })
      let changedLater = try #require(changed.first { $0.startDate == laterDate })
      #expect(
        AppleBirthdayScheduler.matchesApprovedCalendarEvent(unchangedFirst, schedule: schedule))
      #expect(changedLater.alarms?.first?.relativeOffset == -2700)
      let preservedSeriesID = changedLater.calendarItemIdentifier == originalSeriesID
      await #expect(throws: OrganizationError.stalePreview) {
        try await scheduler.validateExisting(schedule)
      }
      await #expect(throws: OrganizationError.stalePreview) { try await scheduler.upsert(schedule) }
      #expect(
        matching().first { $0.startDate == laterDate }?.alarms?.first?.relativeOffset == -2700)
      try await scheduler.remove(schedule)
      #expect(matching().isEmpty)
      print(
        "MEMORYOS_LATER_CALENDAR_EXCEPTION rejected=true firstUnchanged=true sameSeriesID=\(preservedSeriesID) cleaned=true"
      )
    } catch {
      do { try await scheduler.remove(schedule) } catch {
        Issue.record(
          "Later-occurrence fixture cleanup failed: \(String(describing: type(of: error)))")
      }
      throw error
    }
  }

  /// Dated Simulator qualification: EventKit expands the actual adapter-created leap-day series.
  @Test func leapDayCalendarSeriesSkipsNonleapYearsAndReturnsIn2032() async throws {
    try #require(EKEventStore.authorizationStatus(for: .event) == .fullAccess)
    let store = EKEventStore()
    let local = try #require(store.sources.first { $0.sourceType == .local })
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Baghdad")!
    func yearStart(_ year: Int) -> Date {
      calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }
    try #require(
      Date() < yearStart(2028), "This dated qualification must run before its first occurrence.")
    let ownedCalendar = EKCalendar(for: .event, eventStore: store)
    ownedCalendar.source = local
    ownedCalendar.title = "Fictional MemoryOS leap-day verification " + UUID().uuidString
    try store.saveCalendar(ownedCalendar, commit: true)
    let ownedCalendarID = ownedCalendar.calendarIdentifier
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 2, day: 29, hour: 9, minute: 15,
      timeZoneID: calendar.timeZone.identifier, delivery: .calendar,
      title: "Fictional leap-day contract")
    let scheduler = AppleBirthdayScheduler()
    let marker = URL(string: "memoryos-birthday://schedule/" + schedule.id.uuidString)!
    func matching(in year: Int) -> [EKEvent] {
      store.reset()
      let predicate = store.predicateForEvents(
        withStart: yearStart(year), end: yearStart(year + 1), calendars: nil)
      return store.events(matching: predicate).filter { $0.url == marker }
    }
    func removeOwnedCalendar() throws {
      store.reset()
      if let current = store.calendar(withIdentifier: ownedCalendarID) {
        try store.removeCalendar(current, commit: true)
      }
    }
    do {
      try await scheduler.upsert(schedule)
      let first = try #require(matching(in: 2028).first)
      // Keep all retained fixture occurrences in an owned calendar. Do not change their recurrence.
      first.calendar = try #require(store.calendar(withIdentifier: ownedCalendarID))
      try store.save(first, span: .futureEvents, commit: true)
      try await scheduler.upsert(schedule)
      var actualYears: [Int] = []
      for year in 2028...2032 {
        let occurrences = matching(in: year)
        #expect(occurrences.count == (year == 2028 || year == 2032 ? 1 : 0))
        for event in occurrences {
          #expect(event.calendar.calendarIdentifier == ownedCalendarID)
          #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
          let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: event.startDate)
          #expect(parts.month == 2 && parts.day == 29 && parts.hour == 9 && parts.minute == 15)
          actualYears.append(try #require(parts.year))
        }
      }
      #expect(actualYears == [2028, 2032])
      try await scheduler.remove(schedule)
      for year in 2028...2032 { #expect(matching(in: year).isEmpty) }
      try removeOwnedCalendar()
      print(
        "MEMORYOS_LEAP_DAY_CALENDAR actualYears=\(actualYears) nonleapSkipped=true cleaned=true")
    } catch {
      do {
        try await scheduler.remove(schedule)
        try removeOwnedCalendar()
      } catch {
        Issue.record("Leap-day fixture cleanup failed: \(String(describing: type(of: error)))")
      }
      throw error
    }
  }

  @Test func approvedNotificationReplacesByIdentityAndRetainsExactAnnualTrigger() async throws {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    try #require(
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
      "Run the connected birthday permission flow first.")
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 3, day: 12, hour: 9, minute: 15,
      timeZoneID: "Asia/Baghdad", delivery: .notification, title: "Fictional adapter fixture")
    let scheduler = AppleBirthdayScheduler()
    do {
      try await scheduler.upsert(schedule)
      try await scheduler.upsert(schedule)
      let requests = await center.pendingNotificationRequests().filter {
        $0.identifier == schedule.identifier
      }
      #expect(requests.count == 1)
      let request = try #require(requests.first)
      let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
      #expect(trigger.repeats)
      #expect(trigger.dateComponents.month == 3 && trigger.dateComponents.day == 12)
      #expect(trigger.dateComponents.hour == 9 && trigger.dateComponents.minute == 15)
      #expect(trigger.dateComponents.timeZone?.identifier == "Asia/Baghdad")
      #expect(trigger.dateComponents.year == nil)
      #expect(request.content.body == schedule.title)
      #expect(trigger.nextTriggerDate() != nil)
      try await scheduler.remove(schedule)
      #expect(
        await center.pendingNotificationRequests().allSatisfy {
          $0.identifier != schedule.identifier
        })
    } catch {
      try? await scheduler.remove(schedule)
      throw error
    }
  }

  @Test func leapDayContractAcceptsExactDateAndRejectsLastFebruaryDay() throws {
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 2, day: 29, hour: 9, minute: 15,
      timeZoneID: "Asia/Baghdad", delivery: .calendar, title: "Fictional leap-day mapping")
    let event = EKEvent(eventStore: EKEventStore())
    event.title = "Birthday: " + schedule.title
    event.startDate = try #require(ISO8601DateFormatter().date(from: "2028-02-29T06:15:00Z"))
    event.endDate = event.startDate.addingTimeInterval(300)
    event.timeZone = TimeZone(identifier: schedule.timeZoneID)
    event.alarms = [EKAlarm(relativeOffset: 0)]
    event.recurrenceRules = [
      EKRecurrenceRule(
        recurrenceWith: .yearly, interval: 1, daysOfTheWeek: nil, daysOfTheMonth: [29],
        monthsOfTheYear: [2], weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
    ]
    #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.recurrenceRules = [
      EKRecurrenceRule(
        recurrenceWith: .yearly, interval: 1, daysOfTheWeek: nil, daysOfTheMonth: [28, 29],
        monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: [-1], end: nil)
    ]
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
  }

  @Test func calendarContractRejectsChangedAlarmDurationAndRecurrenceScope() throws {
    let schedule = BirthdaySchedule(
      birthdayID: UUID(), personID: UUID(), month: 3, day: 12,
      hour: 9, minute: 15, timeZoneID: "Asia/Baghdad", delivery: .calendar,
      title: "Fictional calendar fixture")
    let event = EKEvent(eventStore: EKEventStore())
    event.title = "Birthday: " + schedule.title
    event.startDate = try #require(ISO8601DateFormatter().date(from: "2027-03-12T06:15:00Z"))
    event.endDate = event.startDate.addingTimeInterval(300)
    event.timeZone = TimeZone(identifier: schedule.timeZoneID)
    event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil))
    event.alarms = [EKAlarm(relativeOffset: 0)]
    #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.alarms = [EKAlarm(relativeOffset: -3600)]
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.alarms = [EKAlarm(relativeOffset: 0), EKAlarm(relativeOffset: -86400)]
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.alarms = [EKAlarm(relativeOffset: 0)]
    event.endDate = event.startDate.addingTimeInterval(3600)
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.endDate = event.startDate.addingTimeInterval(300)
    event.recurrenceRules = [
      EKRecurrenceRule(
        recurrenceWith: .yearly, interval: 1,
        daysOfTheWeek: nil, daysOfTheMonth: nil, monthsOfTheYear: [3, 4], weeksOfTheYear: nil,
        daysOfTheYear: nil, setPositions: nil, end: nil)
    ]
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.recurrenceRules = [
      EKRecurrenceRule(
        recurrenceWith: .yearly, interval: 1,
        daysOfTheWeek: nil, daysOfTheMonth: [12], monthsOfTheYear: [3], weeksOfTheYear: nil,
        daysOfTheYear: nil, setPositions: nil, end: nil)
    ]
    #expect(AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
    event.timeZone = TimeZone(identifier: "UTC")
    #expect(!AppleBirthdayScheduler.matchesApprovedCalendarEvent(event, schedule: schedule))
  }

}

private final class BirthdayNotificationPresenter: NSObject, UNUserNotificationCenterDelegate,
  Sendable
{
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions { [.banner] }
}
