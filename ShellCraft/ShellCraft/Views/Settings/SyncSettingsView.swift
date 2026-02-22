import SwiftUI
import SwiftData

struct SyncSettingsView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showSyncConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: $syncManager.syncEnabled)

                if syncManager.syncEnabled {
                    syncStatusRow
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Syncs hosts, snippets, and settings across all your devices using iCloud. Passwords and private keys are NOT synced for security.")
            }

            if syncManager.syncEnabled {
                Section("Sync Items") {
                    syncItemRow("Hosts", icon: "server.rack", detail: "Connection profiles and groups")
                    syncItemRow("Snippets", icon: "text.word.spacing", detail: "Commands and categories")
                    syncItemRow("Settings", icon: "gearshape", detail: "Theme, font size, preferences")
                }

                Section {
                    Button("Sync Now") {
                        Task {
                            await syncManager.performFullSync(modelContext: modelContext)
                        }
                    }
                    .disabled(syncManager.isSyncing)
                }

                if let error = syncManager.syncError {
                    Section("Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("iCloud Sync")
    }

    private var syncStatusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            if syncManager.isSyncing {
                ProgressView()
                    .controlSize(.small)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastSync = syncManager.lastSyncDate {
                Text("Last: \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not synced yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func syncItemRow(_ title: String, icon: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}
