import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var activeTabID: UUID?
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var showConnectionError: Bool = false
    @Published var sessionLoggingEnabled: Bool {
        didSet { UserDefaults.standard.set(sessionLoggingEnabled, forKey: "sessionLoggingEnabled") }
    }

    let sessionManager: SSHSessionManager
    private let themeManager = ThemeManager.shared

    var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID }
    }

    init(sessionManager: SSHSessionManager) {
        self.sessionManager = sessionManager
        self.sessionLoggingEnabled = UserDefaults.standard.bool(forKey: "sessionLoggingEnabled")
    }

    // MARK: - SSH Connection

    func openConnection(host: Host, password: String? = nil, modelContext: ModelContext? = nil) async {
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

            // Start session logging if enabled
            var logger: SessionLogger?
            if sessionLoggingEnabled, let ctx = modelContext {
                let sessionLogger = SessionLogger()
                sessionLogger.startLogging(
                    hostName: host.name,
                    hostname: host.hostname,
                    username: host.username,
                    modelContext: ctx
                )
                logger = sessionLogger

                // Tap into data stream for logging
                let originalHandler = session.onDataReceived
                session.onDataReceived = { data in
                    sessionLogger.appendData(data)
                    originalHandler?(data)
                }
            }

            let tab = TerminalTab(
                id: session.id,
                title: host.name,
                host: host,
                session: session,
                terminalManager: manager,
                sessionLogger: logger
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

    // MARK: - Mosh Connection

    func openMoshConnection(host: Host, password: String? = nil, modelContext: ModelContext? = nil) async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            // First establish SSH to start mosh-server (reuse sessionManager for auth)
            let sshSession = try await sessionManager.connect(to: host, password: password)

            // Start Mosh session using the underlying SSH connection
            let moshClient = MoshClient()
            try await moshClient.connect(sshConnection: sshSession.connection)

            let moshSession = MoshSession(
                id: UUID(),
                host: host,
                moshClient: moshClient
            )

            let manager = TerminalManager()
            manager.applyTheme(themeManager.selectedTheme)
            manager.setFontSize(CGFloat(host.fontSize))

            // Wire Mosh data to terminal
            moshSession.onDataReceived = { [weak manager] data in
                Task { @MainActor in
                    manager?.handleReceivedData(data)
                }
            }

            // Start session logging if enabled
            var logger: SessionLogger?
            if sessionLoggingEnabled, let ctx = modelContext {
                let sessionLogger = SessionLogger()
                sessionLogger.startLogging(
                    hostName: host.name,
                    hostname: host.hostname,
                    username: host.username,
                    isMosh: true,
                    modelContext: ctx
                )
                logger = sessionLogger

                let originalHandler = moshSession.onDataReceived
                moshSession.onDataReceived = { data in
                    sessionLogger.appendData(data)
                    originalHandler?(data)
                }
            }

            let tab = TerminalTab(
                id: moshSession.id,
                title: "\(host.name) (Mosh)",
                host: host,
                moshSession: moshSession,
                terminalManager: manager,
                sessionLogger: logger
            )

            tabs.append(tab)
            activeTabID = tab.id

            if host.modelContext != nil {
                host.lastConnectedAt = Date()
            }
        } catch {
            connectionError = error.localizedDescription
            showConnectionError = true
        }
    }

    // MARK: - Tab Management

    func closeTab(_ tabID: UUID) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = tabs[index]

        // Stop logging
        tab.sessionLogger?.stopLogging()

        if let session = tab.session {
            tab.terminalManager.detachSession()
            await sessionManager.disconnect(sessionID: tab.id)
        } else if let moshSession = tab.moshSession {
            moshSession.disconnect()
        }

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
            tab.sessionLogger?.stopLogging()
            if tab.session != nil {
                tab.terminalManager.detachSession()
            }
            tab.moshSession?.disconnect()
        }
        await sessionManager.disconnectAll()
        tabs.removeAll()
        activeTabID = nil
    }
}

// MARK: - TerminalTab

struct TerminalTab: Identifiable {
    let id: UUID
    var title: String
    let host: Host
    let session: SSHSession?
    let moshSession: MoshSession?
    let terminalManager: TerminalManager
    let sessionLogger: SessionLogger?

    var isMosh: Bool { moshSession != nil }

    /// Convenience init for SSH sessions
    init(
        id: UUID,
        title: String,
        host: Host,
        session: SSHSession,
        terminalManager: TerminalManager,
        sessionLogger: SessionLogger? = nil
    ) {
        self.id = id
        self.title = title
        self.host = host
        self.session = session
        self.moshSession = nil
        self.terminalManager = terminalManager
        self.sessionLogger = sessionLogger
    }

    /// Convenience init for Mosh sessions
    init(
        id: UUID,
        title: String,
        host: Host,
        moshSession: MoshSession,
        terminalManager: TerminalManager,
        sessionLogger: SessionLogger? = nil
    ) {
        self.id = id
        self.title = title
        self.host = host
        self.session = nil
        self.moshSession = moshSession
        self.terminalManager = terminalManager
        self.sessionLogger = sessionLogger
    }

    /// Send text via whichever transport is active.
    func sendText(_ text: String) {
        if let session = session {
            session.sendText(text)
        } else if let moshSession = moshSession {
            moshSession.sendText(text)
        }
    }

    /// Send raw data via whichever transport is active.
    func sendData(_ data: Data) {
        if let session = session {
            session.sendData(data)
        } else if let moshSession = moshSession {
            moshSession.sendData(data)
        }
    }
}
