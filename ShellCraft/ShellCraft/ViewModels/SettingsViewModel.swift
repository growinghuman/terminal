import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedThemeID: String
    @Published var defaultFontSize: CGFloat
    @Published var enableHapticFeedback: Bool
    @Published var enableBellSound: Bool
    @Published var scrollbackBufferSize: Int
    @Published var defaultKeepAlive: Int
    @Published var useBiometricAuth: Bool

    private let defaults = UserDefaults.standard
    let themeManager = ThemeManager.shared

    init() {
        self.selectedThemeID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "solarized-dark"
        self.defaultFontSize = CGFloat(UserDefaults.standard.double(forKey: "defaultFontSize").nonZero ?? 14)
        self.enableHapticFeedback = UserDefaults.standard.bool(forKey: "enableHapticFeedback")
        self.enableBellSound = UserDefaults.standard.bool(forKey: "enableBellSound")
        self.scrollbackBufferSize = UserDefaults.standard.integer(forKey: "scrollbackBufferSize").nonZero ?? 10000
        self.defaultKeepAlive = UserDefaults.standard.integer(forKey: "defaultKeepAlive").nonZero ?? 60
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: "useBiometricAuth")
    }

    func save() {
        defaults.set(selectedThemeID, forKey: "selectedThemeID")
        defaults.set(Double(defaultFontSize), forKey: "defaultFontSize")
        defaults.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        defaults.set(enableBellSound, forKey: "enableBellSound")
        defaults.set(scrollbackBufferSize, forKey: "scrollbackBufferSize")
        defaults.set(defaultKeepAlive, forKey: "defaultKeepAlive")
        defaults.set(useBiometricAuth, forKey: "useBiometricAuth")

        themeManager.selectTheme(selectedThemeID)
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
