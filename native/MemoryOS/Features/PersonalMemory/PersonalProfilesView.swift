import ImageIO
import MemoryCore
import SwiftUI
import UniformTypeIdentifiers

struct PersonalProfilesView: View {
  @Bindable var model: PersonalMemoryViewModel
  let kind: PersonalProfileKind
  let language: AppLanguage
  var menuIsOpen = false
  @State private var adding = false
  @FocusState private var searchFocused: Bool
  private var search: String { kind == .project ? model.projectsQuery : model.peopleQuery }

  private var profiles: [PersonalProfile] {
    model.snapshot.profiles.filter {
      $0.mergedIntoID == nil && ($0.kind == kind || (kind == .person && $0.kind == .selfProfile))
        && (search.isEmpty || $0.name.localizedStandardContains(search)
          || $0.aliases.contains { $0.localizedStandardContains(search) })
    }
  }
  var body: some View {
    List {
      PersonalMemoryStatus(model: model, language: language)
      TextField(
        language.text("Name or nickname", "الاسم أو اللقب"),
        text: kind == .project ? $model.projectsQuery : $model.peopleQuery
      )
      .focused($searchFocused)
      .accessibilityIdentifier("personal-profile-search")
      if profiles.isEmpty {
        if !search.isEmpty {
          Button(language.text("Clear search", "مسح البحث")) {
            if kind == .project { model.projectsQuery = "" } else { model.peopleQuery = "" }
          }.accessibilityIdentifier("clear-personal-search")
        }
        Text(
          language.text(
            "Add a name, then connect information from your conversations.",
            "أضف اسماً ثم اربط المعلومات من محادثاتك.")
        )
        .foregroundStyle(MemoryTheme.secondary)
      }
      ForEach(profiles) { profile in
        NavigationLink(value: DemoDestination.personalProfile(profile.id)) {
          HStack(spacing: 14) {
            Image(systemName: profile.kind == .project ? "folder" : "person.crop.circle")
              .font(.title2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
              Text(profile.kind == .selfProfile ? language.text("You", "أنت") : profile.name)
              if profile.isSuggested == true {
                Text(language.text("Suggested identity · review", "هوية مقترحة للمراجعة"))
                  .font(.caption).foregroundStyle(MemoryTheme.secondary)
              }
              if !profile.aliases.isEmpty {
                Text(profile.aliases.joined(separator: " · ")).font(.caption)
                  .foregroundStyle(MemoryTheme.secondary)
              }
            }
          }.padding(.vertical, 7)
        }.accessibilityIdentifier("personal-profile-\(profile.id)")
      }
      Button(
        language.text(
          kind == .project ? "Add project" : "Add person",
          kind == .project ? "إضافة مشروع" : "إضافة شخص")
      ) { adding = true }
      .frame(minHeight: 44).accessibilityIdentifier("add-personal-profile")
    }
    .scrollContentBackground(.hidden)
    .sheet(isPresented: $adding) {
      PersonalProfileEditor(model: model, kind: kind, language: language)
    }
    .onChange(of: menuIsOpen) { _, open in if open { searchFocused = false } }
    .task { await model.load() }
  }
}

struct PersonalProfileEditor: View {
  @Bindable var model: PersonalMemoryViewModel
  let kind: PersonalProfileKind
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var aliases = ""
  var existing: PersonalProfile? = nil

