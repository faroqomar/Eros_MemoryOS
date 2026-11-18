import Foundation

extension PersonalMemoryUseCases {
  public func nextAnalysisInput(
    conversationID: UUID? = nil, excluding: Set<UUID> = []
  ) async throws -> PersonalMemoryAnalysisInput? {
    let value = try await snapshot()
    guard
      let source = value.analysisPendingSources.first(where: {
        !excluding.contains($0.id) && (conversationID == nil || $0.conversationID == conversationID)
      })
    else { return nil }
    let context = value.sources.filter {
      $0.id != source.id && $0.conversationID == source.conversationID
        && $0.origin == "chat"
        && $0.createdAt <= source.createdAt
        && ($0.analysis == nil || $0.analysis?.status == .processed)
        && (($0.kind?.createsMemory == true)
          || ($0.kind == .conversationOnly && $0.analysis?.status == .processed))
    }.sorted { $0.createdAt < $1.createdAt }
    let answer = source.analysis?.answerSourceID.flatMap { id in value.sources.first { $0.id == id }
    }
    let entries = value.currentEntries.filter { $0.excerptConversationID == nil }
      .sorted { $0.createdAt < $1.createdAt }.suffix(12)
    let text = ([source] + Array(context.suffix(3))).map(\.text).joined(separator: " ")
    let folded = " " + Self.normalizedWords(text) + " "
    let profiles = value.profiles.filter { profile in
      profile.mergedIntoID == nil
        && (profile.kind == .selfProfile
          || ([profile.name] + profile.aliases).contains {
            folded.contains(" " + Self.normalizedWords($0) + " ")
          } || entries.contains { $0.profileIDs.contains(profile.id) })
    }
    return PersonalMemoryAnalysisInput(
      source: source, context: Array(context.suffix(3)), clarificationAnswer: answer,
      profiles: Array(profiles.prefix(24)), entries: Array(entries), revision: value.revision)
  }

  /// A failed/unavailable model never converts original-only work into an empty success.
  public func deferAnalysis(sourceID: UUID) async throws -> PersonalMemorySnapshot {
    try await edit("Deferred memory organization; original retained") { next in
      guard let index = next.sources.firstIndex(where: { $0.id == sourceID }) else {
        throw PersonalMemoryError.missingSource
      }
      guard
        next.sources[index].analysis?.status == .pending
          || (next.sources[index].analysis == nil && next.sources[index].kind == nil)
      else { return }
      var state = next.sources[index].analysis ?? PersonalMemoryAnalysisState(status: .pending)
      state.status = .deferred
      next.sources[index].analysis = state
    }
  }

  public func retryAnalysis(sourceID: UUID? = nil) async throws -> PersonalMemorySnapshot {
    try await edit("Retried pending memory organization") { next in
      for index in next.sources.indices
      where (sourceID == nil || next.sources[index].id == sourceID)
        && next.sources[index].analysis?.status == .deferred
      {
        next.sources[index].analysis?.status = .pending
        // Explicit retry requests a full-source review, including its linked answer.
        next.sources[index].analysis?.hasDeferredRemainder = nil
      }
    }
  }

  /// Dismissing a question preserves clear memories already accepted from other source clauses.
  public func skipClarification(sourceID: UUID) async throws -> PersonalMemorySnapshot {
    try await edit("Kept original without organizing unanswered part") { next in
      guard let index = next.sources.firstIndex(where: { $0.id == sourceID }),
        let state = next.sources[index].analysis, state.status == .needsClarification
      else { throw PersonalMemoryError.unresolvedSource }
      let deferred = state.hasDeferredRemainder == true
      let answerContext = state.answerSourceID.flatMap { answerID in
        next.sources.first { $0.id == answerID }?.clarificationContext
      }
      next.sources[index].analysis = PersonalMemoryAnalysisState(
        status: deferred ? .deferred : .ignored,
        question: deferred && state.answerSourceID != nil
          ? (answerContext?.question ?? state.question) : nil,
        quote: deferred && state.answerSourceID != nil
          ? (answerContext?.quote ?? state.quote) : nil,
        answerSourceID: state.answerSourceID,
        appliedRevision: state.appliedRevision,
        hasDeferredRemainder: deferred ? true : nil)
      if !deferred
        && !next.entries.contains(where: {
          $0.excerptConversationID == nil && $0.sourceIDs.contains(sourceID)
        })
      {
        next.sources[index].kind = .conversationOnly
      }
    }
  }

