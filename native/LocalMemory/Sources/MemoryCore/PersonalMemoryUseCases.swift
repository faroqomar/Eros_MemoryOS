import Foundation

/// Domain transactions own graph edits; providers receive no access to this actor.
public actor PersonalMemoryUseCases {
  private let repository: any PersonalMemoryRepository
  private var state: PersonalMemorySnapshot?
  private var busy = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(repository: any PersonalMemoryRepository) { self.repository = repository }

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

  private func loaded() async throws -> PersonalMemorySnapshot {
    if let state { return state }
    let value = try await repository.load()
    try value.validate()
    state = value
    return value
  }

  public func snapshot() async throws -> PersonalMemorySnapshot {
    await acquire()
    defer { release() }
    return try await loaded()
  }

  private func commit(_ proposed: PersonalMemorySnapshot, after old: PersonalMemorySnapshot)
    async throws
    -> PersonalMemorySnapshot
  {
    var next = proposed
    guard old.revision < UInt64.max - 1 else { throw PersonalMemoryError.limitReached }
    next.revision = old.revision + 1
    try next.validate()
    try Task.checkCancellation()
    try await repository.save(next)
    state = next
    return next
  }

  func edit(
    _ summary: String, retainsUndo: Bool = true,
    change: (inout PersonalMemorySnapshot) throws -> Void
  )
    async throws
    -> PersonalMemorySnapshot
  {
    await acquire()
    defer { release() }
    let old = try await loaded()
    var next = old
    try change(&next)
    Self.refreshConversationExcerpts(in: &next)
    if next == old { return old }
    if retainsUndo && next.graph != old.graph {
      next.events.append(
        PersonalMemoryEvent(id: UUID(), summary: summary, createdAt: Date(), before: old.graph))
      if next.events.count > PersonalMemoryLimits.retainedEvents { next.events.removeFirst() }
    }
    return try await commit(next, after: old)
  }

  public func ingest(source: PersonalMemorySource) async throws -> PersonalMemoryIngestion {
    let next = try await edit("Preserved original capture") { next in
      if let existing = next.sources.first(where: { $0.id == source.id }) {
        guard existing.text.utf8.elementsEqual(source.text.utf8),
          existing.conversationID == source.conversationID, existing.origin == source.origin,
          existing.clarificationContext == source.clarificationContext,
          existing.createdAt == source.createdAt
        else { throw PersonalMemoryError.conflictingSource }
        return
      }
      var original = source
      if original.kind == nil { original.analysis = PersonalMemoryAnalysisState(status: .pending) }
      next.sources.append(original)
      if let kind = original.kind, kind.createsMemory {
        Self.appendEntry(
          to: &next, text: original.text, kind: kind, sourceIDs: [source.id],
          profileIDs: kind == .preference || kind == .goal ? [next.selfProfileID] : [],
          confirmed: false)
      }
    }
    return PersonalMemoryIngestion(
      sourceID: source.id,
      needsClarification: next.sources.first(where: { $0.id == source.id })?.analysis?.status
        == .needsClarification)
  }

  static func appendEntry(
    to state: inout PersonalMemorySnapshot, text: String,
    kind: PersonalMemoryKind, sourceIDs: [UUID], profileIDs: [UUID], confirmed: Bool,
    ownerReviewed: Bool = false
  ) {
    var linkedProfiles = Set(profileIDs)
    let folded = " " + Self.normalizedWords(text) + " "
    let candidates = state.profiles.filter { $0.kind != .selfProfile && $0.mergedIntoID == nil }
    for profile in candidates {
      for alias in [profile.name] + profile.aliases {
        let name = Self.normalizedWords(alias)
        guard !name.isEmpty, folded.contains(" " + name + " ") else { continue }
        let owners = candidates.filter { candidate in
          ([candidate.name] + candidate.aliases).contains { Self.normalizedWords($0) == name }
        }
        if owners.count == 1 { linkedProfiles.insert(profile.id) }
      }
    }
    state.entries.append(
      PersonalMemoryEntry(
        id: UUID(), text: text, kind: kind,
        sourceIDs: sourceIDs, profileIDs: linkedProfiles.sorted { $0.uuidString < $1.uuidString },
        categories: [kind.rawValue],
        confirmed: kind == .interpretation ? false : confirmed,
        interpretationProvenance: kind == .interpretation && ownerReviewed ? .ownerReviewed : nil,
        createdAt: Date()))
  }

  static func normalizedWords(_ text: String) -> String {
    let folded = text.folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")
    )
    let unmarked = String(
      String.UnicodeScalarView(
        folded.unicodeScalars.filter { !CharacterSet.nonBaseCharacters.contains($0) }))
    return unmarked.replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(
      of: "إ", with: "ا"
    )
    .replacingOccurrences(of: "آ", with: "ا").replacingOccurrences(of: "ى", with: "ي")
    .replacingOccurrences(of: "ـ", with: "")
    .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(
      separator: " ")
  }

  /// Bounded exact excerpts are an inspectable summary, not an inferred psychological claim.
  private static func refreshConversationExcerpts(in state: inout PersonalMemorySnapshot) {
    let existing = state.entries.filter { $0.excerptConversationID != nil }
    let primary = state.entries.filter {
      $0.excerptConversationID == nil && $0.kind != .summary && $0.supersededByID == nil
    }
    let resolved = state.sources.filter {
      $0.conversationID != nil && $0.kind?.createsMemory == true
    }
    let groups = Dictionary(grouping: resolved, by: { $0.conversationID! })
    state.entries.removeAll { $0.excerptConversationID != nil }
    for conversation in groups.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      let sourceIDs = Set(groups[conversation, default: []].map(\.id))
      let entries = primary.filter {
        !$0.sourceIDs.isEmpty && $0.sourceIDs.contains(where: sourceIDs.contains)
          && $0.sourceIDs.allSatisfy { id in
            state.sources.contains { $0.id == id && $0.conversationID == conversation }
          }
      }
      .sorted {
        $0.createdAt == $1.createdAt
          ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
      }
      let selected = Array(entries.suffix(5))
      guard !selected.isEmpty else { continue }
      let old = existing.first { $0.excerptConversationID == conversation }
      let ids =
        old?.isEditedExcerpt == true
        ? old!.sourceIDs
        : Array(Set(selected.flatMap(\.sourceIDs)).intersection(sourceIDs)).sorted {
          $0.uuidString < $1.uuidString
        }
      guard ids.count <= 100 else { continue }
      let supportingEntries =
        old?.isEditedExcerpt == true
        ? entries.filter {
          $0.sourceIDs.filter(sourceIDs.contains).allSatisfy(ids.contains)
        }
        : selected
      let text =
        old?.isEditedExcerpt == true
        ? old!.text
        : "Source excerpts / مقتطفات المصادر\n"
          + selected.map {
            "[" + $0.kind.rawValue + "] " + Self.boundedExcerpt($0.text)
          }.joined(separator: "\n")
      state.entries.append(
        PersonalMemoryEntry(
          id: old?.id ?? UUID(), text: text, kind: .summary, sourceIDs: ids,
          profileIDs: old?.excerptProfilesAreEdited == true
            ? old!.profileIDs
            : Array(Set(supportingEntries.flatMap(\.profileIDs))).sorted {
              $0.uuidString < $1.uuidString
            },
          categories: old?.categories ?? ["Source excerpts"],
          confirmed: false, excerptConversationID: conversation,
          isEditedExcerpt: old?.isEditedExcerpt,
          excerptProfilesAreEdited: old?.excerptProfilesAreEdited,
          createdAt: old?.createdAt ?? selected[0].createdAt))
    }
  }

  private static func boundedExcerpt(_ text: String) -> String {
    var result = ""
    var bytes = 0
    for character in text.prefix(512) {
      let fragment = String(character)
      guard bytes + fragment.utf8.count <= 2_048 else { break }
      result += fragment
      bytes += fragment.utf8.count
    }
    return result
  }

  public func resolve(
    sourceID: UUID, kind: PersonalMemoryKind, profileIDs: [UUID] = [],
    confirmedChange: Bool = false
  ) async throws -> PersonalMemorySnapshot {
    try await edit("Clarified original capture") { next in
      guard let index = next.sources.firstIndex(where: { $0.id == sourceID }) else {
        throw PersonalMemoryError.missingSource
      }
      if next.entries.contains(where: { $0.sourceIDs.contains(sourceID) && $0.confirmed }),
        !confirmedChange
      {
        throw PersonalMemoryError.confirmationRequired
      }
      next.sources[index].kind = kind
      next.sources[index].analysis = PersonalMemoryAnalysisState(status: .processed)
      next.entries.removeAll { $0.sourceIDs.contains(sourceID) }
      let remainingEntryIDs = Set(next.entries.map(\.id))
      for entryIndex in next.entries.indices {
        if let target = next.entries[entryIndex].supersededByID,
          !remainingEntryIDs.contains(target)
        {
          next.entries[entryIndex].supersededByID = nil
        }
      }
      let retained = Set(next.entries.map(\.id)).union(next.profiles.map(\.id)).union(
        next.sources.map(\.id))
      next.links.removeAll { !retained.contains($0.fromID) || !retained.contains($0.toID) }
      for sourceIndex in next.sources.indices {
        if let protected = next.sources[sourceIndex].analysis?.protectedEntryID,
          !next.entries.contains(where: { $0.id == protected })
        {
          next.sources[sourceIndex].analysis = PersonalMemoryAnalysisState(status: .deferred)
        }
      }
      if kind.createsMemory {
        let profiles =
          profileIDs.isEmpty && (kind == .preference || kind == .goal)
          ? [next.selfProfileID] : profileIDs
        Self.appendEntry(
          to: &next, text: next.sources[index].text, kind: kind,
          sourceIDs: [sourceID], profileIDs: profiles, confirmed: kind == .fact,
          ownerReviewed: true)
      }
    }
  }

  public func addEntry(
    text: String, kind: PersonalMemoryKind, sourceIDs: [UUID],
    profileIDs: [UUID] = [], confirmed: Bool = false, ownerReviewed: Bool = false
  ) async throws -> PersonalMemorySnapshot {
    try await edit("Added source-backed memory") { next in
      for id in sourceIDs {
        guard let source = next.sources.first(where: { $0.id == id }) else {
          throw PersonalMemoryError.missingSource
        }
        guard source.kind?.createsMemory == true else { throw PersonalMemoryError.unresolvedSource }
      }
      Self.appendEntry(
        to: &next, text: text, kind: kind, sourceIDs: sourceIDs,
        profileIDs: profileIDs, confirmed: confirmed, ownerReviewed: ownerReviewed)
    }
  }

  public func updateEntry(id: UUID, text: String, confirmedChange: Bool = false) async throws
    -> PersonalMemorySnapshot
  {
    try await edit("Corrected memory; original retained") { next in
      guard let index = next.entries.firstIndex(where: { $0.id == id }) else {
        throw PersonalMemoryError.missingEntry
      }
      guard !next.entries[index].confirmed || confirmedChange else {
        throw PersonalMemoryError.confirmationRequired
      }
      next.entries[index].text = text
      next.entries[index].isOwnerCorrected = true
      next.entries[index].interpretationProvenance =
        next.entries[index].kind == .interpretation ? .ownerReviewed : nil
      next.entries[index].supersededByID = nil
      if next.entries[index].excerptConversationID != nil {
        next.entries[index].isEditedExcerpt = true
      }
    }
  }

  public func organize(entryID: UUID, categories: [String], profileIDs: [UUID]) async throws
    -> PersonalMemorySnapshot
  {
    try await edit("Changed categories and profile links") { next in
      guard let index = next.entries.firstIndex(where: { $0.id == entryID }) else {
        throw PersonalMemoryError.missingEntry
      }
      if next.entries[index].excerptConversationID != nil {
        next.entries[index].excerptProfilesAreEdited = true
      }
      next.entries[index].categories = Array(Set(categories)).sorted()
      next.entries[index].profileIDs = Array(Set(profileIDs)).sorted {
        $0.uuidString < $1.uuidString
      }
    }
  }

  public func createProfile(kind: PersonalProfileKind, name: String, aliases: [String] = [])
    async throws
    -> PersonalMemorySnapshot
  {
    try await edit("Created profile") { next in
      guard kind != .selfProfile else { throw PersonalMemoryError.confirmationRequired }
      var profile = PersonalProfile(kind: kind, name: name, aliases: aliases)
      profile.isSuggested = false
      next.profiles.append(profile)
    }
  }

  public func updateProfile(id: UUID, name: String, aliases: [String]) async throws
    -> PersonalMemorySnapshot
  {
    try await edit("Corrected profile name and aliases") { next in
      guard let index = next.profiles.firstIndex(where: { $0.id == id && $0.mergedIntoID == nil })
      else {
        throw PersonalMemoryError.missingProfile
      }
      next.profiles[index].name = name
      next.profiles[index].aliases = aliases
      next.profiles[index].isSuggested = false
    }
  }

  public func addLink(from: UUID, to: UUID, label: String) async throws -> PersonalMemorySnapshot {
    try await edit("Linked source context") { next in
      guard !next.links.contains(where: { $0.fromID == from && $0.toID == to && $0.label == label })
      else { return }
      next.links.append(PersonalMemoryLink(id: UUID(), fromID: from, toID: to, label: label))
    }
  }

  public func mergePeople(from: UUID, into: UUID, confirmed: Bool) async throws
    -> PersonalMemorySnapshot
  {
    guard confirmed else { throw PersonalMemoryError.confirmationRequired }
    return try await edit("Confirmed person merge; originals retained") { next in
      guard from != into,
        let source = next.profiles.firstIndex(where: {
          $0.id == from && $0.kind == .person && $0.mergedIntoID == nil
        }),
        let target = next.profiles.firstIndex(where: {
          $0.id == into && $0.kind == .person && $0.mergedIntoID == nil
        })
      else { throw PersonalMemoryError.missingProfile }
      // A reviewed target must not confer review on names imported from an unreviewed profile.
      if next.profiles[target].isSuggested == false && next.profiles[source].isSuggested != false {
        next.profiles[target].isSuggested = nil
      }
      next.profiles[target].aliases = Array(
        Set(
          next.profiles[target].aliases
            + next.profiles[source].aliases + [next.profiles[source].name])
      ).sorted()
      next.profiles[source].mergedIntoID = into
      for index in next.entries.indices where next.entries[index].profileIDs.contains(from) {
        next.entries[index].profileIDs = Array(
          Set(next.entries[index].profileIDs.map { $0 == from ? into : $0 })
        )
        .sorted { $0.uuidString < $1.uuidString }
      }
      // Older merged aliases must continue to point to a live target, without chains.
      for index in next.profiles.indices where next.profiles[index].mergedIntoID == from {
        next.profiles[index].mergedIntoID = into
      }
    }
  }

  public func suggestPeople(name: String) async throws -> [PersonalProfile] {
    let snapshot = try await snapshot()
    func normalized(_ text: String) -> String {
      let folded = text.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX"))
      return folded.replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(
        of: "إ", with: "ا"
      )
      .replacingOccurrences(of: "آ", with: "ا").replacingOccurrences(of: "ى", with: "ي")
      .replacingOccurrences(of: "ـ", with: "")
      .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(
        separator: " ")
    }
    let query = normalized(name)
    guard !query.isEmpty else { return [] }
    let terms = Set(query.split(separator: " "))
    return snapshot.profiles.filter { profile in
      profile.kind == .person && profile.mergedIntoID == nil
        && ([profile.name] + profile.aliases).contains { alias in
          let value = normalized(alias)
          return value == query || !Set(value.split(separator: " ")).intersection(terms).isEmpty
        }
    }
  }

  public func setPhoto(
    profileID: UUID, data: Data, origin: PersonalPhotoOrigin, sourceID: UUID? = nil,
    source: PersonalMemorySource? = nil
  ) async throws
    -> PersonalMemorySnapshot
  {
    try await edit("Changed profile image with provenance") { next in
      guard !data.isEmpty, data.count <= PersonalMemoryLimits.imageBytes else {
        throw PersonalMemoryError.invalidPhoto
      }
      guard
        let index = next.profiles.firstIndex(where: { $0.id == profileID && $0.kind != .project })
      else {
        throw PersonalMemoryError.missingProfile
      }
      if let source {
        guard source.kind == .conversationOnly, sourceID == nil || sourceID == source.id,
          !next.sources.contains(where: { $0.id == source.id })
        else { throw PersonalMemoryError.conflictingSource }
        next.sources.append(source)
      }
      let photo = PersonalPhoto(
        id: UUID(), data: data, origin: origin, sourceID: source?.id ?? sourceID, createdAt: Date())
      next.photos.append(photo)
      next.profiles[index].photoID = photo.id
    }
  }

  /// Optional questions use the same explicit original + derivation path; skipping writes nothing.
  public func answerProfileQuestion(
    profileID: UUID, question: String, answer: String,
    kind: PersonalMemoryKind = .preference
  ) async throws -> PersonalMemorySnapshot {
    try await edit("Answered optional profile question") { next in
      guard next.profiles.contains(where: { $0.id == profileID && $0.mergedIntoID == nil }) else {
        throw PersonalMemoryError.missingProfile
      }
      let source = PersonalMemorySource(
        text: question + "\n" + answer, origin: "profile answer", kind: kind)
      next.sources.append(source)
      Self.appendEntry(
        to: &next, text: answer, kind: kind, sourceIDs: [source.id], profileIDs: [profileID],
        confirmed: kind == .fact, ownerReviewed: true)
    }
  }

  public func undo() async throws -> PersonalMemorySnapshot {
    await acquire()
    defer { release() }
    let old = try await loaded()
    guard let event = old.events.last else { throw PersonalMemoryError.nothingToUndo }
    var next = old
    next.events.removeLast()
    next.apply(event.before)
    if event.summary == "Organized conversation memory" {
      for index in next.sources.indices
      where old.sources[index].analysis?.appliedRevision
        != next.sources[index].analysis?.appliedRevision
      {
        next.sources[index].analysis = PersonalMemoryAnalysisState(status: .ignored)
      }
    }
    return try await commit(next, after: old)
  }

  public func exportArchive() async throws -> Data {
    let value = try await snapshot()
    try value.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    guard data.count <= PersonalMemoryLimits.archiveBytes else {
      throw PersonalMemoryError.limitReached
    }
    return data
  }

  /// Restore into an empty graph only. Never silently overwrite live history or confirmed facts.
  public func restoreArchive(_ data: Data) async throws -> PersonalMemorySnapshot {
    guard data.count <= PersonalMemoryLimits.archiveBytes else {
      throw PersonalMemoryError.limitReached
    }
    let restored: PersonalMemorySnapshot
    do { restored = try JSONDecoder().decode(PersonalMemorySnapshot.self, from: data) } catch {
      throw PersonalMemoryError.invalidArchive
    }
    try restored.validate()
    await acquire()
    defer { release() }
    let old = try await loaded()
    guard old.sources.isEmpty, old.entries.isEmpty, old.profiles.count == 1, old.photos.isEmpty,
      old.links.isEmpty, old.events.isEmpty
    else { throw PersonalMemoryError.conflictingSource }
    return try await commit(restored, after: old)
  }
}
