import Core
import DesignSystem
import DeviceInfo
import SwiftUI

// MARK: - MON-04 · GPU

struct GPUMonitorView: View {
    @Bindable var model: MonitorModel

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.gpu, subtitle: Strings.gpuSubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            capabilityCard
            CalloutCard(icon: .info, title: Strings.noLiveGPU, message: Strings.noLiveGPUDetail, tint: SSColor.infoBlue)
            SectionHeader(title: Strings.performanceReports)
            MonitorCard { EmptyNote(title: Strings.noReports, detail: Strings.noReportsDetail) }
            PlatformNote(text: Strings.reportsNote)
            SectionHeader(title: Strings.metalCompatibility)
            SpecCard(rows: [
                SpecRow(label: Strings.metalVersion, value: metalTitle),
                SpecRow(label: Strings.gpuFamilies, value: gpu?.families.isEmpty == false ? gpu?.families.joined(separator: " · ") : nil),
                SpecRow(label: Strings.unifiedMemory, value: gpu.map { $0.supportedCapabilities.contains(.unifiedMemory) ? Strings.yes : Strings.no }),
                SpecRow(label: Strings.maxThreads, value: gpu?.maxThreadsPerThreadgroup.map { $0.formatted() }),
                SpecRow(label: Strings.rayTracing, value: gpu.map { $0.supportedCapabilities.contains(.rayTracing) ? Strings.supported : Strings.notSupported }),
                SpecRow(label: Strings.rasterOrderGroups, value: gpu?.supportsRasterOrderGroups.map { $0 ? Strings.supported : Strings.notSupported }),
            ])
            TechnicalDetails(
                caption: Strings.gpuTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.source, value: "MTLCreateSystemDefaultDevice"),
                    SpecRow(label: Strings.scope, value: Strings.deviceSpecification),
                    SpecRow(label: Strings.workingSet, value: gpu?.recommendedMaxWorkingSetBytes.map { MonitorFormat.memory($0) }),
                    SpecRow(label: Strings.measured, value: gpu.map { MonitorFormat.timeWithSeconds($0.observedAt) }),
                ]
            )
        }
    }

    private var gpu: GPUInformation? { model.gpu }

    private var metalTitle: String? {
        guard let gpu, gpu.metalAvailable else { return nil }
        return gpu.supportedCapabilities.contains(.metal3) ? Strings.metal3 : Strings.metal
    }

    @ViewBuilder
    private var capabilityCard: some View {
        if let gpu, gpu.metalAvailable, let metalTitle {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(gpu.name ?? Strings.gpu)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Circle().fill(SSColor.statusGreen).frame(width: 8, height: 8)
                        Text(Strings.supported).ssText(.chip12).foregroundStyle(.white)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(metalTitle)
                        .ssText(.metric48)
                        .foregroundStyle(.white)
                    if let family = gpu.appleFamily {
                        Text(Strings.gpuFamily(family))
                            .ssText(.bodyMedium13)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                let chips = gpu.supportedCapabilities.compactMap(\.chipTitle)
                if !chips.isEmpty {
                    SSFlowLayout(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            HStack(spacing: 5) {
                                SSIconView(.tickCircle, size: 13, color: SSColor.positiveFill)
                                Text(chip).ssText(.chip12).foregroundStyle(.white)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 10)
                            .padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111214)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        } else {
            MonitorCard { TileUnavailable(reason: Strings.gpuUnavailable) }
        }
    }
}

extension GPUInformation {
    var appleFamily: Int? {
        for capability in supportedCapabilities {
            if case let .appleFamily(number) = capability { return number }
        }
        return nil
    }
}

private extension GPUCapability {
    /// Capabilities worth a chip; the family and Metal version are shown above them.
    var chipTitle: String? {
        switch self {
        case .appleFamily, .metal3: nil
        case .rayTracing: Strings.capabilityRayTracing
        case .unifiedMemory: Strings.capabilityUnifiedMemory
        case .float32Filtering: Strings.capabilityFloatFiltering
        case .bcTextureCompression: Strings.capabilityBC
        }
    }
}

// MARK: - MON-05 · Storage

struct StorageMonitorView: View {
    @Bindable var model: MonitorModel
    @State private var range: MonitorTrendRange = .week

    private var summary: DeviceSummary { model.summary }

    var body: some View {
        let free = summary.storageAvailableBytes
        let total = summary.storageTotalBytes
        DetailPage {
            DetailHeader(title: Strings.storage, subtitle: Strings.storageSubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            usageCard
            HStack(spacing: 8) {
                StatBox(label: Strings.availableLabel, value: free.map { ByteFormatting.storage($0) }, filled: true)
                StatBox(label: Strings.totalVolume, value: total.map { ByteFormatting.storage($0, fractionDigits: 0) }, filled: true)
                StatBox(label: Strings.thisWeek, value: nil, fallback: Strings.noHistory, filled: true)
            }
            PlatformNote(text: Strings.storageNote)
            SectionHeader(title: Strings.usageTrend)
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedSelector(options: MonitorTrendRange.allCases, selection: $range) { $0.title }
                    InsufficientHistoryNote()
                }
            }
            if let free, let total, total > 0, Double(free) / Double(total) <= MonitorRecommendation.storageReviewThreshold {
                SectionHeader(title: Strings.recommendations)
                RecommendationList(items: [
                    .init(title: Strings.reviewLargeFiles, detail: Strings.reviewLargeFilesDetail),
                    .init(title: Strings.reviewDownloads, detail: Strings.reviewDownloadsDetail),
                ])
            }
            TechnicalDetails(
                caption: Strings.storageTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.source, value: Strings.storageSource),
                    SpecRow(label: Strings.scope, value: Strings.thisIPhone),
                    SpecRow(label: Strings.measured, value: model.lastUpdated.map(MonitorFormat.timeWithSeconds)),
                ]
            )
        }
    }

    @ViewBuilder
    private var usageCard: some View {
        MonitorCard {
            if let free = summary.storageAvailableBytes, let total = summary.storageTotalBytes, total > 0 {
                let used = max(0, total - free)
                let fraction = min(1, Double(used) / Double(total))
                let (value, unit) = MonitorFormat.split(ByteFormatting.storage(used))
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(Strings.estimatedUsed)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textLabel)
                        Spacer()
                        MetricStatus(
                            title: Strings.percentUsedValue(Int((fraction * 100).rounded())),
                            dot: 1 - fraction <= DeviceHealthThreshold.lowStorage ? SSColor.statusAmber : SSColor.statusGreen
                        )
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        DetailFigure(value: value, unit: unit, size: .medium)
                        Text(Strings.ofTotal(ByteFormatting.storage(total, fractionDigits: 0)))
                            .ssText(.value16)
                            .foregroundStyle(SSColor.textFaint)
                            .lineLimit(1)
                    }
                    GeometryReader { proxy in
                        HStack(spacing: 4) {
                            Capsule().fill(SSColor.ink).frame(width: max(16, (proxy.size.width - 4) * fraction))
                            Capsule().fill(SSColor.track)
                        }
                    }
                    .frame(height: 16)
                    .accessibilityHidden(true)
                    HStack(spacing: 16) {
                        LegendItem(mark: .swatch(SSColor.ink), title: Strings.usedLegend(ByteFormatting.storage(used)))
                        LegendItem(mark: .swatch(SSColor.track), title: Strings.availableLegend(ByteFormatting.storage(free)))
                    }
                    DataTimestamp(text: Strings.updatedJustNow)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Strings.estimatedUsed)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textLabel)
                    TileUnavailable(reason: Strings.storageUnavailable)
                }
            }
        }
    }
}

