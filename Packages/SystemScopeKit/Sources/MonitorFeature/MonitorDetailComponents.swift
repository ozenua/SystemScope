import DesignSystem
import SwiftUI

// Shared building blocks for the metric screens (MON-02 to MON-08), named after the
// Figma components they implement.

/// MonitorHeader / Detail: back, a trailing action, then title and subtitle.
struct DetailHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SSBackButton(label: Strings.back, action: onBack)
                    .padding(.leading, -6)
                Spacer()
                trailing
            }
            VStack(alignment: .leading, spacing: 8) {
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

/// The 40 pt refresh button used in the detail headers.
struct RefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    SSIconView(.refresh, size: 20, color: Color(hex: 0x292D32))
                }
            }
            .frame(width: 40, height: 40)
            .background(SSColor.hairline, in: Circle())
            .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(isRefreshing)
        .accessibilityLabel(Text(Strings.refresh))
    }
}

/// Scrolling page shell shared by every metric screen.
struct DetailPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 16)
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// SpecificationRow: label on the left, value on the right.
struct SpecRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String?
    var fallback: String = Strings.unavailable
    var valueColor: Color = SSColor.textPrimary
}

/// Specifications: a card of rows separated by hairlines.
struct SpecCard: View {
    let rows: [SpecRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                SpecLine(row: row)
                if index < rows.count - 1 {
                    Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
    }
}

struct SpecLine: View {
    let row: SpecRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Spacer(minLength: 8)
            Text(row.value ?? row.fallback)
                .ssText(.labelSemibold14)
                .foregroundStyle(row.value == nil ? SSColor.textSubtle : row.valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

/// Stat: a small label over a value.
struct StatBox: View {
    let label: String
    let value: String?
    var fallback: String = Strings.unavailable
    var filled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textSubtle)
            Text(value ?? fallback)
                .ssText(.stat16)
                .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            if filled {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SSColor.surface)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Platform note: grey info line explaining what iOS does not share.
struct PlatformNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SSIconView(.info, size: 16, color: SSColor.textFaint)
            Text(text)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// DataTimestamp: clock icon and when the reading was taken.
struct DataTimestamp: View {
    let text: String
    var color: Color = SSColor.textFaint

    var body: some View {
        HStack(spacing: 6) {
            SSIconView(.clock, size: 14, color: color)
            Text(text)
                .ssText(.captionMedium12)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// TimeRangeSelector for any set of options.
struct SegmentedSelector<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .ssText(.segment13)
                        .foregroundStyle(isSelected ? SSColor.textPrimary : SSColor.textSubtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.08), radius: 1.5, y: 2)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(SSColor.hairline, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// ActivityRow list.
struct ActivityList: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    let items: [Item]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    OutlinedIcon(icon: .activity)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textPrimary)
                        Text(item.subtitle)
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
    }
}

/// RecommendationCard list, with dividers between items. No chevron: none of the
/// suggestions lead anywhere inside the app.
struct RecommendationList: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    let items: [Item]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    OutlinedIcon(icon: .lamp, size: 40, iconSize: 20, cornerRadius: 12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .ssText(.rowTitle15)
                            .foregroundStyle(SSColor.textPrimary)
                        Text(item.detail)
                            .ssText(.bodyMedium13)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardSmall, style: .continuous))
    }
}

