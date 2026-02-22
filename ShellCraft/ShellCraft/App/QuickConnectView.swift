import SwiftUI

/// Quick connect dialog - connect without saving a host profile
struct QuickConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var terminalViewModel: TerminalViewModel

    @State private var connectionString = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isConnecting = false
    @State private var recentConnections: [String] = []

    // Parse: user@host:port or host or user@host
    private var parsedConnection: (user: String, host: String, port: Int)? {
        let trimmed = connectionString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var user = "root"
        var host = trimmed
        var port = 22

        // Extract user@
        if let atIndex = host.firstIndex(of: "@") {
            user = String(host[host.startIndex..<atIndex])
            host = String(host[host.index(after: atIndex)...])
        }

        // Extract :port
        if let colonIndex = host.lastIndex(of: ":") {
            let portStr = String(host[host.index(after: colonIndex)...])
            if let parsedPort = Int(portStr), parsedPort > 0, parsedPort <= 65535 {
                port = parsedPort
                host = String(host[host.startIndex..<colonIndex])
            }
        }

        guard !host.isEmpty else { return nil }
        return (user, host, port)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Connection input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect to")
                        .font(.headline)

                    TextField("user@hostname:port", text: $connectionString)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .submitLabel(.next)

                    if let parsed = parsedConnection {
                        HStack(spacing: 12) {
                            Label(parsed.user, systemImage: "person")
                            Label(parsed.host, systemImage: "server.rack")
                            Label("\(parsed.port)", systemImage: "number")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)

                    if showPassword {
                        TextField("Password", text: $password)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Show password", isOn: $showPassword)
                        .font(.caption)
                }

                // Connect button
                Button {
                    connect()
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isConnecting ? "Connecting..." : "Connect")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(parsedConnection != nil ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(parsedConnection == nil || isConnecting)

                // Recent connections
                if !recentConnections.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(recentConnections, id: \.self) { conn in
                            Button {
                                connectionString = conn
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                    Text(conn)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadRecentConnections()
            }
        }
    }

    private func connect() {
        guard let parsed = parsedConnection else { return }
        isConnecting = true

        // Save to recents
        saveRecentConnection(connectionString)

        // Create a temporary host
        let host = Host(
            name: "\(parsed.user)@\(parsed.host)",
            hostname: parsed.host,
            port: parsed.port,
            username: parsed.user,
            authMethod: .password
        )

        Task {
            await terminalViewModel.openConnection(host: host, password: password)
            isConnecting = false
            if terminalViewModel.connectionError == nil {
                dismiss()
            }
        }
    }

    private func loadRecentConnections() {
        recentConnections = UserDefaults.standard.stringArray(forKey: "recentQuickConnections") ?? []
    }

    private func saveRecentConnection(_ connection: String) {
        var recents = UserDefaults.standard.stringArray(forKey: "recentQuickConnections") ?? []
        recents.removeAll { $0 == connection }
        recents.insert(connection, at: 0)
        if recents.count > 10 { recents = Array(recents.prefix(10)) }
        UserDefaults.standard.set(recents, forKey: "recentQuickConnections")
    }
}
