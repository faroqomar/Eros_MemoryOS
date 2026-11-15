import Testing

@testable import MemoryOS

@MainActor
struct ChatResponsivenessTests {
  @Test func generationContinuesAfterAnEarlierScrollEnds() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.userScrollChanged(true)
    probe.start()
    probe.userScrollChanged(false)
    #expect(samples.isEmpty)
    probe.finish(cancellationSeconds: 0.05, firstUsableTextSeconds: 0.2)
    #expect(samples.count == 1)
    #expect(samples.first?.scrollingOnly == false)
    #expect(samples.first?.firstUsableTextSeconds == 0.2)
    #expect(samples.first?.cancellationSeconds == 0.05)
  }

  @Test func scrollingContinuesAfterGenerationEnds() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.start()
    probe.userScrollChanged(true)
    probe.finish(cancellationSeconds: nil, firstUsableTextSeconds: 0.3)
    #expect(samples.isEmpty)
    probe.userScrollChanged(false)
    #expect(samples.count == 1)
    #expect(samples.first?.scrollingOnly == false)
    #expect(samples.first?.firstUsableTextSeconds == 0.3)
  }

  @Test func backgroundEndsTheWindowWithoutIncludingSuspendedTime() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.start()
    probe.userScrollChanged(true)
    probe.suspend()
    probe.finish(cancellationSeconds: 0.1, firstUsableTextSeconds: 0.2)
    #expect(samples.count == 1)
    #expect(samples.first?.interrupted == true)
    probe.userScrollChanged(true)
    probe.userScrollChanged(false)
    #expect(samples.count == 2)
    #expect(samples.last?.interrupted == false)
    #expect(samples.last?.scrollingOnly == true)
    #expect(samples.last?.firstUsableTextSeconds == nil)
  }

  @Test func repeatedCompletionDoesNotEraseMetadataAndLaterGenerationReplacesIt() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.start()
    probe.userScrollChanged(true)
    probe.finish(cancellationSeconds: 0.05, firstUsableTextSeconds: 0.2)
    probe.finish(cancellationSeconds: nil, firstUsableTextSeconds: nil)
    probe.userScrollChanged(false)
    #expect(samples.first?.cancellationSeconds == 0.05)
    #expect(samples.first?.firstUsableTextSeconds == 0.2)

    probe.userScrollChanged(true)
    probe.start()
    probe.finish(cancellationSeconds: 0.07, firstUsableTextSeconds: 0.3)
    probe.start()
    probe.finish(cancellationSeconds: nil, firstUsableTextSeconds: 0.4)
    probe.userScrollChanged(false)
    #expect(samples.count == 2)
    #expect(samples.last?.cancellationSeconds == nil)
    #expect(samples.last?.firstUsableTextSeconds == 0.4)
  }

  @Test func measurementCanRestartAfterSuspendingAnActiveGeneration() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.start()
    probe.suspend()
    probe.start()
    probe.userScrollChanged(true)
    probe.userScrollChanged(false)
    #expect(samples.count == 1)
    probe.finish(cancellationSeconds: nil, firstUsableTextSeconds: 0.5)
    #expect(samples.count == 2)
    #expect(samples.last?.interrupted == false)
    #expect(samples.last?.scrollingOnly == false)
    #expect(samples.last?.firstUsableTextSeconds == 0.5)
  }

  @Test func separateWindowsDoNotCarryGenerationMetadataOrDuplicateSamples() {
    var samples: [ChatUIResponsiveness] = []
    let probe = ChatResponsivenessProbe { samples.append($0) }
    probe.start()
    probe.start()
    probe.finish(cancellationSeconds: 0.01, firstUsableTextSeconds: 0.1)
    probe.finish(cancellationSeconds: nil, firstUsableTextSeconds: nil)
    probe.userScrollChanged(true)
    probe.userScrollChanged(true)
    probe.userScrollChanged(false)
    probe.userScrollChanged(false)
    #expect(samples.count == 2)
    #expect(samples.last?.scrollingOnly == true)
    #expect(samples.last?.firstUsableTextSeconds == nil)
    #expect(samples.last?.cancellationSeconds == nil)
  }
}
