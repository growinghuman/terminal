import Foundation
import NIO
import NIOSSH

/// Manages a single SSH connection lifecycle
final class SSHConnection: @unchecked Sendable {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?

    let host: String
    let port: Int
    let username: String

    private(set) var state: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case authenticating
        case connected
        case error(String)
    }

    var onStateChanged: ((ConnectionState) -> Void)?
    var onDisconnected: (() -> Void)?

    init(host: String, port: Int, username: String) {
        self.host = host
        self.port = port
        self.username = username
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    /// Shuts down the NIO event loop group. Called after disconnect.
    func shutdownEventLoop() {
        try? group.syncShutdownGracefully()
    }

    func connect(authDelegate: NIOSSHClientUserAuthenticationDelegate,
                 serverAuthDelegate: NIOSSHClientServerAuthenticationDelegate) async throws {
        updateState(.connecting)

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    NIOSSHHandler(
                        role: .client(
                            .init(
                                userAuthDelegate: authDelegate,
                                serverAuthDelegate: serverAuthDelegate
                            )
                        ),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                ])
            }
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.connectTimeout, value: .seconds(30))

        do {
            self.channel = try await bootstrap.connect(host: host, port: port)
            updateState(.connected)
        } catch {
            updateState(.error(error.localizedDescription))
            throw error
        }
    }

    /// Creates a session channel with SSHShellHandler installed.
    /// Caller must request PTY before requesting the shell.
    func createSessionChannel() async throws -> Channel {
        guard let channel = self.channel else {
            throw SSHError.notConnected
        }

        let childChannel = try await channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { handler in
            let promise = channel.eventLoop.makePromise(of: Channel.self)
            handler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return channel.eventLoop.makeFailedFuture(SSHError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([
                    SSHShellHandler()
                ])
            }
            return promise.futureResult
        }.get()

        return childChannel
    }

    func requestShell(on channel: Channel) async throws {
        let shellRequest = SSHChannelRequestEvent.ShellRequest(
            wantReply: true
        )
        try await channel.triggerUserOutboundEvent(shellRequest).get()
    }

    func createExecChannel(command: String) async throws -> Channel {
        guard let channel = self.channel else {
            throw SSHError.notConnected
        }

        let childChannel = try await channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { handler in
            let promise = channel.eventLoop.makePromise(of: Channel.self)
            handler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return channel.eventLoop.makeFailedFuture(SSHError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([
                    SSHExecHandler()
                ])
            }
            return promise.futureResult
        }.get()

        let execRequest = SSHChannelRequestEvent.ExecRequest(
            command: command,
            wantReply: true
        )
        try await childChannel.triggerUserOutboundEvent(execRequest).get()

        return childChannel
    }

    func requestPTY(on channel: Channel, term: String = "xterm-256color",
                    cols: Int = 80, rows: Int = 24) async throws {
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: term,
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        try await channel.triggerUserOutboundEvent(ptyRequest).get()
    }

    func resizeTerminal(on channel: Channel, cols: Int, rows: Int) async throws {
        let windowChange = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        try await channel.triggerUserOutboundEvent(windowChange).get()
    }

    func disconnect() async {
        try? await channel?.close().get()
        channel = nil
        updateState(.disconnected)
        onDisconnected?()
    }

    var isConnected: Bool {
        state == .connected && channel?.isActive == true
    }

    private func updateState(_ newState: ConnectionState) {
        state = newState
        onStateChanged?(newState)
    }
}

enum SSHError: LocalizedError {
    case notConnected
    case invalidChannelType
    case authenticationFailed
    case connectionTimeout
    case channelCreationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to SSH server"
        case .invalidChannelType: return "Invalid SSH channel type"
        case .authenticationFailed: return "Authentication failed"
        case .connectionTimeout: return "Connection timed out"
        case .channelCreationFailed: return "Failed to create SSH channel"
        }
    }
}
