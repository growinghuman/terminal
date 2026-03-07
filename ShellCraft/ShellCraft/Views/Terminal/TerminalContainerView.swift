import SwiftUI

struct TerminalContainerView: View {
    @EnvironmentObject var terminalViewModel: TerminalViewModel
    @State private var showHostList = false
    @State private var showSFTP = false
    @State private var showPortForwarding = false
    @StateObject private var portForwardingManager = PortForwardingManager()
    @ObservedObject private var externalDisplayManager = ExternalDisplayManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if terminalViewModel.isConnecting {
                connectingOverlay
            }

            if terminalViewModel.tabs.isEmpty && !terminalViewModel.isConnecting {
                noSessionView
            } else if !terminalViewModel.tabs.isEmpty {
                // Tab Bar
                TerminalTabBar(
                    tabs: terminalViewModel.tabs,
                    activeTabID: terminalViewModel.activeTabID,
                    onSelect: { terminalViewModel.switchToTab($0) },
                    onClose: { tabID in
                        Task { await terminalViewModel.closeTab(tabID) }
                    },
                    onAddNew: { showHostList = true }
                )

                // Active Terminal
                if let activeTab = terminalViewModel.activeTab {
                    ZStack(alignment: .topTrailing) {
                        TerminalWrapperView(terminalManager: activeTab.terminalManager)
                            .id(activeTab.id)

                        // Session action buttons + Mosh indicator
                        VStack(alignment: .trailing, spacing: 8) {
                            if activeTab.isMosh, let moshSession = activeTab.moshSession {
                                moshStatusBadge(moshSession)
                            }
                            sessionToolbar(tab: activeTab)
                        }
                    }

                    VirtualKeyboardBar(
                        onKey: { key in
                            activeTab.sendText(key)
                        }
                    )
                }
            }

            // External display indicator
            if externalDisplayManager.isExternalDisplayConnected {
                externalDisplayBanner
            }
        }
        .sheet(isPresented: $showHostList) {
            HostListView()
        }
        .sheet(isPresented: $showSFTP) {
            if let session = terminalViewModel.activeTab?.session {
                SFTPBrowserView(sftpClient: SFTPClient(session: session))
            }
        }
        .sheet(isPresented: $showPortForwarding) {
            NavigationStack {
                PortForwardingView(forwardingManager: portForwardingManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPortForwarding = false }
                        }
                    }
            }
        }
        .alert("Connection Error",
               isPresented: $terminalViewModel.showConnectionError) {
            Button("OK") {}
        } message: {
            Text(terminalViewModel.connectionError ?? "Unknown error")
        }
    }

    // MARK: - Subviews

    private var connectingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: terminalViewModel.tabs.isEmpty ? .infinity : 0)
        .background(terminalViewModel.tabs.isEmpty ? Color(.systemBackground) : .clear)
    }

    private var noSessionView: some View {
        ContentUnavailableView {
            Label("No Active Sessions", systemImage: "terminal")
        } description: {
            Text("Connect to a host to start a terminal session.")
        } actions: {
            Button("Browse Hosts") {
                showHostList = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func moshStatusBadge(_ moshSession: MoshSession) -> some View {
        HStack(spacing: 4) {
            Image(systemName: moshSession.connectionQuality.iconName)
                .font(.caption2)
            Text("Mosh")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(moshSession.isActive ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
        .foregroundStyle(moshSession.isActive ? .green : .orange)
        .clipShape(Capsule())
        .padding(.trailing, 12)
        .padding(.top, 8)
    }

    private func sessionToolbar(tab: TerminalTab) -> some View {
        HStack(spacing: 8) {
            // SFTP only available for SSH sessions
            if tab.session != nil {
                Button {
                    showSFTP = true
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("SFTP File Browser")

                Button {
                    showPortForwarding = true
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Port Forwarding")
            }

            Menu {
                Button {
                    UIPasteboard.general.string = tab.host.displayAddress
                } label: {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }

                if externalDisplayManager.isExternalDisplayConnected {
                    Button {
                        // Mirror terminal to external display
                    } label: {
                        Label("Show on External Display", systemImage: "rectangle.on.rectangle")
                    }
                }

                Divider()

                Button {
                    Task { await terminalViewModel.closeTab(tab.id) }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(12)
    }

    private var externalDisplayBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.caption)
            Text("External display connected (\(Int(externalDisplayManager.externalScreenBounds.width))x\(Int(externalDisplayManager.externalScreenBounds.height)))")
                .font(.caption)
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
    }
}
