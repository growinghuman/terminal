import SwiftUI
import SwiftData

struct HostDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var host: Host

    @State private var password = ""
    @State private var hasStoredPassword = false

    var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("Name") {
                    TextField("Name", text: $host.name)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Hostname") {
                    TextField("Hostname", text: $host.hostname)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                LabeledContent("Port") {
                    TextField("Port", value: $host.port, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }

                LabeledContent("Username") {
                    TextField("Username", text: $host.username)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }

            Section("Authentication") {
                Picker("Method", selection: $host.authMethod) {
                    ForEach(AuthMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }

                if host.authMethod == .password {
                    if hasStoredPassword {
                        HStack {
                            Text("Password")
                            Spacer()
                            Text("Saved")
                                .foregroundStyle(.secondary)
                            Button("Remove") {
                                try? KeychainHelper.deletePassword(for: host.id.uuidString)
                                hasStoredPassword = false
                            }
                            .foregroundStyle(.red)
                            .font(.caption)
                        }
                    } else {
                        SecureField("Password", text: $password)

                        if !password.isEmpty {
                            Button("Save Password") {
                                try? KeychainHelper.savePassword(password, for: host.id.uuidString)
                                hasStoredPassword = true
                                password = ""
                            }
                        }
                    }
                }
            }

            Section("Organization") {
                LabeledContent("Group") {
                    TextField("Group", text: Binding(
                        get: { host.group ?? "" },
                        set: { host.group = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                }

                Toggle("Favorite", isOn: $host.isFavorite)
            }

            Section("Terminal") {
                LabeledContent("Font Size") {
                    TextField("Size", value: $host.fontSize, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                }

                LabeledContent("Keep Alive") {
                    TextField("Seconds", value: $host.keepAliveInterval, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }
            }

            if let notes = host.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.callout)
                }
            }

            Section {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(host.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }

                if let lastConnected = host.lastConnectedAt {
                    HStack {
                        Text("Last Connected")
                        Spacer()
                        Text(lastConnected, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Edit Host")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasStoredPassword = (try? KeychainHelper.getPassword(for: host.id.uuidString)) != nil
        }
        .onChange(of: host.name) { _, _ in
            host.updatedAt = Date()
            try? modelContext.save()
        }
    }
}
