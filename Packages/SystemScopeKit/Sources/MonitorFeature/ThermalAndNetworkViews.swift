import Core
import DesignSystem
import DeviceInfo
import SpeedTest
import SwiftUI

// MARK: - MON-07 · Thermal

struct ThermalMonitorView: View {
    @Bindable var model: MonitorModel
    @State private var range: MonitorTrendRange = .today

    private var state: ThermalCondition? { model.summary.thermalState }

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.thermal, subtitle: Strings.thermalSubtitle, onBack: model.goBack) {
                RefreshButton(isRefreshing: model.isRefreshing) { Task { await model.refresh() } }
            }
            stateCard
            PlatformNote(text: Strings.thermalNote)
            SectionHeader(title: Strings.whatEachStateMeans)
            VStack(spacing: 4) {
                ForEach(ThermalCondition.ordered, id: \.self) { condition in
                    HStack(spacing: 12) {
                        Circle().fill(condition.statusColor).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(condition.title)
                                .ssText(.labelSemibold14)
                                .foregroundStyle(SSColor.textPrimary)
                            Text(condition.meaning)
                                .ssText(.captionMedium12)
                                .foregroundStyle(SSColor.textSubtle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if condition == state {
                            Text(Strings.now)
                                .ssText(.chip12)
                                .foregroundStyle(SSColor.chartGreen)
                        }
                    }
                    .padding(12)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(8)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
            SectionHeader(title: Strings.stateHistory)
            MonitorCard {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedSelector(options: MonitorTrendRange.allCases, selection: $range) { $0.title }
                    InsufficientHistoryNote()
                }
            }
            SectionHeader(title: Strings.recentChanges)
            if model.thermalChanges.isEmpty {
                MonitorCard { EmptyNote(title: Strings.noChanges, detail: Strings.noChangesDetail) }
            } else {
                ActivityList(items: model.thermalChanges.prefix(5).map { change in
                    .init(title: changeTitle(change), subtitle: change.date.formatted(date: .abbreviated, time: .shortened))
                })
            }
            CalloutCard(icon: .cpuCharge, title: Strings.heatTitle, message: Strings.heatDetail, tint: SSColor.warmBrown)
            if let state, state != .nominal {
                SectionHeader(title: Strings.recommendations)
                RecommendationList(items: [.init(title: Strings.warmTitle, detail: Strings.warmDetail)])
            }
            TechnicalDetails(
                caption: Strings.thermalTechnicalCaption,
                rows: [
                    SpecRow(label: Strings.source, value: Strings.thermalSource),
                    SpecRow(label: Strings.scope, value: Strings.thisIPhone),
                    SpecRow(label: Strings.sampling, value: Strings.batterySampling),
                    SpecRow(label: Strings.measured, value: model.lastUpdated.map(MonitorFormat.timeWithSeconds)),
                ]
            )
        }
    }

    private func changeTitle(_ change: ThermalChange) -> String {
        Strings.change(change.from?.title ?? Strings.unknown, change.to.title)
    }

    @ViewBuilder
    private var stateCard: some View {
        MonitorCard {
            if let state {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(Strings.currentThermalState)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textLabel)
                        Spacer()
                        MetricStatus(title: state == .nominal ? Strings.normal : Strings.elevated, dot: state.statusColor)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.title)
                            .ssText(.metric52)
                            .foregroundStyle(SSColor.textPrimary)
                        Text(state.statusTitle)
                            .ssText(.label15)
                            .foregroundStyle(SSColor.textSubtle)
                    }
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(ThermalCondition.ordered, id: \.self) { step in
                            let isCurrent = step == state
                            VStack(alignment: .leading, spacing: 6) {
                                Capsule()
                                    .fill(isCurrent ? step.statusColor : step.statusColor.opacity(0.22))
                                    .frame(height: 8)
                                Text(step.title)
                                    .ssText(isCurrent ? .chip12 : .captionMedium12)
                                    .foregroundStyle(isCurrent ? SSColor.textPrimary : SSColor.textFaint)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .accessibilityHidden(true)
                    if let change = model.thermalChanges.first {
                        DataTimestamp(text: Strings.lastChange(MonitorFormat.time(change.date), changeTitle(change)))
                    } else {
                        DataTimestamp(text: Strings.updatedJustNow)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Strings.currentThermalState)
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textLabel)
                    TileUnavailable(reason: Strings.thermalUnavailable)
                }
            }
        }
    }
}

extension ThermalCondition {
    static let ordered: [ThermalCondition] = [.nominal, .fair, .serious, .critical]