  /// The answer is a new original, explicitly attached to one question; it is not a memory edit.
  public func answerClarification(sourceID: UUID, answer: String) async throws
    -> PersonalMemorySnapshot
  {
    try PersonalMemoryLimits.text(answer)
    return try await edit("Answered memory clarification; originals retained") { next in
      guard let index = next.sources.firstIndex(where: { $0.id == sourceID }),
        var state = next.sources[index].analysis, state.status == .needsClarification,
        let question = state.question, let quote = state.quote
      else { throw PersonalMemoryError.unresolvedSource }
      var original = PersonalMemorySource(
        conversationID: next.sources[index].conversationID, text: answer,
        origin: "clarification answer", kind: .conversationOnly,
        clarificationContext: PersonalMemoryClarificationContext(
          parentSourceID: sourceID, question: question, quote: quote))
      original.analysis = PersonalMemoryAnalysisState(status: .processed)
      next.sources.append(original)
      state.status = .pending
      state.answerSourceID = original.id
      next.sources[index].analysis = state
    }
  }

  /// Validate and commit one immutable source against the exact state the analyzer saw.
  public func applyAnalysis(_ result: PersonalMemoryAnalysis, input: PersonalMemoryAnalysisInput)
    async throws -> PersonalMemorySnapshot
  {
    try await edit("Organized conversation memory") { next in
      guard let index = next.sources.firstIndex(where: { $0.id == input.source.id }) else {
        throw PersonalMemoryError.missingSource
      }
      let source = next.sources[index]
      guard source.text.utf8.elementsEqual(input.source.text.utf8),
        source.createdAt == input.source.createdAt,
        source.conversationID == input.source.conversationID,
        source.origin.utf8.elementsEqual(input.source.origin.utf8)
      else { throw PersonalMemoryError.conflictingSource }
      if source.analysis?.appliedRevision == input.revision { return }
      guard source.origin == "chat", next.revision == input.revision,
        next.analysisPendingSources.contains(where: { $0.id == source.id })
      else { throw PersonalMemoryError.staleAnalysis }
      guard result.memories.count <= 3, result.deferredQuotes.count <= 4 else {
        throw PersonalMemoryError.invalidAnalysis
      }
      var deferredRanges: [Range<Int>] = []
      for quote in result.deferredQuotes {
        let range = try Self.exactRange(quote, in: source.text)
        guard !deferredRanges.contains(where: { $0.overlaps(range) }) else {
          throw PersonalMemoryError.invalidAnalysis
        }
        deferredRanges.append(range)
      }
      let hasDeferredRemainder =
        !deferredRanges.isEmpty
        || (source.analysis?.hasDeferredRemainder == true
          && source.analysis?.answerSourceID != nil)
      var question = result.clarification
      if let question {
        try PersonalMemoryLimits.text(question.question, maximum: 1_600)
        let range = try Self.exactRange(question.quote, in: source.text)
        guard !deferredRanges.contains(where: { $0.overlaps(range) }) else {
          throw PersonalMemoryError.unresolvedSource
        }
      }
      var proposalRanges: [Range<Int>] = []
      for proposal in result.memories {
        guard proposal.kind.createsMemory, proposal.kind != .summary,
          proposal.contextEvidence.count <= 3
        else { throw PersonalMemoryError.invalidAnalysis }
        let range = try Self.exactRange(proposal.quote, in: source.text)
        if let expression = proposal.eventTimeExpression {
          guard proposal.isEpisode else { throw PersonalMemoryError.invalidAnalysis }
          _ = try Self.exactRange(expression, in: proposal.quote)
        }
        guard !proposalRanges.contains(where: { $0.overlaps(range) }),
          !deferredRanges.contains(where: { $0.overlaps(range) })
        else {
          throw PersonalMemoryError.invalidAnalysis
        }
        proposalRanges.append(range)
        if let question {
          guard !(try Self.exactRange(question.quote, in: source.text)).overlaps(range) else {
            throw PersonalMemoryError.unresolvedSource
          }
        }
      }
      var protectedEntry: UUID?
      var accepted = false
      var acceptedKinds = Set<PersonalMemoryKind>()
      for proposal in result.memories {
        var evidence = [PersonalMemoryEvidence(sourceID: source.id, quote: proposal.quote)]
        for support in proposal.contextEvidence {
          guard support.sourceID != source.id,
            let original = next.sources.first(where: { $0.id == support.sourceID }),
            input.context.contains(where: { $0.id == support.sourceID })
              || input.clarificationAnswer?.id == support.sourceID,
            original.conversationID == source.conversationID,
            original.origin == "chat"
              || (original.origin == "clarification answer"
                && source.analysis?.answerSourceID == original.id),
            original.origin != "chat" || original.createdAt <= source.createdAt,
            original.analysis == nil || original.analysis?.status == .processed,
            original.kind?.createsMemory == true
              || (original.kind == .conversationOnly && original.analysis?.status == .processed)
          else { throw PersonalMemoryError.invalidAnalysis }
          _ = try Self.exactRange(support.quote, in: original.text)
          evidence.append(support)
        }
        let existing: PersonalMemoryEntry?
        if let id = proposal.replacesEntryID {
          guard input.entries.contains(where: { $0.id == id }),
            let match = next.entries.first(where: { $0.id == id }),
            match.excerptConversationID == nil, match.supersededByID == nil,
            match.kind == proposal.kind, (match.isEpisode == true) == proposal.isEpisode
          else { throw PersonalMemoryError.invalidAnalysis }
          if match.confirmed || match.isOwnerCorrected == true || match.evidence == nil {
            if question == nil {
              question = PersonalMemoryClarification(
                quote: proposal.quote,
                question: Self.protectedChangeQuestion(quote: proposal.quote, source: source.text)
              )
              protectedEntry = id
            }
            continue
          }
          existing = match
        } else {
          existing = nil
        }
        let subject: UUID?
        do {
          subject = try Self.analysisSubject(proposal, evidence: evidence, input: input, in: &next)
        } catch PersonalMemoryError.confirmationRequired {
          if question == nil {
            question = PersonalMemoryClarification(
              quote: proposal.quote,
              question: Self.identityQuestion(
                name: proposal.subjectName ?? "this", project: proposal.subjectKind == .project,
                source: source.text)
            )
          }
          continue
        }
        let profileIDs = subject.map { [$0] } ?? []
        if !proposal.isEpisode,
          let duplicate = next.entries.firstIndex(where: {
            $0.supersededByID == nil && $0.excerptConversationID == nil
              && $0.isEpisode != true
              && $0.text.utf8.elementsEqual(proposal.quote.utf8) && $0.kind == proposal.kind
              && $0.profileIDs == profileIDs
          })
        {
          if next.entries[duplicate].confirmed || next.entries[duplicate].isOwnerCorrected == true {
            accepted = true
            acceptedKinds.insert(proposal.kind)
            continue
          }
          let previousEvidence: [PersonalMemoryEvidence]
          if let values = next.entries[duplicate].evidence {
            previousEvidence = values
          } else {
            previousEvidence = try next.entries[duplicate].sourceIDs.map { id in
              guard let original = next.sources.first(where: { $0.id == id }) else {
                throw PersonalMemoryError.invalidAnalysis
              }
              _ = try Self.exactRange(next.entries[duplicate].text, in: original.text)
              return PersonalMemoryEvidence(sourceID: id, quote: next.entries[duplicate].text)
            }
          }
          let combinedSourceIDs = Array(
            Set(next.entries[duplicate].sourceIDs + evidence.map(\.sourceID))
          ).sorted { $0.uuidString < $1.uuidString }
          let combinedEvidence = Self.uniqueEvidence(
            (next.entries[duplicate].evidence ?? previousEvidence) + evidence)
          if combinedSourceIDs.count <= 100 && combinedEvidence.count <= 100 {
            next.entries[duplicate].sourceIDs = combinedSourceIDs
            next.entries[duplicate].evidence = combinedEvidence
          }
          accepted = true
          acceptedKinds.insert(proposal.kind)
          continue
        }
        let entry = PersonalMemoryEntry(
          id: UUID(), text: proposal.quote, kind: proposal.kind,
          sourceIDs: Array(Set(evidence.map(\.sourceID))).sorted { $0.uuidString < $1.uuidString },
          profileIDs: profileIDs, categories: [proposal.kind.rawValue], confirmed: false,
          evidence: evidence, isEpisode: proposal.isEpisode ? true : nil,
          eventTimeExpression: proposal.eventTimeExpression, createdAt: source.createdAt)
        if let existing, let oldIndex = next.entries.firstIndex(where: { $0.id == existing.id }) {
          guard existing.profileIDs == profileIDs else { throw PersonalMemoryError.invalidAnalysis }
          let priorDate =
            existing.sourceIDs.compactMap { id in
              next.sources.first { $0.id == id }?.createdAt
            }.max() ?? existing.createdAt
          if source.createdAt >= priorDate {
            next.entries[oldIndex].supersededByID = entry.id
            next.links.append(
              PersonalMemoryLink(
                id: UUID(), fromID: entry.id, toID: existing.id, label: "Updates earlier report"))
          }
        }
        next.entries.append(entry)
        accepted = true
        acceptedKinds.insert(proposal.kind)
      }
      let hasEarlierMemory = next.entries.contains {
        $0.excerptConversationID == nil && $0.sourceIDs.contains(source.id)
      }
      next.sources[index].kind =
        accepted
        ? (acceptedKinds.count == 1 ? acceptedKinds.first : .fact)
        : (hasEarlierMemory
          ? source.kind : (question == nil && !hasDeferredRemainder ? .conversationOnly : nil))
      next.sources[index].analysis = PersonalMemoryAnalysisState(
        status: question != nil
          ? .needsClarification : (hasDeferredRemainder ? .deferred : .processed),
        question: question?.question
          ?? (source.analysis?.answerSourceID != nil ? source.analysis?.question : nil),
        quote: question?.quote
          ?? (source.analysis?.answerSourceID != nil ? source.analysis?.quote : nil),
        answerSourceID: source.analysis?.answerSourceID,
        protectedEntryID: protectedEntry, appliedRevision: input.revision,
        hasDeferredRemainder: hasDeferredRemainder ? true : nil)
    }
  }

