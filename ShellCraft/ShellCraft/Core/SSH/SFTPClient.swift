import Foundation
import NIO
import NIOSSH

/// Represents a remote file or directory entry
struct SFTPFileEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64
    let permissions: UInt32
    let modifiedAt: Date
    let owner: String
    let group: String

    var displaySize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var permissionsString: String {
        var result = isDirectory ? "d" : "-"
        let perms = [(permissions >> 6) & 7, (permissions >> 3) & 7, permissions & 7]
        for perm in perms {
            result += (perm & 4) != 0 ? "r" : "-"
            result += (perm & 2) != 0 ? "w" : "-"
            result += (perm & 1) != 0 ? "x" : "-"
        }
        return result
    }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log": return "doc.text.fill"
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "java", "kt":
            return "doc.text.fill"
        case "json", "xml", "yaml", "yml", "toml": return "doc.badge.gearshape.fill"
        case "sh", "bash", "zsh": return "terminal.fill"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo.fill"
        case "zip", "tar", "gz", "bz2", "xz", "7z": return "doc.zipper"
        case "pdf": return "doc.richtext.fill"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        default: return "doc.fill"
        }
    }

    var iconColor: SwiftUI.Color {
        if isDirectory { return .blue }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "py": return .green
        case "js", "ts": return .yellow
        case "sh", "bash", "zsh": return .purple
        case "json", "xml", "yaml", "yml": return .pink
        case "png", "jpg", "jpeg", "gif", "svg": return .cyan
        case "zip", "tar", "gz": return .gray
        default: return .secondary
        }
    }
}

import SwiftUI

