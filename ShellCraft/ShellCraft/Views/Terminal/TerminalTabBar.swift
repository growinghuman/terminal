import SwiftUI

struct TerminalTabBar: View {
    let tabs: [TerminalTab]
    let activeTabID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onAddNew: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabItem(tab)
                }

                // Add new tab button
                Button(action: onAddNew) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("New connection")
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tabItem(_ tab: TerminalTab) -> some View {
        let isActive = tab.id == activeTabID

        return Button {
            onSelect(tab.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? .green : .secondary.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(tab.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)

                Button {
                    onClose(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(tab.title)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? .primary : .secondary)
    }
}
