import Foundation

/// Manages terminal themes loading and persistence
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themes: [TerminalTheme] = []
    @Published var selectedThemeID: String

    var defaultTheme: TerminalTheme {
        themes.first { $0.id == "solarized-dark" } ?? themes[0]
    }

    var selectedTheme: TerminalTheme {
        themes.first { $0.id == selectedThemeID } ?? defaultTheme
    }

    private init() {
        self.selectedThemeID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "solarized-dark"
        self.themes = Self.builtInThemes()
    }

    func selectTheme(_ themeID: String) {
        selectedThemeID = themeID
        UserDefaults.standard.set(themeID, forKey: "selectedThemeID")
    }

    // MARK: - Built-in Themes

    static func builtInThemes() -> [TerminalTheme] {
        [
            solarizedDark,
            solarizedLight,
            oneDark,
            monokai,
            dracula,
            nord,
            gruvboxDark,
            tokyoNight,
            catppuccinMocha,
            terminalGreen,
        ]
    }

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        colors: .init(
            foreground: "#839496", background: "#002B36",
            cursor: "#93A1A1", selectionBackground: "#073642",
            black: "#073642", red: "#DC322F", green: "#859900", yellow: "#B58900",
            blue: "#268BD2", magenta: "#D33682", cyan: "#2AA198", white: "#EEE8D5",
            brightBlack: "#002B36", brightRed: "#CB4B16", brightGreen: "#586E75",
            brightYellow: "#657B83", brightBlue: "#839496", brightMagenta: "#6C71C4",
            brightCyan: "#93A1A1", brightWhite: "#FDF6E3"
        ),
        isDark: true
    )

    static let solarizedLight = TerminalTheme(
        id: "solarized-light",
        name: "Solarized Light",
        colors: .init(
            foreground: "#657B83", background: "#FDF6E3",
            cursor: "#586E75", selectionBackground: "#EEE8D5",
            black: "#073642", red: "#DC322F", green: "#859900", yellow: "#B58900",
            blue: "#268BD2", magenta: "#D33682", cyan: "#2AA198", white: "#EEE8D5",
            brightBlack: "#002B36", brightRed: "#CB4B16", brightGreen: "#586E75",
            brightYellow: "#657B83", brightBlue: "#839496", brightMagenta: "#6C71C4",
            brightCyan: "#93A1A1", brightWhite: "#FDF6E3"
        ),
        isDark: false
    )

    static let oneDark = TerminalTheme(
        id: "one-dark",
        name: "One Dark",
        colors: .init(
            foreground: "#ABB2BF", background: "#282C34",
            cursor: "#528BFF", selectionBackground: "#3E4451",
            black: "#282C34", red: "#E06C75", green: "#98C379", yellow: "#E5C07B",
            blue: "#61AFEF", magenta: "#C678DD", cyan: "#56B6C2", white: "#ABB2BF",
            brightBlack: "#545862", brightRed: "#E06C75", brightGreen: "#98C379",
            brightYellow: "#E5C07B", brightBlue: "#61AFEF", brightMagenta: "#C678DD",
            brightCyan: "#56B6C2", brightWhite: "#C8CCD4"
        ),
        isDark: true
    )

    static let monokai = TerminalTheme(
        id: "monokai",
        name: "Monokai",
        colors: .init(
            foreground: "#F8F8F2", background: "#272822",
            cursor: "#F8F8F0", selectionBackground: "#49483E",
            black: "#272822", red: "#F92672", green: "#A6E22E", yellow: "#F4BF75",
            blue: "#66D9EF", magenta: "#AE81FF", cyan: "#A1EFE4", white: "#F8F8F2",
            brightBlack: "#75715E", brightRed: "#F92672", brightGreen: "#A6E22E",
            brightYellow: "#F4BF75", brightBlue: "#66D9EF", brightMagenta: "#AE81FF",
            brightCyan: "#A1EFE4", brightWhite: "#F9F8F5"
        ),
        isDark: true
    )

    static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        colors: .init(
            foreground: "#F8F8F2", background: "#282A36",
            cursor: "#F8F8F2", selectionBackground: "#44475A",
            black: "#21222C", red: "#FF5555", green: "#50FA7B", yellow: "#F1FA8C",
            blue: "#BD93F9", magenta: "#FF79C6", cyan: "#8BE9FD", white: "#F8F8F2",
            brightBlack: "#6272A4", brightRed: "#FF6E6E", brightGreen: "#69FF94",
            brightYellow: "#FFFFA5", brightBlue: "#D6ACFF", brightMagenta: "#FF92DF",
            brightCyan: "#A4FFFF", brightWhite: "#FFFFFF"
        ),
        isDark: true
    )

    static let nord = TerminalTheme(
        id: "nord",
        name: "Nord",
        colors: .init(
            foreground: "#D8DEE9", background: "#2E3440",
            cursor: "#D8DEE9", selectionBackground: "#434C5E",
            black: "#3B4252", red: "#BF616A", green: "#A3BE8C", yellow: "#EBCB8B",
            blue: "#81A1C1", magenta: "#B48EAD", cyan: "#88C0D0", white: "#E5E9F0",
            brightBlack: "#4C566A", brightRed: "#BF616A", brightGreen: "#A3BE8C",
            brightYellow: "#EBCB8B", brightBlue: "#81A1C1", brightMagenta: "#B48EAD",
            brightCyan: "#8FBCBB", brightWhite: "#ECEFF4"
        ),
        isDark: true
    )

    static let gruvboxDark = TerminalTheme(
        id: "gruvbox-dark",
        name: "Gruvbox Dark",
        colors: .init(
            foreground: "#EBDBB2", background: "#282828",
            cursor: "#EBDBB2", selectionBackground: "#3C3836",
            black: "#282828", red: "#CC241D", green: "#98971A", yellow: "#D79921",
            blue: "#458588", magenta: "#B16286", cyan: "#689D6A", white: "#A89984",
            brightBlack: "#928374", brightRed: "#FB4934", brightGreen: "#B8BB26",
            brightYellow: "#FABD2F", brightBlue: "#83A598", brightMagenta: "#D3869B",
            brightCyan: "#8EC07C", brightWhite: "#EBDBB2"
        ),
        isDark: true
    )

    static let tokyoNight = TerminalTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        colors: .init(
            foreground: "#A9B1D6", background: "#1A1B26",
            cursor: "#C0CAF5", selectionBackground: "#33467C",
            black: "#15161E", red: "#F7768E", green: "#9ECE6A", yellow: "#E0AF68",
            blue: "#7AA2F7", magenta: "#BB9AF7", cyan: "#7DCFFF", white: "#A9B1D6",
            brightBlack: "#414868", brightRed: "#F7768E", brightGreen: "#9ECE6A",
            brightYellow: "#E0AF68", brightBlue: "#7AA2F7", brightMagenta: "#BB9AF7",
            brightCyan: "#7DCFFF", brightWhite: "#C0CAF5"
        ),
        isDark: true
    )

    static let catppuccinMocha = TerminalTheme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        colors: .init(
            foreground: "#CDD6F4", background: "#1E1E2E",
            cursor: "#F5E0DC", selectionBackground: "#45475A",
            black: "#45475A", red: "#F38BA8", green: "#A6E3A1", yellow: "#F9E2AF",
            blue: "#89B4FA", magenta: "#F5C2E7", cyan: "#94E2D5", white: "#BAC2DE",
            brightBlack: "#585B70", brightRed: "#F38BA8", brightGreen: "#A6E3A1",
            brightYellow: "#F9E2AF", brightBlue: "#89B4FA", brightMagenta: "#F5C2E7",
            brightCyan: "#94E2D5", brightWhite: "#A6ADC8"
        ),
        isDark: true
    )

    static let terminalGreen = TerminalTheme(
        id: "terminal-green",
        name: "Retro Green",
        colors: .init(
            foreground: "#00FF00", background: "#000000",
            cursor: "#00FF00", selectionBackground: "#003300",
            black: "#000000", red: "#FF0000", green: "#00FF00", yellow: "#FFFF00",
            blue: "#0000FF", magenta: "#FF00FF", cyan: "#00FFFF", white: "#FFFFFF",
            brightBlack: "#555555", brightRed: "#FF5555", brightGreen: "#55FF55",
            brightYellow: "#FFFF55", brightBlue: "#5555FF", brightMagenta: "#FF55FF",
            brightCyan: "#55FFFF", brightWhite: "#FFFFFF"
        ),
        isDark: true
    )
}
