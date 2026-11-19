import Core
import DesignSystem
import DeviceInfo
import SwiftUI
import UIKit

enum MonitorFormat {
    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(seconds)).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
    }

    static func gigabytes(_ bytes: UInt64) -> String {
        (Double(bytes) / 1_073_741_824).formatted(.number.precision(.fractionLength(1)))
    }

    static func memory(_ bytes: UInt64) -> String {
        Int64(clamping: bytes).formatted(.byteCount(style: .memory))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func timeWithSeconds(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    /// Splits "312 MB" into ("312", "MB") for a figure with a smaller unit.
    static func split(_ formatted: String) -> (String, String) {
        let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : (formatted, "")
    }

    static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}

/// Large figure with a smaller unit, sized for the metric screens.
struct DetailFigure: View {
    enum Size {
        case large
        case medium
        case small
    }

    let value: String
    let unit: String
    var size: Size = .large
    var color: Color = SSColor.textPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            switch size {
            case .large:
                Text(value).ssText(.metric56)
                Text(unit).ssText(.unit28)
            case .medium:
                Text(value).ssText(.metric52)
                Text(unit).ssText(.unit26)
            case .small:
                Text(value).ssText(.metric32)
                Text(unit).ssText(.unit16)
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(value) \(unit)"))
    }
}

// MARK: - MON-02 · CPU

struct CPUMonitorView: View {
    @Bindable var model: MonitorModel
    @State private var copied = false

    private var summary: DeviceSummary { model.summary }

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.cpuTitle, subtitle: Strings.cpuSubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            SectionHeader(title: Strings.processor)
            SpecCard(rows: [
                SpecRow(label: Strings.chip, value: summary.processor),
                SpecRow(label: Strings.architecture, value: MonitorFormat.architecture),
                SpecRow(label: Strings.totalCores, value: totalCores),
                SpecRow(label: Strings.activeCores, value: summary.activeCoreCount.map { "\($0)" }),
                SpecRow(label: Strings.physicalRAM, value: summary.physicalMemoryBytes.map { ByteFormatting.memory($0) }),
            ])
            appCPUCard
            PlatformNote(text: Strings.appOnlyNote)
            SectionHeader(title: Strings.activity)
            activityChart
            MonitorCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Strings.cpuTimeUsed)
                        .ssText(.bodyMedium13)
                        .foregroundStyle(SSColor.textSubtle)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text((model.sessionCPUTime ?? 0).formatted(.number.precision(.fractionLength(1))))
                            .ssText(.metric28)
                        Text(Strings.secondsThisSession)
                            .ssText(.labelSemibold14)
                    }
                    .foregroundStyle(SSColor.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
            SectionHeader(title: Strings.sessionHistory)
            MonitorCard { EmptyNote(title: Strings.noSessions, detail: Strings.noSessionsDetail) }
            TechnicalDetails(
                caption: Strings.cpuTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.source, value: Strings.cpuSource),
                    SpecRow(label: Strings.scope, value: Strings.thisApp),
                    SpecRow(label: Strings.sampling, value: Strings.cpuSampling),
                    SpecRow(label: Strings.measured, value: model.cpuSamples.last.map { MonitorFormat.timeWithSeconds($0.date) }),
                ],
                limitation: Strings.cpuLimitation
            )
        }
    }

    private var totalCores: String? {
        guard let total = summary.processorCoreCount else { return nil }
        if let performance = summary.performanceCoreCount, let efficiency = summary.efficiencyCoreCount {
            return Strings.coreDescription(total, performance, efficiency)
        }
        return "\(total)"
    }

    private var appCPUCard: some View {
        MonitorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Text(Strings.appCPU)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textLabel)
                        SSIconView(.info, size: 16, color: SSColor.textFaint)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(Strings.appCPU))
                    .accessibilityHint(Text(Strings.appCPUInfo))
                    Spacer()
                    if let latest = model.latestCPU {
                        MetricStatus(title: level(latest).title, dot: level(latest).color)
                    }
                }
                if let latest = model.latestCPU {
                    HStack(alignment: .bottom) {
                        DetailFigure(value: "\(Int(latest.rounded()))", unit: "%")
                        Spacer()
                        Button {
                            UIPasteboard.general.string = MonitorFormat.percent(latest)
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                SSIconView(copied ? .tickCircle : .copy, size: 14, color: SSColor.textPrimary)
                                Text(copied ? Strings.copied : Strings.copy)
                                    .ssText(.chip12)
                                    .foregroundStyle(SSColor.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(SSColor.hairline, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(Strings.collectingReadings)
                            .ssText(.bodyMedium13)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                    .frame(minHeight: 56, alignment: .leading)
                }
                HStack(spacing: 8) {
                    StatBox(label: Strings.session, value: model.sessionStart.map { MonitorFormat.duration(Date.now.timeIntervalSince($0)) })
                    StatBox(label: Strings.average, value: model.averageCPU.map(MonitorFormat.percent))
                    StatBox(label: Strings.peak, value: model.peakCPU.map(MonitorFormat.percent))
                }
                DataTimestamp(text: "\(Strings.updatedJustNow) · \(Strings.liveSession)")
            }
        }
    }

    private func level(_ percent: Double) -> (title: String, color: Color) {
        switch percent {
        case ..<20: (Strings.low, SSColor.statusGreen)
        case ..<50: (Strings.moderate, SSColor.statusAmber)
        default: (Strings.high, SSColor.coral)
        }
    }

    private var activityChart: some View {
        MonitorCard {
            VStack(alignment: .leading, spacing: 14) {
                SegmentedSelector(options: CPURange.allCases, selection: $model.cpuRange) { $0.title }
                if model.cpuSamples.count >= 2 {
                    LiveLineChart(
                        points: model.cpuSamples.map { .init(date: $0.date, value: $0.percent) },
                        window: model.cpuRange.window,
                        range: 0...max((model.peakCPU ?? 0) * 1.25, 10),
                        average: model.averageCPU,
                        tint: SSColor.accent
                    )
                } else {
                    collecting
                }
                TimeAxis(labels: TimeAxis.labels(window: model.cpuRange.window, step: model.cpuRange.tickStep))
                HStack(spacing: 14) {
                    LegendItem(mark: .line(SSColor.accent), title: Strings.appActivity)
                    LegendItem(mark: .dashed(SSColor.textMuted), title: Strings.sessionAverage)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Strings.cpuSummary(
            model.latestCPU.map(MonitorFormat.percent) ?? Strings.unavailable,
            model.averageCPU.map(MonitorFormat.percent) ?? Strings.unavailable,
            model.peakCPU.map(MonitorFormat.percent) ?? Strings.unavailable
        )))
    }

    private var collecting: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(Strings.collectingReadings)
                .ssText(.bodyMedium13)
                .foregroundStyle(SSColor.textSubtle)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
    }
}

