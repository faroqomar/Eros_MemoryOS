import MemoryCore
import SwiftUI

struct PersonalEntryDetail: View {
  @Bindable var model: PersonalMemoryViewModel
  let entryID: UUID
  let language: AppLanguage
  @State private var editing: PersonalMemoryEntry?
  @State private var linking = false
  private var entry: PersonalMemoryEntry? { model.snapshot.entries.first { $0.id == entryID } }

  var body: some View {
    List {
      PersonalMemoryStatus(model: model, language: language)
      if let entry {
        Section(entry.kind.title(language)) {
          Text(entry.text).textSelection(.enabled).accessibilityIdentifier("personal-entry-text")
          if entry.confirmed {
            Text(language.text("Confirmed by you", "أكدتها أنت")).font(.caption)
          }
          if entry.isOwnerCorrected == true {
            Text(language.text("Corrected by you", "صححتها أنت")).font(.caption)
          }
          if entry.isEpisode == true {
            Text(
              language.text("Event", "حدث") + (entry.eventTimeExpression.map { " · " + $0 } ?? "")
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
          }
          if let updatedID = entry.supersededByID {
            NavigationLink(
              language.text(
                "Earlier report · view current information", "معلومة سابقة · عرض المعلومة الحالية"),
              value: DemoDestination.personalEntry(updatedID))
          }
          Button(language.text("Correct or organize", "تصحيح أو تنظيم")) { editing = entry }
            .accessibilityIdentifier("edit-personal-entry")
        }
        Section(language.text("Sources and dates", "المصادر والتواريخ")) {
          ForEach(model.snapshot.sources.filter { entry.sourceIDs.contains($0.id) }) { source in
            NavigationLink(value: DemoDestination.personalSource(source.id)) {
              VStack(alignment: .leading, spacing: 5) {
                Text(source.text).lineLimit(3)
                Text(source.createdAt, format: .dateTime.month().day().year()).font(.caption)
              }
            }
          }
        }
        Section(language.text("People and projects", "أشخاص ومشاريع")) {
          ForEach(model.snapshot.profiles.filter { entry.profileIDs.contains($0.id) }) { profile in
            NavigationLink(profile.name, value: DemoDestination.personalProfile(profile.id))
          }
          let categories = entry.categories.filter { $0 != entry.kind.rawValue }
          if !categories.isEmpty { Text(categories.joined(separator: " · ")) }
        }
        Section(language.text("Connections", "روابط")) {
          ForEach(model.snapshot.links.filter { $0.fromID == entryID || $0.toID == entryID }) {
            link in
            let other = link.fromID == entryID ? link.toID : link.fromID
            if let target = model.snapshot.entries.first(where: { $0.id == other }) {
              NavigationLink(value: DemoDestination.personalEntry(target.id)) {
                Text(link.label + ": " + target.text).lineLimit(3)
              }
            }
          }
          Button(language.text("Link another memory", "ربط ذكرى أخرى")) { linking = true }
        }
        Button(language.text("Undo last change", "تراجع عن آخر تغيير")) {
          Task { await model.undo() }
        }
        .disabled(model.isBusy || model.snapshot.events.isEmpty)
        Section(language.text("Previous versions", "الإصدارات السابقة")) {
          ForEach(model.snapshot.events.reversed()) { event in
            if let previous = event.previousEntries.first(where: { $0.id == entryID }),
              !previous.text.utf8.elementsEqual(entry.text.utf8)
            {
              VStack(alignment: .leading, spacing: 5) {
                Text(previous.text).textSelection(.enabled)
                Text(event.createdAt, format: .dateTime.month().day().hour().minute()).font(
                  .caption)
              }
            }
          }
        }
        PersonalHistorySection(model: model, language: language)
      } else {
        Text(
          language.text(
            "This item changed after undo. Go back to your memory list.",
            "تغير العنصر بعد التراجع. عد إلى قائمة الذكريات."))
      }
    }.scrollContentBackground(.hidden).background(MemoryTheme.canvas)
      .navigationTitle(language.text("Memory", "ذكرى"))
      .toolbar(.visible, for: .navigationBar)
      .sheet(item: $editing) { entry in
        PersonalEntryEditor(model: model, entry: entry, language: language)
      }
      .sheet(isPresented: $linking) {
        PersonalLinkEditor(model: model, fromID: entryID, language: language)
      }
  }
}

struct PersonalInformationEditor: View {
  @Bindable var model: PersonalMemoryViewModel
  let profileID: UUID?
  let language: AppLanguage
  let question: PersonalProfileQuestion?
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var kind: PersonalMemoryKind = .fact
  @State private var sources: Set<UUID> = []

  init(
    model: PersonalMemoryViewModel, profileID: UUID?, language: AppLanguage,
    question: PersonalProfileQuestion? = nil
  ) {
    self.model = model
    self.profileID = profileID
    self.language = language
    self.question = question
    _kind = State(initialValue: question?.kind ?? .fact)
  }

