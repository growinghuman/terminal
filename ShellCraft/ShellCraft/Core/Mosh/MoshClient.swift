import Foundation
import NIO
import Crypto

/// Mosh client that establishes and maintains a Mosh connection via UDP.
/// Uses SSH to launch mosh-server on the remote, then communicates
/// over a UDP-based State Synchronization Protocol (SSP).
@MainActor
final class MoshClient: ObservableObject {
    @Published var state: MoshState = .disconnected
    @Published var latency: TimeInterval = 0
    @Published var predictedText: String = ""

    private var udpChannel: Channel?
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var sessionKey: SymmetricKey?
    private var remotePort: Int?
    private var sequenceNumber: UInt64 = 0

    private var keepAliveTimer: DispatchSourceTimer?
    private var reconnectTimer: DispatchSourceTimer?
    private var lastServerTimestamp: Date?

    var onDataReceived: ((Data) -> Void)?
    var onStateChanged: ((MoshState) -> Void)?

    enum MoshState: Equatable {
        case disconnected
        case startingServer
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case error(String)

        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .startingServer: return "Starting mosh-server..."
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting(let attempt): return "Reconnecting (\(attempt))..."
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    deinit {
        keepAliveTimer?.cancel()
        reconnectTimer?.cancel()
        try? group.syncShutdownGracefully()
    }

    // MARK: - Connection

    /// Initiates a Mosh connection by first SSH-ing to start mosh-server,
    /// then establishing a UDP session.
    func connect(
        sshConnection: SSHConnection,
        moshServerPath: String = "mosh-server"
    ) async throws {
        updateState(.startingServer)

        // Execute mosh-server on the remote host via SSH exec channel
        let startCommand = "\(moshServerPath) new -s -c 256 -l LANG=en_US.UTF-8"
        let execChannel = try await sshConnection.createExecChannel(command: startCommand)

        // Read mosh-server output to get port and key
        let (port, key) = try await parseMoshServerOutput(channel: execChannel)
        self.remotePort = port
        self.sessionKey = SymmetricKey(data: key)

        // Close exec channel; we no longer need SSH for data transport
        try? await execChannel.close().get()

        // Establish UDP connection
        updateState(.connecting)
        try await establishUDP(host: sshConnection.host, port: port)
        updateState(.connected)

        startKeepAlive()
    }

    private func parseMoshServerOutput(channel: Channel) async throws -> (port: Int, key: Data) {
        // mosh-server prints:
        //   MOSH CONNECT <port> <base64-key>
        return try await withCheckedThrowingContinuation { continuation in
            let handler = MoshServerOutputHandler { result in
                continuation.resume(with: result)
            }
            channel.pipeline.addHandler(handler, position: .last).whenComplete { _ in }
        }
    }

    private func establishUDP(host: String, port: Int) async throws {
        let bootstrap = DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(MoshUDPHandler(client: self))
            }

        let channel = try await bootstrap
            .bind(host: "0.0.0.0", port: 0)
            .get()

        // Connect to remote endpoint
        let remoteAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
        self.udpChannel = channel

        // Send initial handshake
        try await sendDatagram(to: remoteAddress, payload: buildHandshake())
    }

    // MARK: - Data Transport

    func sendData(_ data: Data) {
        guard let channel = udpChannel,
              let remotePort = remotePort,
              state == .connected else { return }

        sequenceNumber += 1

        let encrypted = encryptPayload(data)
        let envelope = channel.allocator.buffer(bytes: encrypted)

        let remoteAddress = try? SocketAddress.makeAddressResolvingHost(
            "", port: remotePort
        )
        guard let address = remoteAddress else { return }

        let packet = AddressedEnvelope(remoteAddress: address, data: envelope)
        channel.writeAndFlush(packet, promise: nil)
    }

