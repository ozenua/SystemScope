import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// Home tab root: owns the tab's navigation stack and the speed-test sheet.
public struct HomeView: View {
    @Bindable private var model: HomeModel
    private let onOpenAlerts: () -> Void

    public init(model: HomeModel, onOpenAlerts: @escaping () -> Void) {
        self.model = model
        self.onOpenAlerts = onOpenAlerts
    }

    public var body: some View {
        NavigationStack(path: $model.path) {
            HomeOverview(model: model, onOpenAlerts: onOpenAlerts)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: HomeModel.Route.self) { route in
                    Group {
                        switch route {
                        case .network: NetworkView(model: model)
                        case .dataUsage: DataUsageView(model: model)
                        case .gpu: GPUView(model: model)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .backSwipe { model.goBack() }
    }
}

public extension View {
    /// Presents the speed-test screen whenever `model` asks for it. Applied once at the
    /// app shell so any tab (Home or Monitor) can start a test.
    func speedTestSheet(model: HomeModel) -> some View {
        modifier(SpeedTestSheetModifier(model: model))
    }
}

private struct SpeedTestSheetModifier: ViewModifier {
    @Bindable var model: HomeModel

    func body(content: Content) -> some View {
        content.sheet(isPresented: $model.isSpeedTestPresented, onDismiss: model.speedTestDismissed) {
            SpeedTestSheet(model: model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(SSColor.sheet)
        }
    }
}

/// HOME: at-a-glance device overview (PRD §6.2).
private struct HomeOverview: View {
    let model: HomeModel
    let onOpenAlerts: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        MemoryCard(summary: model.summary)
                        BatteryCard(summary: model.summary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        TemperatureCard(state: model.summary.thermalState)
                        StorageCard(summary: model.summary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    PerformanceCard(
                        performance: model.performance,
                        processor: model.summary.processor,
                        processorCores: model.summary.processorCoreCount,
                        gpu: model.gpu
                    ) { model.open(.gpu) }
                    NetworkCard(network: model.network) { model.open(.network) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .refreshable { await model.refresh() }
        .background(SSScreenBackground())
        .task { await model.refresh() }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await model.refreshNetwork()
            }
        }
        // Values go stale in the background; re-read when the app returns (PRD §7.4).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            } else {
                model.appDidLeaveForeground()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                AppLogo(size: 50)
                Spacer()
                Button(action: onOpenAlerts) {
                    SSIconView(.bell, size: 24, color: Color(hex: 0x292D32))
                        .frame(width: 40, height: 40)
                        .background(SSColor.hairline, in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text(Strings.alerts))
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.displayName)
                        .ssText(.title20)
                        .foregroundStyle(SSColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    DotSeparated(items: identityItems)
                }
                Spacer(minLength: 8)
                healthPill
            }
        }
    }

    private var identityItems: [String] {
        [
            model.summary.modelName ?? Strings.unknownModel,
            // The design drops the "Apple" prefix here.
            model.summary.processor?.replacingOccurrences(of: "Apple ", with: ""),
            model.summary.physicalMemoryBytes.map { ByteFormatting.memory($0) },
        ].compactMap { $0 }
    }

    @ViewBuilder
    private var healthPill: some View {
        switch model.health {
        case .healthy:
            StatusPill(title: Strings.healthy)
        case .attention:
            StatusPill(title: Strings.attention, dot: Color(hex: 0xF5A623), surface: Color(hex: 0xFFF1D6))
        case .critical:
            StatusPill(title: Strings.critical, dot: SSColor.coral, surface: Color(hex: 0xFFE1DC))
        case .partial:
            StatusPill(title: Strings.partial, dot: SSColor.textMuted, surface: SSColor.hairline)
        }
    }
}

// MARK: - Cards

private struct CardTitle: View {
    let title: String
    var detail: String?
    var color: Color = SSColor.textLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .ssText(.labelSemibold14)
                .foregroundStyle(color)
            if let detail {
                Text(detail)
                    .ssText(.micro10)
                    .foregroundStyle(SSColor.textFaint)
            }
        }
    }
}

/// Large figure with a smaller unit on the same baseline, e.g. "62 %".
private struct Figure: View {
    let value: String
    let unit: String
    var large = true
    var color: Color = SSColor.textPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).ssText(large ? .metric48 : .metric32)
            Text(unit).ssText(large ? .unit24 : .unit16)
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(value)\(unit)"))
    }
}