  var body: some View {
    NavigationStack {
      Form {
        PersonalMemoryStatus(model: model, language: language)
        if let question {
          Text(question.title(language)).font(.headline)
            .accessibilityIdentifier("profile-question-" + question.rawValue)
        }
        Picker(language.text("Meaning", "المعنى"), selection: $kind) {
          ForEach(PersonalMemoryKind.allCases.filter(\.createsMemory), id: \.self) { kind in
            Text(kind.title(language)).tag(kind)
          }
        }.accessibilityIdentifier("personal-information-kind")
        TextField(language.text("Information", "المعلومة"), text: $text, axis: .vertical)
          .lineLimit(4...10).accessibilityIdentifier("personal-information-text")
        if kind == .interpretation {
          Text(
            language.text(
              "A possible explanation, open to correction. It is not a confirmed fact.",
              "تفسير محتمل قابل للتصحيح، وليس حقيقة مؤكدة.")
          )
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
        }
        DisclosureGroup(language.text("Link existing sources", "ربط مصادر موجودة")) {
          ForEach(model.snapshot.sources.filter { $0.kind?.createsMemory == true }) { source in
            Toggle(
              source.text,
              isOn: Binding(
                get: { sources.contains(source.id) },
                set: { if $0 { sources.insert(source.id) } else { sources.remove(source.id) } }))
          }
        }
        Button(language.text("Save", "حفظ")) {
          Task {
            if await model.addReport(
              text: text, kind: kind, profileID: profileID,
              question: question?.title(language), sourceIDs: Array(sources))
            {
              dismiss()
            }
          }
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
          .accessibilityIdentifier("save-personal-information")
      }
      .navigationTitle(language.text("Add information", "إضافة معلومة"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
        }
      }
    }.preferredColorScheme(.dark)
  }
}

struct PersonalEntryEditor: View {
  @Bindable var model: PersonalMemoryViewModel
  let entry: PersonalMemoryEntry
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var text: String
  @State private var categories: String
  @State private var profiles: Set<UUID>
  @State private var confirmsChange = false

  init(model: PersonalMemoryViewModel, entry: PersonalMemoryEntry, language: AppLanguage) {
    self.model = model
    self.entry = entry
    self.language = language
    _text = State(initialValue: entry.text)
    _categories = State(initialValue: entry.categories.joined(separator: ", "))
    _profiles = State(initialValue: Set(entry.profileIDs))
  }
  var body: some View {
    NavigationStack {
      Form {
        PersonalMemoryStatus(model: model, language: language)
        TextField(language.text("Correction", "التصحيح"), text: $text, axis: .vertical)
          .lineLimit(3...10).accessibilityIdentifier("personal-correction-text")
        Button(language.text("Save correction", "حفظ التصحيح")) {
          if entry.confirmed || entry.isOwnerCorrected == true || entry.evidence == nil {
            confirmsChange = true
          } else {
            Task { await saveCorrection(false) }
          }
        }.disabled(
          model.isBusy || text.utf8.elementsEqual(entry.text.utf8)
            || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityIdentifier("save-personal-correction")
        Section(language.text("Organization", "التنظيم")) {
          TextField(
            language.text("Categories, separated by commas", "فئات مفصولة بفواصل"),
            text: $categories
          )
          .accessibilityIdentifier("personal-categories")
          ForEach(model.snapshot.profiles.filter { $0.mergedIntoID == nil }) { profile in
            Toggle(
              profile.name,
              isOn: Binding(
                get: { profiles.contains(profile.id) },
                set: { if $0 { profiles.insert(profile.id) } else { profiles.remove(profile.id) } })
            )
          }
          Button(language.text("Save organization", "حفظ التنظيم")) {
            Task {
              if await model.organize(entry.id, categories: categories, profiles: Array(profiles)) {
                dismiss()
              }
            }
          }.disabled(model.isBusy).accessibilityIdentifier("save-personal-organization")
        }
      }.navigationTitle(language.text("Correct and organize", "تصحيح وتنظيم"))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(language.text("Cancel", "إلغاء")) { dismiss() }
          }
        }
        .confirmationDialog(
          language.text("Change this saved information?", "تغيير هذه المعلومة المحفوظة؟"),
          isPresented: $confirmsChange, titleVisibility: .visible
        ) {
          Button(language.text("Confirm correction", "تأكيد التصحيح")) {
            Task { await saveCorrection(true) }
          }
          Button(language.text("Cancel", "إلغاء"), role: .cancel) {}
        } message: {
          Text(
            language.text(
              "Your original source and previous version remain available.",
              "يبقى المصدر الأصلي والإصدار السابق محفوظين."))
        }
    }.preferredColorScheme(.dark)
  }
  private func saveCorrection(_ confirmed: Bool) async {
    if await model.correct(entry.id, text: text, confirmedChange: confirmed) { dismiss() }
  }
}

private struct PersonalLinkEditor: View {
  let model: PersonalMemoryViewModel
  let fromID: UUID
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var label = ""
  var body: some View {
    NavigationStack {
      List {
        PersonalMemoryStatus(model: model, language: language)
        TextField(language.text("Connection label", "وصف الرابط"), text: $label)
        ForEach(model.snapshot.currentEntries.filter { $0.id != fromID }) { entry in
          Button(entry.text) {
            Task { if await model.link(fromID, to: entry.id, label: label) { dismiss() } }
          }.disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
        }
      }.navigationTitle(language.text("Link memory", "ربط ذكرى"))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(language.text("Cancel", "إلغاء")) { dismiss() }
          }
        }
    }.preferredColorScheme(.dark)
  }
}
