import Foundation
import SwiftData

/// Records terminal session output for later review and search.
@MainActor
final class SessionLogger: ObservableObject {
    @Published var isLogging: Bool = false

    private var activeLog: SessionLog?
    private var writeBuffer = Data()
    private var flushTimer: Timer?
    private var modelContext: ModelContext?

    /// Maximum log size per session (10 MB default).
    var maxLogSize: Int = 10 * 1024 * 1024

    func startLogging(
        hostName: String,
        hostname: String,
        username: String,
        isMosh: Bool = false,
        modelContext: ModelContext
    ) {
        let log = SessionLog(
            hostName: hostName,
            hostname: hostname,
            username: username,
            isMoshSession: isMosh
        )
        modelContext.insert(log)
        self.activeLog = log
        self.modelContext = modelContext
        self.isLogging = true

        // Flush buffer to disk periodically
        flushTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushBuffer()
            }
        }
    }

    func appendData(_ data: Data) {
        guard isLogging, activeLog != nil else { return }
        guard writeBuffer.count + data.count < maxLogSize else {
            // Reached limit — stop appending but keep logging metadata
            return
        }
        writeBuffer.append(data)
    }

    func stopLogging() {
        flushBuffer()
        flushTimer?.invalidate()
        flushTimer = nil
        activeLog?.finalize()
        try? modelContext?.save()
        activeLog = nil
        modelContext = nil
        isLogging = false
    }

    private func flushBuffer() {
        guard !writeBuffer.isEmpty, let log = activeLog else { return }
        log.logData.append(writeBuffer)
        log.byteCount = log.logData.count
        log.durationSeconds = Int(Date().timeIntervalSince(log.startedAt))
        writeBuffer.removeAll(keepingCapacity: true)
        try? modelContext?.save()
    }

    /// Search across all session logs for a given query string.
    static func search(
        query: String,
        in modelContext: ModelContext
    ) -> [SessionLog] {
        let descriptor = FetchDescriptor<SessionLog>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return [] }

        if query.isEmpty { return logs }

        return logs.filter { log in
            log.hostName.localizedCaseInsensitiveContains(query) ||
            log.hostname.localizedCaseInsensitiveContains(query) ||
            log.plainText.localizedCaseInsensitiveContains(query)
        }
    }

    /// Exports a session log as plain text.
    static func exportLog(_ log: SessionLog) -> String {
        var output = ""
        output += "Session Log: \(log.hostName)\n"
        output += "Host: \(log.username)@\(log.hostname)\n"
        output += "Started: \(log.startedAt.formatted())\n"
        if let ended = log.endedAt {
            output += "Ended: \(ended.formatted())\n"
        }
        output += "Duration: \(log.displayDuration)\n"
        output += "Size: \(log.displaySize)\n"
        output += String(repeating: "─", count: 60) + "\n"
        output += log.plainText
        return output
    }
}
