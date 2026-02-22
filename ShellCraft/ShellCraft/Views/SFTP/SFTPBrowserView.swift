import SwiftUI

struct SFTPBrowserView: View {
    @StateObject var sftpClient: SFTPClient
    @State private var searchText = ""
    @State private var showCreateDir = false
    @State private var newDirName = ""
    @State private var selectedFile: SFTPFileEntry?
    @State private var showFileDetail = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var fileToRename: SFTPFileEntry?
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: SFTPFileEntry?
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case modified = "Modified"
    }

    var filteredEntries: [SFTPFileEntry] {
        var result = sftpClient.entries
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .name:
            break // Already sorted by name
        case .size:
            result.sort { $0.size > $1.size }
        case .modified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Path breadcrumb
                pathBreadcrumb

                // File list
                if sftpClient.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = sftpClient.error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await sftpClient.listDirectory() }
                        }
                    }
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView {
                        Label("Empty Directory", systemImage: "folder")
                    } description: {
                        Text("This directory is empty.")
                    }
                } else {
                    fileList
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search files")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateDir = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }

                        Divider()

                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }

                        Divider()

                        Button {
                            Task { await sftpClient.listDirectory() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await sftpClient.goUp() }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(sftpClient.currentPath == "/")
                }
            }
            .alert("New Folder", isPresented: $showCreateDir) {
                TextField("Folder name", text: $newDirName)
                Button("Create") {
                    Task {
                        try? await sftpClient.createDirectory(newDirName)
                        newDirName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newDirName = "" }
            }
            .alert("Rename", isPresented: $showRenameAlert) {
                TextField("New name", text: $renameText)
                Button("Rename") {
                    if let file = fileToRename {
                        Task {
                            try? await sftpClient.rename(from: file.path, to: renameText)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete {
                        Task {
                            try? await sftpClient.delete(file.path, isDirectory: file.isDirectory)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let file = fileToDelete {
                    Text("Delete \"\(file.name)\"? This cannot be undone.")
                }
            }
            .sheet(isPresented: $showFileDetail) {
                if let file = selectedFile {
                    FileDetailView(file: file, sftpClient: sftpClient)
                }
            }
            .task {
                await sftpClient.listDirectory()
            }
        }
    }

    // MARK: - Subviews

    private var pathBreadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let components = sftpClient.currentPath.split(separator: "/")
                Button("/") {
                    Task { await sftpClient.listDirectory("/") }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

                ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)

                    let path = "/" + components[0...index].joined(separator: "/")
                    Button(String(component)) {
                        Task { await sftpClient.listDirectory(path) }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(index == components.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var fileList: some View {
        List(filteredEntries) { entry in
            fileRow(entry)
                .contentShape(Rectangle())
                .onTapGesture {
                    if entry.isDirectory {
                        Task { await sftpClient.listDirectory(entry.path) }
                    } else {
                        selectedFile = entry
                        showFileDetail = true
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        fileToDelete = entry
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        fileToRename = entry
                        renameText = entry.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    if entry.isDirectory {
                        Button {
                            Task { await sftpClient.listDirectory(entry.path) }
                        } label: {
                            Label("Open", systemImage: "folder")
                        }
                    } else {
                        Button {
                            selectedFile = entry
                            showFileDetail = true
                        } label: {
                            Label("View", systemImage: "eye")
                        }
                    }

                    Button {
                        UIPasteboard.general.string = entry.path
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    Button {
                        fileToRename = entry
                        renameText = entry.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        fileToDelete = entry
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.plain)
    }

    private func fileRow(_ entry: SFTPFileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.iconName)
                .foregroundStyle(entry.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.permissionsString)
                        .font(.system(size: 10, design: .monospaced))
                    Text(entry.displaySize)
                        .font(.caption2)
                    Text(entry.owner)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