  private static func protectedChangeQuestion(quote: String, source: String) -> String {
    let excerpt = confirmationExcerpt(quote)
    if usesArabic(source) {
      return
        "تختلف هذه المعلومة عما أكّدته أو صحّحته: «\(excerpt)». هل تريد تغيير الذاكرة المحفوظة؟ يمكنك تصحيحها من عرض المصدر."
    }
    return
      "This differs from information you confirmed or corrected: “\(excerpt)”. Should that saved memory be changed? You can correct it from its source view."
  }

  private static func identityQuestion(name: String, project: Bool, source: String) -> String {
    if usesArabic(source) {
      return "أي \(project ? "مشروع" : "شخص") باسم «\(name)» تقصد؟"
    }
    return "Which \(project ? "project" : "person") named \(name) did you mean?"
  }

  /// This clips only presentation text. The full original quote stays in source provenance.
  private static func confirmationExcerpt(_ text: String) -> String {
    var excerpt = ""
    var bytes = 0
    for character in text {
      let width = String(character).utf8.count
      guard bytes + width <= 200 else { return excerpt + "…" }
      excerpt.append(character)
      bytes += width
    }
    return excerpt
  }

  /// Selects the two supported message languages by letter counts; punctuation has no vote.
  private static func usesArabic(_ text: String) -> Bool {
    var arabic = 0
    var other = 0
    for scalar in text.unicodeScalars {
      switch scalar.properties.generalCategory {
      case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
        let value = scalar.value
        if (0x0600...0x06FF).contains(value) || (0x0750...0x077F).contains(value)
          || (0x0870...0x08FF).contains(value) || (0xFB50...0xFDFF).contains(value)
          || (0xFE70...0xFEFF).contains(value) || (0x1EE00...0x1EEFF).contains(value)
        {
          arabic += 1
        } else {
          other += 1
        }
      default: continue
      }
    }
    return arabic > other
  }

