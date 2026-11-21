import SwiftUI

public struct SSTabBarItem<ID: Hashable & Sendable>: Identifiable, Sendable {
    public let id: ID
    public let icon: SSIcon
    /// Filled variant shown while selected, where Figma provides one.
    public let selectedIcon: SSIcon?
    public let label: String

    public init(id: ID, icon: SSIcon, selectedIcon: SSIcon? = nil, label: String) {
        self.id = id
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.label = label
    }
}

/// The app's bottom navigation: icon-only items on the dark shell (Figma "NAVIGATION").
/// The selected item uses its filled icon where Figma provides one (Home, Monitor) and
/// every icon stays white, as designed. Tabs with no filled icon dim the others
/// instead, so selection is always visible.
public struct SSTabBar<ID: Hashable & Sendable>: View {
    private let items: [SSTabBarItem<ID>]
    @Binding private var selection: ID

    public init(items: [SSTabBarItem<ID>], selection: Binding<ID>) {
        self.items = items
        _selection = selection
    }

    public var body: some View {
        let dimsUnselected = items.first { $0.id == selection }?.selectedIcon == nil
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    SSIconView(isSelected ? item.selectedIcon ?? item.icon : item.icon, size: 24, color: .white)
                        .opacity(isSelected || !dimsUnselected ? 1 : 0.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.label))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 10)
        .background(SSColor.shell)
    }
}

/// Circular chip holding a 16 pt icon, used in the corner of metric cards.
public struct SSIconChip: View {
    private let icon: SSIcon
    private let tint: Color
    private let fill: Color

    public init(_ icon: SSIcon, tint: Color = SSColor.textStrong, fill: Color = SSColor.iconChip) {
        self.icon = icon
        self.tint = tint
        self.fill = fill
    }

    public var body: some View {
        SSIconView(icon, size: 16, color: tint)
            .frame(width: 32, height: 32)
            .background(fill, in: Circle())
    }
}
