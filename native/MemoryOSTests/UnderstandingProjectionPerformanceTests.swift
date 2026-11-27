import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

struct UnderstandingProjectionPerformanceTests {
  @Test func thousandSourcesRemainNavigableWithinProjectionBudget() throws {
    let conversation = UUID()
    var snapshot = PersonalMemorySnapshot()
    snapshot.sources = (0..<1_000).map {
      PersonalMemorySource(
        conversationID: conversation, text: "Fictional planning record \($0): Saturday meeting.",
        createdAt: Date(timeIntervalSince1970: Double(1_700_000_000 + $0)), kind: .conversationOnly)
    }
    _ = MemorySearchCollection.make(personal: snapshot, local: RecordSnapshot())
    var seconds: [Double] = []
    for _ in 0..<5 {
      let started = ContinuousClock.now
      let projection = MemorySearchCollection.make(personal: snapshot, local: RecordSnapshot())
      let elapsed = started.duration(to: .now).components
      seconds.append(Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
      #expect(projection.documents.count == 1_001)
    }
    let p95 = seconds.max()!
    print("MEMORYOS_PROJECTION sources=1000 runs=5 p95Seconds=\(p95)")
    #expect(p95 < 0.250, "Current-source projection exceeds the Step 1 250 ms budget.")
  }
}
