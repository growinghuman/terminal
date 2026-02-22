import SwiftUI
import SwiftData

struct HostListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Host.updatedAt, order: .reverse) private var hosts: [Host]

    @StateObject private var viewModel = HostListViewModel()
    @EnvironmentObject var terminalViewModel: TerminalViewModel

    @State private var showingAddHost = false
    @State private var selectedHost: Host?
    @State private var showingPasswordPrompt = false
    @State private var passwordInput = ""

    var body: some View {
        NavigationStack {
            Group {
                if hosts.isEmpty {
                    emptyState
                } else {
                    hostList
                }
            }
            .navigationTitle("ShellCraft")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddHost = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if !terminalViewModel.tabs.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            // Switch to terminal view
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                Text("\(terminalViewModel.tabs.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search hosts")
            .sheet(isPresented: $showingAddHost) {
                AddHostView()
            }
            .alert("Enter Password", isPresented: $showingPasswordPrompt) {
                SecureField("Password", text: $passwordInput)
                Button("Connect") {
                    if let host = selectedHost {
                        connectToHost(host, password: passwordInput, mosh: connectWithMosh)
                        passwordInput = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    passwordInput = ""
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Hosts", systemImage: "server.rack")
        } description: {
            Text("Add your first SSH server to get started.")
        } actions: {
            Button("Add Host") {
                showingAddHost = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var hostList: some View {
        List {
            // Favorites Section
            let favorites = viewModel.filteredHosts(hosts).filter(\.isFavorite)
            if !favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favorites) { host in
                        hostRow(host)
                    }
                }
            }

            // Groups
            let groups = viewModel.groups(from: hosts)
            if !groups.isEmpty {
                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        let groupHosts = viewModel.filteredHosts(hosts).filter { $0.group == group && !$0.isFavorite }
                        ForEach(groupHosts) { host in
                            hostRow(host)
                        }
                    }
                }
            }

            // Ungrouped
            let ungrouped = viewModel.filteredHosts(hosts).filter { $0.group == nil && !$0.isFavorite }
            if !ungrouped.isEmpty {
                Section(groups.isEmpty ? "All Hosts" : "Other") {
                    ForEach(ungrouped) { host in
                        hostRow(host)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func hostRow(_ host: Host) -> some View {
        Button {
            initiateConnection(to: host)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: host.authMethod.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(host.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(host.displayAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lastConnected = host.lastConnectedAt {
                    Text(lastConnected, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteHosts([host], context: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.toggleFavorite(host, context: modelContext)
            } label: {
                Label(
                    host.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: host.isFavorite ? "star.slash" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .contextMenu {
            Button {
                initiateConnection(to: host)
            } label: {
                Label("Connect (SSH)", systemImage: "bolt.fill")
            }

            Button {
                initiateConnection(to: host, useMosh: true)
            } label: {
                Label("Connect (Mosh)", systemImage: "arrow.triangle.2.circlepath")
            }

            NavigationLink {
                HostDetailView(host: host)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                viewModel.toggleFavorite(host, context: modelContext)
            } label: {
                Label(
                    host.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: host.isFavorite ? "star.slash" : "star.fill"
                )
            }

            Divider()

            Button {
                UIPasteboard.general.string = host.displayAddress
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteHosts([host], context: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    @State private var connectWithMosh = false

    private func initiateConnection(to host: Host, useMosh: Bool = false) {
        selectedHost = host
        connectWithMosh = useMosh

        switch host.authMethod {
        case .password:
            if let storedPassword = try? KeychainHelper.getPassword(for: host.id.uuidString) {
                connectToHost(host, password: storedPassword, mosh: useMosh)
            } else {
                showingPasswordPrompt = true
            }
        case .publicKey, .certificate:
            connectToHost(host, mosh: useMosh)
        }
    }

    private func connectToHost(_ host: Host, password: String? = nil, mosh: Bool = false) {
        Task {
            if mosh {
                await terminalViewModel.openMoshConnection(
                    host: host,
                    password: password,
                    modelContext: modelContext
                )
            } else {
                await terminalViewModel.openConnection(
                    host: host,
                    password: password,
                    modelContext: modelContext
                )
            }
        }
    }
}
