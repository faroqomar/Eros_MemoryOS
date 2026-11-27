import MemoryCore
import OrganizationCore
import SwiftUI

struct BirthdaysView: View {
  @Environment(OrganizationViewModel.self) private var model
  let session: DemoSession
  @State private var adding = false
  @State private var reviewingMerge: MergedBirthdayReview?
  private var language: AppLanguage { session.language }
  var body: some View {
    List {
      OrganizationErrorRow(model: model, language: language)
      Section {
        Button {
          adding = true
        } label: {
          Label(language.text("Save a birthday", "حفظ عيد ميلاد"), systemImage: "plus")
            .frame(minHeight: 44)
        }.accessibilityIdentifier("birthday-add").disabled(model.people.isEmpty || model.isBusy)
        if model.people.isEmpty && !model.isBusy {
          Button(language.text("Open People", "فتح الأشخاص")) { session.section = .profiles }
        }
        if !model.snapshot.schedules.isEmpty {
          Button(language.text("Check approved schedules", "فحص الجداول المعتمدة")) {
            Task { await model.reconcile() }
          }
          .disabled(model.isBusy).accessibilityIdentifier("birthday-reconcile")
        }
        if model.isBusy {
          ProgressView(language.text("Updating birthdays…", "جارٍ تحديث أعياد الميلاد…"))
        }
      }
      if !model.mergedBirthdayReviews.isEmpty {
        Section(language.text("Review merged people", "مراجعة الأشخاص المدمجين")) {
          ForEach(model.mergedBirthdayReviews) { review in
            Button {
              reviewingMerge = review
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(
                  model.memory.profiles.first { $0.id == review.personID }?.name
                    ?? language.text("Person", "الشخص"))
                Text(
                  language.text(
                    "Choose the birthday to keep and check the reminder status.",
                    "اختر عيد الميلاد الذي تريد الاحتفاظ به وتحقق من حالة التذكيرات.")
                )
                .font(.caption).foregroundStyle(MemoryTheme.secondary)
              }
            }.disabled(model.isBusy).accessibilityIdentifier(
              "birthday-merge-review-" + review.id.uuidString)
          }
        }
      }
      Section {
        if model.snapshot.birthdays.isEmpty && !model.isBusy && model.error == nil {
          Text(
            language.text(
              model.people.isEmpty
                ? "Add a person to save their birthday."
                : "Choose a person and save the date parts you know.",
              model.people.isEmpty
                ? "أضف شخصاً لحفظ عيد ميلاده."
                : "اختر شخصاً واحفظ أجزاء التاريخ التي تعرفها.")
          )
          .foregroundStyle(MemoryTheme.secondary)
        }
        ForEach(model.snapshot.birthdays) { birthday in
          NavigationLink {
            BirthdayRecordDetailView(birthdayID: birthday.id, language: language)
          } label: {
            VStack(alignment: .leading) {
              Text(
                model.memory.profiles.first(where: { $0.id == birthday.personID })?.name
                  ?? language.text("Person unavailable", "الشخص غير متاح"))
              Text(birthday.date.display(language)).font(.subheadline).foregroundStyle(
                MemoryTheme.secondary)
              if birthday.resolvedIntoBirthdayID != nil {
                Text(
                  language.text(
                    "Earlier record · retained after merge", "سجل سابق · محفوظ بعد الدمج")
                )
                .font(.caption).foregroundStyle(MemoryTheme.secondary)
              }
            }
          }.accessibilityIdentifier("birthday-" + birthday.id.uuidString)
        }
      } footer: {
        Text(
          language.text(
            "Saving a date schedules nothing. You approve the exact annual schedule for each person.",
            "لا تؤدي إضافة التاريخ إلى جدولة تذكير. وافق على الجدول السنوي المحدد لكل شخص."))
      }
    }
    .listStyle(.insetGrouped).scrollContentBackground(.hidden)
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $adding) { BirthdayEditor(model: model, language: language) }
    .sheet(item: $reviewingMerge) { review in
      MergedBirthdayReviewView(model: model, review: review, language: language)
    }
  }
}

