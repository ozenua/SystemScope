import DesignSystem
import SwiftUI

/// White rounded container used by every Monitor card.
struct MonitorCard<Content: View>: View {
    var radius: CGFloat = 24
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Outlined circle or rounded square holding an icon.
struct OutlinedIcon: View {
    let icon: SSIcon
    var size: CGFloat = 32
    var iconSize: CGFloat = 16
    var cornerRadius: CGFloat?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius ?? size / 2, style: .continuous)
        SSIconView(icon, size: iconSize, color: Color(hex: 0x292D32))
            .frame(width: size, height: size)
            .overlay(shape.strokeBorder(SSColor.border, lineWidth: 1))
    }
}

/// Outlined pill with a coloured dot. The text carries the meaning.
struct MetricStatus: View {
    let title: String
    var dot: Color = SSColor.statusGreen

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(title)
                .ssText(.chip12)
                .foregroundStyle(SSColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Large figure with a smaller unit on the same baseline.
struct MetricValue: View {
    enum Size {
        case large
        case medium
        case small
        case compact
    }

    let value: String
    let unit: String
    var size: Size = .large

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            switch size {
            case .large:
                Text(value).ssText(.metric48)
                Text(unit).ssText(.unit24)
            case .medium:
                Text(value).ssText(.metric40)
                Text(unit).ssText(.unit20)
            case .small:
                Text(value).ssText(.metric36)
                Text(unit).ssText(.unit18)
            case .compact:
                Text(value).ssText(.metric28)
                Text(unit).ssText(.labelSemibold14)
            }
        }
        .foregroundStyle(SSColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(value) \(unit)"))
    }
}

/// Title, small caption and icon chip at the top of a resource tile.
struct TileHeader: View {
    let title: String
    let caption: String?
    let icon: SSIcon

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textLabel)
                if let caption {
                    Text(caption)
                        .ssText(.micro10)
                        .foregroundStyle(SSColor.textFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 4)
            OutlinedIcon(icon: icon)
        }
    }
}

/// The body of a tile whose reading could not be obtained: a labelled state with a
/// reason, never a zero.
struct TileUnavailable: View {
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricStatus(title: Strings.unavailable, dot: SSColor.textMuted)
            Text(reason)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textSubtle)
        }
    }
}

struct TileCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .ssText(.captionMedium12)
            .foregroundStyle(SSColor.textSubtle)
    }
}

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .ssText(.section18)
                .foregroundStyle(SSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(Strings.viewAll)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(minHeight: 24)
    }
}

/// Title and explanation shown where a section has nothing to list yet.
struct EmptyNote: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .ssText(.rowTitle15)
                .foregroundStyle(SSColor.textPrimary)
            Text(detail)
                .ssText(.bodyMedium13)
                .foregroundStyle(SSColor.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Line chart for a stored series. Each run of readings is a solid line; a period
/// with no readings is a dashed grey bridge, so a gap never reads as data.
struct TrendChart: View {
    let trend: MonitorTrend

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let values = trend.segments.flatMap { $0 }.map(\.value)
            let low = (values.min() ?? 0)
            let high = (values.max() ?? 1)
            let span = max(high - low, 1)
            let point: (MonitorTrend.Point) -> CGPoint = { item in
                // 12% headroom above and below keeps the line off the edges.
                let fraction = (item.value - low) / span
                return CGPoint(x: item.position * size.width, y: size.height * (0.88 - fraction * 0.76))
            }

            ZStack {
                ForEach([0.24, 0.58, 0.91], id: \.self) { line in
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                        .position(x: size.width / 2, y: size.height * line)
                }

                ForEach(Array(trend.segments.enumerated()), id: \.offset) { index, segment in
                    Path { path in
                        path.addLines(segment.map(point))
                    }
                    .stroke(SSColor.chartGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if index + 1 < trend.segments.count,
                       let end = segment.last, let next = trend.segments[index + 1].first {
                        Path { path in
                            path.move(to: point(end))
                            path.addLine(to: point(next))
                        }
                        .stroke(SSColor.textFaint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
                    }
                }

                if let last = trend.segments.last?.last {
                    Circle()
                        .fill(SSColor.chartGreen)
                        .frame(width: 6, height: 6)
                        .position(point(last))
                }
            }
        }
        .frame(height: 90)
    }
}

/// Grey placeholder block for the loading state.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(SSColor.hairline)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
