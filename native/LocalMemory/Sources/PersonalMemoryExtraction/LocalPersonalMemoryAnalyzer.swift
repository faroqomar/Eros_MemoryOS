import ChatCore
import CoreFoundation
import Foundation
import MemoryCore

public enum PersonalMemoryExtractionError: Error, Equatable {
  case inputTooLarge, invalidOutput, semanticDisagreement
}

/// Thin semantic adapter. The model receives data, never a repository or action capability.
public struct LocalPersonalMemoryAnalyzer: PersonalMemoryAnalyzing {
  private let model: any StructuredChatModel
  public init(model: any StructuredChatModel) { self.model = model }

  public func analyze(_ input: PersonalMemoryAnalysisInput) async throws -> PersonalMemoryAnalysis {
    try Task.checkCancellation()
    let prompt = try makePrompt(input)
    do {
      let output = try await model.generateJSON(
        turns: [.init(role: .system, text: Self.instructions)]
          + Self.examples
          + [.init(role: .user, text: prompt.text)],
        grammar: prompt.grammar, maximumOutputTokens: 512)
      try Task.checkCancellation()
      let analysis = try decode(output, prompt: prompt)
      guard
        let review = try PersonalMemoryAcceptance.request(
          sourcePayload: prompt.text, analysis: analysis,
          answerSourceID: input.clarificationAnswer?.id)
      else { return analysis }
      let verdict = try await model.generateJSON(
        turns: [
          .init(role: .system, text: PersonalMemoryAcceptance.instructions),
          .init(role: .user, text: review.text),
        ],
        grammar: review.grammar, maximumOutputTokens: 512)
      try Task.checkCancellation()
      return try PersonalMemoryAcceptance.apply(verdict, to: analysis)
    } catch ChatError.modelUnavailable {
      throw PersonalMemoryAnalysisRuntimeError.temporarilyUnavailable
    } catch ChatError.busy {
      throw CancellationError()
    }
  }

  private struct Prompt {
    let text: String
    let context: [String: PersonalMemorySource]
    let entries: [String: UUID]
    let grammar: String
  }