struct BirthdayRecordDetailView: View {
  @Environment(OrganizationViewModel.self) private var model
  let birthdayID: UUID
  let language: AppLanguage
  @State private var editing = false
  @State private var delivery: BirthdayDelivery = .notification
  @State private var hour = 9
  @State private var minute = 0
  @State private var zone = TimeZone.current.identifier
  @State private var reviewingMerge: MergedBirthdayReview?
  private var birthday: BirthdayRecord? { model.snapshot.birthdays.first { $0.id == birthdayID } }
  private var title: String {
    guard let birthday else { return language.text("Birthday", "عيد الميلاد") }
    return model.memory.profiles.first { $0.id == birthday.personID }?.name
      ?? language.text("Person unavailable", "الشخص غير متاح")
  }
  private var currentPerson: Bool {
    guard let birthday else { return false }
    return model.people.contains { $0.id == birthday.personID }
  }
  var body: some View {
    List {
      OrganizationErrorRow(model: model, language: language)
      if let birthday {
        Section(language.text("Saved date", "التاريخ المحفوظ")) {
          Text(birthday.date.display(language))
          if currentPerson {
            Button(language.text("Correct date", "تصحيح التاريخ")) { editing = true }
              .disabled(model.isBusy).accessibilityIdentifier("birthday-correct")
          }
          if let review = model.mergedBirthdayReviews.first(where: { $0.id == birthdayID }) {
            Button(
              language.text(
                "Review birthday after person merge", "مراجعة عيد الميلاد بعد دمج الشخص")
            ) { reviewingMerge = review }
            .disabled(model.isBusy)
          }
          if let target = birthday.resolvedIntoBirthdayID {
            Text(
              language.text(
                "This earlier date is retained as history. Open the reviewed birthday for the current person and date.",
                "يُحفظ هذا التاريخ السابق ضمن السجل. افتح عيد الميلاد المراجع لعرض الشخص والتاريخ الحاليين."
              )
            )
            .foregroundStyle(MemoryTheme.secondary)
            NavigationLink(language.text("Open reviewed birthday", "فتح عيد الميلاد المراجع")) {
              BirthdayRecordDetailView(birthdayID: target, language: language)
            }
          } else if model.memory.profiles.allSatisfy({ $0.id != birthday.personID }) {
            Text(
              language.text(
                "The original person is unavailable. This date keeps its original reference. Check the reminder status below; create a person in People and save a new birthday to set up another reminder.",
                "الشخص الأصلي غير متاح. يحتفظ هذا التاريخ بمرجعه الأصلي. تحقق من حالة التذكير أدناه؛ أنشئ شخصاً في قسم الأشخاص واحفظ عيد ميلاد جديداً لإعداد تذكير آخر."
              )
            ).font(.callout).foregroundStyle(MemoryTheme.secondary)
          }
          if !birthday.previousDates.isEmpty {
            DisclosureGroup(language.text("Previous dates", "التواريخ السابقة")) {
              Text(birthday.previousDates.map { $0.display(language) }.joined(separator: "\n"))
            }
          }
        }
        if currentPerson {
          Section {
            if birthday.date.month == nil || birthday.date.day == nil {
              Label(
                language.text(
                  "Add the month and day in Correct date to review a reminder.",
                  "أضف الشهر واليوم من تصحيح التاريخ لمراجعة التذكير."
                ),
                systemImage: "calendar.badge.exclamationmark"
              )
              .foregroundStyle(MemoryTheme.secondary)
            }
            Picker(language.text("Delivery", "طريقة التذكير"), selection: $delivery) {
              Text(language.text("Notification", "إشعار")).tag(BirthdayDelivery.notification)
              Text(language.text("On-device calendar", "تقويم على الجهاز")).tag(
                BirthdayDelivery.calendar)
            }.accessibilityIdentifier("birthday-delivery")
            Stepper(value: $hour, in: 0...23) {
              Text(language.text("Hour: \(hour)", "الساعة: \(hour)"))
            }
            Stepper(value: $minute, in: 0...59) {
              Text(language.text("Minute: \(minute)", "الدقيقة: \(minute)"))
            }
            TextField(language.text("Timezone", "المنطقة الزمنية"), text: $zone)
              .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier(
                "birthday-zone")
            Button(language.text("Review annual schedule", "مراجعة الجدول السنوي")) {
              Task {
                await model.previewBirthday(
                  birthdayID, delivery: delivery, hour: hour, minute: minute, zone: zone)
              }
            }.accessibilityIdentifier("birthday-preview").disabled(
              model.isBusy || birthday.date.month == nil || birthday.date.day == nil)
          } header: {
            Text(language.text("Choose reminder", "اختيار التذكير"))
          } footer: {
            Text(
              language.text(
                "Annual Gregorian date at this fixed timezone. Feb 29 runs only in leap years. Calendar needs an on-device calendar; synced accounts are excluded. Each delivery follows your one exact approval.",
                "تاريخ ميلادي سنوي في المنطقة الزمنية المحددة. يعمل ٢٩ فبراير في السنوات الكبيسة فقط. يتطلب التقويم تقويماً محلياً على الجهاز. يجري كل تذكير وفق موافقتك على الجدول المحدد."
              ))
          }
        }
        Section(language.text("Approved schedules", "الجداول المعتمدة")) {
          let active = model.snapshot.schedules.filter {
            $0.birthdayID == birthdayID && $0.state != .disabled
          }
          if active.isEmpty {
            Text(language.text("Reminders are off", "التذكيرات متوقفة"))
              .foregroundStyle(MemoryTheme.secondary)
          }
          ForEach(active) { schedule in
            VStack(alignment: .leading, spacing: 4) {
              Text(schedule.display(language))
              Text(schedule.state.title(language)).font(.caption).foregroundStyle(
                MemoryTheme.secondary)
            }.accessibilityIdentifier("birthday-schedule")
          }
          if active.contains(where: { $0.state == .reviewRequired }) {
            Text(
              language.text(
                "Calendar behavior differs from your approval. Keep that behavior, turn reminders off, or review and approve a new schedule. The old approval cannot replace it.",
                "يختلف سلوك التقويم عن موافقتك. احتفظ بهذا السلوك أو أوقف التذكيرات أو راجع جدولاً جديداً ووافق عليه. لا يمكن للموافقة القديمة استبداله."
              )
            ).font(.caption).foregroundStyle(MemoryTheme.secondary)
          }
          let earlier = model.snapshot.schedules.filter {
            $0.birthdayID == birthdayID && $0.state == .disabled
          }
          if !earlier.isEmpty {
            DisclosureGroup(language.text("Earlier approvals (off)", "الموافقات السابقة (متوقفة)"))
            {
              ForEach(earlier) { schedule in
                VStack(alignment: .leading, spacing: 4) {
                  Text(schedule.display(language))
                  if schedule.stateBeforeRestore != nil {
                    Text(
                      language.text(
                        "Restored approval. Review a new schedule to enable reminders.",
                        "موافقة مستعادة. راجع جدولاً جديداً لتفعيل التذكيرات.")
                    )
                    .font(.caption).foregroundStyle(MemoryTheme.secondary)
                  }
                }
              }
            }
          }
          Button(language.text("Turn reminders off", "إيقاف التذكيرات"), role: .destructive) {
            Task { await model.disableBirthday(birthdayID) }
          }.disabled(model.isBusy || active.isEmpty).accessibilityIdentifier("birthday-disable")
        }
      } else {
        ContentUnavailableView(
          language.text("Birthday unavailable", "عيد الميلاد غير متاح"), systemImage: "gift",
          description: Text(
            language.text(
              "Return to birthdays or refresh to check the current saved record.",
              "عد إلى أعياد الميلاد أو حدّث لعرض السجل المحفوظ الحالي.")))
        Button(language.text("Refresh", "تحديث")) { Task { await model.load() } }.disabled(
          model.isBusy)
      }
    }
    .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
    .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $editing) {
      BirthdayEditor(model: model, birthday: birthday, language: language)
    }
    .sheet(item: $reviewingMerge) { review in
      MergedBirthdayReviewView(model: model, review: review, language: language)
    }
    .sheet(
      isPresented: Binding(
        get: { model.schedulePreview != nil }, set: { if !$0 { model.dismissSchedule() } })
    ) {
      if let proposal = model.schedulePreview {
        NavigationStack {
          List {
            Text(proposal.display(language))
            Text(
              language.text(
                "Approve this exact annual behavior once. Changes to person, date, delivery, time or timezone require another review. The OS requests permission after approval.",
                "وافق مرة واحدة على هذا السلوك السنوي المحدد. يتطلب تغيير الشخص أو التاريخ أو طريقة التذكير أو الوقت أو المنطقة الزمنية مراجعة جديدة. سيطلب النظام الإذن بعد الموافقة."
              ))
            OrganizationErrorRow(model: model, language: language)
            Button(language.text("Approve recurring schedule", "اعتماد الجدول المتكرر")) {
              Task { await model.approveSchedule() }
            }
            .disabled(model.isBusy).accessibilityIdentifier("birthday-approve")
          }.navigationTitle(language.text("Review schedule", "مراجعة الجدول"))
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(language.text("Cancel", "إلغاء")) { model.dismissSchedule() }
              }
            }
        }.preferredColorScheme(.dark)
      }
    }
  }
}