    var meaning: String {
        switch self {
        case .nominal: Strings.operatingNormally
        case .fair: Strings.fairMeaning
        case .serious: Strings.seriousMeaning
        case .critical: Strings.criticalMeaning
        }
    }
}

// MARK: - MON-08 · Network

struct NetworkMonitorView: View {
    @Bindable var model: MonitorModel
    let onRunSpeedTest: () -> Void
    @State private var range: MonitorTrendRange = .today
    @State private var detailsExpanded = true

    private var network: NetworkSnapshot? { model.network }
    private var isConnected: Bool { network?.isConnected == true }
    private var latest: InternetSpeedTestResult? { model.latestSpeedTest }

    var body: some View {
        DetailPage {
            DetailHeader(title: Strings.network, subtitle: Strings.networkSubtitle, onBack: model.goBack) {
                Button(action: onRunSpeedTest) {
                    HStack(spacing: 6) {
                        SSIconView(.radar, size: 16, color: .white)
                        Text(Strings.speedTest).ssText(.segment13).foregroundStyle(.white)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 14)
                    .padding(.vertical, 9)
                    .background(SSColor.ink, in: Capsule())
                    .frame(minHeight: 44)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                connectionCard
                DataTimestamp(text: speedTestCaption)
            }
            HStack(spacing: 8) {
                StatBox(label: Strings.latency, value: latest?.measurements.idleLatencyMs.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) ms" }, fallback: Strings.notTested, filled: true)
                StatBox(label: Strings.deviceTraffic, value: totalTraffic.map(bytes), filled: true)
                StatBox(label: Strings.cellular, value: network?.isCellularAvailable.map { $0 ? Strings.availableValue : Strings.notAvailable }, filled: true)
            }
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: Strings.deviceTraffic)
                SegmentedSelector(options: MonitorTrendRange.allCases, selection: $range) { $0.title }
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Strings.sinceRestartOn(network?.interface?.title ?? Strings.connection))
                            .ssText(.bodyMedium14)
                            .foregroundStyle(SSColor.textSubtle)
                        Text(totalTraffic.map(bytes) ?? Strings.unavailable)
                            .ssText(.metric32)
                            .foregroundStyle(totalTraffic == nil ? SSColor.textSubtle : SSColor.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    EmptyNote(title: Strings.insufficientHistory, detail: Strings.historyNotRecorded)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SSColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                HStack(spacing: 8) {
                    breakdown(Strings.download, network?.receivedBytes, SSColor.accent)
                    breakdown(Strings.upload, network?.sentBytes, SSColor.lilac)
                }
            }
            PlatformNote(text: Strings.trafficNote)
            SectionHeader(title: Strings.networkDetails)
            interfaceDetails
            if network?.interface == .wifi, let cellular = network?.isCellularAvailable {
                HStack(spacing: 12) {
                    SSIconView(.cellular, size: 18, color: Color(hex: 0x292D32))
                        .frame(width: 36, height: 36)
                        .background(SSColor.hairline, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.cellular).ssText(.rowTitle15).foregroundStyle(SSColor.textPrimary)
                        Text(cellular ? Strings.availableNotInUse : Strings.notAvailable)
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.networkHealth).ssText(.rowTitle15).foregroundStyle(SSColor.textPrimary)
                    Text(Strings.basedOnConnection).ssText(.captionMedium12).foregroundStyle(SSColor.textFaint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                health
            }
            .padding(16)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            Button(Strings.runSpeedTest, action: onRunSpeedTest)
                .buttonStyle(.ssPrimary)
        }
    }

    private func bytes(_ value: UInt64) -> String {
        Int64(clamping: value).formatted(.byteCount(style: .file))
    }

    private var totalTraffic: UInt64? {
        guard let received = network?.receivedBytes, let sent = network?.sentBytes else { return nil }
        return received &+ sent
    }

    private var speedTestCaption: String {
        guard let latest else { return Strings.noSpeedTest }
        return Strings.lastSpeedTest(
            latest.timestamp.formatted(.relative(presentation: .named)),
            latest.connection.title,
            "\(Int(latest.testDurationSeconds.rounded()))"
        )
    }

