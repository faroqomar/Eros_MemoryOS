import SwiftUI

@main
struct MemoryOSApp: App {
    @State private var session = DemoSession()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .environment(\.layoutDirection, session.language == .arabic ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: session.language.rawValue))
                .preferredColorScheme(.dark)
                .tint(MemoryTheme.ink)
        }
    }
}
