import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var terminalViewModel: TerminalViewModel
    @State private var selectedTab: Tab = .hosts
    @State private var showSettings = false
    @State private var showQuickConnect = false

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
            SnippetsListView()
                .tabItem {
                    Label("Snippets", systemImage: "text.word.spacing")
                }
                .tag(Tab.snippets)
        }
        .onChange(of: terminalViewModel.tabs.count) { oldValue, newValue in
            if newValue > oldValue {
                selectedTab = .terminal
            }
            if newValue == 0 && selectedTab == .terminal {
                selectedTab = .hosts
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showQuickConnect) {
            QuickConnectView()
        }
        .onOpenURL { url in
            Task {
                await URLSchemeHandler.handle(url: url, terminalViewModel: terminalViewModel)
            }
        }
        // Global keyboard shortcuts
        .onKeyPress(.init("t"), modifiers: .command) {
            showQuickConnect = true
            return .handled
        }
        .onKeyPress(.init(","), modifiers: .command) {
            showSettings = true
            return .handled
        }
    }
}

// MARK: - Full Snippets View

struct SnippetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Snippet.usageCount, order: .reverse) private var snippets: [Snippet]
    @EnvironmentObject var terminalViewModel: TerminalViewModel

    @StateObject private var viewModel = SnippetsViewModel()
    @State private var showAddSnippet = false
    @State private var selectedSnippet: Snippet?

    var body: some View {
        NavigationStack {
            Group {
                if snippets.isEmpty {
                    emptyState
                } else {
                    snippetList
                }
            }
            .navigationTitle("Snippets")
            .searchable(text: $viewModel.searchText, prompt: "Search snippets")
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Snippets", systemImage: "text.word.spacing")
        } description: {
            Text("Save frequently used commands for quick access.\nUse variables like ${HOST}, ${USER}, ${DATE}.")
        } actions: {
            Button("Add Snippet") {
                showAddSnippet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var snippetList: some View {
        List {
            // Categories
            let categories = viewModel.categories(from: snippets)
            if !categories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip("All", isSelected: viewModel.selectedCategory == nil) {
                                viewModel.selectedCategory = nil
                            }
                            ForEach(categories, id: \.self) { cat in
                                categoryChip(cat, isSelected: viewModel.selectedCategory == cat) {
                                    viewModel.selectedCategory = cat
                                }
                            }
                        }
                    }
                }
            }

            // Snippets
            ForEach(viewModel.filteredSnippets(snippets)) { snippet in
                snippetRow(snippet)
            }
            .onDelete { indexSet in
                let filtered = viewModel.filteredSnippets(snippets)
                for index in indexSet {
                    modelContext.delete(filtered[index])
                }
                try? modelContext.save()
            }
        }
        .listStyle(.insetGrouped)
    }

    private func categoryChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snippet.title)
                    .font(.headline)

                Spacer()

                if snippet.usageCount > 0 {
                    Text("\(snippet.usageCount)x")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }

            Text(snippet.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let category = snippet.category {
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            executeSnippet(snippet)
        }
        .contextMenu {
            Button {
                executeSnippet(snippet)
            } label: {
                Label("Execute", systemImage: "play.fill")
            }
            .disabled(terminalViewModel.activeTab == nil)

            Button {
                UIPasteboard.general.string = snippet.command
            } label: {
                Label("Copy Command", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                modelContext.delete(snippet)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func executeSnippet(_ snippet: Snippet) {
        guard let session = terminalViewModel.activeTab?.session else { return }
        viewModel.executeSnippet(snippet, in: session, context: modelContext)
    }
}

// MARK: - Add Snippet View

struct AddSnippetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var category = ""
    @State private var showVariableHelp = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Snippet") {
                    TextField("Title", text: $title)

                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: $command)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)

                        Button {
                            showVariableHelp.toggle()
                        } label: {
                            Label("Variables", systemImage: "info.circle")
                                .font(.caption)
                        }
                    }
                }

                if showVariableHelp {
                    Section("Available Variables") {
                        variableRow("${HOST}", description: "Server hostname")
                        variableRow("${USER}", description: "Username")
                        variableRow("${PORT}", description: "SSH port")
                        variableRow("${NAME}", description: "Host display name")
                        variableRow("${DATE}", description: "Current date (ISO 8601)")
                    }
                }

                Section("Organization") {
                    TextField("Category (optional)", text: $category)
                }

                Section("Templates") {
                    Button("System Info") { command = "uname -a && uptime && free -h && df -h" }
                    Button("Docker Status") { command = "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'" }
                    Button("Git Status") { command = "git status && git log --oneline -5" }
                    Button("Process List") { command = "ps aux --sort=-%mem | head -20" }
                    Button("Network Info") { command = "ip addr show && ss -tlnp" }
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
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func variableRow(_ variable: String, description: String) -> some View {
        HStack {
            Text(variable)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                command += variable
            } label: {
                Image(systemName: "plus.circle")
                    .font(.caption)
            }
        }
    }
}
