import DesignSystem
import SwiftUI

/// Set Up Monitoring: the only permission asked for in onboarding is notifications,
/// in context and skippable (ONB-02, ONB-04, ONB-05).
struct MonitoringSetupView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(onBack: model.goBack, trailingTitle: Strings.skip, onTrailing: model.goForward) {
                StepLabel(current: 5)
            }

            OnboardingScrollPage {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        Text(Strings.monitoringTitle)
                            .ssText(.title32)
                            .foregroundStyle(SSColor.textPrimary)
                            .frame(maxWidth: 236)
                            .accessibilityAddTraits(.isHeader)
                        Text(Strings.monitoringBody)
                            .ssText(.body16)
                            .foregroundStyle(SSColor.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                    notificationRow
                    privacyNote
                    askedWhenUsed
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            } footer: {
                VStack(spacing: 0) {
                    Button(Strings.continueAction, action: model.goForward)
                        .buttonStyle(.ssPrimary)
                    Button(Strings.maybeLater, action: model.goForward)
                        .buttonStyle(.ssSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
        .task { await model.refreshNotificationPermission() }
    }

    private var notificationRow: some View {
        HStack(spacing: 12) {
            SSIconTile(.notification, size: 44, iconSize: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.notifications)
                    .ssText(.rowTitle17)
                    .foregroundStyle(SSColor.textPrimary)
                Text(model.notificationPermission == .denied ? Strings.notificationsDeniedDetail : Strings.notificationsDetail)
                    .ssText(.caption13)
                    .foregroundStyle(SSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            notificationAction
        }
        .padding(14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardSmall, style: .continuous))
    }

    @ViewBuilder
    private var notificationAction: some View {
        switch model.notificationPermission {
        case .notDetermined:
            Button {
                Task { await model.enableNotifications() }
            } label: {
                Text(Strings.enable)
                    .ssText(.captionMedium12)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(SSColor.ink, in: Capsule())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        case .granted:
            statePill(Strings.enabled, color: SSColor.positive)
        case .denied:
            statePill(Strings.notAllowed, color: SSColor.textSecondary)
        }
    }

    private func statePill(_ text: String, color: Color) -> some View {
        Text(text)
            .ssText(.captionMedium12)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            SSIconView(.shieldTick, size: 20, color: SSColor.textSecondary)
            Text(Strings.privacyNote)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
    }

    private var askedWhenUsed: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Strings.askedWhenUsed)
                .ssText(.overline13)
                .foregroundStyle(SSColor.textTertiary)
                .accessibilityAddTraits(.isHeader)
            deferredPermission(Strings.location, Strings.locationReason)
            deferredPermission(Strings.camera, Strings.cameraReason)
            deferredPermission(Strings.motion, Strings.motionReason)
        }
    }

    private func deferredPermission(_ name: String, _ reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .ssText(.label14)
                .foregroundStyle(Color(hex: 0x111111))
                .fixedSize()
            Text(reason)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
