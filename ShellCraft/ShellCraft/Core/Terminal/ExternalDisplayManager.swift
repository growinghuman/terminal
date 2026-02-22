import Foundation
import UIKit

/// Manages external display support for terminal sessions.
/// Detects connected displays and provides a dedicated terminal window.
@MainActor
final class ExternalDisplayManager: ObservableObject {
    static let shared = ExternalDisplayManager()

    @Published var isExternalDisplayConnected = false
    @Published var externalScreenBounds: CGRect = .zero

    private var externalWindow: UIWindow?
    private var screenObservers: [NSObjectProtocol] = []

    private init() {
        setupScreenNotifications()
        checkForExternalDisplay()
    }

    private func setupScreenNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let screen = notification.object as? UIScreen else { return }
                self?.handleScreenConnected(screen)
            }
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenDisconnected()
            }
        }

        screenObservers = [connectObserver, disconnectObserver]
    }

    private func checkForExternalDisplay() {
        if UIScreen.screens.count > 1, let external = UIScreen.screens.last {
            handleScreenConnected(external)
        }
    }

    private func handleScreenConnected(_ screen: UIScreen) {
        isExternalDisplayConnected = true
        externalScreenBounds = screen.bounds

        // Create a window on the external screen
        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        self.externalWindow = window
    }

    private func handleScreenDisconnected() {
        externalWindow?.isHidden = true
        externalWindow = nil
        isExternalDisplayConnected = false
        externalScreenBounds = .zero
    }

    /// Shows a terminal view controller on the external display.
    func showTerminalOnExternalDisplay(_ viewController: UIViewController) {
        guard let window = externalWindow else { return }
        window.rootViewController = viewController
        window.makeKeyAndVisible()
    }

    /// Hides the external display terminal.
    func hideExternalDisplay() {
        externalWindow?.rootViewController = nil
        externalWindow?.isHidden = true
    }

    /// Optimal font size for the external display resolution.
    var recommendedFontSize: CGFloat {
        let width = externalScreenBounds.width
        if width >= 3840 { return 20 }       // 4K
        if width >= 2560 { return 18 }       // QHD
        if width >= 1920 { return 16 }       // FHD
        return 14
    }

    /// Optimal terminal columns for the external display.
    var recommendedColumns: Int {
        let charWidth: CGFloat = recommendedFontSize * 0.6
        return max(80, Int(externalScreenBounds.width / charWidth))
    }

    deinit {
        for observer in screenObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
