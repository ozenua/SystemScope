import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// Meet Your Device: static identification read without any permission (ONB-03).
struct MeetDeviceView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(onBack: model.goBack, trailingTitle: Strings.skip, onTrailing: model.goForward)

            OnboardingScrollPage {
                EmptyView()
            } footer: {
                VStack(spacing: 8) {
                    card
                    Button(Strings.identifyAgain) {
                        Task { await model.identifyDevice() }
                    }
                    .buttonStyle(.ssSecondary)
                    .disabled(model.isIdentifying)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
        .task {
            if model.summary.osVersion == nil { await model.identifyDevice() }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SSIconTile(.mobile)
                VStack(alignment: .leading, spacing: 5) {
                    Text(Strings.yourIPhone)
                        .ssText(.cardTitle18)
                    Text(Strings.deviceIdentification)
                        .ssText(.body16)
                }
                .foregroundStyle(SSColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 24) {
                row(Strings.deviceModel, model.summary.modelName, fallback: Strings.unknownModel)
                row(Strings.iosVersion, model.summary.osVersion.map(Strings.iosVersionValue))
                row(Strings.processor, model.summary.processor)
                row(Strings.memory, model.summary.physicalMemoryBytes.map { ByteFormatting.memory($0) })
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            Button(Strings.continueAction, action: model.goForward)
                .buttonStyle(.ssPrimary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 16)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous))
    }

    private func row(_ label: String, _ value: String?, fallback: String = Strings.unavailable) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .ssText(.body16)
                .foregroundStyle(SSColor.textPrimary)
            Spacer(minLength: 0)
            if model.isIdentifying {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text(Strings.identifying))
            } else {
                Text(value ?? fallback)
                    .ssText(.bodyMedium16)
                    .foregroundStyle(value == nil ? SSColor.textSecondary : SSColor.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
