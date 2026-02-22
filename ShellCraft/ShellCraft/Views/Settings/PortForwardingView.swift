import SwiftUI

struct PortForwardingView: View {
    @ObservedObject var forwardingManager: PortForwardingManager
    @State private var showAddTunnel = false

    var body: some View {
        List {
            if forwardingManager.activeTunnels.isEmpty {
                ContentUnavailableView {
                    Label("No Tunnels", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Create a port forwarding tunnel to securely access remote services.")
                } actions: {
                    Button("Create Tunnel") {
                        showAddTunnel = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Section("Active Tunnels") {
                    ForEach(forwardingManager.activeTunnels) { tunnel in
                        tunnelRow(tunnel)
                    }
                }
            }
        }
        .navigationTitle("Port Forwarding")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTunnel = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTunnel) {
            AddTunnelView(forwardingManager: forwardingManager)
        }
    }

    private func tunnelRow(_ tunnel: PortForwardTunnel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tunnel.type.iconName)
                .foregroundStyle(tunnel.state.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(tunnel.label)
                    .font(.headline)

                Text(tunnel.displayDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(tunnel.state.color)
                        .frame(width: 6, height: 6)
                    Text(tunnel.state.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await forwardingManager.stopTunnel(tunnel.id) }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddTunnelView: View {
    @ObservedObject var forwardingManager: PortForwardingManager
    var connection: SSHConnection?
    @Environment(\.dismiss) private var dismiss

    @State private var tunnelType: PortForwardTunnel.TunnelType = .local
    @State private var localPort = ""
    @State private var remoteHost = "127.0.0.1"
    @State private var remotePort = ""
    @State private var label = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tunnel Type") {
                    Picker("Type", selection: $tunnelType) {
                        Text("Local (-L)").tag(PortForwardTunnel.TunnelType.local)
                        Text("Remote (-R)").tag(PortForwardTunnel.TunnelType.remote)
                        Text("Dynamic (-D)").tag(PortForwardTunnel.TunnelType.dynamic)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Configuration") {
                    HStack {
                        Text("Local Port")
                        Spacer()
                        TextField("8080", text: $localPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    if tunnelType != .dynamic {
                        TextField("Remote Host", text: $remoteHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        HStack {
                            Text("Remote Port")
                            Spacer()
                            TextField("80", text: $remotePort)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    TextField("Label (optional)", text: $label)
                }

                Section {
                    previewText
                } header: {
                    Text("Preview")
                } footer: {
                    switch tunnelType {
                    case .local:
                        Text("Forwards connections from your device's port to the remote server's destination.")
                    case .remote:
                        Text("Forwards connections from the remote server's port to your device.")
                    case .dynamic:
                        Text("Creates a SOCKS5 proxy on your device through the SSH connection.")
                    }
                }
            }
            .navigationTitle("New Tunnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTunnel()
                    }
                    .disabled(!isValid || connection == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func createTunnel() {
        guard let connection = connection,
              let lp = Int(localPort) else { return }

        let rp = Int(remotePort) ?? 0

        Task {
            do {
                _ = try await forwardingManager.createLocalForward(
                    connection: connection,
                    localPort: lp,
                    remoteHost: remoteHost,
                    remotePort: rp,
                    label: label.isEmpty ? nil : label
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private var isValid: Bool {
        guard let lp = Int(localPort), lp > 0, lp <= 65535 else { return false }
        if tunnelType != .dynamic {
            guard let rp = Int(remotePort), rp > 0, rp <= 65535 else { return false }
            guard !remoteHost.isEmpty else { return false }
        }
        return true
    }

    private var previewText: some View {
        let command: String
        switch tunnelType {
        case .local:
            command = "ssh -L \(localPort):\(remoteHost):\(remotePort)"
        case .remote:
            command = "ssh -R \(remotePort):\(remoteHost):\(localPort)"
        case .dynamic:
            command = "ssh -D \(localPort)"
        }
        return Text(command)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
