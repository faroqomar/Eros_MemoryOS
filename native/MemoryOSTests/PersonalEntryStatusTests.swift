import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor EntryStatusRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

struct PersonalEntryStatusTests {
  private func entry(_ kind: PersonalMemoryKind) async throws -> PersonalMemoryEntry {
    let memory = PersonalMemoryUseCases(repository: EntryStatusRepository())
    _ = try await memory.ingest(source: .init(text: "Fictional saved information", kind: kind))
    return try #require(try await memory.snapshot().entries.first)
  }

  @Test(arguments: AppLanguage.allCases)
  func interpretationLabelsDistinguishReviewAIAndUnknownAuthor(_ language: AppLanguage) async throws
  {
    var entry = try await entry(.interpretation)
    #expect(
      entry.statusTitle(language)
        == language.text("Interpretation · author unknown", "تفسير · صاحبه غير محدد"))
    #expect(
      entry.statusTitle(language) == MemorySearchKind.unreviewedInterpretation.title(language))
    #expect(
      entry.statusTitle(language)
        == RelationshipMemoryLayer.unreviewedInterpretation.title(language))

    entry.interpretationProvenance = .aiProposed
    #expect(
      entry.statusTitle(language)
        == language.text("AI hypothesis · revisable", "فرضية ذكاء اصطناعي · قابلة للتصحيح"))
    #expect(entry.statusTitle(language) == MemorySearchKind.hypothesis.title(language))
    #expect(entry.statusTitle(language) == RelationshipMemoryLayer.aiHypothesis.title(language))

    entry.interpretationProvenance = .ownerReviewed
    #expect(
      entry.statusTitle(language)
        == language.text(
          "Interpretation confirmed by you · revisable", "تفسير أكدته أنت · قابل للتصحيح"))
    #expect(entry.statusTitle(language) == MemorySearchKind.confirmedInterpretation.title(language))
    #expect(
      entry.statusTitle(language) == RelationshipMemoryLayer.confirmedInterpretation.title(language)
    )
    #expect(entry.confirmationTitle(language) == nil)
  }

  @Test(arguments: AppLanguage.allCases)
  func legacyConfirmationDoesNotInventAuthorshipButExplicitCorrectionRetainsReview(
    _ language: AppLanguage
  ) async throws {
    var entry = try await entry(.interpretation)
    entry.confirmed = true
    #expect(
      entry.statusTitle(language) == MemorySearchKind.unreviewedInterpretation.title(language))
    #expect(entry.confirmationTitle(language) == nil)
    entry.interpretationProvenance = .aiProposed
    #expect(entry.statusTitle(language) == MemorySearchKind.hypothesis.title(language))
    entry.isOwnerCorrected = true
    #expect(entry.statusTitle(language) == MemorySearchKind.confirmedInterpretation.title(language))
    #expect(entry.confirmationTitle(language) == nil)
  }

  @Test(arguments: AppLanguage.allCases)
  func ordinaryKindsKeepTheirLabelAndSeparateConfirmation(_ language: AppLanguage) async throws {
    for kind in PersonalMemoryKind.allCases where kind.createsMemory && kind != .interpretation {
      var entry = try await entry(kind)
      #expect(entry.statusTitle(language) == kind.title(language))
      #expect(entry.confirmationTitle(language) == nil)
      entry.confirmed = true
      #expect(entry.statusTitle(language) == kind.title(language))
      #expect(entry.confirmationTitle(language) == language.text("Confirmed by you", "أكدتها أنت"))
      if kind == .fact {
        #expect(entry.statusTitle(language) == language.text("Reported fact", "حقيقة مذكورة"))
      }
    }
  }
}