private struct MergedBirthdayReviewView: View {
  let model: OrganizationViewModel
  let review: MergedBirthdayReview
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var choice = 0
  private var selectedDate: BirthdayDate? {
    choice == 1 ? review.date : (choice == 2 ? review.existingBirthdayDate : nil)
  }
  private func name(_ id: UUID) -> String {
    model.memory.profiles.first { $0.id == id }?.name
      ?? language.text("Person unavailable", "الشخص غير متاح")
  }
  var body: some View {
    NavigationStack {
      Form {
        OrganizationErrorRow(model: model, language: language)
        Text(
          language.text(
            "These profiles were merged into \(name(review.personID)). Choose which saved date to keep for this person.",
            "دُمجت هذه الملفات في \(name(review.personID)). اختر التاريخ المحفوظ الذي تريد الاحتفاظ به لهذا الشخص."
          ))
        Section(
          language.text(
            "Earlier profile: \(name(review.previousPersonID))",
            "الملف السابق: \(name(review.previousPersonID))")
        ) {
          Text(review.date.display(language))
        }
        if let existingDate = review.existingBirthdayDate {
          Section(
            language.text(
              "Current profile: \(name(review.personID))", "الملف الحالي: \(name(review.personID))")
          ) {
            Text(existingDate.display(language))
          }
        }
        if model.mergedBirthdayReviews.contains(review) {
          Picker(language.text("Date to keep", "التاريخ المراد الاحتفاظ به"), selection: $choice) {
            Text(language.text("Choose a date", "اختر تاريخاً")).tag(0)
            Text(language.text("Earlier profile's date", "تاريخ الملف السابق")).tag(1)
            if review.existingBirthdayDate != nil {
              Text(language.text("Current profile's date", "تاريخ الملف الحالي")).tag(2)
            }
          }.accessibilityIdentifier("birthday-merge-date")
          Text(
            language.text(
              "This confirms only the person and date. Earlier records remain in history. No reminder is created; review a new schedule separately.",
              "يؤكد هذا الشخص والتاريخ فقط. تبقى السجلات السابقة في التاريخ. لن يُنشأ تذكير؛ راجع جدولاً جديداً بشكل منفصل."
            )
          )
          .font(.callout).foregroundStyle(MemoryTheme.secondary)
          Button(
            language.text(
              "Confirm birthday for \(name(review.personID))",
              "تأكيد عيد ميلاد \(name(review.personID))")
          ) {
            guard let selectedDate else { return }
            Task {
              if await model.resolveMergedBirthday(review, date: selectedDate) { dismiss() }
            }
          }.disabled(selectedDate == nil || model.isBusy).accessibilityIdentifier(
            "birthday-merge-confirm")
        } else {
          Text(
            language.text(
              "This review has changed or finished. Close it and reopen the birthday to check the current dates and reminder status.",
              "تغيرت هذه المراجعة أو انتهت. أغلقها وافتح عيد الميلاد مجدداً للتحقق من التواريخ الحالية وحالة التذكيرات."
            ))
        }
      }
      .navigationTitle(language.text("Review birthday", "مراجعة عيد الميلاد"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Close", "إغلاق")) { dismiss() }
        }
      }
    }.preferredColorScheme(.dark)
  }
}

