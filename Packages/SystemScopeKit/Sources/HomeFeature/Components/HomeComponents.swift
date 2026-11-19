import DesignSystem
import DeviceInfo
import SwiftUI

enum Format {
    static func mbps(_ value: Double?) -> String? {
        value.map { Strings.mbps($0.formatted(.number.precision(.fractionLength(0...1)))) }
    }

    static func milliseconds(_ value: Double?) -> String? {
        value.map { Strings.milliseconds($0.formatted(.number.precision(.fractionLength(0...1)))) }
    }

    static func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file))
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

extension NetworkInterfaceKind {
    var title: String {
        switch self {
        case .wifi: Strings.wifi
        case .cellular: Strings.cellular
        case .wired: Strings.ethernet
        case .other: Strings.otherNetwork
        }
    }
}

/// Back button with an optional trailing text action.
struct HomeTopBar: View {
    let onBack: () -> Void
    var trailingTitle: String?
    var onTrailing: (() -> Void)?

    var body: some View {
        HStack {
            SSBackButton(label: Strings.back, action: onBack)
                .padding(.leading, -6)
            Spacer()
            if let trailingTitle, let onTrailing {
                Button(action: onTrailing) {
                    Text(trailingTitle)
                        .ssText(.section18)
                        .foregroundStyle(SSColor.textPrimary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }
}

/// Text items separated by small dots, e.g. "iPhone 15 Pro • A17 Pro • 16 GB".
struct DotSeparated: View {
    let items: [String]
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Circle()
                        .fill(SSColor.track)
                        .frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                }
                Text(item)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Coloured dot plus label. The label carries the meaning; colour is secondary.
struct StatusPill: View {
    let title: String
    var dot: Color = SSColor.statusGreen
    var surface: Color = SSColor.statusGreenSurface

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
            Text(title)
                .ssText(.chip12)
                .foregroundStyle(SSColor.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// White rounded card used across Home.
struct HomeCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
    }
}

/// Stacked usage bars: total traffic behind, downloaded share in front.
struct UsageBars: View {
    let series: DataUsageSeries
    let height: CGFloat
    let summary: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(series.bars.enumerated()), id: \.offset) { _, bar in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SSColor.lilac)
                        .frame(height: max(4, height * bar.total))
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(SSColor.accent)
                                .frame(height: max(2, height * bar.download))
                        }
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .bottom)

            HStack(spacing: 10) {
                ForEach(series.axisLabels, id: \.self) { label in
                    Text(label)
                        .ssText(.axis12)
                        .foregroundStyle(SSColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary))
    }
}

/// Shown instead of a chart when there is not enough recorded history (MON-06).
struct InsufficientHistory: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Strings.insufficientHistory)
                .ssText(.labelSemibold14)
                .foregroundStyle(SSColor.textPrimary)
            Text(Strings.insufficientHistoryDetail)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One labelled value with an optional arrow chip, as in the speed rows.
struct StatCell: View {
    let label: String
    let value: String?
    var fallback: String = Strings.notTested
    var chip: SSIcon?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
                Text(value ?? fallback)
                    .ssText(.value16)
                    .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let chip {
                SSIconChip(chip, tint: .black, fill: Color.black.opacity(0.05))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(SSColor.borderStrong)
            .frame(width: 1, height: 34)
            .accessibilityHidden(true)
    }
}

/// Download and upload side by side.
struct SpeedRow: View {
    let downloadMbps: Double?
    let uploadMbps: Double?
    var fallback: String = Strings.notTested

    var body: some View {
        HStack(spacing: 12) {
            StatCell(label: Strings.download, value: Format.mbps(downloadMbps), fallback: fallback, chip: .arrowDown)
            StatDivider()
            StatCell(label: Strings.upload, value: Format.mbps(uploadMbps), fallback: fallback, chip: .arrowUp)
        }
        .padding(10)
    }
}