  private func makePrompt(_ input: PersonalMemoryAnalysisInput) throws -> Prompt {
    guard input.source.text.utf8.count <= 2_400,
      (input.clarificationAnswer?.text.utf8.count ?? 0) <= 800
    else { throw PersonalMemoryExtractionError.inputTooLarge }
    var context: [[String: String]] = []
    var sources: [String: PersonalMemorySource] = [:]
    for (index, source) in input.context.enumerated() {
      guard source.text.utf8.count <= 500 else { continue }
      context.append(["id": "C\(index)", "text": source.text])
      sources["C\(index)"] = source
      if context.count == 3 { break }
    }
    if let answer = input.clarificationAnswer {
      context.append(["id": "A", "text": answer.text])
      sources["A"] = answer
    }
    let memories: [[String: Any]] = input.entries.enumerated().compactMap { index, entry in
      guard entry.text.utf8.count <= 300 else { return nil }
      return [
        "id": String(index), "text": entry.text, "kind": entry.kind.rawValue,
        "protected": entry.confirmed || entry.isOwnerCorrected == true || entry.evidence == nil,
      ]
    }.prefix(6).map { $0 }
    let profiles = input.profiles.filter { $0.mergedIntoID == nil && $0.name.utf8.count <= 128 }
      .prefix(8).map {
        ["name": $0.name, "type": $0.kind == .selfProfile ? "self" : $0.kind.rawValue]
      }
    var payload: [String: Any] = [
      "target": input.source.text,
      "context": context, "profiles": profiles, "existing": memories,
    ]
    if input.clarificationAnswer != nil {
      payload["askedQuestion"] = input.source.analysis?.question
      payload["ambiguousQuote"] = input.source.analysis?.quote
    }
    let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    guard bytes.count + Self.instructions.utf8.count <= 6_000 else {
      throw PersonalMemoryExtractionError.inputTooLarge
    }
    let offered = Set(memories.compactMap { $0["id"] as? String })
    let entries = Dictionary(
      uniqueKeysWithValues: input.entries.enumerated().compactMap { index, entry in
        offered.contains(String(index)) ? (String(index), entry.id) : nil
      })
    let options = [#""\"\"""#] + entries.keys.sorted().map { #""\""# + $0 + #"\"""# }
    let contextOptions = sources.keys.sorted().map { "\"\\\"" + $0 + "\\\"\"" }
    var grammar = Self.grammar.replacingOccurrences(
      of: "UPDATE_OPTIONS", with: options.joined(separator: " | ")
    )
    .replacingOccurrences(
      of: "CONTEXT_OPTIONS",
      with: contextOptions.isEmpty ? #""\"\"""# : contextOptions.joined(separator: " | "))
    if sources.isEmpty {
      grammar = grammar.replacingOccurrences(
        of: #"evidence ::= "[" ws (span (ws "," ws span)? (ws "," ws span)?)? ws "]""#,
        with: #"evidence ::= "[" ws "]""#)
    }
    return Prompt(
      text: String(decoding: bytes, as: UTF8.self), context: sources, entries: entries,
      grammar: grammar)
  }

  private func decode(_ output: String, prompt: Prompt) throws
    -> PersonalMemoryAnalysis
  {
    guard output.utf8.count <= 24_000,
      let object = try? JSONSerialization.jsonObject(with: Data(output.utf8)),
      let root = object as? [String: Any],
      Set(root.keys) == ["memories", "clarification"],
      let items = root["memories"] as? [[String: Any]], items.count <= 3
    else { throw PersonalMemoryExtractionError.invalidOutput }
    var proposals: [PersonalMemoryProposal] = []
    let acceptedKinds: Set<PersonalMemoryKind> = [
      .fact, .preference, .goal, .interpretation, .idea, .plan, .workflow, .commitment,
    ]
    for item in items {
      guard
        Set(item.keys) == [
          "quote", "kind", "subject", "type", "update", "context", "episode", "time",
        ],
        let quote = item["quote"] as? String, !quote.isEmpty,
        let rawKind = item["kind"] as? String, let kind = PersonalMemoryKind(rawValue: rawKind),
        acceptedKinds.contains(kind), let subject = item["subject"] as? String,
        let type = item["type"] as? String, let update = item["update"] as? String,
        let evidence = item["context"] as? [[String: Any]], evidence.count <= 3,
        let episode = jsonBoolean(item["episode"]), let time = item["time"] as? String,
        episode || time.isEmpty
      else { throw PersonalMemoryExtractionError.invalidOutput }
      let subjectKind: PersonalProfileKind?
      switch type {
      case "self":
        guard subject == "self" else { throw PersonalMemoryExtractionError.invalidOutput }
        subjectKind = .selfProfile
      case "person": subjectKind = .person
      case "project": subjectKind = .project
      case "none":
        guard subject.isEmpty else { throw PersonalMemoryExtractionError.invalidOutput }
        subjectKind = nil
      default: throw PersonalMemoryExtractionError.invalidOutput
      }
      var context: [PersonalMemoryEvidence] = []
      for value in evidence {
        guard Set(value.keys) == ["source", "quote"], let id = value["source"] as? String,
          let quote = value["quote"] as? String, !quote.isEmpty
        else { throw PersonalMemoryExtractionError.invalidOutput }
        guard let source = prompt.context[id] else {
          throw PersonalMemoryExtractionError.invalidOutput
        }
        context.append(.init(sourceID: source.id, quote: quote))
      }
      let oldID: UUID?
      if update.isEmpty {
        oldID = nil
      } else if let id = prompt.entries[update] {
        oldID = id
      } else {
        throw PersonalMemoryExtractionError.invalidOutput
      }
      proposals.append(
        .init(
          quote: quote, kind: kind, subjectName: subject.isEmpty || type == "self" ? nil : subject,
          subjectKind: subjectKind, replacesEntryID: oldID, contextEvidence: context,
          isEpisode: episode, eventTimeExpression: time.isEmpty ? nil : time))
    }
    var clarification: PersonalMemoryClarification?
    if !(root["clarification"] is NSNull) {
      guard let value = root["clarification"] as? [String: Any],
        Set(value.keys) == ["quote", "question"],
        let quote = value["quote"] as? String, !quote.isEmpty,
        let question = value["question"] as? String, !question.isEmpty,
        question.utf8.count <= 1_000
      else { throw PersonalMemoryExtractionError.invalidOutput }
      clarification = .init(quote: quote, question: question)
    }
    return .init(memories: proposals, clarification: clarification)
  }

  private func jsonBoolean(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
      return nil
    }
    return number.boolValue
  }
}
