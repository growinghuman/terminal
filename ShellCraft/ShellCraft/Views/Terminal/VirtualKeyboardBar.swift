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
        ("_", "_", 30),
        ("\\", "\\", 30),
        ("\"", "\"", 30),
        ("'", "'", 30),
        ("[", "[", 30),
        ("]", "]", 30),
        ("{", "{", 30),
        ("}", "}", 30),
        ("$", "$", 30),
        ("&", "&", 30),
        ("`", "`", 30),
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

                // Quick Ctrl combos
                keyButton(label: "C-c", minWidth: 36) {
                    sendRawKey(String(UnicodeScalar(3)))  // Ctrl+C = ETX
                }
                .accessibilityLabel("Control C, interrupt")

                keyButton(label: "C-d", minWidth: 36) {
                    sendRawKey(String(UnicodeScalar(4)))  // Ctrl+D = EOT
                }
                .accessibilityLabel("Control D, end of input")

                keyButton(label: "C-z", minWidth: 36) {
                    sendRawKey(String(UnicodeScalar(26))) // Ctrl+Z = SUB
                }
                .accessibilityLabel("Control Z, suspend")

                Divider()
                    .frame(height: 24)

                // Special keys
                ForEach(specialKeys, id: \.label) { key in
                    keyButton(label: key.label, minWidth: key.width) {
                        sendKey(key.key)
                    }
                    .accessibilityLabel(accessibleName(for: key.label))
                }

                Divider()
                    .frame(height: 24)

                // Arrow keys
                ForEach(arrowKeys, id: \.label) { arrow in
                    keyButton(icon: arrow.icon, minWidth: 32) {
                        sendKey(arrow.key)
                    }
                    .accessibilityLabel("Arrow \(arrow.label)")
                }

                Divider()
                    .frame(height: 24)

                // Navigation keys
                keyButton(label: "PgUp", minWidth: 40) {
                    sendKey("\u{1B}[5~")
                }
                .accessibilityLabel("Page Up")

                keyButton(label: "PgDn", minWidth: 40) {
                    sendKey("\u{1B}[6~")
                }
                .accessibilityLabel("Page Down")

                keyButton(label: "Home", minWidth: 44) {
                    sendKey("\u{1B}[H")
                }

                keyButton(label: "End", minWidth: 36) {
                    sendKey("\u{1B}[F")
                }

                keyButton(label: "Ins", minWidth: 36) {
                    sendKey("\u{1B}[2~")
                }
                .accessibilityLabel("Insert")

                keyButton(label: "Del", minWidth: 36) {
                    sendKey("\u{1B}[3~")
                }
                .accessibilityLabel("Delete")

                Divider()
                    .frame(height: 24)

                // Function keys
                ForEach(1..<13) { n in
                    keyButton(label: "F\(n)", minWidth: 36) {
                        sendKey(functionKeySequence(n))
                    }
                    .accessibilityLabel("Function \(n)")
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .accessibilityLabel("\(label) modifier")
        .accessibilityAddTraits(isActive.wrappedValue ? .isSelected : [])
    }

    private func keyButton(label: String? = nil, icon: String? = nil,
                           minWidth: CGFloat = 30, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            action()
        } label: {
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
            if key.count == 1, let ascii = key.uppercased().first?.asciiValue {
                let ctrlChar = ascii - 64
                if ctrlChar > 0 && ctrlChar < 32 {
                    modifiedKey = String(UnicodeScalar(ctrlChar))
                }
            }
            isCtrlActive = false
        }

        if isAltActive {
            modifiedKey = "\u{1B}" + key
            isAltActive = false
        }

        onKey(modifiedKey)
    }

    private func sendRawKey(_ key: String) {
        isCtrlActive = false
        isAltActive = false
        onKey(key)
    }

    private func functionKeySequence(_ n: Int) -> String {
        switch n {
        case 1: return "\u{1B}OP"
        case 2: return "\u{1B}OQ"
        case 3: return "\u{1B}OR"
        case 4: return "\u{1B}OS"
        case 5: return "\u{1B}[15~"
        case 6: return "\u{1B}[17~"
        case 7: return "\u{1B}[18~"
        case 8: return "\u{1B}[19~"
        case 9: return "\u{1B}[20~"
        case 10: return "\u{1B}[21~"
        case 11: return "\u{1B}[23~"
        case 12: return "\u{1B}[24~"
        default: return ""
        }
    }

    private func accessibleName(for key: String) -> String {
        switch key {
        case "|": return "Pipe"
        case "/": return "Slash"
        case "-": return "Dash"
        case "~": return "Tilde"
        case "_": return "Underscore"
        case "\\": return "Backslash"
        case "\"": return "Double quote"
        case "'": return "Single quote"
        case "[": return "Left bracket"
        case "]": return "Right bracket"
        case "{": return "Left brace"
        case "}": return "Right brace"
        case "$": return "Dollar sign"
        case "&": return "Ampersand"
        case "`": return "Backtick"
        default: return key
        }
    }
}
