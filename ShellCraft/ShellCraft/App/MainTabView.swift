import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var terminalViewModel: TerminalViewModel
    @State private var selectedTab: Tab = .hosts
    @State private var showSettings = false

    enum Tab: String {
        case hosts
        case terminal
        case snippets
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Hosts Tab
            HostListView()
                .tabItem {
                    Label("Hosts", systemImage: "server.rack")
                }
                .tag(Tab.hosts)

            // Terminal Tab
            TerminalContainerView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal.fill")
                }
                .tag(Tab.terminal)
                .badge(terminalViewModel.tabs.count > 0 ? terminalViewModel.tabs.count : 0)

            // Snippets Tab
            SnippetsView()
                .tabItem {
                    Label("Snippets", systemImage: "text.word.spacing")
                }
                .tag(Tab.snippets)
        }
        .onChange(of: terminalViewModel.tabs.count) { oldValue, newValue in
            // Auto-switch to terminal when a new connection is made
            if newValue > oldValue {
                selectedTab = .terminal
            }
            // Switch back to hosts when all sessions are closed
            if newValue == 0 && selectedTab == .terminal {
                selectedTab = .hosts
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // Keyboard shortcuts for external keyboards
        .keyboardShortcut("t", modifiers: .command) // Cmd+T: New Tab
        .keyboardShortcut("w", modifiers: .command) // Cmd+W: Close Tab
        .keyboardShortcut(",", modifiers: .command) // Cmd+,: Settings
    }
}

// MARK: - Snippets View (Phase 1 placeholder)

struct SnippetsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSnippet = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Snippets", systemImage: "text.word.spacing")
            } description: {
                Text("Save frequently used commands for quick access.")
            } actions: {
                Button("Add Snippet") {
                    showAddSnippet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Snippets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSnippet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSnippet) {
                AddSnippetView()
            }
        }
    }
}

struct AddSnippetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var category = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Snippet") {
                    TextField("Title", text: $title)
                    TextField("Command", text: $command, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3...10)
                }

                Section("Organization") {
                    TextField("Category (optional)", text: $category)
                }
            }
            .navigationTitle("New Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let snippet = Snippet(
                            title: title,
                            command: command,
                            category: category.isEmpty ? nil : category
                        )
                        modelContext.insert(snippet)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty || command.isEmpty)
                }
            }
        }
    }
}