extension CPURange {
    var title: String {
        switch self {
        case .live: Strings.live
        case .fiveMinutes: Strings.fiveMinutes
        case .fifteenMinutes: Strings.fifteenMinutes
        case .hour: Strings.oneHour
        }
    }
}

extension HistoryRange {
    var title: String {
        switch self {
        case .live: Strings.live
        case .today: Strings.today
        case .week: Strings.sevenDays
        case .month: Strings.thirtyDays
        }
    }
}

// MARK: - MON-03 · Memory

struct MemoryMonitorView: View {
    @Bindable var model: MonitorModel

    private let liveWindow: TimeInterval = 60

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.memory, subtitle: Strings.memorySubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            inUseCard
            SectionHeader(title: Strings.memoryInUse)
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedSelector(options: HistoryRange.allCases, selection: $model.memoryRange) { $0.title }
                    if model.memoryRange == .live {
                        liveChart
                    } else {
                        InsufficientHistoryNote()
                    }
                }
            }
            SectionHeader(title: Strings.appDiagnostics)
            appCard
            TechnicalDetails(
                caption: Strings.cpuTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.currentFootprint, value: model.appResources?.footprintBytes.map(MonitorFormat.memory)),
                    SpecRow(label: Strings.availableProcessMemory, value: model.appResources?.availableBytes.map { "≈ \(ByteFormatting.memory($0, fractionDigits: 1))" }),
                    SpecRow(label: Strings.peakFootprint, value: model.peakFootprintBytes.map(MonitorFormat.memory)),
                    SpecRow(label: Strings.lastMemoryWarning, value: model.lastMemoryWarning.map(MonitorFormat.time) ?? Strings.noneThisSession),
                    SpecRow(label: Strings.source, value: Strings.memorySource),
                    SpecRow(label: Strings.measured, value: model.appResources.map { MonitorFormat.timeWithSeconds($0.observedAt) }),
                ],
                limitation: Strings.memoryLimitation
            )
            SectionHeader(title: Strings.historicalObservations)
            MonitorCard { EmptyNote(title: Strings.noObservations, detail: Strings.noObservationsDetail) }
        }
    }

    private var inUseCard: some View {
        MonitorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(Strings.memoryInUse)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textLabel)
                    Spacer()
                    MetricStatus(title: Strings.thisIPhone, dot: SSColor.accent)
                }
                if let breakdown = model.memoryBreakdown {
                    VStack(alignment: .leading, spacing: 6) {
                        DetailFigure(value: MonitorFormat.gigabytes(breakdown.inUseBytes), unit: "GB")
                        if let total = model.summary.physicalMemoryBytes {
                            Text(Strings.thisIPhoneOf(ByteFormatting.memory(total)))
                                .ssText(.bodyMedium13)
                                .foregroundStyle(SSColor.textSubtle)
                        }
                    }
                    HStack(spacing: 8) {
                        StatBox(label: Strings.wired, value: "\(MonitorFormat.gigabytes(breakdown.wiredBytes)) GB")
                        StatBox(label: Strings.active, value: "\(MonitorFormat.gigabytes(breakdown.activeBytes)) GB")
                        StatBox(label: Strings.compressed, value: "\(MonitorFormat.gigabytes(breakdown.compressedBytes)) GB")
                    }
                    DataTimestamp(text: Strings.updatedJustNow)
                } else {
                    TileUnavailable(reason: Strings.memoryUnavailableDetail)
                }
            }
        }
    }

    @ViewBuilder
    private var liveChart: some View {
        let values = model.memorySamples.map { Double($0.inUseBytes) }
        if values.count >= 2, let low = values.min(), let high = values.max() {
            let padding = max((high - low) * 0.4, 50_000_000)
            LiveLineChart(
                points: model.memorySamples.map { .init(date: $0.date, value: Double($0.inUseBytes)) },
                window: liveWindow,
                range: (low - padding)...(high + padding),
                average: model.averageMemory.map(Double.init),
                tint: SSColor.footprintPurple
            )
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(Strings.collectingReadings)
                    .ssText(.bodyMedium13)
                    .foregroundStyle(SSColor.textSubtle)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
        }
        TimeAxis(labels: TimeAxis.labels(window: liveWindow, step: 15))
        HStack(spacing: 14) {
            LegendItem(mark: .line(SSColor.footprintPurple), title: Strings.inUse)
            LegendItem(mark: .dashed(SSColor.textMuted), title: Strings.average)
        }
    }

    /// SystemScope's own footprint against physical RAM. The rest of the bar is not a
    /// reading: iOS doesn't show apps what other processes use.
    private var appCard: some View {
        MonitorCard {
            VStack(alignment: .leading, spacing: 12) {
                if let footprint = model.appResources?.footprintBytes {
                    let (value, unit) = MonitorFormat.split(MonitorFormat.memory(footprint))
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Strings.appFootprint)
                                .ssText(.bodyMedium13)
                                .foregroundStyle(SSColor.textSubtle)
                            DetailFigure(value: value, unit: unit, size: .small)
                        }
                        Spacer()
                        if let peak = model.peakFootprintBytes {
                            Text(Strings.peakValue(MonitorFormat.memory(peak)))
                                .ssText(.captionMedium13)
                                .foregroundStyle(SSColor.textFaint)
                        }
                    }
                    GeometryReader { proxy in
                        let total = Double(model.summary.physicalMemoryBytes ?? footprint)
                        Capsule()
                            .fill(SSColor.hairline)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(SSColor.footprintPurple)
                                    .frame(width: max(14, proxy.size.width * Double(footprint) / total))
                            }
                    }
                    .frame(height: 12)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        LegendItem(mark: .swatch(SSColor.footprintPurple), title: Strings.systemScopeUses(MonitorFormat.memory(footprint)))
                        LegendItem(mark: .swatch(SSColor.track), title: Strings.restOfIPhone)
                    }
                } else {
                    Text(Strings.appFootprint)
                        .ssText(.bodyMedium13)
                        .foregroundStyle(SSColor.textSubtle)
                    TileUnavailable(reason: Strings.memoryUnavailableDetail)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