  var body: some View {
    NavigationStack {
      Form {
        PersonalMemoryStatus(model: model, language: language)
        TextField(language.text("Name", "الاسم"), text: $name)
          .accessibilityIdentifier("personal-profile-name")
        TextField(
          language.text("Nicknames, separated by commas", "ألقاب مفصولة بفواصل"), text: $aliases)
        if !model.suggestions.isEmpty && kind == .person {
          Section(
            language.text(
              "Possible existing people · no automatic merge", "أشخاص محتملون دون دمج تلقائي")
          ) {
            ForEach(model.suggestions) { person in Text(person.name) }
          }
        }
        Button(language.text("Save", "حفظ")) {
          Task {
            let saved: Bool
            if let existing {
              saved = await model.updateProfile(existing.id, name: name, aliases: aliases)
            } else {
              saved = await model.createProfile(kind: kind, name: name, aliases: aliases)
            }
            if saved { dismiss() }
          }
        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
          .accessibilityIdentifier("save-personal-profile")
      }
      .navigationTitle(
        language.text(
          kind == .project ? "New project" : "New person",
          kind == .project ? "مشروع جديد" : "شخص جديد")
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
        }
      }
      .onAppear {
        if let existing {
          name = existing.name
          aliases = existing.aliases.joined(separator: ", ")
        }
      }
      .task(id: name) { await model.suggestPeople(name) }
    }.preferredColorScheme(.dark)
  }
}

struct PersonalProfileDetail: View {
  @Bindable var model: PersonalMemoryViewModel
  let profileID: UUID
  let language: AppLanguage
  private enum InformationSheet: Identifiable {
    case manual
    case question(PersonalProfileQuestion)
    var id: String {
      switch self {
      case .manual: "manual"
      case .question(let question): question.id
      }
    }
    var question: PersonalProfileQuestion? {
      if case .question(let value) = self { value } else { nil }
    }
  }
  @State private var informationSheet: InformationSheet?
  @State private var photoPicker = false
  @State private var photoOrigin: PersonalPhotoOrigin = .supplied
  @State private var mergeTarget: PersonalProfile?
  @State private var editingProfile: PersonalProfile?