  static func exactRange(_ quote: String, in original: String) throws -> Range<Int> {
    try PersonalMemoryLimits.text(quote, maximum: 4_096)
    guard let range = Data(original.utf8).range(of: Data(quote.utf8)) else {
      throw PersonalMemoryError.invalidAnalysis
    }
    return range
  }

  private static func uniqueEvidence(_ values: [PersonalMemoryEvidence]) -> [PersonalMemoryEvidence]
  {
    values.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
  }

  private static func analysisSubject(
    _ proposal: PersonalMemoryProposal, evidence: [PersonalMemoryEvidence],
    input: PersonalMemoryAnalysisInput, in state: inout PersonalMemorySnapshot
  ) throws -> UUID? {
    guard let kind = proposal.subjectKind else {
      guard proposal.subjectName == nil else { throw PersonalMemoryError.invalidAnalysis }
      return nil
    }
    if kind == .selfProfile { return state.selfProfileID }
    guard let name = proposal.subjectName else { throw PersonalMemoryError.invalidAnalysis }
    try PersonalMemoryLimits.text(name, maximum: 240)
    let normalized = normalizedWords(name)
    guard !normalized.isEmpty else { throw PersonalMemoryError.invalidAnalysis }
    let matches = state.profiles.filter {
      $0.kind == kind && $0.mergedIntoID == nil
        && ([$0.name] + $0.aliases).contains { normalizedWords($0) == normalized }
    }
    guard matches.count <= 1 else { throw PersonalMemoryError.confirmationRequired }
    let names = matches.first.map { [$0.name] + $0.aliases } ?? [name]
    let groundedName = evidence.contains {
      let quote = " " + normalizedWords($0.quote) + " "
      return names.contains { quote.contains(" " + normalizedWords($0) + " ") }
    }
    guard groundedName else { throw PersonalMemoryError.invalidAnalysis }
    if let match = matches.first {
      guard input.profiles.contains(where: { $0.id == match.id }) else {
        throw PersonalMemoryError.invalidAnalysis
      }
      return match.id
    }
    guard
      evidence.contains(where: {
        Data($0.quote.utf8).range(of: Data(name.utf8)) != nil
      })
    else { throw PersonalMemoryError.invalidAnalysis }
    var profile = PersonalProfile(kind: kind, name: name)
    profile.isSuggested = true
    state.profiles.append(profile)
    return profile.id
  }
}