/// Thresholds shared with the Home and alert rules (PRD §8.5).
enum DeviceHealthThreshold {
    static let lowStorage = 0.10
    static let lowBattery = 0.20
}

extension MonitorTrendRange {
    var title: String {
        switch self {
        case .today: Strings.today
        case .week: Strings.sevenDays
        case .month: Strings.thirtyDays
        }
    }
}

// MARK: - MON-06 · Battery

struct BatteryMonitorView: View {
    @Bindable var model: MonitorModel
    @State private var range: MonitorTrendRange = .today

    private var reading: BatterySnapshot { model.batterySnapshot }

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.battery, subtitle: Strings.batterySubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            levelCard
            SectionHeader(title: Strings.batteryActivity)
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedSelector(options: MonitorTrendRange.allCases, selection: $range) { $0.title }
                    InsufficientHistoryNote()
                }
            }
            SectionHeader(title: Strings.batteryInformation)
            SpecCard(rows: [
                SpecRow(label: Strings.batteryState, value: stateTitle),
                SpecRow(label: Strings.level, value: reading.level.map { "\($0)%" }),
                SpecRow(label: Strings.lowPowerMode, value: reading.isLowPowerModeEnabled ? Strings.on : Strings.off),
                SpecRow(label: Strings.batteryHealth, value: Strings.inSettings, valueColor: SSColor.textSubtle),
            ])
            PlatformNote(text: Strings.batteryNote)
            if let level = reading.level, Double(level) / 100 <= DeviceHealthThreshold.lowBattery,
               reading.state == .unplugged, !reading.isLowPowerModeEnabled {
                SectionHeader(title: Strings.recommendations)
                RecommendationList(items: [.init(title: Strings.lowPowerRecommendation, detail: Strings.lowPowerRecommendationDetail)])
            }
            TechnicalDetails(
                caption: Strings.batteryTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.source, value: Strings.batterySource),
                    SpecRow(label: Strings.scope, value: Strings.thisIPhone),
                    SpecRow(label: Strings.sampling, value: Strings.batterySampling),
                    SpecRow(label: Strings.measured, value: MonitorFormat.timeWithSeconds(reading.observedAt)),
                ]
            )
        }
    }

    private var stateTitle: String? {
        switch reading.state {
        case .charging: Strings.charging
        case .full: Strings.fullyCharged
        case .unplugged: Strings.notCharging
        case nil: nil
        }
    }

    @ViewBuilder
    private var levelCard: some View {
        if let level = reading.level {
            let fraction = Double(level) / 100
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(Strings.batteryLevel)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        if reading.state == .charging {
                            SSIconView(.bolt, size: 12, color: SSColor.chargingGreen)
                        }
                        Text(stateTitle ?? Strings.unknown)
                            .ssText(.chip12)
                            .foregroundStyle(.black)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 10)
                    .padding(.vertical, 4)
                    .background(.white, in: Capsule())
                }
                HStack(spacing: 4) {
                    GeometryReader { proxy in
                        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
                        ZStack(alignment: .leading) {
                            shape.fill(.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.3))
                                .frame(width: max(24, (proxy.size.width - 10) * fraction))
                                .padding(5)
                            DetailFigure(value: "\(level)", unit: "%", color: .white)
                                .padding(.leading, 21)
                        }
                        .overlay(shape.strokeBorder(.white.opacity(0.7), lineWidth: 3))
                    }
                    .frame(height: 112)
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.7)).frame(width: 6, height: 34)
                }
                HStack(spacing: 8) {
                    whiteStat(Strings.state, stateTitle ?? Strings.unknown)
                    whiteStat(Strings.lowPowerMode, reading.isLowPowerModeEnabled ? Strings.on : Strings.off)
                    whiteStat(Strings.updated, MonitorFormat.time(reading.observedAt))
                }
                DataTimestamp(text: Strings.updatedJustNow, color: .white.opacity(0.85))
            }
            .padding(18)
            .background(
                LinearGradient(colors: [Color(hex: 0x6FDC8C), Color(hex: 0x22A04B)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        } else {
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Strings.batteryLevel)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textLabel)
                    TileUnavailable(reason: Strings.batteryUnavailable)
                }
            }
        }
    }

    private func whiteStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).ssText(.captionMedium12).opacity(0.8)
            Text(value).ssText(.stat16)
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
