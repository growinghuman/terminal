import Foundation
import NIO
import NIOSSH

/// Manages known SSH host keys for host verification.
/// Thread-safe: all access is serialized through a lock.
final class KnownHostsStore: @unchecked Sendable {
    private let lock = NSLock()
    enum VerificationResult {
        case trusted
        case changed
        case unknown
    }

    private struct HostEntry: Codable {
        let hostname: String
        let port: Int
        let keyType: String
        let keyData: Data
        let addedAt: Date
    }

    private var entries: [HostEntry] = []
    private let fileURL: URL

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = documentsPath.appendingPathComponent("known_hosts.json")
        loadEntries()
    }

    func verify(host: String, port: Int, key: NIOSSHPublicKey) -> VerificationResult {
        lock.lock()
        defer { lock.unlock() }

        let keyData = serializePublicKey(key)
        let matching = entries.filter { $0.hostname == host && $0.port == port }

        if matching.isEmpty {
            return .unknown
        }

        for entry in matching {
            if entry.keyData == keyData {
                return .trusted
            }
        }

        return .changed
    }

    func addHost(_ hostname: String, port: Int, key: NIOSSHPublicKey) {
        lock.lock()
        defer { lock.unlock() }

        let entry = HostEntry(
            hostname: hostname,
            port: port,
            keyType: describeKeyType(key),
            keyData: serializePublicKey(key),
            addedAt: Date()
        )

        entries.removeAll { $0.hostname == hostname && $0.port == port }
        entries.append(entry)
        saveEntries()
    }

    func removeHost(_ hostname: String, port: Int) {
        lock.lock()
        defer { lock.unlock() }

        entries.removeAll { $0.hostname == hostname && $0.port == port }
        saveEntries()
    }

    func allHosts() -> [(hostname: String, port: Int, keyType: String, addedAt: Date)] {
        lock.lock()
        defer { lock.unlock() }

        return entries.map { ($0.hostname, $0.port, $0.keyType, $0.addedAt) }
    }

    // MARK: - Private

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([HostEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("Failed to save known hosts: \(error)")
            #endif
        }
    }

    private func serializePublicKey(_ key: NIOSSHPublicKey) -> Data {
        // Use the SSH wire format for stable, standard serialization
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        buffer.writeSSHHostKey(key)
        return Data(buffer.readableBytesView)
    }

    private func describeKeyType(_ key: NIOSSHPublicKey) -> String {
        if key.isEd25519PublicKey {
            return "ed25519"
        } else if key.isP256PublicKey {
            return "ecdsa-sha2-nistp256"
        } else if key.isP384PublicKey {
            return "ecdsa-sha2-nistp384"
        } else if key.isP521PublicKey {
            return "ecdsa-sha2-nistp521"
        }
        return "unknown"
    }
}
