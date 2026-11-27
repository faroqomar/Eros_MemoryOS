import Foundation
import Testing

@testable import ChatCore

struct MemoryEvidenceFilterTests {
  @Test func identityMetadataKeepsExactNamesAndSeparateRecordMembership() {
    let id = UUID()
    let composed = ChatEvidenceIdentity(names: ["é"], documentIDs: [id])
    let decomposed = ChatEvidenceIdentity(names: ["e\u{301}"], documentIDs: [id])
    #expect(composed != decomposed)
    #expect(composed != ChatEvidenceIdentity(names: ["é"]))
    #expect(composed == ChatEvidenceIdentity(names: ["é"], documentIDs: [id]))
  }
}