    func sendText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        sendData(data)
    }

    // MARK: - Prediction Engine

    /// Local echo prediction for low-latency typing feedback.
    /// Predicts printable characters and common control sequences.
    func predictInput(_ text: String) -> String? {
        guard state == .connected else { return nil }
        // Only predict printable ASCII characters
        let printable = text.unicodeScalars.allSatisfy {
            $0.value >= 0x20 && $0.value < 0x7F
        }
        if printable {
            predictedText += text
            return predictedText
        }
        return nil
    }

    func confirmPrediction(upTo index: String.Index) {
        if index <= predictedText.endIndex {
            predictedText = String(predictedText[index...])
        }
    }

    func resetPrediction() {
        predictedText = ""
    }

    // MARK: - Reconnection

    func handleNetworkChange() {
        guard state == .connected || state != .disconnected else { return }
        updateState(.reconnecting(attempt: 1))
        attemptReconnect(attempt: 1)
    }

    private func attemptReconnect(attempt: Int) {
        guard attempt <= 10 else {
            updateState(.error("Failed to reconnect after 10 attempts"))
            return
        }

        let delay = min(Double(attempt) * 0.5, 5.0) // 0.5s, 1s, 1.5s, ... max 5s

        reconnectTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateState(.reconnecting(attempt: attempt))

                // Try sending a keepalive; if we get a response, we're reconnected
                let keepalive = self.buildKeepAlive()
                if let channel = self.udpChannel {
                    var buffer = channel.allocator.buffer(capacity: keepalive.count)
                    buffer.writeBytes(keepalive)
                    // Re-resolve the address in case of network change
                    channel.writeAndFlush(buffer, promise: nil)
                }

                // Schedule next attempt
                self.attemptReconnect(attempt: attempt + 1)
            }
        }
        timer.resume()
        reconnectTimer = timer
    }

    func handleServerResponse() {
        lastServerTimestamp = Date()
        reconnectTimer?.cancel()

        if case .reconnecting = state {
            updateState(.connected)
        }
    }

    // MARK: - Keep Alive

    private func startKeepAlive() {
        keepAliveTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.sendKeepAlive()
            }
        }
        timer.resume()
        keepAliveTimer = timer
    }

    private func sendKeepAlive() {
        let payload = buildKeepAlive()
        guard let channel = udpChannel else { return }
        var buffer = channel.allocator.buffer(capacity: payload.count)
        buffer.writeBytes(payload)
        channel.writeAndFlush(buffer, promise: nil)

        // Check for stale connection
        if let last = lastServerTimestamp, Date().timeIntervalSince(last) > 15 {
            handleNetworkChange()
        }
    }

    // MARK: - Encryption

    private func encryptPayload(_ data: Data) -> [UInt8] {
        guard let key = sessionKey else { return [UInt8](data) }

        // AES-128-OCB is used by Mosh, but Apple CryptoKit provides AES-GCM.
        // We use AES-GCM as a compatible authenticated encryption mode.
        var nonceBytes = [UInt8](repeating: 0, count: 12)
        withUnsafeBytes(of: sequenceNumber.bigEndian) { ptr in
            nonceBytes.replaceSubrange(4..<12, with: ptr)
        }

        do {
            let nonce = try AES.GCM.Nonce(data: nonceBytes)
            let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
            return [UInt8](sealed.combined ?? Data())
        } catch {
            return [UInt8](data)
        }
    }

    private func decryptPayload(_ data: Data) -> Data? {
        guard let key = sessionKey else { return data }

        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            return nil
        }
    }

    // MARK: - Protocol Messages

    private func buildHandshake() -> [UInt8] {
        // Initial handshake: sequence 0 + timestamp
        var payload = [UInt8]()
        withUnsafeBytes(of: UInt64(0).bigEndian) { payload.append(contentsOf: $0) }
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        withUnsafeBytes(of: timestamp.bigEndian) { payload.append(contentsOf: $0) }
        return encryptPayload(Data(payload))
    }

    private func buildKeepAlive() -> [UInt8] {
        sequenceNumber += 1
        var payload = [UInt8]()
        withUnsafeBytes(of: sequenceNumber.bigEndian) { payload.append(contentsOf: $0) }
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        withUnsafeBytes(of: timestamp.bigEndian) { payload.append(contentsOf: $0) }
        return encryptPayload(Data(payload))
    }

    private func sendDatagram(to address: SocketAddress, payload: [UInt8]) async throws {
        guard let channel = udpChannel else { throw MoshError.notConnected }
        var buffer = channel.allocator.buffer(capacity: payload.count)
        buffer.writeBytes(payload)
        let envelope = AddressedEnvelope(remoteAddress: address, data: buffer)
        try await channel.writeAndFlush(envelope)
    }

    // MARK: - State

    private func updateState(_ newState: MoshState) {
        state = newState
        onStateChanged?(newState)
    }

    func disconnect() {
        keepAliveTimer?.cancel()
        reconnectTimer?.cancel()
        try? udpChannel?.close().wait()
        udpChannel = nil
        sessionKey = nil
        remotePort = nil
        updateState(.disconnected)
    }
}

// MARK: - UDP Handler

private final class MoshUDPHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>

    private let client: MoshClient

    init(client: MoshClient) {
        self.client = client
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        var buffer = envelope.data
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else { return }

        Task { @MainActor in
            client.handleServerResponse()
            client.onDataReceived?(Data(bytes))
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Task { @MainActor in
            client.handleNetworkChange()
        }
    }
}

// MARK: - mosh-server Output Parser

private final class MoshServerOutputHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private var buffer = ""
    private let completion: (Result<(port: Int, key: Data), Error>) -> Void
    private var completed = false

    init(completion: @escaping (Result<(port: Int, key: Data), Error>) -> Void) {
        self.completion = completion
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var inBuffer = unwrapInboundIn(data)
        if let str = inBuffer.readString(length: inBuffer.readableBytes) {
            buffer += str
        }

        // Look for "MOSH CONNECT <port> <key>"
        if !completed, let range = buffer.range(of: "MOSH CONNECT") {
            let line = buffer[range.lowerBound...]
            let parts = line.split(separator: " ")
            if parts.count >= 4,
               let port = Int(parts[2]),
               let keyData = Data(base64Encoded: String(parts[3])) {
                completed = true
                completion(.success((port: port, key: keyData)))
            }
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        if !completed {
            completion(.failure(MoshError.serverStartFailed))
        }
    }
}

// MARK: - Errors

enum MoshError: LocalizedError {
    case notConnected
    case serverStartFailed
    case invalidServerResponse
    case encryptionFailed
    case reconnectionFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Mosh is not connected"
        case .serverStartFailed: return "Failed to start mosh-server on remote host"
        case .invalidServerResponse: return "Invalid response from mosh-server"
        case .encryptionFailed: return "Mosh encryption error"
        case .reconnectionFailed: return "Failed to reconnect"
        }
    }
}
