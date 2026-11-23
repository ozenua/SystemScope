import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// MON-01 · Monitor overview: current device readings, then alerts, trends, recent
/// activity and recommendations.
public struct MonitorView: View {
    @Bindable private var model: MonitorModel
    private let isActive: Bool
    private let onOpenActivity: () -> Void
    private let onRunSpeedTest: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter isActive: whether the Monitor tab is the one on screen. Readings are
    ///   only refreshed while it is (MON-03).
    public init(
        model: MonitorModel,
        isActive: Bool,
        onOpenActivity: @escaping () -> Void,
        onRunSpeedTest: @escaping () -> Void
    ) {
        self.model = model
        self.isActive = isActive
        self.onOpenActivity = onOpenActivity
        self.onRunSpeedTest = onRunSpeedTest
    }

    private var isMonitoring: Bool { isActive && scenePhase == .active }

    public var body: some View {
        NavigationStack(path: $model.path) {
            overview
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MonitorRoute.self) { route in
                    Group {
                        switch route {
                        case .cpu: CPUMonitorView(model: model)
                        case .memory: MemoryMonitorView(model: model)
                        case .gpu: GPUMonitorView(model: model)
                        case .storage: StorageMonitorView(model: model)
                        case .battery: BatteryMonitorView(model: model)
                        case .thermal: ThermalMonitorView(model: model)
                        case .network: NetworkMonitorView(model: model, onRunSpeedTest: onRunSpeedTest)
                        }
                    }
                    .ssFadeInNavigationDestination()
                }
        }
        .backSwipe { model.goBack() }
        // One live session while the Monitor tab is visible and the app is active
        // (PRD §7.5, §9). It continues across Monitor screens and ends on leaving.
        .task(id: isMonitoring) {
            guard isMonitoring else { return }
            await model.runSession()
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if model.hasLoaded {
                    if model.isRefreshing { refreshingBanner }
                    deviceCard
                    resourceCards
                    alertsSection
                    if model.userSettings().showHistoricalTrends { trendsSection }
                    activitySection
                    recommendedSection
                } else {
                    loading
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .refreshable { await model.refresh() }
        .background(SSScreenBackground())
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.title)
                    .ssText(.pageTitle28)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Strings.subtitle)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Group {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        SSIconView(.refresh, size: 20, color: Color(hex: 0x292D32))
                    }
                }
                .frame(width: 40, height: 40)
                .background(SSColor.hairline, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.isRefreshing)
            .accessibilityLabel(Text(Strings.refresh))
        }
    }

    private var refreshingBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            ProgressView().controlSize(.mini)
            Text(Strings.refreshing)
                .ssText(.bodyMedium13)
                .foregroundStyle(SSColor.meterBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Device

    private var deviceCard: some View {
        MonitorCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    OutlinedIcon(icon: .mobile, size: 44, iconSize: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .ssText(.value16)
                            .foregroundStyle(SSColor.textPrimary)
                        Text(deviceSubtitle)
                            .ssText(.bodyMedium13)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    MetricStatus(
                        title: isMonitoring ? Strings.monitoringActive : Strings.monitoringPaused,
                        dot: isMonitoring ? SSColor.statusGreen : SSColor.textMuted
                    )
                    .fixedSize()
                }
                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                HStack {
                    HStack(spacing: 6) {
                        SSIconView(.clock, size: 14, color: SSColor.textFaint)
                        Text(Strings.lastUpdate(model.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—"))
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                    }
                    Spacer(minLength: 8)
                    Text(Strings.standardMonitoring)
                        .ssText(.captionMedium12)
                        .foregroundStyle(SSColor.textFaint)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
    }

    private var deviceSubtitle: String {
        [model.summary.modelName ?? Strings.unknownModel, model.summary.osVersion.map(Strings.iosVersion)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - Resource cards

    private var summary: DeviceSummary { model.summary }

    private func isVisible(_ route: MonitorRoute) -> Bool {
        !model.userSettings().hiddenMonitorTiles.contains(route.rawValue)
    }

    /// Tiles in Figma order. A hidden tile's partner takes the full row (SET-03).
    private var resourceCards: some View {
        VStack(spacing: 8) {
            pair(.cpu, processorTile, .memory, memoryTile)
            pair(.battery, batteryTile, .thermal, thermalTile)
            if isVisible(.storage) { storageTile }
            pair(.gpu, gpuTile, .network, networkTile)
        }
    }

    @ViewBuilder
    private func pair(_ first: MonitorRoute, _ a: some View, _ second: MonitorRoute, _ b: some View) -> some View {
        let showFirst = isVisible(first), showSecond = isVisible(second)
        if showFirst || showSecond {
            HStack(spacing: 8) {
                if showFirst { a }
                if showSecond { b }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(
        _ route: MonitorRoute,
        _ title: String,
        _ caption: String?,
        _ icon: SSIcon,
        @ViewBuilder content: () -> some View
    ) -> some View {
        Button {
            model.open(route)
        } label: {
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    TileHeader(title: title, caption: caption, icon: icon)
                    content()
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var processorTile: some View {
        tile(.cpu, Strings.processor, Strings.deviceSpec, .cpu) {
            if let cores = summary.processorCoreCount {
                MetricValue(value: "\(cores)", unit: Strings.cores)
                Spacer(minLength: 0)
                if let detail = processorDetail { TileCaption(text: detail) }
            } else {
                TileUnavailable(reason: Strings.processorUnavailable)
            }
        }
    }

    private var processorDetail: String? {
        let chip = summary.processor?.replacingOccurrences(of: "Apple ", with: "")
        var split: String?
        if let performance = summary.performanceCoreCount, let efficiency = summary.efficiencyCoreCount {
            split = Strings.coreSplit(performance, efficiency)
        }
        let parts = [chip, split].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var memoryTile: some View {
        tile(.memory, Strings.memory, Strings.thisIPhone, .cpuSetting) {
            if let used = summary.memoryInUseBytes, let total = summary.physicalMemoryBytes, total > 0 {
                let fraction = min(1, Double(used) / Double(total))
                MetricValue(value: gigabytes(Double(used) / 1_073_741_824), unit: "GB")
                HStack(spacing: 2) {
                    ForEach(0..<24, id: \.self) { index in
                        Capsule()
                            .fill(index < Int((fraction * 24).rounded()) ? SSColor.meterBlue : SSColor.border)
                            .frame(width: 4, height: 28)
                    }
                }
                .accessibilityHidden(true)
                TileCaption(text: Strings.inUseOf(ByteFormatting.memory(total)))
            } else {
                TileUnavailable(reason: Strings.memoryUnavailable)
            }
        }
    }

    private var batteryTile: some View {
        tile(.battery, Strings.battery, Strings.level, .battery) {
            if let level = summary.batteryLevel {
                MetricValue(value: "\(Int((level * 100).rounded()))", unit: "%")
                HStack(spacing: 4) {
                    if summary.batteryState == .charging {
                        SSIconView(.bolt, size: 12, color: SSColor.chargingGreen)
                    }
                    Text(batteryStateTitle)
                        .ssText(.chip12)
                        .foregroundStyle(summary.batteryState == .charging ? SSColor.chargingGreen : SSColor.textSubtle)
                }
            } else {
                TileUnavailable(reason: Strings.batteryUnavailable)
            }
        }
    }

    private var batteryStateTitle: String {
        switch summary.batteryState {
        case .charging: Strings.charging
        case .full: Strings.fullyCharged
        case .unplugged, nil: Strings.notCharging
        }
    }

    /// The iOS thermal state only; never a temperature (PRD §2.6).
    private var thermalTile: some View {
        tile(.thermal, Strings.thermal, Strings.systemState, .cpuCharge) {
            if let state = summary.thermalState {
                Text(state.title)
                    .ssText(.metric32)
                    .foregroundStyle(SSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                MetricStatus(title: state.statusTitle, dot: state.statusColor)
            } else {
                TileUnavailable(reason: Strings.thermalUnavailable)
            }
        }
    }

    private var storageTile: some View {
        let free = summary.storageAvailableBytes
        let total = summary.storageTotalBytes
        let used = free.flatMap { free in total.map { max(0, $0 - free) } }
        let caption = used.flatMap { used in
            total.map { Strings.usedOf(ByteFormatting.storage(used), ByteFormatting.storage($0, fractionDigits: 0)) }
        }
        return tile(.storage, Strings.storage, caption, .storage) {
            if let used, let free, let total, total > 0 {
                let fraction = min(1, Double(used) / Double(total))
                HStack(alignment: .lastTextBaseline) {
                    MetricValue(value: "\(Int((fraction * 100).rounded()))", unit: Strings.percentUsed, size: .medium)
                    Spacer(minLength: 8)
                    TileCaption(text: Strings.available(ByteFormatting.storage(free)))
                }
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        Capsule().fill(Color.black).frame(width: max(10, (proxy.size.width - 3) * fraction))
                        Capsule().fill(SSColor.track)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
            } else {
                TileUnavailable(reason: Strings.storageUnavailable)
            }
        }
    }

    /// Capability only: there is no live GPU reading to show (PRD §2.6).
    private var gpuTile: some View {
        tile(.gpu, Strings.gpu, Strings.graphicsCapability, .cube) {
            if let gpu = model.gpu, gpu.metalAvailable {
                Text(gpu.supportedCapabilities.contains(.metal3) ? Strings.metal3 : Strings.metal)
                    .ssText(.metric32)
                    .foregroundStyle(SSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                if let family = gpu.appleFamily { TileCaption(text: Strings.appleFamily(family)) }
            } else {
                TileUnavailable(reason: Strings.gpuUnavailable)
            }
        }
    }

    private var networkTile: some View {
        tile(.network, Strings.network, networkCaption, .wifi) {
            if let received = model.network?.receivedBytes, let sent = model.network?.sentBytes {
                let (value, unit) = byteParts(Int64(clamping: received &+ sent))
                MetricValue(value: value, unit: unit, size: .small)
                Spacer(minLength: 0)
                Text(Strings.trafficSinceRestart)
                    .ssText(.chip12)
                    .foregroundStyle(SSColor.textTertiary)
            } else {
                TileUnavailable(reason: Strings.networkUnavailable)
            }
        }
    }

    private var networkCaption: String? {
        guard let network = model.network else { return nil }
        guard network.isConnected == true else { return Strings.offline }
        switch network.interface {
        case .wifi: return Strings.wifiConnected
        case .cellular: return Strings.cellularConnected
        case .wired: return Strings.ethernetConnected
        case .other, nil: return Strings.connected
        }
    }

    private func gigabytes(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Splits a formatted byte count such as "3.6 GB" into its number and unit.
    private func byteParts(_ bytes: Int64) -> (String, String) {
        let formatted = bytes.formatted(.byteCount(style: .file))
        let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : (formatted, "")
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: Strings.alerts, action: model.alerts.isEmpty ? nil : onOpenActivity)
            if model.alerts.isEmpty {
                MonitorCard(radius: 20) {
                    EmptyNote(title: Strings.noAlerts, detail: Strings.noAlertsDetail)
                }
            } else {
                ForEach(model.alerts) { alert in
                    MonitorCard(radius: 20) {
                        HStack(spacing: 12) {
                            OutlinedIcon(icon: alert.kind.icon, size: 40, iconSize: 18)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title)
                                    .ssText(.rowTitle15)
                                    .foregroundStyle(SSColor.textPrimary)
                                Text(verbatim: "\(alert.detail) · \(relative(alert.date))")
                                    .ssText(.bodyMedium13)
                                    .foregroundStyle(SSColor.textSubtle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MetricStatus(title: alert.severity.title, dot: alert.severity.color)
                                .fixedSize()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - Trends

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: Strings.trends)
            MonitorCard {
                VStack(alignment: .leading, spacing: 16) {
                    rangeSelector
                    if let trend = model.selectedTrend {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trend.title)
                                    .ssText(.bodyMedium13)
                                    .foregroundStyle(SSColor.textSubtle)
                                MetricValue(value: trend.latestValue.formatted(.number.precision(.fractionLength(0...1))), unit: trend.unit, size: .compact)
                            }
                            Spacer()
                            Text(Strings.observations(trend.observationCount))
                                .ssText(.captionMedium12)
                                .foregroundStyle(SSColor.textFaint)
                        }
                        TrendChart(trend: trend)
                            .accessibilityLabel(Text(Strings.trendSummary(
                                trend.title,
                                "\(trend.latestValue.formatted()) \(trend.unit)",
                                trend.observationCount
                            )))
                        HStack {
                            ForEach(Array(trend.axisLabels.enumerated()), id: \.offset) { index, label in
                                if index > 0 { Spacer(minLength: 0) }
                                Text(label)
                                    .ssText(.axis12)
                                    .foregroundStyle(SSColor.textSecondary)
                            }
                        }
                        if trend.hasGaps {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .stroke(SSColor.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                    .frame(width: 18, height: 1.5)
                                Text(Strings.noReadingsWhileClosed)
                                    .ssText(.captionMedium12)
                                    .foregroundStyle(SSColor.textFaint)
                            }
                        }
                    } else {
                        EmptyNote(title: Strings.insufficientHistory, detail: Strings.insufficientHistoryDetail)
                    }
                }
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 2) {
            ForEach(MonitorTrendRange.allCases, id: \.self) { range in
                let isSelected = range == model.selectedRange
                Button {
                    model.selectedRange = range
                } label: {
                    Text(range.title)
                        .ssText(.segment13)
                        .foregroundStyle(isSelected ? SSColor.textPrimary : SSColor.textSubtle)
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
        .background(SSColor.hairline.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: Strings.recentActivity, action: model.activity.isEmpty ? nil : onOpenActivity)
            if model.activity.isEmpty {
                MonitorCard {
                    EmptyNote(title: Strings.noActivity, detail: Strings.noActivityDetail)
                }
            } else {
                MonitorCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(model.activity) { item in
                            HStack(spacing: 12) {
                                OutlinedIcon(icon: .activity)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .ssText(.labelSemibold14)
                                        .foregroundStyle(SSColor.textPrimary)
                                    Text(relative(item.date))
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
                }
            }
        }
    }

    // MARK: - Recommended

    @ViewBuilder
    private var recommendedSection: some View {
        if !model.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: Strings.recommended)
                ForEach(Array(model.recommendations.enumerated()), id: \.offset) { _, recommendation in
                    MonitorCard(radius: 20) {
                        HStack(spacing: 12) {
                            OutlinedIcon(icon: .lamp, size: 40, iconSize: 20, cornerRadius: 12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.title)
                                    .ssText(.rowTitle15)
                                    .foregroundStyle(SSColor.textPrimary)
                                Text(recommendation.detail)
                                    .ssText(.bodyMedium13)
                                    .foregroundStyle(SSColor.textSubtle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }

    // MARK: - Loading

    /// First load: placeholders in the shape of the page. The spinner is
    /// indeterminate because the reads report no measurable progress.
    private var loading: some View {
        VStack(spacing: 8) {
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Circle().fill(SSColor.hairline).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 140, height: 14)
                            SkeletonBlock(width: 90, height: 10)
                        }
                    }
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(Strings.collecting)
                            .ssText(.bodyMedium13)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                }
            }
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)

            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 8) {
                    skeletonTile
                    skeletonTile
                }
            }
            skeletonTile
        }
        .accessibilityElement(children: .contain)
    }

    private var skeletonTile: some View {
        MonitorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    SkeletonBlock(width: 70, height: 12)
                    Spacer()
                    Circle().fill(SSColor.hairline).frame(width: 32, height: 32)
                }
                SkeletonBlock(width: 90, height: 32, radius: 8)
                SkeletonBlock(height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Presentation helpers

extension ThermalCondition {
    var title: String {
        switch self {
        case .nominal: Strings.thermalNominal
        case .fair: Strings.thermalFair
        case .serious: Strings.thermalSerious
        case .critical: Strings.thermalCritical
        }
    }

    var statusTitle: String {
        switch self {
        case .nominal: Strings.operatingNormally
        case .fair: Strings.slightlyWarm
        case .serious: Strings.runningHot
        case .critical: Strings.tooHot
        }
    }

    var statusColor: Color {
        switch self {
        case .nominal: SSColor.statusGreen
        case .fair: SSColor.statusAmber
        case .serious: SSColor.thermalOrange
        case .critical: SSColor.thermalRed
        }
    }
}

private extension MonitorAlert.Kind {
    var icon: SSIcon {
        switch self {
        case .network: .wifi
        case .battery: .battery
        case .storage: .storage
        case .thermal: .cpuCharge
        }
    }
}

private extension MonitorAlert.Severity {
    var title: String {
        switch self {
        case .info: Strings.info
        case .attention: Strings.attention
        case .critical: Strings.critical
        }
    }

    var color: Color {
        switch self {
        case .info: SSColor.accent
        case .attention: SSColor.statusAmber
        case .critical: SSColor.coral
        }
    }
}

private extension MonitorRecommendation {
    var title: String {
        switch self {
        case .reviewStorage: Strings.reviewStorageTitle
        case .considerLowPowerMode: Strings.lowPowerTitle
        }
    }

    var detail: String {
        switch self {
        case let .reviewStorage(freeFraction):
            Strings.reviewStorageDetail(freeFraction.formatted(.percent.precision(.fractionLength(0))))
        case .considerLowPowerMode: Strings.lowPowerDetail
        }
    }
}
