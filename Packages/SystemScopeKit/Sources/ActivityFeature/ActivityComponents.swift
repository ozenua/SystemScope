import ActivityStore
import DesignSystem
import SwiftUI

// Building blocks for the Activity screens, named after the Figma components.

extension ActivityCategory {
    var icon: SSIcon {
        switch self {
        case .performance: .cpu
        case .battery: .batteryFull
        case .network: .wifi
        case .thermal: .tempCold
        case .storage: .storage
        case .sessions: .timer
        }
    }
}

extension AlertSeverity {
    var label: String {
        switch self {
        case .information: L("Information")
        case .attention: L("Attention")
        case .critical: L("Critical")
        }
    }

    var color: Color {
        switch self {
        case .information: SSColor.accent
        case .attention: SSColor.statusAmber
        case .critical: SSColor.thermalRed
        }
    }
}

extension SessionType {
    var icon: SSIcon {
        switch self {
        case .performance: .cpu
        case .network: .wifi
        case .battery: .batteryFull
        }
    }
}

extension SessionStatus {
    var label: String {
        switch self {
        case .active: L("Recording")
        case .paused: L("Paused")
        case .completed: L("Completed")
        case .interrupted: L("Interrupted")
        case .failed: L("Failed")
        }
    }

    var dot: Color {
        switch self {
        case .active, .paused: SSColor.accent
        case .completed: SSColor.statusGreen
        case .interrupted: SSColor.statusAmber
        case .failed: SSColor.thermalRed
        }
    }
}

/// Page shell shared by every pushed Activity screen.
struct ActivityPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 24)
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// 40 pt grey circle with an icon.
struct CircleButton: View {
    let icon: SSIcon
    let label: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SSIconView(icon, size: iconSize, color: SSColor.textStrong)
                .frame(width: size, height: size)
                .background(SSColor.hairline, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Back, an optional trailing action, title and subtitle.
struct ActivityDetailHeader: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    var trailingIcon: SSIcon?
    var trailingLabel = ""
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SSBackButton(label: L("Back"), action: onBack)
                    .padding(.leading, -6)
                Spacer()
                if let trailingIcon, let trailingAction {
                    CircleButton(icon: trailingIcon, label: trailingLabel, action: trailingAction)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .ssText(.screenTitle24)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
        }
    }
}

