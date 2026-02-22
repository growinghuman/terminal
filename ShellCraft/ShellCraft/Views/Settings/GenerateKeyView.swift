import SwiftUI
import SwiftData

struct GenerateKeyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var keyType: SSHKeyType = .ed25519
    @State private var comment = ""
    @State private var isGenerating = false
    @State private var generatedPublicKey: String?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Key Details") {
                    TextField("Key Name", text: $keyName)

                    Picker("Key Type", selection: $keyType) {
                        ForEach(SSHKeyType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Comment (optional)", text: $comment)
                        .textContentType(.none)
                }

                Section {
                    HStack {
                        Text("Bits")
                        Spacer()
                        Text("\(keyType.bitSize)")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Ed25519 is recommended for its security and performance.")
                }

                if let publicKey = generatedPublicKey {
                    Section("Public Key") {
                        Text(publicKey)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(5)
                            .textSelection(.enabled)

                        Button {
                            UIPasteboard.general.string = publicKey
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Generate SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if generatedPublicKey != nil {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Generate") { generateKey() }
                            .disabled(keyName.isEmpty || isGenerating)
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .overlay {
                if isGenerating {
                    ProgressView("Generating key...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func generateKey() {
        isGenerating = true

        Task {
            do {
                let result = try KeyManager.shared.generateKeyPair(
                    type: keyType,
                    comment: comment.isEmpty ? nil : comment
                )

                let keyPair = SSHKeyPair(
                    name: keyName,
                    keyType: keyType,
                    publicKeyData: result.publicKey,
                    privateKeyKeychainID: result.privateKeychainID,
                    comment: comment.isEmpty ? nil : comment
                )

                modelContext.insert(keyPair)
                try? modelContext.save()

                generatedPublicKey = KeyManager.shared.exportPublicKeyOpenSSH(
                    publicKeyData: result.publicKey,
                    type: keyType,
                    comment: comment
                )

                isGenerating = false
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
