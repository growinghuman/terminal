import SwiftUI

struct TerminalContainerView: View {
    @EnvironmentObject var terminalViewModel: TerminalViewModel
    @State private var showHostList = false

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
                    TerminalWrapperView(terminalManager: activeTab.terminalManager)
                        .id(activeTab.id)

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
}