/// SFTP client that executes remote file operations over an SSH exec channel.
/// Uses standard Unix commands since SwiftNIO SSH does not include SFTP subsystem.
@MainActor
final class SFTPClient: ObservableObject {
    private let session: SSHSession
    @Published var currentPath: String = "~"
    @Published var entries: [SFTPFileEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var pathHistory: [String] = []

    init(session: SSHSession) {
        self.session = session
    }

    /// List files in a directory using ls -la
    func listDirectory(_ path: String? = nil) async {
        let targetPath = path ?? currentPath
        isLoading = true
        error = nil

        do {
            // Use stat-format output for reliable parsing
            let command = """
            cd \(escapeShellArg(targetPath)) && pwd && ls -la --time-style=long-iso 2>/dev/null || ls -la \(escapeShellArg(targetPath)) 2>&1
            """
            let output = try await executeCommand(command)
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            guard !lines.isEmpty else {
                entries = []
                isLoading = false
                return
            }

            // First line from pwd is the resolved path
            var resolvedPath = targetPath
            var startIndex = 0
            if lines[0].hasPrefix("/") && !lines[0].contains(" ") {
                resolvedPath = lines[0]
                startIndex = 1
            }

            var parsedEntries: [SFTPFileEntry] = []

            for i in startIndex..<lines.count {
                let line = lines[i]
                // Skip "total N" line
                if line.hasPrefix("total ") { continue }

                if let entry = parseLsLine(line, parentPath: resolvedPath) {
                    // Skip . and ..
                    if entry.name == "." || entry.name == ".." { continue }
                    parsedEntries.append(entry)
                }
            }

            // Sort: directories first, then alphabetically
            parsedEntries.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            if targetPath != currentPath {
                pathHistory.append(currentPath)
            }
            currentPath = resolvedPath
            entries = parsedEntries
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Navigate to parent directory
    func goUp() async {
        let parent = (currentPath as NSString).deletingLastPathComponent
        if !parent.isEmpty {
            await listDirectory(parent)
        }
    }

    /// Go back in navigation history
    func goBack() async {
        guard let previous = pathHistory.popLast() else { return }
        await listDirectory(previous)
    }

    /// Read a text file's contents
    func readFile(_ path: String, maxBytes: Int = 1_000_000) async throws -> String {
        let command = "head -c \(maxBytes) \(escapeShellArg(path))"
        return try await executeCommand(command)
    }

    /// Get file info (stat)
    func fileInfo(_ path: String) async throws -> String {
        let command = "stat \(escapeShellArg(path)) 2>&1"
        return try await executeCommand(command)
    }

    /// Delete a file or directory
    func delete(_ path: String, isDirectory: Bool) async throws {
        let command = isDirectory
            ? "rm -rf \(escapeShellArg(path))"
            : "rm -f \(escapeShellArg(path))"
        _ = try await executeCommand(command)
        await listDirectory()
    }

    /// Create a directory
    func createDirectory(_ name: String) async throws {
        let path = (currentPath as NSString).appendingPathComponent(name)
        let command = "mkdir -p \(escapeShellArg(path))"
        _ = try await executeCommand(command)
        await listDirectory()
    }

    /// Rename a file or directory
    func rename(from oldPath: String, to newName: String) async throws {
        let dir = (oldPath as NSString).deletingLastPathComponent
        let newPath = (dir as NSString).appendingPathComponent(newName)
        let command = "mv \(escapeShellArg(oldPath)) \(escapeShellArg(newPath))"
        _ = try await executeCommand(command)
        await listDirectory()
    }

    /// Change file permissions
    func chmod(_ path: String, permissions: String) async throws {
        let command = "chmod \(permissions) \(escapeShellArg(path))"
        _ = try await executeCommand(command)
        await listDirectory()
    }

    /// Get disk usage info
    func diskUsage() async throws -> String {
        return try await executeCommand("df -h \(escapeShellArg(currentPath))")
    }

    // MARK: - Private

    private func executeCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let channel = try await session.connection.createExecChannel(command: command)

                    if let handler = try? await channel.pipeline.handler(type: SSHExecHandler.self).get() {
                        handler.onComplete = { data in
                            let output = String(data: data, encoding: .utf8) ?? ""
                            continuation.resume(returning: output)
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func escapeShellArg(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Parse a single line of `ls -la` output
    private func parseLsLine(_ line: String, parentPath: String) -> SFTPFileEntry? {
        // Format: drwxr-xr-x 2 user group 4096 2025-01-15 10:30 filename
        // Or:     -rw-r--r-- 1 user group 1234 Jan 15 10:30 filename
        let parts = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
        guard parts.count >= 8 else { return nil }

        let permStr = String(parts[0])
        guard permStr.count >= 10 else { return nil }

        let isDirectory = permStr.hasPrefix("d")
        let owner = String(parts[2])
        let group = String(parts[3])
        let size = UInt64(parts[4]) ?? 0

        // Parse permissions from string
        let permissions = parsePermissions(permStr)

        // Filename is the last part (may contain spaces)
        let name: String
        if parts.count > 8 {
            name = String(parts[8...].joined(separator: " "))
        } else {
            name = String(parts[7])
        }

        // Remove symlink target (name -> target)
        let cleanName = name.components(separatedBy: " -> ").first ?? name

        let path = parentPath == "/" ? "/\(cleanName)" : "\(parentPath)/\(cleanName)"

        return SFTPFileEntry(
            name: cleanName,
            path: path,
            isDirectory: isDirectory,
            size: size,
            permissions: permissions,
            modifiedAt: Date(), // Simplified; full date parsing could be added
            owner: owner,
            group: group
        )
    }

    private func parsePermissions(_ str: String) -> UInt32 {
        guard str.count >= 10 else { return 0 }
        let chars = Array(str)
        var perm: UInt32 = 0

        // Owner
        if chars[1] == "r" { perm |= 0o400 }
        if chars[2] == "w" { perm |= 0o200 }
        if chars[3] == "x" || chars[3] == "s" { perm |= 0o100 }

        // Group
        if chars[4] == "r" { perm |= 0o040 }
        if chars[5] == "w" { perm |= 0o020 }
        if chars[6] == "x" || chars[6] == "s" { perm |= 0o010 }

        // Other
        if chars[7] == "r" { perm |= 0o004 }
        if chars[8] == "w" { perm |= 0o002 }
        if chars[9] == "x" || chars[9] == "t" { perm |= 0o001 }

        return perm
    }
}
