import SwiftUI
import SwiftData

@main
struct ShellCraftApp: App {
    @StateObject private var sessionManager = SSHSessionManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var terminalViewModel: TerminalViewModel

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Host.self,
            SSHKeyPair.self,
            Snippet.self,
            SessionLog.self,
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

    init() {
        let manager = SSHSessionManager()
        _sessionManager = StateObject(wrappedValue: manager)
        _terminalViewModel = StateObject(wrappedValue: TerminalViewModel(sessionManager: manager))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(sessionManager)
                .environmentObject(themeManager)
                .environmentObject(terminalViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