struct BirthdayEditor: View {
  let model: OrganizationViewModel
  var birthday: BirthdayRecord?
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var personID: UUID?
  @State private var year = ""
  @State private var month = ""
  @State private var day = ""
  var body: some View {
    NavigationStack {
      Form {
        OrganizationErrorRow(model: model, language: language)
        Picker(language.text("Person", "الشخص"), selection: $personID) {
          Text(language.text("Choose person", "اختر شخصاً")).tag(nil as UUID?)
          ForEach(model.people) { person in Text(person.name).tag(Optional(person.id)) }
        }.disabled(birthday != nil).accessibilityIdentifier("birthday-person")
        TextField(language.text("Year (optional)", "السنة (اختياري)"), text: $year).keyboardType(
          .numberPad
        ).accessibilityIdentifier("birthday-year")
        TextField(language.text("Month (optional)", "الشهر (اختياري)"), text: $month).keyboardType(
          .numberPad
        ).accessibilityIdentifier("birthday-month")
        TextField(language.text("Day (optional)", "اليوم (اختياري)"), text: $day).keyboardType(
          .numberPad
        ).accessibilityIdentifier("birthday-day")
        Text(
          language.text(
            "Leave unknown parts empty. Corrections retain the previous date and turn reminders off until you approve a new schedule.",
            "اترك الأجزاء غير المعروفة فارغة. يحتفظ التصحيح بالتاريخ السابق ويوقف التذكيرات إلى أن تعتمد جدولاً جديداً."
          ))
      }
      .navigationTitle(language.text("Save birthday", "حفظ عيد ميلاد"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Save", "حفظ")) {
            guard let personID else { return }
            Task {
              if await model.saveBirthday(personID: personID, year: year, month: month, day: day) {
                dismiss()
              }
            }
          }.disabled(personID == nil || model.isBusy).accessibilityIdentifier("birthday-save")
        }
      }
      .onAppear {
        guard let birthday else { return }
        personID = birthday.personID
        year = birthday.date.year.map(String.init) ?? ""
        month = birthday.date.month.map(String.init) ?? ""
        day = birthday.date.day.map(String.init) ?? ""
      }
    }.preferredColorScheme(.dark)
  }
}

