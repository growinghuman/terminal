import SwiftUI
import SwiftData

@main
struct ShellCraftApp: App {
    @StateObject private var sessionManager = SSHSessionManager()
    @StateObject private var themeManager = ThemeManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Host.self,
            SSHKeyPair.self,
            Snippet.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(sessionManager)
                .environmentObject(themeManager)
                .environmentObject(
                    TerminalViewModel(sessionManager: sessionManager)
                )
        }
        .modelContainer(sharedModelContainer)
    }
}