private struct MemoryCard: View {
    let summary: DeviceSummary
    private let barCount = 27

    var body: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(title: Strings.memory, detail: detail)
                    if let fraction {
                        Figure(value: "\(Int((fraction * 100).rounded()))", unit: "%")
                    } else if let total = summary.physicalMemoryBytes {
                        Text(ByteFormatting.memory(total))
                            .ssText(.metric32)
                            .foregroundStyle(SSColor.textPrimary)
                    } else {
                        Text(Strings.unavailable)
                            .ssText(.title20)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(index < filledBars ? SSColor.accent : SSColor.track)
                            .frame(height: 29)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) { SSIconChip(.cpu).padding(16) }
        .accessibilityElement(children: .combine)
    }

    private var fraction: Double? {
        guard let used = summary.memoryInUseBytes, let total = summary.physicalMemoryBytes, total > 0 else { return nil }
        return min(1, Double(used) / Double(total))
    }

    private var filledBars: Int {
        Int(((fraction ?? 0) * Double(barCount)).rounded())
    }

    private var detail: String? {
        guard let total = summary.physicalMemoryBytes else { return nil }
        guard let used = summary.memoryInUseBytes else { return Strings.memoryInUseUnavailable }
        return Strings.usedOfTotal(ByteFormatting.memory(used, fractionDigits: 1), ByteFormatting.memory(total))
    }
}

private struct BatteryCard: View {
    let summary: DeviceSummary

    var body: some View {
        if let level = summary.batteryLevel {
            let isLow = level <= DeviceHealth.lowBatteryThreshold && summary.batteryState == .unplugged
            let shape = RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous)
            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: Strings.battery, color: .white)
                Spacer(minLength: 12)
                Figure(value: "\(Int((level * 100).rounded()))", unit: "%", color: .white)
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    if summary.batteryState == .charging || isLow {
                        SSIconView(.lightning, size: 12, color: .white)
                    }
                    Text(stateTitle(isLow: isLow))
                        .ssText(.chip12)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                LinearGradient(
                    // Low-charge colours are matched by eye from the Figma frame.
                    colors: isLow ? [Color(hex: 0xFF6B5E), Color(hex: 0xD42A2A)] : [Color(hex: 0x00AAFF), Color(hex: 0x71D0FF)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 36)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .clipShape(shape)
            .overlay(alignment: .topTrailing) {
                SSIconChip(.battery, tint: .white, fill: .white.opacity(0.2)).padding(16)
            }
            .accessibilityElement(children: .combine)
        } else {
            HomeCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(title: Strings.battery)
                    Text(Strings.unavailable)
                        .ssText(.title20)
                        .foregroundStyle(SSColor.textSubtle)
                    Text(Strings.batteryNotReported)
                        .ssText(.bodyMedium14)
                        .foregroundStyle(SSColor.textSubtle)
                }
            }
            .overlay(alignment: .topTrailing) { SSIconChip(.battery).padding(16) }
            .accessibilityElement(children: .combine)
        }
    }

    private func stateTitle(isLow: Bool) -> String {
        if isLow { return Strings.lowCharge }
        switch summary.batteryState {
        case .charging: return Strings.charging
        case .full: return Strings.fullyCharged
        case .unplugged, nil: return Strings.notCharging
        }
    }
}

/// Shows the iOS thermal state only; never a temperature reading (PRD §2.6).
private struct TemperatureCard: View {
    let state: ThermalCondition?

    var body: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: Strings.temperature)
                Text(title)
                    .ssText(.metric32)
                    .foregroundStyle(state == nil ? SSColor.textSubtle : SSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text(detail)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
        }
        .overlay(alignment: .topTrailing) { SSIconChip(.temperature).padding(16) }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .nominal: Strings.thermalNominal
        case .fair: Strings.thermalFair
        case .serious: Strings.thermalSerious
        case .critical: Strings.thermalCritical
        case nil: Strings.unavailable
        }
    }

    private var detail: String {
        switch state {
        case .nominal: Strings.thermalNominalDetail
        case .fair: Strings.thermalFairDetail
        case .serious: Strings.thermalSeriousDetail
        case .critical: Strings.thermalCriticalDetail
        case nil: Strings.notReported
        }
    }
}

private struct StorageCard: View {
    let summary: DeviceSummary
    private let segmentCount = 6

