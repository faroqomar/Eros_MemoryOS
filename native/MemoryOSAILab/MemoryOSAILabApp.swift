import AIEvaluationCore
import SwiftUI

@main
struct MemoryOSAILabApp: App {
  @State private var model = LabComposition.makeViewModel()

  var body: some Scene {
    WindowGroup {
      LabView(model: model, cases: EvaluationSuite.fictional().cases)
        .preferredColorScheme(.dark)
    }
  }
}
