import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// Your Device Is Ready: summarises what the scan identified and what iOS does not
/// expose (ONB-09), then opens the full app.
struct DeviceReadyView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppLogo(size: 32)
                Spacer()
                HStack(spacing: 6) {
                    SSIconView(.tickCircle, size: 16, color: SSColor.positiveFill)
                    Text(Strings.setupComplete)
                        .ssText(.captionMedium13)
                        .foregroundStyle(SSColor.positive)
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)

            OnboardingScrollPage {
                VStack(spacing: 10) {
                    OnboardingHeading(title: Strings.readyTitle, message: Strings.readyBody, spacing: 8)
                    summaryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } footer: {
                Button(Strings.continueAction, action: model.finish)
                    .buttonStyle(.ssSecondaryCompact)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
    }

    // MARK: - Summary

    private var summary: DeviceSummary { model.summary }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SSIconTile(.mobile)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.modelName ?? Strings.unknownModel)
                        .ssText(.cardTitle18)
                        .foregroundStyle(SSColor.textPrimary)
                    if !identitySubtitle.isEmpty {
                        Text(identitySubtitle)
                            .ssText(.body14)
                            .foregroundStyle(SSColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            Grid(alignment: .topLeading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    metric(Strings.storage, storageValue, storageCaption)
                    metric(Strings.battery, batteryValue, batteryCaption)
                }
                GridRow {
                    metric(Strings.thermalState, thermalValue, Strings.iosThermalState)
                    metric(Strings.memory, memoryValue, memoryCaption)
                }
            }

            if model.hasUnavailableInformation {
                Text(Strings.unavailableNote)
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textSecondary)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous))
    }

    private func metric(_ label: String, _ value: String?, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textSecondary)
            Text(value ?? Strings.unavailable)
                .ssText(.metric17)
                .foregroundStyle(value == nil ? SSColor.textSecondary : SSColor.textPrimary)
            Text(caption)
                .ssText(.caption12)
                .foregroundStyle(SSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var identitySubtitle: String {
        [summary.osVersion.map(Strings.iosVersionValue), summary.processor]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var storageValue: String? {
        summary.storageAvailableBytes.map { Strings.storageFree(ByteFormatting.storage($0)) }
    }

    private var storageCaption: String {
        summary.storageTotalBytes.map { Strings.ofTotal(ByteFormatting.storage($0, fractionDigits: 0)) }
            ?? Strings.notReported
    }

    private var batteryValue: String? {
        summary.batteryLevel.map { $0.formatted(.percent.precision(.fractionLength(0))) }
    }

    private var batteryCaption: String {
        switch summary.batteryState {
        case .unplugged: Strings.notCharging
        case .charging: Strings.charging
        case .full: Strings.fullyCharged
        case nil: Strings.notReported
        }
    }

    private var thermalValue: String? {
        switch summary.thermalState {
        case .nominal: Strings.thermalNominal
        case .fair: Strings.thermalFair
        case .serious: Strings.thermalSerious
        case .critical: Strings.thermalCritical
        case nil: nil
        }
    }

    /// Device-wide memory in use is shown only when a provider measured it; otherwise
    /// the tile falls back to physical memory rather than inventing a figure.
    private var memoryValue: String? {
        if let inUse = summary.memoryInUseBytes {
            return ByteFormatting.memory(inUse, fractionDigits: 1)
        }
        return summary.physicalMemoryBytes.map { ByteFormatting.memory($0) }
    }

    private var memoryCaption: String {
        guard let total = summary.physicalMemoryBytes else { return Strings.notReported }
        return summary.memoryInUseBytes == nil
            ? Strings.physicalMemory
            : Strings.inUseOf(ByteFormatting.memory(total))
    }

}
