import Foundation
import NIO
import NIOSSH

/// Manages SSH port forwarding tunnels
@MainActor
final class PortForwardingManager: ObservableObject {
    @Published var activeTunnels: [PortForwardTunnel] = []

    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    /// Call this before the manager is released to cleanly shut down the event loop group
    nonisolated func shutdown() {
        try? group.syncShutdownGracefully()
    }

    /// Create a local port forwarding tunnel: -L localPort:remoteHost:remotePort
    func createLocalForward(
        connection: SSHConnection,
        localPort: Int,
        remoteHost: String,
        remotePort: Int,
        label: String? = nil
    ) async throws -> PortForwardTunnel {
        let tunnel = PortForwardTunnel(
            id: UUID(),
            type: .local,
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            label: label ?? "L:\(localPort)→\(remoteHost):\(remotePort)",
            state: .starting
        )
        activeTunnels.append(tunnel)

        // Start local listener
        do {
            let serverBootstrap = ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { childChannel in
                    // For each incoming local connection, create an SSH direct-tcpip channel
                    childChannel.pipeline.addHandler(
                        LocalForwardHandler(
                            connection: connection,
                            remoteHost: remoteHost,
                            remotePort: remotePort
                        )
                    )
                }

            let channel = try await serverBootstrap.bind(host: "127.0.0.1", port: localPort).get()

            if let index = activeTunnels.firstIndex(where: { $0.id == tunnel.id }) {
                activeTunnels[index].state = .active
                activeTunnels[index].channel = channel
            }

            return tunnel
        } catch {
            if let index = activeTunnels.firstIndex(where: { $0.id == tunnel.id }) {
                activeTunnels[index].state = .error(error.localizedDescription)
            }
            throw error
        }
    }

    /// Stop a specific tunnel
    func stopTunnel(_ tunnelID: UUID) async {
        guard let index = activeTunnels.firstIndex(where: { $0.id == tunnelID }) else { return }
        try? await activeTunnels[index].channel?.close().get()
        activeTunnels[index].state = .stopped
        activeTunnels.remove(at: index)
    }

    /// Stop all tunnels
    func stopAllTunnels() async {
        for i in activeTunnels.indices {
            try? await activeTunnels[i].channel?.close().get()
        }
        activeTunnels.removeAll()
    }
}

struct PortForwardTunnel: Identifiable {
    let id: UUID
    let type: TunnelType
    let localPort: Int
    let remoteHost: String
    let remotePort: Int
    let label: String
    var state: TunnelState
    var channel: Channel?
    var bytesTransferred: UInt64 = 0

    enum TunnelType: String {
        case local = "Local"
        case remote = "Remote"
        case dynamic = "Dynamic"

        var iconName: String {
            switch self {
            case .local: return "arrow.right"
            case .remote: return "arrow.left"
            case .dynamic: return "arrow.triangle.branch"
            }
        }
    }

    enum TunnelState: Equatable {
        case starting
        case active
        case stopped
        case error(String)

        var displayName: String {
            switch self {
            case .starting: return "Starting..."
            case .active: return "Active"
            case .stopped: return "Stopped"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var color: SwiftUI.Color {
            switch self {
            case .starting: return .orange
            case .active: return .green
            case .stopped: return .secondary
            case .error: return .red
            }
        }
    }

    var displayDescription: String {
        switch type {
        case .local:
            return "localhost:\(localPort) → \(remoteHost):\(remotePort)"
        case .remote:
            return "\(remoteHost):\(remotePort) → localhost:\(localPort)"
        case .dynamic:
            return "SOCKS5 on localhost:\(localPort)"
        }
    }
}

import SwiftUI

/// Handler that bridges a local TCP connection to an SSH direct-tcpip channel
final class LocalForwardHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let connection: SSHConnection
    private let remoteHost: String
    private let remotePort: Int

    init(connection: SSHConnection, remoteHost: String, remotePort: Int) {
        self.connection = connection
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    func channelActive(context: ChannelHandlerContext) {
        // When a local client connects, open a direct-tcpip SSH channel
        // This is a simplified placeholder - full implementation would
        // create a direct-tcpip channel and bridge data bidirectionally
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // Forward data from local client to SSH channel
        let buffer = unwrapInboundIn(data)
        _ = buffer // Would write to SSH channel
        context.fireChannelRead(data)
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
}
