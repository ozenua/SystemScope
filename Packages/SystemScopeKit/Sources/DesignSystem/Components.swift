import SwiftUI

/// The white-to-grey vertical wash behind every light onboarding screen.
public struct SSScreenBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [SSColor.backgroundTop, SSColor.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Rounded square holding an icon, e.g. the 50 pt device tile.
public struct SSIconTile: View {
    private let icon: SSIcon
    private let size: CGFloat
    private let iconSize: CGFloat

    public init(_ icon: SSIcon, size: CGFloat = 50, iconSize: CGFloat = 24) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: SSRadius.tile, style: .continuous)
        SSIconView(icon, size: iconSize)
            .frame(width: size, height: size)
            .background(SSColor.surfaceSubtle, in: shape)
            .overlay(shape.strokeBorder(SSColor.hairline, lineWidth: 1))
    }
}

/// Page indicator: the current page is the wide pill.
public struct SSPageDots: View {
    private let count: Int
    private let current: Int

    public init(count: Int, current: Int) {
        self.count = count
        self.current = current
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? SSColor.track : SSColor.textMuted)
                    .frame(width: index == current ? 24 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One segment per step: done, current, pending.
public struct SSSegmentedProgress: View {
    private let total: Int
    private let completed: Int
    private let hasCurrent: Bool

    public init(total: Int, completed: Int, hasCurrent: Bool) {
        self.total = total
        self.completed = completed
        self.hasCurrent = hasCurrent
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for index: Int) -> Color {
        if index < completed { return SSColor.ink }
        if index == completed && hasCurrent { return SSColor.textMuted }
        return SSColor.track
    }
}

/// Leading-aligned wrapping layout for chips.
public struct SSFlowLayout: Layout {
    private let spacing: CGFloat

    public init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
