import Foundation
import SwiftData

@Model
final class SessionLog {
    var id: UUID
    var hostName: String
    var hostname: String
    var username: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var logData: Data
    var byteCount: Int
    var isMoshSession: Bool

    init(
        hostName: String,
        hostname: String,
        username: String,
        isMoshSession: Bool = false
    ) {
        self.id = UUID()
        self.hostName = hostName
        self.hostname = hostname
        self.username = username
        self.startedAt = Date()
        self.durationSeconds = 0
        self.logData = Data()
        self.byteCount = 0
        self.isMoshSession = isMoshSession
    }

    var displayDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    var displaySize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }

    /// Returns the log text, stripping ANSI escape codes for readability.
    var plainText: String {
        guard let raw = String(data: logData, encoding: .utf8) else { return "" }
        // Strip ANSI escape sequences: ESC [ ... (letter)
        let pattern = "\u{1B}\\[[0-9;]*[a-zA-Z]"
        return raw.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    func finalize() {
        endedAt = Date()
        durationSeconds = Int(Date().timeIntervalSince(startedAt))
    }
}
