import DesignSystem
import DeviceInfo
import SpeedTest
import SwiftUI

/// The internet speed-test screen. It opens ready and idle: nothing is transferred
/// until the user taps Start (PRD §10.2). Every figure shown comes from the test server.
struct SpeedTestSheet: View {
    @Bindable var model: HomeModel

    var body: some View {
        switch model.speedTest {
        case .idle:
            Color.clear
        case .unavailable:
            message(
                title: Strings.speedTestUnavailableTitle,
                body: Strings.speedTestUnavailableBody,
                canRetry: false
            )
        case .ready:
            ready
        case let .running(progress):
            running(progress)
        case let .completed(result):
            completed(result)
        case let .failed(error):
            message(title: error.title, body: error.message, canRetry: error != .notConfigured)
        }
    }

    // MARK: - Ready

    private var ready: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Strings.speedTestTitle)
                    .ssText(.screenTitle24)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                HomeCard {
                    VStack(spacing: 16) {
                        infoRow(Strings.connectionLabel, connectionTitle)
                        infoRow(Strings.serverLabel, Strings.serverChosenAtStart)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 2) {
                        ForEach(model.availableProfiles, id: \.self) { profile in
                            let isSelected = profile == model.selectedProfile
                            Button {
                                model.selectedProfile = profile
                            } label: {
                                Text(profile.title)
                                    .ssText(.segment13)
                                    .foregroundStyle(isSelected ? SSColor.textPrimary : SSColor.textSubtle)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
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

                    // The data cost is stated before anything is transferred.
                    notice(Strings.upToData(Format.bytes(Int64(model.selectedProfile.dataBudgetBytes))))
                    if model.connection?.interface == .cellular {
                        notice(Strings.cellularNotice)
                    } else if model.connection?.isExpensive == true {
                        notice(Strings.expensiveNotice)
                    }
                    if model.connection?.isConstrained == true {
                        notice(Strings.lowDataNotice)
                    }
                }

                Button(Strings.startTest, action: model.startSpeedTest)
                    .buttonStyle(.ssPrimary)
                    .disabled(model.connection?.isConnected != true)

                history
            }
            .padding(.horizontal, 23)
            .padding(.top, 32)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var connectionTitle: String {
        guard let connection = model.connection else { return Strings.checkingConnection }
        guard connection.isConnected, let interface = connection.interface else { return Strings.noInternet }
        return [interface.title, model.network?.networkName].compactMap { $0 }.joined(separator: " · ")
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .ssText(.bodyMedium14)
            .foregroundStyle(SSColor.textSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(_ label: String, _ value: String?, fallback: String = Strings.unavailable) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Spacer(minLength: 8)
            Text(value ?? fallback)
                .ssText(.labelSemibold14)
                .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Running

    private func running(_ progress: SpeedTestProgress) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                SpeedGauge(mbps: progress.liveMbps ?? 0)
                    .padding(.top, 45)

                VStack(spacing: 14) {
                    Text(progress.phase.title)
                        .ssText(.section18)
                        .foregroundStyle(SSColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle(server: progress.serverHost, region: progress.serverRegion))
                        .ssText(.bodyMedium14)
                        .foregroundStyle(SSColor.textSubtle)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 34)

                SSSegmentedProgress(total: 4, completed: progress.phase.step, hasCurrent: true)
                    .frame(width: 160)
                    .padding(.top, 20)

                statsBox {
                    SpeedRow(
                        downloadMbps: progress.measurements.downloadMbps,
                        uploadMbps: progress.measurements.uploadMbps,
                        fallback: Strings.pending
                    )
                    HStack(spacing: 12) {
                        StatCell(label: Strings.latency, value: Format.milliseconds(progress.measurements.idleLatencyMs), fallback: Strings.pending)
                        StatDivider()
                        StatCell(label: Strings.jitter, value: Format.milliseconds(progress.measurements.jitterMs), fallback: Strings.pending)
                        StatDivider()
                        StatCell(label: Strings.packetLoss, value: nil, fallback: Strings.unavailable)
                    }
                    .padding(10)
                }
                .padding(.top, 28)

                Button(Strings.cancelTest, action: model.cancelSpeedTest)
                    .buttonStyle(.ssSecondary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 23)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func subtitle(server: String?, region: String?) -> String {
        let connection = [model.connection?.interface?.title, model.network?.networkName].compactMap { $0 }
        let serverName = server.map { host in region.map { "\(host) (\($0))" } ?? host }
        return (connection + [serverName].compactMap { $0 }).joined(separator: " · ")
    }

    private func statsBox(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 2) { content() }
            .padding(2)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 24,
                    style: .continuous
                )
                .strokeBorder(SSColor.hairline, lineWidth: 1)
            )
    }

    // MARK: - Completed

    private func completed(_ result: InternetSpeedTestResult) -> some View {
        let measured = result.measurements
        return ScrollView {
            VStack(spacing: 0) {
                SpeedGauge(mbps: measured.downloadMbps ?? 0)
                    .padding(.top, 45)

                Text(Strings.testComplete)
                    .ssText(.section18)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 34)

                HomeCard {
                    VStack(spacing: 14) {
                        infoRow(Strings.download, Format.mbps(measured.downloadMbps))
                        infoRow(Strings.upload, Format.mbps(measured.uploadMbps))
                        infoRow(Strings.idleLatency, Format.milliseconds(measured.idleLatencyMs))
                        infoRow(Strings.downloadLatency, Format.milliseconds(measured.downloadLatencyMs), fallback: Strings.notMeasured)
                        infoRow(Strings.uploadLatency, Format.milliseconds(measured.uploadLatencyMs), fallback: Strings.notMeasured)
                        infoRow(Strings.jitter, Format.milliseconds(measured.jitterMs))
                        infoRow(Strings.packetLoss, measured.packetLossPercentage.map { Format.percent($0 / 100) })
                    }
                }
                .padding(.top, 20)

                HomeCard {
                    VStack(spacing: 14) {
                        infoRow(Strings.connectionLabel, [result.connection.title, result.wifiSSID].compactMap { $0 }.joined(separator: " · "))
                        infoRow(Strings.serverLabel, result.serverRegion.map { "\(result.serverHost) (\($0))" } ?? result.serverHost)
                        infoRow(Strings.dataUsed, Format.bytes(result.transferredBytes))
                    }
                }
                .padding(.top, 8)

                Text(Strings.latencyMethodNote)
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                Button(Strings.testAgain) { model.speedTest = .ready }
                    .buttonStyle(.ssPrimary)
                    .padding(.top, 20)
                Button(Strings.done, action: model.endSpeedTest)
                    .buttonStyle(.ssSecondary)
            }
            .padding(.horizontal, 23)
            .padding(.bottom, 16)
        }
    }

    // MARK: - History

    @ViewBuilder
    private var history: some View {
        if !model.speedTestHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(Strings.previousTests)
                    .ssText(.section18)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(model.speedTestHistory) { result in
                    HomeCard(padding: 14) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: "\(result.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(result.connection.title)")
                                    .ssText(.bodyMedium14)
                                    .foregroundStyle(SSColor.textSubtle)
                                HStack(spacing: 12) {
                                    historyValue(.arrowDown, Format.mbps(result.measurements.downloadMbps), flipped: false)
                                    historyValue(.arrowDown, Format.mbps(result.measurements.uploadMbps), flipped: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            Spacer(minLength: 8)
                            Button {
                                Task { await model.deleteSpeedTest(result.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(SSColor.textSubtle)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(Text(Strings.deleteResult))
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func historyValue(_ icon: SSIcon, _ text: String?, flipped: Bool) -> some View {
        HStack(spacing: 4) {
            SSIconView(icon, size: 14, color: SSColor.positive)
                .scaleEffect(y: flipped ? -1 : 1)
            Text(text ?? Strings.unavailable)
                .ssText(.labelSemibold14)
                .foregroundStyle(SSColor.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(flipped ? Strings.upload : Strings.download) \(text ?? Strings.unavailable)"))
    }

    // MARK: - Messages

    private func message(title: String, body: String, canRetry: Bool) -> some View {
        VStack(spacing: 12) {
            Spacer()
            SSIconChip(.wifi)
            Text(title)
                .ssText(.section18)
                .foregroundStyle(SSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Spacer()
            if canRetry {
                Button(Strings.tryAgain) { model.speedTest = .ready }
                    .buttonStyle(.ssPrimary)
            }
            Button(Strings.close, action: model.endSpeedTest)
                .buttonStyle(.ssSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 23)
        .padding(.bottom, 16)
    }
}

private extension SpeedTestProfile {
    var title: String {
        switch self {
        case .quick: Strings.quickTest
        case .standard: Strings.standardTest
        }
    }
}

private extension SpeedTestPhase {
    var title: String {
        switch self {
        case .preparing: Strings.preparingTest
        case .latency: Strings.measuringLatency
        case .download: Strings.checkingDownload
        case .upload: Strings.checkingUpload
        case .completing: Strings.finishingUp
        }
    }

    /// Completed steps out of four: latency, download, upload, finishing.
    var step: Int {
        switch self {
        case .preparing, .latency: 0
        case .download: 1
        case .upload: 2
        case .completing: 3
        }
    }
}

private extension SpeedTestError {
    var title: String {
        switch self {
        case .notConfigured: Strings.speedTestUnavailableTitle
        case .noConnection: Strings.errorNoConnectionTitle
        case .serverUnreachable, .alreadyRunning: Strings.errorServerTitle
        case .networkChanged: Strings.errorNetworkChangedTitle
        case .timedOut: Strings.errorTimedOutTitle
        case .invalidMeasurement: Strings.errorInvalidTitle
        }
    }

    var message: String {
        switch self {
        case .notConfigured: Strings.speedTestUnavailableBody
        case .noConnection: Strings.errorNoConnectionBody
        case .serverUnreachable, .alreadyRunning: Strings.errorServerBody
        case .networkChanged: Strings.errorNetworkChangedBody
        case .timedOut: Strings.errorTimedOutBody
        case .invalidMeasurement: Strings.errorInvalidBody
        }
    }
}

/// The dial artwork from Figma with a needle that tracks the live reading.
private struct SpeedGauge: View {
    let mbps: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The dial sweeps 270° from lower-left to lower-right on a log scale.
    private var needleAngle: Angle {
        let fraction = min(1, log10(1 + max(0, mbps)) / log10(251))
        return .degrees(135 + 270 * fraction)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Image(SSArtwork.gaugeGlow).resizable().frame(width: 222, height: 222).offset(x: 20, y: 20)
            Image(SSArtwork.gaugeTrack)
            Image(SSArtwork.gaugeRingOuter)
            Image(SSArtwork.gaugeRingInner).offset(x: 20, y: 20)
            Image(SSArtwork.gaugeTicks).resizable().frame(width: 256, height: 218.5).offset(x: 3, y: 3)
            Image(SSArtwork.gaugeDiscOuter).offset(x: 54, y: 54)
            Image(SSArtwork.gaugeDiscInner).offset(x: 67, y: 67)
            Image(SSArtwork.gaugeNeedle)
                .rotationEffect(needleAngle, anchor: .leading)
                .offset(x: 131, y: 130)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: mbps)
            Image(SSArtwork.gaugeHub).offset(x: 126, y: 126)
        }
        .frame(width: 262, height: 262, alignment: .topLeading)
        .accessibilityHidden(true)
        .overlay(alignment: .top) { reading.padding(.top, 215) }
    }

    private var reading: some View {
        let whole = Int(mbps)
        let fraction = Int(((mbps - Double(whole)) * 100).rounded())
        return VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: "\(whole).").ssText(.metric40)
                Text(verbatim: String(format: "%02d", min(fraction, 99))).ssText(.unitMedium24)
            }
            Text(Strings.mbpsUnit)
                .ssText(.bodyMedium16)
        }
        .foregroundStyle(SSColor.textPrimary)
        .monospacedDigit()
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Format.mbps(mbps) ?? ""))
    }
}
