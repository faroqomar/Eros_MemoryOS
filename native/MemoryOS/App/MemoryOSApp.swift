import SwiftUI

@main
struct MemoryOSApp: App {
  @State private var session = DemoSession()
  @State private var records = LocalStoreComposition.makeViewModel()

  var body: some Scene {
    WindowGroup {
      RootView(session: session, records: records)
        .task { await records.load() }
        .environment(\.layoutDirection, session.language == .arabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: session.language.rawValue))
        .preferredColorScheme(.dark)
        .tint(MemoryTheme.ink)
    }
  }
}
