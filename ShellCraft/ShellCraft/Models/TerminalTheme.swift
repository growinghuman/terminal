import Foundation
import SwiftUI

struct TerminalTheme: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let colors: ThemeColors
    let isDark: Bool

    struct ThemeColors: Codable, Hashable {
        let foreground: String
        let background: String
        let cursor: String
        let selectionBackground: String
        let black: String
        let red: String
        let green: String
        let yellow: String
        let blue: String
        let magenta: String
        let cyan: String
        let white: String
        let brightBlack: String
        let brightRed: String
        let brightGreen: String
        let brightYellow: String
        let brightBlue: String
        let brightMagenta: String
        let brightCyan: String
        let brightWhite: String
    }

    var foregroundColor: Color { Color(hex: colors.foreground) }
    var backgroundColor: Color { Color(hex: colors.background) }
    var cursorColor: Color { Color(hex: colors.cursor) }

    var ansiColors: [Color] {
        [
            Color(hex: colors.black),
            Color(hex: colors.red),
            Color(hex: colors.green),
            Color(hex: colors.yellow),
            Color(hex: colors.blue),
            Color(hex: colors.magenta),
            Color(hex: colors.cyan),
            Color(hex: colors.white),
            Color(hex: colors.brightBlack),
            Color(hex: colors.brightRed),
            Color(hex: colors.brightGreen),
            Color(hex: colors.brightYellow),
            Color(hex: colors.brightBlue),
            Color(hex: colors.brightMagenta),
            Color(hex: colors.brightCyan),
            Color(hex: colors.brightWhite),
        ]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0,
                1.0
            )
        case 8:
            (r, g, b, a) = (
                Double((int >> 24) & 0xFF) / 255.0,
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
