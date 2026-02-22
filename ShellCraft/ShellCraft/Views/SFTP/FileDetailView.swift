import SwiftUI

struct FileDetailView: View {
    let file: SFTPFileEntry
    @ObservedObject var sftpClient: SFTPClient
    @Environment(\.dismiss) private var dismiss

    @State private var fileContent: String?
    @State private var fileInfo: String?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showEditMode = false
    @State private var editedContent = ""

    private var isTextFile: Bool {
        let textExtensions = Set([
            "txt", "md", "log", "conf", "cfg", "ini", "env",
            "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "hpp",
            "java", "kt", "rb", "php", "pl", "lua", "sh", "bash", "zsh",
            "json", "xml", "yaml", "yml", "toml", "csv",
            "html", "css", "scss", "less",
            "sql", "graphql", "proto",
            "dockerfile", "makefile", "cmake",
            "gitignore", "gitattributes", "editorconfig",
        ])
        let ext = (file.name as NSString).pathExtension.lowercased()
        let nameOnly = file.name.lowercased()
        return textExtensions.contains(ext)
            || nameOnly.hasPrefix(".")
            || ["Makefile", "Dockerfile", "Vagrantfile", "Gemfile", "Rakefile", "LICENSE", "README"]
                .contains(where: { nameOnly.caseInsensitiveCompare($0) == .orderedSame })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if showEditMode {
                    editorView
                } else {
                    contentView
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if isTextFile && fileContent != nil && !showEditMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editedContent = fileContent ?? ""
                            showEditMode = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }

                if showEditMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveFile()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await loadContent()
            }
        }
    }

    // MARK: - Content Views

    private var contentView: some View {
        List {
            // File Info Section
            Section("Info") {
                LabeledContent("Name", value: file.name)
                LabeledContent("Path", value: file.path)
                LabeledContent("Size", value: file.displaySize)
                LabeledContent("Permissions", value: file.permissionsString)
                LabeledContent("Owner", value: "\(file.owner):\(file.group)")
            }

            // Content Section (for text files)
            if let content = fileContent {
                Section("Content") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(content)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: 400)

                    HStack {
                        Text("\(content.components(separatedBy: "\n").count) lines")
                        Spacer()
                        Text("\(content.count) chars")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Stat Info
            if let info = fileInfo {
                Section("Details") {
                    Text(info)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            // Actions
            Section {
                Button {
                    UIPasteboard.general.string = file.path
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                if let content = fileContent {
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Label("Copy Content", systemImage: "doc.on.clipboard")
                    }
                }
            }
        }
    }

    private var editorView: some View {
        TextEditor(text: $editedContent)
            .font(.system(size: 13, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func loadContent() async {
        isLoading = true

        do {
            fileInfo = try await sftpClient.fileInfo(file.path)

            if isTextFile {
                fileContent = try await sftpClient.readFile(file.path)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func saveFile() {
        Task {
            do {
                try await sftpClient.writeFile(file.path, content: editedContent)
                showEditMode = false
                fileContent = editedContent
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
