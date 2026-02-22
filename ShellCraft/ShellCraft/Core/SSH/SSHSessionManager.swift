import Foundation
import Combine
import NIO
import NIOSSH

/// Manages multiple SSH sessions and their lifecycle
@MainActor
final class SSHSessionManager: ObservableObject {
    @Published var sessions: [SSHSession] = []
    @Published var activeSessionID: UUID?

    private let knownHosts = KnownHostsStore()

    var activeSession: SSHSession? {
        sessions.first { $0.id == activeSessionID }
    }

    func connect(to host: Host, password: String? = nil,
                 privateKey: NIOSSHPrivateKey? = nil) async throws -> SSHSession {
        let connection = SSHConnection(
            host: host.hostname,
            port: host.port,
            username: host.username
        )

        let authDelegate: NIOSSHClientUserAuthenticationDelegate
        switch host.authMethod {
        case .password:
            guard let password = password else {
                throw SSHError.authenticationFailed
            }
            authDelegate = PasswordAuthDelegate(
                username: host.username,
                password: password
            )
        case .publicKey, .certificate:
            guard let privateKey = privateKey else {
                throw SSHError.authenticationFailed
            }
            authDelegate = PublicKeyAuthDelegate(
                username: host.username,
                privateKey: privateKey
            )
        }

        let serverAuthDelegate = KnownHostsDelegate(
            knownHosts: knownHosts,
            hostname: host.hostname,
            port: host.port
        )

        try await connection.connect(
            authDelegate: authDelegate,
            serverAuthDelegate: serverAuthDelegate
        )

        let session = SSHSession(
            id: UUID(),
            host: host,
            connection: connection
        )

        sessions.append(session)
        activeSessionID = session.id

        return session
    }

    func disconnect(sessionID: UUID) async {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let session = sessions[index]
        await session.disconnect()
        session.connection.shutdownEventLoop()
        sessions.remove(at: index)

        if activeSessionID == sessionID {
            activeSessionID = sessions.last?.id
        }
    }

    func disconnectAll() async {
        for session in sessions {
            await session.disconnect()
            session.connection.shutdownEventLoop()
        }
        sessions.removeAll()
        activeSessionID = nil
    }

    func setActiveSession(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        activeSessionID = id
    }
}

/// Represents an active SSH session with its terminal
@MainActor
final class SSHSession: ObservableObject, Identifiable {
    let id: UUID
    let host: Host
    let connection: SSHConnection

    @Published var title: String
    @Published var isActive: Bool = true

    private var shellChannel: Channel?

    var onDataReceived: ((Data) -> Void)?

    init(id: UUID, host: Host, connection: SSHConnection) {
        self.id = id
        self.host = host
        self.connection = connection
        self.title = host.name
    }

    func startShell(cols: Int = 80, rows: Int = 24) async throws {
        // Create session channel
        let channel = try await connection.createSessionChannel()
        self.shellChannel = channel

        // PTY must be requested BEFORE the shell (SSH protocol requirement)
        try await connection.requestPTY(on: channel, cols: cols, rows: rows)
        try await connection.requestShell(on: channel)

        // Set up data handler - dispatch to MainActor since onData comes from NIO event loop
        if let handler = try? await channel.pipeline.handler(type: SSHShellHandler.self).get() {
            handler.onData = { [weak self] data in
                Task { @MainActor in
                    self?.onDataReceived?(data)
                }
            }
        }
    }

    func sendData(_ data: Data) {
        guard let channel = shellChannel, channel.isActive else { return }

        // Dispatch write to the channel's event loop for thread safety
        channel.eventLoop.execute {
            var buffer = channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            channel.writeAndFlush(buffer, promise: nil)
        }
    }

    func sendText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        sendData(data)
    }

    func resizeTerminal(cols: Int, rows: Int) async {
        guard let channel = shellChannel else { return }
        try? await connection.resizeTerminal(on: channel, cols: cols, rows: rows)
    }

    func disconnect() async {
        try? await shellChannel?.close().get()
        await connection.disconnect()
        isActive = false
    }
}
