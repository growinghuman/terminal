import SwiftUI

/// Extra key bar shown above the iOS keyboard for special terminal keys
struct VirtualKeyboardBar: View {
    let onKey: (String) -> Void

    @State private var isCtrlActive = false
    @State private var isAltActive = false

    private let specialKeys: [(label: String, key: String, width: CGFloat)] = [
        ("Esc", "\u{1B}", 40),
        ("Tab", "\t", 40),
        ("|", "|", 30),
        ("/", "/", 30),
        ("-", "-", 30),
        ("~", "~", 30),
    ]

    private let arrowKeys: [(label: String, icon: String, key: String)] = [
        ("Up", "chevron.up", "\u{1B}[A"),
        ("Down", "chevron.down", "\u{1B}[B"),
        ("Left", "chevron.left", "\u{1B}[D"),
        ("Right", "chevron.right", "\u{1B}[C"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Modifier keys
                modifierKey("Ctrl", isActive: $isCtrlActive)
                modifierKey("Alt", isActive: $isAltActive)

                Divider()
                    .frame(height: 24)

                // Special keys
                ForEach(specialKeys, id: \.label) { key in
                    keyButton(label: key.label, minWidth: key.width) {
                        sendKey(key.key)
                    }
                }

                Divider()
                    .frame(height: 24)

                // Arrow keys
                ForEach(arrowKeys, id: \.label) { arrow in
                    keyButton(icon: arrow.icon, minWidth: 32) {
                        sendKey(arrow.key)
                    }
                }

                Divider()
                    .frame(height: 24)

                // Function-like keys
                keyButton(label: "PgUp", minWidth: 40) {
                    sendKey("\u{1B}[5~")
                }
                keyButton(label: "PgDn", minWidth: 40) {
                    sendKey("\u{1B}[6~")
                }
                keyButton(label: "Home", minWidth: 44) {
                    sendKey("\u{1B}[H")
                }
                keyButton(label: "End", minWidth: 36) {
                    sendKey("\u{1B}[F")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 40)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Key Components

    private func modifierKey(_ label: String, isActive: Binding<Bool>) -> some View {
        Button {
            isActive.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive.wrappedValue ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive.wrappedValue ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }

    private func keyButton(label: String? = nil, icon: String? = nil,
                           minWidth: CGFloat = 30, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
            }
            .foregroundStyle(.primary)
            .frame(minWidth: minWidth)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Handling

    private func sendKey(_ key: String) {
        var modifiedKey = key

        if isCtrlActive {
            // Ctrl modifier: convert to control character
            if key.count == 1, let ascii = key.uppercased().first?.asciiValue {
                let ctrlChar = ascii - 64 // '@' = 64, so Ctrl+A = 1, Ctrl+C = 3
                if ctrlChar > 0 && ctrlChar < 32 {
                    modifiedKey = String(UnicodeScalar(ctrlChar))
                }
            }
            isCtrlActive = false
        }

        if isAltActive {
            // Alt modifier: prepend ESC
            modifiedKey = "\u{1B}" + key
            isAltActive = false
        }

        onKey(modifiedKey)
    }
}
