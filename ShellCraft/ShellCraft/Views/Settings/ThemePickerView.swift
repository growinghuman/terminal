import SwiftUI

struct ThemePickerView: View {
    @Binding var selectedThemeID: String
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        List {
            Section("Dark Themes") {
                ForEach(themeManager.themes.filter(\.isDark)) { theme in
                    themeRow(theme)
                }
            }

            Section("Light Themes") {
                ForEach(themeManager.themes.filter { !$0.isDark }) { theme in
                    themeRow(theme)
                }
            }
        }
        .navigationTitle("Theme")
    }

    private func themeRow(_ theme: TerminalTheme) -> some View {
        Button {
            selectedThemeID = theme.id
        } label: {
            HStack(spacing: 12) {
                // Theme preview
                themePreview(theme)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(theme.isDark ? "Dark" : "Light")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedThemeID == theme.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func themePreview(_ theme: TerminalTheme) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.backgroundColor)
            .frame(width: 80, height: 48)
            .overlay {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Text("$")
                            .foregroundStyle(Color(hex: theme.colors.green))
                        Text("ls")
                            .foregroundStyle(theme.foregroundColor)
                    }
                    HStack(spacing: 4) {
                        Text("src")
                            .foregroundStyle(Color(hex: theme.colors.blue))
                        Text("docs")
                            .foregroundStyle(Color(hex: theme.colors.cyan))
                    }
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}
