import Foundation
import Network

/// Manages a Mosh session lifecycle including network monitoring for seamless roaming.
@MainActor
final class MoshSession: ObservableObject {
    let id: UUID
    let host: Host
    let moshClient: MoshClient

    @Published var title: String
    @Published var isActive: Bool = true
    @Published var connectionQuality: ConnectionQuality = .good

    private var networkMonitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?

    var onDataReceived: ((Data) -> Void)? {
        get { moshClient.onDataReceived }
        set { moshClient.onDataReceived = newValue }
    }

    enum ConnectionQuality: Equatable {
        case excellent  // < 50ms
        case good       // 50-150ms
        case fair       // 150-500ms
        case poor       // > 500ms

        init(latency: TimeInterval) {
            switch latency {
            case ..<0.05: self = .excellent
            case ..<0.15: self = .good
            case ..<0.5: self = .fair
            default: self = .poor
            }
        }

        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }

        var iconName: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            }
        }
    }

    init(id: UUID, host: Host, moshClient: MoshClient) {
        self.id = id
        self.host = host
        self.moshClient = moshClient
        self.title = host.name

        setupNetworkMonitoring()
        observeMoshState()
    }

    // MARK: - Network Monitoring

    /// Monitors network path changes (Wi-Fi <-> Cellular) and triggers Mosh reconnection.
    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "mosh.network.monitor")
        self.networkMonitor = monitor
        self.monitorQueue = queue

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if path.status == .satisfied {
                    // Network is available — trigger reconnect if needed
                    if case .reconnecting = self.moshClient.state {
                        // Already reconnecting
                    } else if self.moshClient.state != .connected {
                        self.moshClient.handleNetworkChange()
                    }
                } else {
                    // Network lost — start reconnection cycle
                    self.moshClient.handleNetworkChange()
                }
            }
        }

        monitor.start(queue: queue)
    }

    private func observeMoshState() {
        moshClient.onStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch state {
                case .connected:
                    self.isActive = true
                case .disconnected, .error:
                    self.isActive = false
                default:
                    break
                }
            }
        }
    }

    // MARK: - Data Transmission

    func sendData(_ data: Data) {
        // Apply local echo prediction
        if let text = String(data: data, encoding: .utf8) {
            _ = moshClient.predictInput(text)
        }
        moshClient.sendData(data)
    }

    func sendText(_ text: String) {
        _ = moshClient.predictInput(text)
        moshClient.sendText(text)
    }

    // MARK: - Terminal Resize

    func resizeTerminal(cols: Int, rows: Int) {
        // Mosh handles terminal resize via SSP protocol state sync
        var payload = Data()
        payload.append(0x1B) // ESC
        payload.append(contentsOf: "[8;\(rows);\(cols)t".utf8)
        moshClient.sendData(payload)
    }

    // MARK: - Lifecycle

    func disconnect() {
        networkMonitor?.cancel()
        networkMonitor = nil
        moshClient.disconnect()
        isActive = false
    }
}
