import ActivityStore
import Core
import DesignSystem
import SwiftUI

/// SET-01 · Settings overview and the pushed Settings screens.
public struct SettingsView: View {
    @Bindable private var model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }
    public var body: some View {
        NavigationStack(path: $model.path) {
            SettingsOverview(model: model)
                .navigationDestination(for: SettingsRoute.self) { route in
                Group {
                    switch route {
                    case .myDevice: MyDeviceView(model: model)
                    case .monitoring: MonitoringSettingsView(model: model)
                    case .notifications: NotificationSettingsView(model: model)
                    case .thresholds: ThresholdsView(model: model)
                    case .appearance: AppearanceView(model: model)
                    case .data: DataHistoryView(model: model)
                    case .export: ExportView(model: model)
                    case .privacy: PrivacyView(model: model)
                    case .support: SupportView(model: model)
                    case .about: AboutView(model: model)
                    }
                    }
                    .ssFadeInNavigationDestination()
                }
        }
        .backSwipe { model.goBack() }
        .task { await model.refreshStatuses() }
    }
}

public extension View {
    /// Settings sheets, dialogs and toast. Applied by the shell at its root, like the
    /// Device and Activity sheets, so a root update never dismisses them.
    func settingsSheets(model: SettingsModel) -> some View {
        modifier(SettingsSheetsModifier(model: model))
    }
}

private struct SettingsSheetsModifier: ViewModifier {
    @Bindable var model: SettingsModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.sheet) { sheet in
                switch sheet {
                case .rename: RenameDeviceSheet(model: model)
                case .clearHistory: ClearHistorySheet(model: model)
                case .howMonitoringWorks: InfoSheet(title: L("How monitoring works"), paragraphs: InfoText.monitoring) { model.sheet = nil }
                case .whatsNew: InfoSheet(title: L("What’s New"), paragraphs: InfoText.whatsNew) { model.sheet = nil }
                case .licenses: InfoSheet(title: L("Open Source Licenses"), paragraphs: InfoText.licenses) { model.sheet = nil }
                case .whatWeCollect: InfoSheet(title: L("What SystemScope collects"), paragraphs: InfoText.collects) { model.sheet = nil }
                }
            }
            .overlay {
                switch model.dialog {
                case .resetPreferences:
                    ConfirmDialog(
                        icon: .refresh, iconColor: SSColor.textStrong,
                        title: L("Reset preferences?"),
                        message: L("Your SystemScope preferences will return to their default settings. Your device profile and saved history will remain unchanged."),
                        confirmTitle: L("Reset Preferences"),
                        onConfirm: { model.resetPreferences() },
                        onCancel: { model.dialog = nil }
                    ) {
                        VStack(spacing: 6) {
                            TickLine(text: L("Monitoring, notifications and appearance"), boxed: true)
                            TickLine(text: L("Thresholds back to recommended"), boxed: true)
                        }
                    }
                case .resetDeviceProfile:
                    ConfirmDialog(
                        icon: .close, iconColor: SSColor.errorText,
                        title: L("Reset local device profile?"),
                        message: L("The display name returns to “\(AppPreferences.defaultDeviceDisplayName)”. Your history and preferences are kept."),
                        confirmTitle: L("Reset Profile"),
                        onConfirm: { model.resetDeviceProfile() },
                        onCancel: { model.dialog = nil }
                    ) { EmptyView() }
                case nil:
                    EmptyView()
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    SettingsToast(message: toast)
                        .padding(.bottom, 116)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.dialog)
            .animation(.easeInOut(duration: 0.25), value: model.toast)
    }
}

struct SettingsOverview: View {
    let model: SettingsModel

    var body: some View {
        let device = model.device
        let settings = model.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                deviceProfile(device)
                SettingsGroup(title: nil) {
                    SettingsRow(icon: .activity, title: L("Monitoring Preferences"), subtitle: L("What SystemScope measures and shows")) { model.open(.monitoring) }
                    SettingsRow(icon: .refresh, title: L("Refresh Preferences"), value: settings.refreshOnEntry ? L("On open") : L("Manual")) { model.open(.monitoring) }
                    SettingsRow(icon: .notification, title: L("Notification Preferences"), value: model.notificationsDelivered ? L("On") : L("Off")) { model.open(.notifications) }
                    SettingsRow(icon: .warning, title: L("Alert Thresholds"), value: settings.thresholdAlertsEnabled ? L("\(settings.activeThresholdCount) active") : L("Off")) { model.open(.thresholds) }
                    SettingsRow(icon: .brush, title: L("Theme"), value: AppearanceView.label(settings.theme)) { model.open(.appearance) }
                    SettingsRow(icon: .monitor, title: L("Display Preferences")) { model.open(.appearance) }
                    SettingsRow(icon: .storage, title: L("Data & History"), value: SettingsFormat.bytes(model.measuredTotal)) { model.open(.data) }
                    SettingsRow(icon: .shieldTick, title: L("Privacy & Permissions")) { model.open(.privacy) }
                    SettingsRow(icon: .messageQuestion, title: L("Support")) { model.open(.support) }
                    SettingsRow(icon: .info, title: L("About SystemScope"), value: model.dependencies.appVersion) { model.open(.about) }
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Settings"))
                    .ssText(.pageTitle28)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
                Text(L("Make SystemScope yours."))
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button(L("Reset preferences")) { model.dialog = .resetPreferences }
                Button(L("Replay onboarding")) { model.dependencies.replayOnboarding() }
            } label: {
                SSIconView(.more, size: 20, color: SSColor.textStrong)
                    .frame(width: 44, height: 44)
                    .background(SSColor.surface, in: Circle())
            }
            .accessibilityLabel(Text(L("More options")))
        }
    }

    private func deviceProfile(_ device: SettingsDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { model.open(.myDevice) } label: {
                HStack(spacing: 14) {
                    SSIconView(.mobile, size: 30, color: SSColor.textStrong)
                        .frame(width: 60, height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .tracking(-0.66)
                            .foregroundStyle(SSColor.textStrong)
                        Text(deviceLine(device))
                            .ssText(.captionMedium13)
                            .foregroundStyle(SSColor.textStrong.opacity(0.6))
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            Button { model.open(.myDevice) } label: {
                Text(L("Manage Device"))
                    .ssText(.rowTitle15)
                    .foregroundStyle(SSColor.textStrong)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func deviceLine(_ device: SettingsDeviceInfo) -> String {
        [device.modelName ?? L("Unknown iPhone model"), device.osVersion.map { L("iOS \($0)") }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("SystemScope \(model.dependencies.appVersion) (\(model.dependencies.buildNumber))")
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textTertiary)
            HStack(spacing: 14) {
                if let terms = model.dependencies.links.terms {
                    Link(L("Terms of Use"), destination: terms)
                }
                if let privacy = model.dependencies.links.privacyPolicy {
                    Link(L("Privacy Policy"), destination: privacy)
                }
            }
            .ssText(.chip12)
            .underline()
            .foregroundStyle(SSColor.textStrong)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