/// Activity summary: three counts split by hairlines, with an optional timestamp.
struct SummaryCard: View {
    struct Cell: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let caption: String
        var action: (() -> Void)?
    }

    let cells: [Cell]
    var timestamp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    if index > 0 { Rectangle().fill(SSColor.border).frame(width: 1) }
                    Group {
                        if let action = cell.action {
                            Button(action: action) { content(cell) }.buttonStyle(.plain)
                        } else {
                            content(cell)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            if let timestamp {
                HStack(spacing: 6) {
                    SSIconView(.clock, size: 14, color: SSColor.textFaint)
                    Text(timestamp).ssText(.captionMedium12).foregroundStyle(SSColor.textFaint)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func content(_ cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cell.label).ssText(.captionMedium12).foregroundStyle(SSColor.textStrong.opacity(0.6))
            Text(cell.value)
                .font(.system(size: 30, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(SSColor.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(cell.caption).ssText(.caption12).foregroundStyle(SSColor.textStrong.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

/// Category chip: dark when selected, outlined otherwise.
struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .ssText(.labelSemibold14)
                .foregroundStyle(isSelected ? Color.white : SSColor.textStrong)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isSelected ? SSColor.textStrong : SSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .clear : SSColor.border, lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A horizontally scrolling row of chips, edge to edge.
struct ChipRow<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    CategoryChip(label: label(option), isSelected: option == selection) { selection = option }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}

/// Activity Date Header: title, count badge and a collapse chevron.
struct DateHeader: View {
    let title: String
    let count: Int
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .ssText(.section18)
                    .foregroundStyle(SSColor.textStrong)
                Text("\(count)")
                    .ssText(.chip12)
                    .foregroundStyle(SSColor.textStrong)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(SSColor.border, in: Capsule())
                Spacer()
                SSIconView(.chevronDown, size: 20, color: SSColor.textTertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 180))
            }
            .padding(4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(Text(isCollapsed ? L("Collapsed") : L("Expanded")))
    }
}

/// Activity Category Icon: outlined rounded square.
struct CategoryIcon: View {
    let icon: SSIcon
    var size: CGFloat = 44

    var body: some View {
        SSIconView(icon, size: 20, color: SSColor.textStrong)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
    }
}

/// Outlined pill with a coloured dot. The text carries the meaning.
struct StatusPill: View {
    let title: String
    var dot: Color = SSColor.statusGreen
    var dark = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(title)
                .ssText(.chip12)
                .foregroundStyle(dark ? Color.white : SSColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(dark ? SSColor.textStrong : SSColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(dark ? .clear : SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Activity Item: icon, unread dot, title, time, detail and chevron.
struct ActivityRow: View {
    let item: ActivityItem
    var compact = false
    var timeText: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(icon: icon)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if item.isUnread {
                        Circle().fill(SSColor.accent).frame(width: 8, height: 8)
                            .accessibilityLabel(Text(L("Unread")))
                    }
                    Text(item.title)
                        .ssText(.rowTitle15)
                        .foregroundStyle(item.isResolved ? SSColor.textTertiary : SSColor.textStrong)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(timeText)
                        .ssText(.captionMedium12)
                        .foregroundStyle(SSColor.textTertiary)
                }
                if !compact, !item.detail.isEmpty {
                    Text(item.detail)
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textTertiary)
                        .lineLimit(2)
                }
                if item.isResolved {
                    StatusPill(title: L("Resolved")).padding(.top, 3)
                }
            }
            SSIconView(.chevronRight, size: 20, color: SSColor.textFaint)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var icon: SSIcon {
        if case .session(let session) = item { return session.type.icon }
        return item.category.icon
    }
}

/// A row that reveals Read and Delete on a left swipe (ACT-12). The same actions are
/// in the context menu, the accessibility actions and on each detail screen.
struct SwipeActionRow<Content: View>: View {
    let isUnread: Bool
    let canToggleRead: Bool
    let onToggleRead: () -> Void
    let onDelete: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @GestureState private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var revealWidth: CGFloat { canToggleRead ? 152 : 76 }

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                HStack(spacing: 6) {
                    if canToggleRead {
                        actionButton(icon: .tickCircle, title: isUnread ? L("Read") : L("Unread"), color: SSColor.accent) {
                            close(); onToggleRead()
                        }
                    }
                    actionButton(icon: .close, title: L("Delete"), color: SSColor.thermalRed) {
                        close(); onDelete()
                    }
                }
                .padding(.trailing, 6)
            }
            content
                .background(SSColor.surface)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            offset = min(0, max(-revealWidth - 20, value.translation.width + (offset <= -revealWidth ? -revealWidth : 0)))
                        }
                        .onEnded { value in
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
                                offset = value.translation.width < -revealWidth / 2 ? -revealWidth : 0
                            }
                        }
                )
        }
        .clipped()
        .contextMenu {
            if canToggleRead {
                Button(isUnread ? L("Mark as read") : L("Mark as unread"), action: onToggleRead)
            }
            Button(L("Delete"), role: .destructive, action: onDelete)
        }
        .accessibilityActions {
            if canToggleRead {
                Button(isUnread ? L("Mark as read") : L("Mark as unread"), action: onToggleRead)
            }
            Button(L("Delete"), action: onDelete)
        }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { offset = 0 }
    }

    private func actionButton(icon: SSIcon, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                SSIconView(icon, size: 20, color: .white)
                Text(title).ssText(.chip12).foregroundStyle(.white)
            }
            .frame(width: 70)
            .frame(maxHeight: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}

/// White rounded card.
struct ActivityCard<Content: View>: View {
    var radius: CGFloat = 22
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Label/value rows with hairlines (Measurements, Observed information).
struct MeasurementList: View {
    let rows: [ActivityMeasurement]
    var onCopy: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 12) {
                    Text(row.label).ssText(.body14).foregroundStyle(SSColor.textTertiary)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textStrong)
                        .multilineTextAlignment(.trailing)
                    if let onCopy {
                        Button { onCopy(row.value) } label: {
                            SSIconView(.copy, size: 16, color: SSColor.textTertiary)
                                .frame(minWidth: 32, minHeight: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(L("Copy \(row.label)")))
                    }
                }
                .padding(.vertical, onCopy == nil ? 14 : 7)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 {
                    Rectangle().fill(SSColor.border).frame(height: 1)
                }
            }
        }
    }
}

/// Card with a title over its content ("What happened", "Measurements").
struct TitledCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Empty state card: icon, title, message and an optional button.
struct EmptyStateCard: View {
    let icon: SSIcon
    let title: String
    let message: String
    var button: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            SSIconView(icon, size: 22, color: SSColor.textStrong)
                .frame(width: 56, height: 56)
                .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
            Text(title).ssText(.metric17).foregroundStyle(SSColor.textStrong)
            Text(message)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textTertiary)
                .multilineTextAlignment(.center)
            if let button, let action {
                Button(action: action) {
                    Text(button)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SSColor.textStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Small bordered or filled button for the bottom action rows.
struct ActionPill: View {
    let icon: SSIcon
    let title: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SSIconView(icon, size: 16, color: destructive ? SSColor.thermalRed : SSColor.textStrong)
                Text(title)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(destructive ? SSColor.thermalRed : SSColor.textStrong)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Dark capsule with a tick, shown after an action.
struct ActivityToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            SSIconView(.tickCircleBold, size: 18, color: SSColor.statusGreen)
            Text(message).ssText(.labelSemibold14).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SSColor.ink, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Sheet chrome: grabber, title with a close button, white background.
struct SheetScaffold<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(SSColor.track).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.66)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                CircleButton(icon: .close, label: L("Close"), size: 32, iconSize: 14, action: onClose)
            }
            .padding(.horizontal, 20)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SSColor.surface)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
    }
}
