import Foundation
import SwiftUI

struct CalendarOverviewView: View {
  private struct Birthday: Identifiable {
    let id: UUID
    let name: String
    let birthYear: Int?
  }

  private struct BirthdayDay: Hashable {
    let month: Int
    let day: Int
  }

  @Environment(OrganizationViewModel.self) private var model
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .callout) private var dayHeight = 48.0
  @State private var addingBirthday = false

  @Bindable var session: DemoSession

  private var language: AppLanguage { session.language }
  private var range: CalendarRange { session.calendarRange }
  private var selectedDate: Date {
    get { session.calendarDate }
    nonmutating set { session.calendarDate = newValue }
  }
  private let accent = MemoryTheme.workspaceAccent
  private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7)
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.locale = locale
    value.timeZone = .autoupdatingCurrent
    return value
  }

  var body: some View {
    let birthdayIndex = birthdaysByDate
    ScrollView {
      VStack(spacing: 20) {
        rangeControls
        periodHeader
        let selectedBirthdays = birthdays(on: selectedDate, in: birthdayIndex)
        if typeSize.isAccessibilitySize {
          birthdayList(selectedBirthdays)
          calendarGrid(birthdays: birthdayIndex)
        } else {
          calendarGrid(birthdays: birthdayIndex)
          birthdayList(selectedBirthdays)
        }
      }
      .padding(.horizontal, 14)
      .padding(.top, 8)
      .padding(.bottom, 20)
    }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $addingBirthday) {
      BirthdayEditor(model: model, language: language)
    }
  }

  private var rangeControls: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
      : AnyLayout(HStackLayout(spacing: 12))
    return layout {
      Picker(language.text("Calendar view", "عرض التقويم"), selection: $session.calendarRange) {
        Text(language.text("Month", "شهر")).tag(CalendarRange.month)
        Text(language.text("Week", "أسبوع")).tag(CalendarRange.week)
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("calendar-range")

      Button(language.text("Today", "اليوم")) { selectedDate = .now }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .foregroundStyle(accent)
        .accessibilityIdentifier("calendar-today")
    }
  }

  private var periodHeader: some View {
    HStack(spacing: 4) {
      periodButton(-1, symbol: "chevron.backward", label: previousPeriodLabel)
      Text(periodTitle)
        .font(.title2.weight(.semibold))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("calendar-period")
      periodButton(1, symbol: "chevron.forward", label: nextPeriodLabel)
    }
  }

  private var periodTitle: String {
    guard range == .week,
      let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate),
      let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)
    else { return selectedDate.formatted(dateFormat.month(.wide).year()) }
    let format = Date.IntervalFormatStyle(
      date: .abbreviated, time: .omitted, locale: locale, calendar: calendar,
      timeZone: calendar.timeZone)
    return (interval.start..<lastDay).formatted(format)
  }

  private var previousPeriodLabel: String {
    range == .month
      ? language.text("Previous month", "الشهر السابق")
      : language.text("Previous week", "الأسبوع السابق")
  }

  private var nextPeriodLabel: String {
    range == .month
      ? language.text("Next month", "الشهر التالي")
      : language.text("Next week", "الأسبوع التالي")
  }

  private func periodButton(_ offset: Int, symbol: String, label: String) -> some View {
    Button {
      let unit: Calendar.Component = range == .month ? .month : .weekOfYear
      if let date = calendar.date(byAdding: unit, value: offset, to: selectedDate) {
        selectedDate = date
      }
    } label: {
      Image(systemName: symbol).font(.body.weight(.medium))
        .frame(width: 44, height: 44)
        .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityIdentifier(offset < 0 ? "calendar-previous" : "calendar-next")
  }

  @ViewBuilder private func calendarGrid(birthdays: [BirthdayDay: [Birthday]]) -> some View {
    let days = visibleDays
    let weekdays = calendar.veryShortStandaloneWeekdaySymbols
    let firstWeekday = calendar.firstWeekday - 1
    if typeSize.isAccessibilitySize {
      LazyVStack(spacing: 4) {
        ForEach(days.compactMap { $0 }, id: \.self) { date in
          dayButton(date, hasBirthdays: !self.birthdays(on: date, in: birthdays).isEmpty)
        }
      }
    } else {
      LazyVGrid(columns: columns, spacing: 3) {
        ForEach(0..<7) { index in
          Text(weekdays[(firstWeekday + index) % 7])
            .font(.caption.weight(.semibold))
            .foregroundStyle(MemoryTheme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 6)
            .accessibilityHidden(true)
        }
        ForEach(days.indices, id: \.self) { index in
          if let date = days[index] {
            dayButton(date, hasBirthdays: !self.birthdays(on: date, in: birthdays).isEmpty)
          } else {
            Color.clear.frame(height: dayHeight).accessibilityHidden(true)
          }
        }
      }
    }
  }

  private func dayButton(_ date: Date, hasBirthdays: Bool) -> some View {
    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
    let isToday = calendar.isDateInToday(date)
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let shape = RoundedRectangle(cornerRadius: 12)
    return Button {
      selectedDate = date
    } label: {
      Text(
        typeSize.isAccessibilitySize
          ? date.formatted(fullDateFormat) : day.formatted(.number.locale(locale))
      )
      .font(.callout.weight(isSelected || isToday ? .bold : .medium))
      .monospacedDigit()
      .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
      .padding(.horizontal, typeSize.isAccessibilitySize ? 10 : 0)
      .frame(maxWidth: .infinity, minHeight: dayHeight)
      .foregroundStyle(isSelected ? MemoryTheme.onFilledControl : MemoryTheme.ink)
      .background(isSelected ? MemoryTheme.ink : .clear, in: shape)
      .overlay {
        if isToday && !isSelected { shape.strokeBorder(accent.opacity(0.65), lineWidth: 1) }
      }
      .overlay(alignment: .bottom) {
        if hasBirthdays {
          Circle()
            .fill(isSelected ? MemoryTheme.onFilledControl : accent)
            .frame(width: 5, height: 5)
            .padding(.bottom, 5)
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(date.formatted(fullDateFormat))
    .accessibilityValue(hasBirthdays ? language.text("Birthdays", "أعياد ميلاد") : "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("calendar-day-\(year)-\(month)-\(day)")
  }

  private func birthdayList(_ birthdays: [Birthday]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(selectedDate.formatted(fullDateFormat))
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("calendar-selected-date")
      OrganizationErrorRow(model: model, language: language)

      if model.isBusy && birthdays.isEmpty {
        ProgressView(language.text("Loading birthdays…", "جارٍ تحميل أعياد الميلاد…"))
      } else if model.error != nil {
        Button(language.text("Reload birthdays", "إعادة تحميل أعياد الميلاد")) {
          Task { await model.load() }
        }
        .frame(minHeight: 44)
      } else if birthdays.isEmpty {
        Text(language.text("No birthdays on this date", "لا توجد أعياد ميلاد في هذا التاريخ"))
          .foregroundStyle(MemoryTheme.secondary)
          .accessibilityIdentifier("calendar-empty-day")
      }
      Divider()
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) { birthdayActions }
        VStack(alignment: .leading, spacing: 0) { birthdayActions }
      }

      ForEach(birthdays) { birthday in
        NavigationLink {
          BirthdayRecordDetailView(birthdayID: birthday.id, language: language)
        } label: {
          Label(birthday.name, systemImage: "birthday.cake")
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("calendar-birthday-" + birthday.id.uuidString)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(MemoryTheme.panel, in: RoundedRectangle(cornerRadius: 22))
  }

  @ViewBuilder private var birthdayActions: some View {
    if model.people.isEmpty && !model.isBusy && model.error == nil {
      Button {
        session.section = .profiles
      } label: {
        Label(
          language.text("Add a person first", "أضف شخصاً أولاً"), systemImage: "person.badge.plus"
        )
        .frame(minHeight: 44)
      }
      .font(.subheadline.weight(.semibold))
    } else {
      Button {
        addingBirthday = true
      } label: {
        Label(language.text("Add birthday", "إضافة عيد ميلاد"), systemImage: "plus")
          .frame(minHeight: 44)
      }
      .font(.subheadline.weight(.semibold))
      .disabled(model.people.isEmpty || model.isBusy)
      .accessibilityIdentifier("calendar-add-birthday")
    }

    NavigationLink {
      BirthdaysView(session: session)
        .navigationTitle(language.text("Saved birthdays", "أعياد الميلاد المحفوظة"))
        .toolbar(.visible, for: .navigationBar)
    } label: {
      Text(language.text("View all birthdays", "عرض كل أعياد الميلاد"))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(accent)
        .frame(minHeight: 44)
    }
    .accessibilityIdentifier("calendar-all-birthdays")
  }

  private var dateFormat: Date.FormatStyle {
    Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
  }

  private var fullDateFormat: Date.FormatStyle {
    dateFormat.weekday(.wide).month(.wide).day().year()
  }

  private var visibleDays: [Date?] {
    let unit: Calendar.Component = range == .month ? .month : .weekOfYear
    guard let interval = calendar.dateInterval(of: unit, for: selectedDate) else { return [] }
    let leadingSpaces =
      (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday
        + 7) % 7
    let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    return Array(repeating: nil, count: leadingSpaces)
      + (0..<count).map { offset in
        calendar.date(byAdding: .day, value: offset, to: interval.start)
      }
  }

  private var birthdaysByDate: [BirthdayDay: [Birthday]] {
    let people = Dictionary(uniqueKeysWithValues: model.people.map { ($0.id, $0.name) })
    var result: [BirthdayDay: [Birthday]] = [:]
    for record in model.snapshot.birthdays {
      guard record.resolvedIntoBirthdayID == nil, let name = people[record.personID],
        let month = record.date.month, let day = record.date.day
      else { continue }
      result[BirthdayDay(month: month, day: day), default: []].append(
        Birthday(id: record.id, name: name, birthYear: record.date.year))
    }
    return result
  }

  private func birthdays(on date: Date, in index: [BirthdayDay: [Birthday]]) -> [Birthday] {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return [] }
    let key = BirthdayDay(month: month, day: day)
    return index[key, default: []].filter { ($0.birthYear ?? year) <= year }
  }
}