    var body: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 19) {
                    CardTitle(title: Strings.storage, detail: detail)
                    if let fraction {
                        Figure(value: "\(Int((fraction * 100).rounded()))", unit: "%", large: false)
                    } else {
                        Text(Strings.unavailable)
                            .ssText(.title20)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        Capsule()
                            .fill(index < filledSegments ? SSColor.accent : SSColor.track)
                            .frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) { SSIconChip(.storage).padding(16) }
        .accessibilityElement(children: .combine)
    }

    private var usedBytes: Int64? {
        guard let free = summary.storageAvailableBytes, let total = summary.storageTotalBytes else { return nil }
        return max(0, total - free)
    }

    /// Used share, from the same capacity basis as the alert threshold (PRD §6.3 Storage).
    private var fraction: Double? {
        guard let used = usedBytes, let total = summary.storageTotalBytes, total > 0 else { return nil }
        return min(1, Double(used) / Double(total))
    }

    private var filledSegments: Int {
        Int(((fraction ?? 0) * Double(segmentCount)).rounded())
    }

    private var detail: String? {
        guard let used = usedBytes, let total = summary.storageTotalBytes else { return nil }
        return Strings.usedOfTotal(ByteFormatting.storage(used), ByteFormatting.storage(total, fractionDigits: 0))
    }
}

private struct PerformanceCard: View {
    let performance: PerformanceSnapshot?
    let processor: String?
    let processorCores: Int?
    let gpu: GPUInformation?
    let open: () -> Void

    var body: some View {
        Button(action: open) { card }
            .buttonStyle(.plain)
            .accessibilityHint(Text(Strings.openGPU))
    }

    private var card: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(Strings.performance)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textLabel)
                if let performance {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { proxy in
                            let width = proxy.size.width - 8
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8).fill(SSColor.borderStrong)
                                RoundedRectangle(cornerRadius: 8).fill(SSColor.accent)
                                    .frame(width: max(22, width * performance.cpu))
                                RoundedRectangle(cornerRadius: 8).fill(SSColor.coral)
                                    .frame(width: max(22, width * performance.gpu))
                            }
                        }
                        .frame(height: 25)
                        .accessibilityHidden(true)
                        HStack(spacing: 8) {
                            legend(Strings.cpu, performance.cpu)
                            dot
                            legend(Strings.gpu, performance.gpu)
                            dot
                            legend(Strings.inactive, performance.inactive)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        hardwareRow(Strings.cpu, processor.map { name in
                            processorCores.map { "\(name) · \($0) \(Strings.cores)" } ?? name
                        })
                        hardwareRow(Strings.gpu, gpu?.name)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) { SSIconChip(.activity).padding(16) }
        .contentShape(RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var dot: some View {
        Circle().fill(SSColor.track).frame(width: 4, height: 4).accessibilityHidden(true)
    }

    private func legend(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Text(Format.percent(value))
                .ssText(.labelSemibold14)
                .foregroundStyle(SSColor.textPrimary)
        }
        .lineLimit(1)
    }

    private func hardwareRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Spacer(minLength: 8)
            Text(value ?? Strings.unavailable)
                .ssText(.labelSemibold14)
                .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct NetworkCard: View {
    let network: NetworkSnapshot?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        SSIconView(.signal, size: 14, color: .black)
                        Text(Strings.network)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textLabel)
                    }
                    DotSeparated(items: subtitleItems)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    if let received = network?.receivedBytes {
                        chip(Format.bytes(Int64(clamping: received)), up: false)
                    }
                    if let sent = network?.sentBytes {
                        chip(Format.bytes(Int64(clamping: sent)), up: true)
                    }
                    SSIconView(.arrowRight, size: 14, color: Color(hex: 0x292D32))
                }
                .fixedSize()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var subtitleItems: [String] {
        guard let network, network.isConnected != false else { return [Strings.offline] }
        guard let interface = network.interface else { return [Strings.unavailable] }
        return [interface.title, network.networkName].compactMap { $0 }
    }

    private func chip(_ text: String, up: Bool) -> some View {
        HStack(spacing: 4) {
            SSIconView(.arrowDown, size: 14, color: SSColor.positive)
                .scaleEffect(y: up ? -1 : 1)
            Text(text)
                .ssText(.chip12)
                .foregroundStyle(SSColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(SSColor.chipGreen, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(up ? Strings.uploaded : Strings.downloaded) \(text)"))
    }
}
