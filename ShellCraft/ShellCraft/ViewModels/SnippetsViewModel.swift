import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SnippetsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: String?

    /// Execute a snippet in the active terminal session
    func executeSnippet(_ snippet: Snippet, in session: SSHSession?, context: ModelContext) {
        guard let session = session else { return }

        let command = resolveVariables(snippet.command, for: session)
        session.sendText(command + "\n")

        // Update usage count
        snippet.usageCount += 1
        snippet.updatedAt = Date()
        try? context.save()
    }

    /// Resolve template variables in snippet commands
    private func resolveVariables(_ command: String, for session: SSHSession) -> String {
        var result = command
        result = result.replacingOccurrences(of: "${HOST}", with: session.host.hostname)
        result = result.replacingOccurrences(of: "${USER}", with: session.host.username)
        result = result.replacingOccurrences(of: "${PORT}", with: String(session.host.port))
        result = result.replacingOccurrences(of: "${NAME}", with: session.host.name)
        result = result.replacingOccurrences(of: "${DATE}", with: ISO8601DateFormatter().string(from: Date()))
        return result
    }

    func filteredSnippets(_ snippets: [Snippet]) -> [Snippet] {
        var result = snippets

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.command.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { $0.usageCount > $1.usageCount }
    }

    func categories(from snippets: [Snippet]) -> [String] {
        let cats = Set(snippets.compactMap(\.category))
        return cats.sorted()
    }
}