  private var profile: PersonalProfile? { model.snapshot.profiles.first { $0.id == profileID } }
  private var entries: [PersonalMemoryEntry] {
    model.snapshot.currentEntries.filter { $0.profileIDs.contains(profileID) }
      .sorted { $0.createdAt > $1.createdAt }
  }
  var body: some View {
    List {
      PersonalMemoryStatus(model: model, language: language)
      if let profile {
        if profile.isSuggested == true {
          Text(
            language.text(
              "MemoryOS suggested this identity from your words. Review its name and sources before merging people.",
              "اقترح MemoryOS هذه الهوية من كلامك. راجع الاسم والمصادر قبل دمج الأشخاص.")
          )
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
          .accessibilityIdentifier("suggested-personal-identity")
        }
        if let targetID = profile.mergedIntoID,
          let target = model.snapshot.profiles.first(where: { $0.id == targetID })
        {
          Section(language.text("Merged with", "دُمج مع")) {
            NavigationLink(target.name, value: DemoDestination.personalProfile(target.id))
            Button(language.text("Undo last change", "تراجع عن آخر تغيير")) {
              Task { await model.undo() }
            }
            .disabled(model.isBusy || model.snapshot.events.isEmpty)
          }
        }
        if let photo = model.snapshot.photos.first(where: { $0.id == profile.photoID }) {
          Section {
            PersonalPhotoView(data: photo.data, language: language)
            Text(photo.origin.title(language)).font(.caption)
            if let sourceID = photo.sourceID,
              let source = model.snapshot.sources.first(where: { $0.id == sourceID })
            {
              NavigationLink(
                language.text("Image source", "مصدر الصورة"),
                value: DemoDestination.personalSource(source.id))
            }
          }
        }
        Button(language.text("Edit name and nicknames", "تعديل الاسم والألقاب")) {
          editingProfile = profile
        }
        if !profile.aliases.isEmpty {
          Section(language.text("Also known as", "أسماء أخرى")) {
            Text(profile.aliases.joined(separator: " · "))
          }
        }
        Section(language.text("Information and timeline", "معلومات وتسلسل زمني")) {
          if entries.isEmpty {
            Text(
              language.text(
                "Link a saved statement or add information.", "اربط عبارة محفوظة أو أضف معلومة.")
            )
            .foregroundStyle(MemoryTheme.secondary)
          }
          ForEach(entries) { entry in
            NavigationLink(value: DemoDestination.personalEntry(entry.id)) {
              PersonalEntryRow(entry: entry, language: language)
            }
          }
          Button(language.text("Add information", "إضافة معلومة")) { informationSheet = .manual }
            .accessibilityIdentifier("profile-add-information")
        }
        if profile.kind != .project {
          Section(language.text("Optional questions", "أسئلة اختيارية")) {
            Text(language.text("Answer one, or skip them all.", "أجب عن سؤال أو تجاوزها كلها."))
              .font(.caption).foregroundStyle(MemoryTheme.secondary)
            ForEach(PersonalProfileQuestion.questions(for: profile.kind)) { question in
              Button(question.title(language)) {
                informationSheet = .question(question)
              }
            }
          }
          Section(language.text("Photo", "الصورة")) {
            Picker(language.text("Image origin", "أصل الصورة"), selection: $photoOrigin) {
              ForEach(PersonalPhotoOrigin.allCases, id: \.self) { origin in
                Text(origin.title(language)).tag(origin)
              }
            }
            Button(language.text("Choose image file", "اختيار ملف صورة")) { photoPicker = true }
          }
        }
        if profile.kind == .person {
          Section(language.text("Identity", "الهوية")) {
            Menu(language.text("Merge with another person…", "دمج مع شخص آخر…")) {
              ForEach(
                model.snapshot.profiles.filter {
                  $0.kind == .person && $0.id != profileID && $0.mergedIntoID == nil
                }
              ) { person in
                Button(person.name) { mergeTarget = person }
              }
            }.accessibilityIdentifier("personal-merge-menu")
          }
        }
        Button(language.text("Undo last change", "تراجع عن آخر تغيير")) {
          Task { await model.undo() }
        }
        .disabled(model.isBusy || model.snapshot.events.isEmpty)
      }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle(
      profile?.kind == .selfProfile ? language.text("You", "أنت") : profile?.name ?? ""
    )
    .toolbar(.visible, for: .navigationBar)
    .sheet(item: $editingProfile) { profile in
      PersonalProfileEditor(model: model, kind: profile.kind, language: language, existing: profile)
    }
    .sheet(item: $informationSheet) { destination in
      PersonalInformationEditor(
        model: model, profileID: profileID, language: language,
        question: destination.question
      ).id(destination.id)
    }
    .fileImporter(isPresented: $photoPicker, allowedContentTypes: [.image]) { result in
      switch result {
      case .success(let url):
        Task { await model.photo(profile: profileID, url: url, origin: photoOrigin) }
      case .failure(let error): model.fileOperationFailed(error)
      }
    }
    .confirmationDialog(
      language.text("Merge these people?", "دمج الشخصين؟"),
      isPresented: Binding(get: { mergeTarget != nil }, set: { if !$0 { mergeTarget = nil } }),
      titleVisibility: .visible
    ) {
      if let target = mergeTarget {
        Button(language.text("Merge into ", "دمج مع ") + target.name) {
          Task {
            await model.merge(profileID, into: target.id)
            mergeTarget = nil
          }
        }
      }
      Button(language.text("Cancel", "إلغاء"), role: .cancel) { mergeTarget = nil }
    } message: {
      Text(
        language.text(
          "Original sources stay separate. Undo can restore the profiles.",
          "تبقى المصادر الأصلية منفصلة. يمكنك التراجع لاستعادة الملفين."))
    }
  }

}

private struct PersonalPhotoView: View {
  let data: Data
  let language: AppLanguage
  var body: some View {
    if let image = thumbnail {
      Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 230)
        .accessibilityLabel(language.text("Profile image", "صورة الملف"))
    } else {
      Label(language.text("Image unavailable", "الصورة غير متاحة"), systemImage: "photo")
    }
  }

  // Render restored photos with a bounded thumbnail too; retain the original bytes in the model.
  private var thumbnail: UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, width <= 12_000, height <= 12_000, width * height <= 40_000_000,
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 720,
        ] as CFDictionary)
    else { return nil }
    return UIImage(cgImage: image)
  }
}
