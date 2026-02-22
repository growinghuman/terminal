import Foundation
import SwiftUI
import Combine

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var activeTabID: UUID?
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var showConnectionError: Bool = false

    let sessionManager: SSHSessionManager
    private let themeManager = ThemeManager.shared

    var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID }
    }

    init(sessionManager: SSHSessionManager) {
        self.sessionManager = sessionManager
    }

    func openConnection(host: Host, password: String? = nil) async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            let session = try await sessionManager.connect(to: host, password: password)

            let manager = TerminalManager()
            manager.applyTheme(themeManager.selectedTheme)

            manager.setFontSize(CGFloat(host.fontSize))

            manager.attachSession(session)
            try await session.startShell(
                cols: manager.terminalSize.cols,
                rows: manager.terminalSize.rows
            )

            let tab = TerminalTab(
                id: session.id,
                title: host.name,
                host: host,
                session: session,
                terminalManager: manager
            )

            tabs.append(tab)
            activeTabID = tab.id

            // Update last connected (only for persisted hosts)
            if host.modelContext != nil {
                host.lastConnectedAt = Date()
            }
        } catch {
            connectionError = error.localizedDescription
            showConnectionError = true
        }
    }

    func closeTab(_ tabID: UUID) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = tabs[index]

        tab.terminalManager.detachSession()
        await sessionManager.disconnect(sessionID: tab.id)
        tabs.remove(at: index)

        if activeTabID == tabID {
            activeTabID = tabs.last?.id
        }
    }

    func switchToTab(_ tabID: UUID) {
        activeTabID = tabID
    }

    func closeAllTabs() async {
        for tab in tabs {
            tab.terminalManager.detachSession()
        }
        await sessionManager.disconnectAll()
        tabs.removeAll()
        activeTabID = nil
    }
}

struct TerminalTab: Identifiable {
    let id: UUID
    var title: String
    let host: Host
    let session: SSHSession
    let terminalManager: TerminalManager
}