    private func mbps(_ value: Double?) -> String? {
        value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) Mbps" }
    }

    private var connectionCard: some View {
        VStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isConnected && network?.networkName != nil ? Strings.connectedTo : Strings.connection)
                    .ssText(.labelSemibold14)
                HStack(spacing: 8) {
                    Text(connectionTitle)
                        .ssText(.screenTitle24)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if network?.networkName != nil, let interface = network?.interface {
                        Text(interface.title)
                            .ssText(.micro10)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.white, in: Capsule())
                    }
                }
                HStack(spacing: 4) {
                    if isConnected { SSIconView(.tickCircleBold, size: 14, color: .white) }
                    Text(isConnected ? Strings.internetConnected : Strings.noInternet).ssText(.chip12)
                }
                .padding(.vertical, 4)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background {
                LinearGradient(colors: [Color(hex: 0x0A6FD8), Color(hex: 0x0050A8)], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 36)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 22,
                style: .continuous
            ))
            .overlay(alignment: .topTrailing) {
                SSIconChip(.wifiBold, tint: .white, fill: .white.opacity(0.2)).padding(16)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                speedStat(Strings.download, mbps(latest?.measurements.downloadMbps), .arrowDown)
                Rectangle().fill(SSColor.borderStrong).frame(width: 1, height: 34)
                speedStat(Strings.upload, mbps(latest?.measurements.uploadMbps), .arrowUp)
            }
            .padding(10)
        }
        .padding(2)
        .background(
            LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 24, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 24,
                style: .continuous
            )
        )
        .padding(.horizontal, -2)
    }

    private func speedStat(_ label: String, _ value: String?, _ icon: SSIcon) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label).ssText(.bodyMedium14).foregroundStyle(SSColor.textSubtle)
                Text(value ?? Strings.notTested)
                    .ssText(.value16)
                    .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SSIconChip(icon, tint: SSColor.textStrong, fill: SSColor.iconChip)
        }
        .accessibilityElement(children: .combine)
    }

    private var connectionTitle: String {
        guard let network else { return Strings.unavailable }
        guard network.isConnected == true else { return Strings.notConnected }
        return network.networkName ?? network.interface?.title ?? Strings.unavailable
    }

    private func breakdown(_ label: String, _ value: UInt64?, _ color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).ssText(.captionMedium12).foregroundStyle(SSColor.textSubtle)
                Text(value.map(bytes) ?? Strings.unavailable)
                    .ssText(.stat16)
                    .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var interfaceDetails: some View {
        if let network, network.isConnected == true, let interface = network.interface {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    detailsExpanded.toggle()
                } label: {
                    HStack(spacing: 12) {
                        OutlinedIcon(icon: interface == .cellular ? .cellular : .wifi, size: 36, iconSize: 18, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(interface.title).ssText(.rowTitle15).foregroundStyle(SSColor.textPrimary)
                            Text(Strings.connectedOnly).ssText(.captionMedium12).foregroundStyle(SSColor.textFaint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        SSIconView(.chevronDown, size: 20, color: SSColor.textPrimary)
                            .rotationEffect(.degrees(detailsExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(detailsExpanded ? Strings.expanded : Strings.collapsed))

                if detailsExpanded {
                    let rows: [SpecRow] = [
                        interface == .wifi ? SpecRow(label: Strings.networkName, value: network.networkName, fallback: Strings.notAvailable) : nil,
                        SpecRow(label: Strings.interface, value: interface == .wifi ? "\(interface.title) (en0)" : interface.title),
                        SpecRow(label: Strings.ipVersions, value: ipVersions),
                        SpecRow(label: Strings.expensiveConstrained, value: "\(network.isExpensive ? Strings.yes : Strings.no) · \(network.isConstrained ? Strings.yes : Strings.no)"),
                        SpecRow(label: Strings.signalStrength, value: nil, fallback: Strings.notAvailable),
                    ].compactMap { $0 }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SpecLine(row: row)
                        if index < rows.count - 1 {
                            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        SSIconView(.info, size: 14, color: SSColor.textSecondary)
                        Text(Strings.networkNameNote)
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
        } else {
            MonitorCard { TileUnavailable(reason: Strings.networkUnavailable) }
        }
    }

    private var ipVersions: String? {
        let versions = [network?.supportsIPv4 == true ? "IPv4" : nil, network?.supportsIPv6 == true ? "IPv6" : nil].compactMap { $0 }
        return versions.isEmpty ? nil : versions.joined(separator: " · ")
    }

    @ViewBuilder
    private var health: some View {
        if let network, network.isConnected == true {
            if network.isConstrained {
                MetricStatus(title: Strings.limited, dot: SSColor.statusAmber)
            } else {
                MetricStatus(title: Strings.good)
            }
        } else if network?.isConnected == false {
            MetricStatus(title: Strings.offline, dot: SSColor.coral)
        } else {
            MetricStatus(title: Strings.unavailable, dot: SSColor.textMuted)
        }
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
