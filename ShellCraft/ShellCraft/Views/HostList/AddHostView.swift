import SwiftUI
import SwiftData

struct AddHostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = "root"
    @State private var authMethod: AuthMethod = .password
    @State private var password = ""
    @State private var savePassword = true
    @State private var group = ""
    @State private var notes = ""
    @State private var keepAliveInterval = "60"
    @State private var fontSize = "14"

    @State private var showAdvanced = false

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                authSection
                if showAdvanced {
                    advancedSection
                }
                toggleAdvanced
            }
            .navigationTitle("New Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHost() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var basicSection: some View {
        Section("Connection") {
            TextField("Display Name", text: $name)
                .textContentType(.name)

            TextField("Hostname or IP", text: $hostname)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            HStack {
                Text("Port")
                Spacer()
                TextField("22", text: $port)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Username", text: $username)
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    private var authSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $authMethod) {
                ForEach(AuthMethod.allCases) { method in
                    Label(method.displayName, systemImage: method.iconName)
                        .tag(method)
                }
            }

            switch authMethod {
            case .password:
                SecureField("Password", text: $password)
                    .textContentType(.password)

                Toggle("Save Password", isOn: $savePassword)
            case .publicKey:
                NavigationLink("Select Key") {
                    KeySelectionView()
                }
            case .certificate:
                NavigationLink("Select Certificate") {
                    KeySelectionView()
                }
            }
        }
    }

    private var advancedSection: some View {
        Group {
            Section("Organization") {
                TextField("Group (optional)", text: $group)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Terminal") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    TextField("14", text: $fontSize)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

            Section("Connection") {
                HStack {
                    Text("Keep Alive (seconds)")
                    Spacer()
                    TextField("60", text: $keepAliveInterval)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }
        }
    }

    private var toggleAdvanced: some View {
        Section {
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text(showAdvanced ? "Hide Advanced" : "Show Advanced")
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                }
            }
        }
    }

    // MARK: - Validation & Save

    private var isValid: Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(port) ?? 0) > 0 && (Int(port) ?? 0) <= 65535
    }

    private func saveHost() {
        let displayName = name.isEmpty ? hostname : name
        let host = Host(
            name: displayName,
            hostname: hostname.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespaces),
            authMethod: authMethod,
            group: group.isEmpty ? nil : group,
            fontSize: Int(fontSize) ?? 14,
            keepAliveInterval: Int(keepAliveInterval) ?? 60,
            notes: notes.isEmpty ? nil : notes
        )

        modelContext.insert(host)

        // Save password to Keychain
        if authMethod == .password && savePassword && !password.isEmpty {
            try? KeychainHelper.savePassword(password, for: host.id.uuidString)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Key Selection (placeholder)

struct KeySelectionView: View {
    @Query(sort: \SSHKeyPair.createdAt, order: .reverse) private var keys: [SSHKeyPair]
    @State private var showGenerateKey = false

    var body: some View {
        List {
            if keys.isEmpty {
                ContentUnavailableView {
                    Label("No Keys", systemImage: "key")
                } description: {
                    Text("Generate or import an SSH key pair.")
                } actions: {
                    Button("Generate Key") {
                        showGenerateKey = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(keys) { key in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(key.name)
                                .font(.headline)
                            Text(key.keyType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if key.isDefault {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("SSH Keys")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGenerateKey = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showGenerateKey) {
            GenerateKeyView()
        }
    }
}