/// Coloured callout with an icon, title and body.
struct CalloutCard: View {
    let icon: SSIcon
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SSIconView(icon, size: 20, color: tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).ssText(.labelSemibold14)
                Text(message).ssText(.captionMedium12)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// TechnicalDetails: collapsed by default, expands to its source rows.
struct TechnicalDetails: View {
    let caption: String
    let rows: [SpecRow]
    var limitation: String?
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    SSIconView(.info, size: 18, color: Color(hex: 0x292D32))
                        .frame(width: 36, height: 36)
                        .background(SSColor.hairline, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.technicalDetails)
                            .ssText(.rowTitle15)
                            .foregroundStyle(SSColor.textPrimary)
                        Text(isExpanded ? Strings.expanded : caption)
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SSIconView(.chevronDown, size: 20, color: SSColor.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? Strings.expanded : Strings.collapsed))

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SpecLine(row: row)
                        if index < rows.count - 1 {
                            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                        }
                    }
                }
                if let limitation {
                    HStack(alignment: .top, spacing: 8) {
                        SSIconView(.info, size: 14, color: SSColor.textSecondary)
                        Text(limitation)
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Where a chart would go when there are not enough stored readings (MON-06).
struct InsufficientHistoryNote: View {
    var detail: String = Strings.historyNotRecorded

    var body: some View {
        VStack(spacing: 8) {
            SSIconView(.activity, size: 20, color: SSColor.footprintPurple)
                .frame(width: 40, height: 40)
                .background(SSColor.footprintPurple.opacity(0.12), in: Circle())
            Text(Strings.insufficientHistory)
                .ssText(.rowTitle15)
                .foregroundStyle(SSColor.textPrimary)
            Text(detail)
                .ssText(.bodyMedium13)
                .foregroundStyle(SSColor.textSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(SSColor.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Line chart of readings taken this session. x is time within `window` seconds
/// ending now; the stretch before the first reading is left empty, never filled in.
struct LiveLineChart: View {
    struct Point {
        var date: Date
        var value: Double
    }

    let points: [Point]
    let window: TimeInterval
    let range: ClosedRange<Double>
    var average: Double?
    var tint: Color = SSColor.accent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { proxy in
                let size = proxy.size
                let now = context.date
                let span = max(range.upperBound - range.lowerBound, 0.0001)
                let place: (Point) -> CGPoint = { point in
                    let x = 1 - now.timeIntervalSince(point.date) / window
                    let y = (point.value - range.lowerBound) / span
                    return CGPoint(x: x * size.width, y: size.height * (1 - y))
                }
                let visible = points.filter { now.timeIntervalSince($0.date) <= window }.map(place)

                ZStack(alignment: .topLeading) {
                    ForEach([0.24, 0.48, 0.72, 0.95], id: \.self) { line in
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 1)
                            .offset(y: size.height * line)
                    }
                    if visible.count >= 2, let first = visible.first, let last = visible.last {
                        Path { path in
                            path.move(to: CGPoint(x: first.x, y: size.height))
                            for point in visible { path.addLine(to: point) }
                            path.addLine(to: CGPoint(x: last.x, y: size.height))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        Path { $0.addLines(visible) }
                            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        if let average {
                            let y = size.height * (1 - (average - range.lowerBound) / span)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            }
                            .stroke(SSColor.textMuted, style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        }
                        Circle()
                            .fill(.white)
                            .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                            .frame(width: 9, height: 9)
                            .position(last)
                    }
                }
            }
        }
        .frame(height: 130)
        .clipped()
    }
}

/// Axis labels for a window ending now, e.g. "−60s −45s −30s −15s Now".
struct TimeAxis: View {
    let labels: [String]
    var leadingPadding: CGFloat = 0

    var body: some View {
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                if index > 0 { Spacer(minLength: 0) }
                Text(label)
                    .ssText(.axis12)
                    .foregroundStyle(SSColor.textSecondary)
            }
        }
        .padding(.leading, leadingPadding)
        .accessibilityHidden(true)
    }

    static func labels(window: TimeInterval, step: TimeInterval) -> [String] {
        stride(from: window, to: 0, by: -step).map { seconds in
            seconds > 60 ? "−\(Int(seconds / 60))m" : "−\(Int(seconds))s"
        } + [Strings.now]
    }
}

/// Line or swatch with a label, for chart legends.
struct LegendItem: View {
    enum Mark {
        case line(Color)
        case dashed(Color)
        case swatch(Color)
    }

    let mark: Mark
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            switch mark {
            case let .line(color):
                Capsule().fill(color).frame(width: 14, height: 3)
            case let .dashed(color):
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 14, height: 1.5)
            case let .swatch(color):
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            }
            Text(title)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textSubtle)
        }
    }
}
