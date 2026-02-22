import SwiftUI
import SwiftTerm
import UIKit

/// SwiftUI wrapper for SwiftTerm's UIKit TerminalView
struct TerminalWrapperView: UIViewRepresentable {
    let terminalManager: TerminalManager

    func makeUIView(context: Context) -> TerminalView {
        let view = terminalManager.terminalView
        view.becomeFirstResponder()
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Theme or font updates are handled by TerminalManager
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(terminalManager: terminalManager)
    }

    class Coordinator: NSObject {
        let terminalManager: TerminalManager

        init(terminalManager: TerminalManager) {
            self.terminalManager = terminalManager
        }
    }
}

/// Full-screen terminal view with gesture support
struct TerminalFullScreenView: View {
    let terminalManager: TerminalManager
    @State private var currentFontSize: CGFloat = 14
    @GestureState private var pinchScale: CGFloat = 1.0

    var body: some View {
        TerminalWrapperView(terminalManager: terminalManager)
            .gesture(
                MagnifyGesture()
                    .updating($pinchScale) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        let newSize = max(8, min(32, currentFontSize * value.magnification))
                        currentFontSize = newSize
                        terminalManager.setFontSize(newSize)
                    }
            )
            .ignoresSafeArea(.keyboard)
    }
}
