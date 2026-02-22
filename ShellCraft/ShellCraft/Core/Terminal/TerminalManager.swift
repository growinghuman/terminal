import Foundation
import SwiftTerm
import UIKit

/// Bridges SwiftTerm's terminal emulator with the SSH session
@MainActor
final class TerminalManager: ObservableObject {
    let terminalView: TerminalView
    private var session: SSHSession?

    @Published var title: String = "Terminal"
    @Published var currentTheme: TerminalTheme = ThemeManager.shared.defaultTheme
    @Published var fontSize: CGFloat = 14

    init() {
        self.terminalView = TerminalView(frame: .zero)
        configureTerminal()
    }

    private func configureTerminal() {
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.terminalDelegate = self
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .white

        applyTheme(currentTheme)
    }

    // MARK: - Session Binding

    func attachSession(_ session: SSHSession) {
        self.session = session
        self.title = session.host.name

        session.onDataReceived = { [weak self] data in
            Task { @MainActor in
                self?.handleReceivedData(data)
            }
        }
    }

    func detachSession() {
        session?.onDataReceived = nil
        session = nil
    }

    private func handleReceivedData(_ data: Data) {
        let bytes = [UInt8](data)
        terminalView.feed(byteArray: bytes)
    }

    // MARK: - Terminal Size

    var terminalSize: (cols: Int, rows: Int) {
        let cols = terminalView.getTerminal().cols
        let rows = terminalView.getTerminal().rows
        return (cols, rows)
    }

    func notifyTerminalSizeChanged() async {
        let size = terminalSize
        await session?.resizeTerminal(cols: size.cols, rows: size.rows)
    }

    // MARK: - Theme

    func applyTheme(_ theme: TerminalTheme) {
        self.currentTheme = theme

        terminalView.nativeBackgroundColor = UIColor(theme.backgroundColor)
        terminalView.nativeForegroundColor = UIColor(theme.foregroundColor)

        // Apply ANSI colors
        let colors = theme.ansiColors.map { UIColor($0) }
        if colors.count >= 16 {
            terminalView.installColors(
                colors.map { SwiftTerm.Color(color: $0) }
            )
        }
    }

    func setFontSize(_ size: CGFloat) {
        self.fontSize = size
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        terminalView.font = font
    }
}

// MARK: - TerminalViewDelegate

extension TerminalManager: TerminalViewDelegate {
    nonisolated func scrolled(source: TerminalView, position: Double) {
        // Handle scroll position if needed
    }

    nonisolated func setTerminalTitle(source: TerminalView, title: String) {
        Task { @MainActor in
            self.title = title
        }
    }

    nonisolated func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor in
            await self.notifyTerminalSizeChanged()
        }
    }

    nonisolated func send(source: TerminalView, data: ArraySlice<UInt8>) {
        let bytes = Data(data)
        Task { @MainActor in
            self.session?.sendData(bytes)
        }
    }

    nonisolated func clipboardCopy(source: TerminalView, content: Data) {
        if let text = String(data: content, encoding: .utf8) {
            Task { @MainActor in
                UIPasteboard.general.string = text
            }
        }
    }

    nonisolated func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - SwiftTerm Color Extension

extension SwiftTerm.Color {
    init(color: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: UInt16(r * 65535), green: UInt16(g * 65535), blue: UInt16(b * 65535))
    }
}
