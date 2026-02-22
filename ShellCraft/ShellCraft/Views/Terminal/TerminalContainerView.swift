import SwiftUI

struct TerminalContainerView: View {
    @EnvironmentObject var terminalViewModel: TerminalViewModel
    @State private var showHostList = false
    @State private var showSFTP = false
    @State private var showPortForwarding = false
    @StateObject private var portForwardingManager = PortForwardingManager()

    var body: some View {
        VStack(spacing: 0) {
            if terminalViewModel.tabs.isEmpty {
                noSessionView
            } else {
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

                        // Session action buttons
                        sessionToolbar(session: activeTab.session)
                    }

                    VirtualKeyboardBar(
                        onKey: { key in
                            activeTab.session.sendText(key)
                        }
                    )
                }
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

    private func sessionToolbar(session: SSHSession) -> some View {
        HStack(spacing: 8) {
            Button {
                showSFTP = true
            } label: {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Button {
                showPortForwarding = true
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14))
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Menu {
                Button {
                    UIPasteboard.general.string = session.host.displayAddress
                } label: {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }

                Button {
                    Task { await session.disconnect() }
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
}
