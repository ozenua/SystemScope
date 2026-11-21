import DesignSystem
import DeviceInfo
import SwiftUI

/// Home / Network: connection, last speed-test result and observed data usage.
struct NetworkView: View {
    let model: HomeModel

    var body: some View {
        VStack(spacing: 0) {
            networkTopBar

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Strings.network)
                            .ssText(.screenTitle24)
                            .foregroundStyle(SSColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(Strings.networkSubtitle)
                            .ssText(.bodyMedium14)
                            .foregroundStyle(SSColor.textSubtle)
                    }

                    connection

                    VStack(spacing: 16) {
                        Button {
                            model.open(.dataUsage)
                        } label: {
                            HStack {
                                Text(Strings.dataUsage)
                                    .ssText(.section18)
                                    .foregroundStyle(SSColor.textPrimary)
                                Spacer()
                                SSIconView(.arrowCircleRight, size: 20, color: Color(hex: 0x292D32))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(Strings.openDataUsage))

                        usageCard
                    }

                    Button(Strings.runSpeedTest, action: model.openSpeedTest)
                        .ssText(.section18)
                        .foregroundStyle(SSColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
        .task { await model.refresh() }
    }

    private var networkTopBar: some View {
        HStack {
            SSBackButton(label: Strings.back, action: model.goBack)
                .padding(.leading, -6)
            Spacer()
            HStack(spacing: 8) {
                Text(Strings.networkHealth)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textPrimary)
                healthPill
            }
            .accessibilityElement(children: .combine)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    // MARK: - Connection

    private var isConnected: Bool { model.network?.isConnected == true }

    private var connection: some View {
        VStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isConnected && model.network?.networkName != nil ? Strings.connectedTo : Strings.connection)
                    .ssText(.labelSemibold14)
                HStack(spacing: 8) {
                    Text(connectionTitle)
                        .ssText(.screenTitle24)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // The interface pill only adds information next to a network name.
                    if model.network?.networkName != nil, let interface = model.network?.interface {
                        Text(interface.title)
                            .ssText(.micro10)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.white, in: Capsule())
                    }
                }
                HStack(spacing: 4) {
                    if isConnected {
                        SSIconView(.tickCircleBold, size: 14, color: .white)
                    }
                    Text(isConnected ? Strings.internetConnected : Strings.noInternet)
                        .ssText(.chip12)
                }
                .padding(.vertical, 4)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background {
                LinearGradient(colors: [Color(hex: 0x00AAFF), Color(hex: 0x83D6FF)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
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

            // The most recent saved test, if there is one. Never a live or sampled figure.
            SpeedRow(
                downloadMbps: model.latestSpeedTest?.measurements.downloadMbps,
                uploadMbps: model.latestSpeedTest?.measurements.uploadMbps
            )
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

    private var connectionTitle: String {
        guard let network = model.network else { return Strings.unavailable }
        guard network.isConnected == true else { return Strings.notConnected }
        return network.networkName ?? network.interface?.title ?? Strings.unavailable
    }

    /// Derived from the current path only: connected and unconstrained is Good.
    @ViewBuilder
    private var healthPill: some View {
        if let network = model.network, network.isConnected == true {
            if network.isConstrained {
                StatusPill(title: Strings.limited, dot: Color(hex: 0xF5A623), surface: Color(hex: 0xFFF1D6))
            } else {
                StatusPill(title: Strings.good)
            }
        } else if model.network?.isConnected == false {
            StatusPill(title: Strings.offline, dot: SSColor.coral, surface: Color(hex: 0xFFE1DC))
        } else {
            StatusPill(title: Strings.unavailable, dot: SSColor.textMuted, surface: SSColor.hairline)
        }
    }

    // MARK: - Usage

    private var usageCard: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 12) {
                if let series = model.todayUsage {
                    UsageHeading(label: Strings.today, total: Format.bytes(series.totalBytes))
                    UsageBars(
                        series: series,
                        height: 63,
                        summary: Strings.usageSummary(Format.bytes(series.totalBytes), Strings.today)
                    )
                } else {
                    UsageHeading(label: Strings.sinceRestart, total: observedTotal)
                    InsufficientHistory()
                }
            }
        }
    }

    /// Cumulative interface counters: observed device traffic, not a billing figure.
    private var observedTotal: String? {
        guard let received = model.network?.receivedBytes, let sent = model.network?.sentBytes else { return nil }
        return Format.bytes(Int64(clamping: received &+ sent))
    }
}

struct UsageHeading: View {
    let label: String
    let total: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Text(total ?? Strings.unavailable)
                .ssText(.metric32)
                .foregroundStyle(total == nil ? SSColor.textSubtle : SSColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
