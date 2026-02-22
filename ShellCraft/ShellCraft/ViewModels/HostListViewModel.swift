import Foundation
import SwiftData
import SwiftUI

@MainActor
final class HostListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedGroup: String?
    @Published var isAddingHost: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    var filteredHosts: (allHosts: [Host]) -> [Host] {
        { hosts in
            var result = hosts

            if let group = self.selectedGroup {
                result = result.filter { $0.group == group }
            }

            if !self.searchText.isEmpty {
                result = result.filter {
                    $0.name.localizedCaseInsensitiveContains(self.searchText) ||
                    $0.hostname.localizedCaseInsensitiveContains(self.searchText) ||
                    $0.username.localizedCaseInsensitiveContains(self.searchText)
                }
            }

            return result.sorted { ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast) }
        }
    }

    func groups(from hosts: [Host]) -> [String] {
        let groups = Set(hosts.compactMap { $0.group })
        return groups.sorted()
    }

    func deleteHosts(_ hosts: [Host], context: ModelContext) {
        for host in hosts {
            // Clean up stored passwords
            try? KeychainHelper.deletePassword(for: host.id.uuidString)
            context.delete(host)
        }
        try? context.save()
    }

    func toggleFavorite(_ host: Host, context: ModelContext) {
        host.isFavorite.toggle()
        host.updatedAt = Date()
        try? context.save()
    }

    func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
