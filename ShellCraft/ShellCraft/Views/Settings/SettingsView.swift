import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                terminalSection
                connectionSection
                securitySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.save()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            NavigationLink {
                ThemePickerView(selectedThemeID: $viewModel.selectedThemeID)
            } label: {
                HStack {
                    Text("Theme")
                    Spacer()
                    Text(viewModel.themeManager.selectedTheme.name)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Font Size")
                Spacer()
                Stepper(
                    "\(Int(viewModel.defaultFontSize)) pt",
                    value: $viewModel.defaultFontSize,
                    in: 8...32,
                    step: 1
                )
            }
        }
    }

    private var terminalSection: some View {
        Section("Terminal") {
            HStack {
                Text("Scrollback Buffer")
                Spacer()
                Picker("", selection: $viewModel.scrollbackBufferSize) {
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("10,000").tag(10000)
                    Text("50,000").tag(50000)
                    Text("Unlimited").tag(Int.max)
                }
                .pickerStyle(.menu)
            }

            Toggle("Haptic Feedback", isOn: $viewModel.enableHapticFeedback)
            Toggle("Bell Sound", isOn: $viewModel.enableBellSound)
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Text("Default Keep Alive")
                Spacer()
                Picker("", selection: $viewModel.defaultKeepAlive) {
                    Text("Off").tag(0)
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                    Text("120s").tag(120)
                }
                .pickerStyle(.menu)
            }

            NavigationLink("Known Hosts") {
                KnownHostsView()
            }

            NavigationLink("SSH Keys") {
                KeySelectionView()
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle("Require Face ID / Touch ID", isOn: $viewModel.useBiometricAuth)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundStyle(.secondary)
            }

            Link("GitHub Repository", destination: URL(string: "https://github.com/shellcraft/shellcraft-ios")!)

            Link("Privacy Policy", destination: URL(string: "https://shellcraft.app/privacy")!)
        }
    }
}

// MARK: - Known Hosts View

struct KnownHostsView: View {
    @State private var hosts: [(hostname: String, port: Int, keyType: String, addedAt: Date)] = []
    private let store = KnownHostsStore()

    var body: some View {
        List {
            if hosts.isEmpty {
                ContentUnavailableView {
                    Label("No Known Hosts", systemImage: "server.rack")
                } description: {
                    Text("Host keys will be saved here when you connect to servers.")
                }
            } else {
                ForEach(hosts.indices, id: \.self) { index in
                    let host = hosts[index]
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(host.hostname):\(host.port)")
                            .font(.headline)
                        HStack {
                            Text(host.keyType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())

                            Spacer()

                            Text(host.addedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let host = hosts[index]
                        store.removeHost(host.hostname, port: host.port)
                    }
                    hosts = store.allHosts()
                }
            }
        }
        .navigationTitle("Known Hosts")
        .onAppear {
            hosts = store.allHosts()
        }
    }
}
