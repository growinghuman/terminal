import SwiftUI
import SwiftData

struct SessionLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionLog.startedAt, order: .reverse) private var logs: [SessionLog]
    @State private var searchText = ""
    @State private var selectedLog: SessionLog?
    @State private var showExportSheet = false
    @State private var exportText = ""

    var body: some View {
        List {
            if filteredLogs.isEmpty {
                ContentUnavailableView {
                    Label("No Session Logs", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Session logs will appear here when logging is enabled in Settings.")
                }
            } else {
                ForEach(filteredLogs) { log in
                    NavigationLink {
                        SessionLogDetailView(log: log)
                    } label: {
                        logRow(log)
                    }
                }
                .onDelete(perform: deleteLogs)
            }
        }
        .navigationTitle("Session Logs")
        .searchable(text: $searchText, prompt: "Search logs")
    }

    private var filteredLogs: [SessionLog] {
        if searchText.isEmpty { return logs }
        return logs.filter {
            $0.hostName.localizedCaseInsensitiveContains(searchText) ||
            $0.hostname.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func logRow(_ log: SessionLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.hostName)
                    .font(.headline)

                if log.isMoshSession {
                    Text("Mosh")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(log.displaySize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(log.username)@\(log.hostname)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(log.displayDuration)
                    .font(.caption)

                Spacer()

                Text(log.startedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredLogs[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Detail View

struct SessionLogDetailView: View {
    let log: SessionLog
    @State private var showExport = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                GroupBox("Session Info") {
                    VStack(spacing: 8) {
                        infoRow("Host", value: log.hostName)
                        infoRow("Address", value: "\(log.username)@\(log.hostname)")
                        infoRow("Started", value: log.startedAt.formatted(date: .abbreviated, time: .standard))
                        if let ended = log.endedAt {
                            infoRow("Ended", value: ended.formatted(date: .abbreviated, time: .standard))
                        }
                        infoRow("Duration", value: log.displayDuration)
                        infoRow("Size", value: log.displaySize)
                        if log.isMoshSession {
                            infoRow("Protocol", value: "Mosh")
                        }
                    }
                }

                // Log content
                GroupBox("Terminal Output") {
                    let text = displayText
                    if text.isEmpty {
                        Text("No output recorded.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView(.horizontal) {
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(log.hostName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExport) {
            let exportedText = SessionLogger.exportLog(log)
            let safeName = log.hostName.replacingOccurrences(of: "/", with: "_")
            let timestamp = Int(log.startedAt.timeIntervalSince1970)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)_\(timestamp).log")
            let _ = try? exportedText.data(using: .utf8)?.write(to: tempURL)
            ShareSheet(items: [tempURL])
        }
    }

    private var displayText: String {
        let plain = log.plainText
        if searchText.isEmpty { return plain }
        return plain // Full text; search highlighting handled by native TextEditor search
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
