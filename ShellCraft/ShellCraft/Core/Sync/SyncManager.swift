import Foundation
import SwiftData
import CloudKit

/// Manages iCloud sync for hosts, snippets, keys, and settings.
/// Uses NSUbiquitousKeyValueStore for lightweight settings and
/// CloudKit for structured data (hosts, snippets, key metadata).
@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncEnabled: Bool {
        didSet { UserDefaults.standard.set(syncEnabled, forKey: "iCloudSyncEnabled") }
    }

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let container = CKContainer.default()
    private let privateDB: CKDatabase

    private init() {
        self.syncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        self.privateDB = CKContainer.default().privateCloudDatabase

        // Observe remote KV store changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )

        kvStore.synchronize()
    }

    // MARK: - Settings Sync (NSUbiquitousKeyValueStore)

    func syncSettings() {
        // Push local settings to iCloud KV store
        let defaults = UserDefaults.standard
        let keys = [
            "selectedThemeID", "defaultFontSize", "enableHapticFeedback",
            "enableBellSound", "scrollbackBufferSize", "defaultKeepAlive",
            "useBiometricAuth"
        ]

        for key in keys {
            if let value = defaults.object(forKey: key) {
                kvStore.set(value, forKey: key)
            }
        }
        kvStore.synchronize()
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }

        // Only apply if change is from server
        if reason == NSUbiquitousKeyValueStoreServerChange ||
           reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            Task { @MainActor in
                applyRemoteSettings()
            }
        }
    }

    private func applyRemoteSettings() {
        let defaults = UserDefaults.standard
        let keys = [
            "selectedThemeID", "defaultFontSize", "enableHapticFeedback",
            "enableBellSound", "scrollbackBufferSize", "defaultKeepAlive",
            "useBiometricAuth"
        ]

        for key in keys {
            if let value = kvStore.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    // MARK: - Host Sync (CloudKit)

    func syncHosts(modelContext: ModelContext) async {
        guard syncEnabled else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Fetch remote hosts
            let query = CKQuery(recordType: "Host", predicate: NSPredicate(value: true))
            let results = try await privateDB.records(matching: query)
            let remoteRecords = results.matchResults.compactMap { try? $0.1.get() }

            // Fetch local hosts
            let descriptor = FetchDescriptor<Host>()
            let localHosts = (try? modelContext.fetch(descriptor)) ?? []

            // Merge: remote wins for conflicts (last-write-wins by updatedAt)
            let localByID = Dictionary(uniqueKeysWithValues: localHosts.map { ($0.id.uuidString, $0) })

            for record in remoteRecords {
                let remoteID = record["hostID"] as? String ?? ""
                let remoteUpdated = record["updatedAt"] as? Date ?? Date.distantPast

                if let local = localByID[remoteID] {
                    // Merge: take whichever is newer
                    if remoteUpdated > local.updatedAt {
                        applyRecord(record, to: local)
                    }
                } else {
                    // New remote host — create locally
                    let host = hostFromRecord(record)
                    modelContext.insert(host)
                }
            }

            // Push local-only hosts to CloudKit
            let remoteIDs = Set(remoteRecords.compactMap { $0["hostID"] as? String })
            for host in localHosts where !remoteIDs.contains(host.id.uuidString) {
                let record = recordFromHost(host)
                try await privateDB.save(record)
            }

            try? modelContext.save()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Snippet Sync

    func syncSnippets(modelContext: ModelContext) async {
        guard syncEnabled else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let query = CKQuery(recordType: "Snippet", predicate: NSPredicate(value: true))
            let results = try await privateDB.records(matching: query)
            let remoteRecords = results.matchResults.compactMap { try? $0.1.get() }

            let descriptor = FetchDescriptor<Snippet>()
            let localSnippets = (try? modelContext.fetch(descriptor)) ?? []
            let localByID = Dictionary(uniqueKeysWithValues: localSnippets.map { ($0.id.uuidString, $0) })

            for record in remoteRecords {
                let remoteID = record["snippetID"] as? String ?? ""
                let remoteUpdated = record["updatedAt"] as? Date ?? Date.distantPast

                if let local = localByID[remoteID] {
                    if remoteUpdated > local.updatedAt {
                        local.title = record["title"] as? String ?? local.title
                        local.command = record["command"] as? String ?? local.command
                        local.category = record["category"] as? String
                        local.updatedAt = remoteUpdated
                    }
                } else {
                    let snippet = Snippet(
                        title: record["title"] as? String ?? "",
                        command: record["command"] as? String ?? "",
                        category: record["category"] as? String
                    )
                    modelContext.insert(snippet)
                }
            }

            // Push local-only snippets
            let remoteIDs = Set(remoteRecords.compactMap { $0["snippetID"] as? String })
            for snippet in localSnippets where !remoteIDs.contains(snippet.id.uuidString) {
                let record = CKRecord(recordType: "Snippet")
                record["snippetID"] = snippet.id.uuidString
                record["title"] = snippet.title
                record["command"] = snippet.command
                record["category"] = snippet.category
                record["updatedAt"] = snippet.updatedAt
                try await privateDB.save(record)
            }

            try? modelContext.save()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Full Sync

    func performFullSync(modelContext: ModelContext) async {
        syncSettings()
        await syncHosts(modelContext: modelContext)
        await syncSnippets(modelContext: modelContext)
    }

    // MARK: - CloudKit Record Mapping

    private func recordFromHost(_ host: Host) -> CKRecord {
        let record = CKRecord(recordType: "Host")
        record["hostID"] = host.id.uuidString
        record["name"] = host.name
        record["hostname"] = host.hostname
        record["port"] = host.port
        record["username"] = host.username
        record["authMethod"] = host.authMethod.rawValue
        record["group"] = host.group
        record["fontSize"] = host.fontSize
        record["keepAliveInterval"] = host.keepAliveInterval
        record["notes"] = host.notes
        record["isFavorite"] = host.isFavorite
        record["updatedAt"] = host.updatedAt
        return record
    }

    private func hostFromRecord(_ record: CKRecord) -> Host {
        let host = Host(
            name: record["name"] as? String ?? "",
            hostname: record["hostname"] as? String ?? "",
            port: record["port"] as? Int ?? 22,
            username: record["username"] as? String ?? "root",
            authMethod: AuthMethod(rawValue: record["authMethod"] as? String ?? "password") ?? .password,
            group: record["group"] as? String,
            fontSize: record["fontSize"] as? Int ?? 14,
            keepAliveInterval: record["keepAliveInterval"] as? Int ?? 60,
            notes: record["notes"] as? String
        )
        host.isFavorite = record["isFavorite"] as? Bool ?? false
        return host
    }

    private func applyRecord(_ record: CKRecord, to host: Host) {
        host.name = record["name"] as? String ?? host.name
        host.hostname = record["hostname"] as? String ?? host.hostname
        host.port = record["port"] as? Int ?? host.port
        host.username = record["username"] as? String ?? host.username
        host.authMethod = AuthMethod(rawValue: record["authMethod"] as? String ?? "") ?? host.authMethod
        host.group = record["group"] as? String
        host.fontSize = record["fontSize"] as? Int ?? host.fontSize
        host.keepAliveInterval = record["keepAliveInterval"] as? Int ?? host.keepAliveInterval
        host.notes = record["notes"] as? String
        host.isFavorite = record["isFavorite"] as? Bool ?? host.isFavorite
        host.updatedAt = record["updatedAt"] as? Date ?? host.updatedAt
    }
}