extension BirthdayDate {
  func display(_ language: AppLanguage) -> String {
    language.text(
      "Year \(year.map(String.init) ?? "?") · Month \(month.map(String.init) ?? "?") · Day \(day.map(String.init) ?? "?")",
      "السنة \(year.map(String.init) ?? "؟") · الشهر \(month.map(String.init) ?? "؟") · اليوم \(day.map(String.init) ?? "؟")"
    )
  }
}
extension BirthdaySchedule {
  func display(_ language: AppLanguage) -> String {
    let time = String(format: "%02d:%02d", hour, minute)
    let kind =
      delivery == .notification
      ? language.text("Notification", "إشعار")
      : language.text("On-device calendar", "تقويم على الجهاز")
    let date = language.text("Month \(month) · Day \(day)", "الشهر \(month) · اليوم \(day)")
    return "\(title) · \(date) · \(time) · \(timeZoneID) · \(kind)"
  }
}
extension BirthdayScheduleState {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .pending:
      language.text("Approved · OS outcome unconfirmed", "معتمد · نتيجة النظام غير مؤكدة")
    case .active: language.text("Scheduled annually", "مجدول سنوياً")
    case .disabled: language.text("Off", "متوقف")
    case .cancellationPending:
      language.text(
        "Cancellation pending · an old OS reminder may still run",
        "الإلغاء قيد الانتظار · قد يستمر تذكير النظام القديم")
    case .reviewRequired:
      language.text(
        "Calendar behavior differs · review required", "يختلف سلوك التقويم · المراجعة مطلوبة")
    case .failed:
      language.text(
        "Delivery setup failed · check permissions and retry",
        "فشل إعداد التذكير · افحص الأذونات وأعد المحاولة")
    }
  }
}
