import ActivityStore
import Core
import DesignSystem
import SwiftUI

// SET-07 Data & History, SET-08 Export, SET-09 Subscription, SET-10 Privacy,
// SET-11 Support, SET-12 About.

extension HistoryKind {
    var title: String {
        switch self {
        case .activity: L("Activity history")
        case .alerts: L("Alert history")
        case .sessions: L("Session history")
        }
    }

    var icon: SSIcon {
        switch self {
        case .activity: .activity
        case .alerts: .warning
        case .sessions: .clock
        }
    }

    var color: Color {
        switch self {
        case .activity: SSColor.textStrong
        case .alerts: SSColor.footprintPurple
        case .sessions: SSColor.chartGreen
        }
    }

    func countLabel(_ count: Int) -> String {
        switch self {
        case .activity: L("\(count) records")
        case .alerts: L("\(count) alerts")
        case .sessions: L("\(count) sessions")
        }
    }
}

// MARK: - Data & History (SET-07)

struct DataHistoryView: View {
    let model: SettingsModel

    var body: some View {
        let sizes = model.measuredSizes
        let total = max(model.measuredTotal, 1)
        let retention = model.log.settings.retention
        SettingsPage {
            SettingsHeader(title: L("Data & History"), subtitle: L("Manage your SystemScope records."), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 10) {
                // SET-07: the size is measured from what is actually stored.
                let parts = SettingsFormat.bytes(model.measuredTotal).split(separator: " ", maxSplits: 1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(parts.first.map(String.init) ?? "0").font(.system(size: 44, weight: .bold)).tracking(-1.76)
                    Text(L("\(parts.count > 1 ? String(parts[1]) : "") stored on this iPhone")).ssText(.label14).foregroundStyle(SSColor.textSubtle)
                }
                .foregroundStyle(SSColor.textStrong)
                .accessibilityElement(children: .combine)
                GeometryReader { proxy in
                    HStack(spacing: 4) {
                        ForEach(HistoryKind.allCases) { kind in
                            Capsule().fill(kind.color.opacity(0.85))
                                .frame(width: max(4, (proxy.size.width - 8) * CGFloat(sizes[kind] ?? 0) / CGFloat(total)))
                        }
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    ForEach(HistoryKind.allCases) { kind in
                        HStack(spacing: 5) {
                            Circle().fill(kind.color).frame(width: 7, height: 7)
                            Text("\(kind.shortTitle) \(SettingsFormat.bytes(sizes[kind] ?? 0))").ssText(.caption12).foregroundStyle(SSColor.textSubtle)
                        }
                    }
                }
            }
            HStack(spacing: 0) {
                stat(L("Activity records"), "\(model.log.events.count)")
                Rectangle().fill(SSColor.border).frame(width: 1)
                stat(L("Monitoring sessions"), "\(model.log.sessions.count)")
                Rectangle().fill(SSColor.border).frame(width: 1)
                stat(L("Oldest record"), model.log.oldestRecord.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? "–")
            }
            .fixedSize(horizontal: false, vertical: true)
            SettingsGroup(title: L("Keep history"), footer: L("Turning one off stops new records. Existing records stay until they expire or you clear them.")) {
                ToggleRow(icon: .activity, title: L("Activity history"), subtitle: L("Keep recorded device events."), isOn: model.log.settings.recordActivity) { value in
                    model.log.updateSettings { $0.recordActivity = value }
                }
                ToggleRow(icon: .clock, title: L("Session history"), subtitle: L("Keep completed monitoring sessions."), isOn: model.log.settings.recordSessions) { value in
                    model.log.updateSettings { $0.recordSessions = value }
                }
            }
            SettingsGroup(title: L("History retention"), footer: L("Records older than this are removed automatically. Open alerts are kept until you resolve them.")) {
                RadioRow(title: L("7 days"), isSelected: retention == .sevenDays) { model.log.updateSettings { $0.retention = .sevenDays } }
                RadioRow(title: L("30 days"), subtitle: L("Recommended"), isSelected: retention == .thirtyDays) { model.log.updateSettings { $0.retention = .thirtyDays } }
                RadioRow(title: L("90 days"), isSelected: retention == .ninetyDays) { model.log.updateSettings { $0.retention = .ninetyDays } }
                RadioRow(title: L("Keep indefinitely"), subtitle: L("History may use more storage over time."), isSelected: retention == .indefinitely) { model.log.updateSettings { $0.retention = .indefinitely } }
            }
            SettingsGroup(title: L("Data actions")) {
                SettingsRow(icon: .arrowUp, title: L("Export data"), subtitle: L("CSV or JSON files")) { model.open(.export) }
                ForEach(HistoryKind.allCases) { kind in
                    SettingsRow(icon: .close, title: L("Clear \(kind.title.lowercased())"), subtitle: kind.countLabel(model.count(of: kind)), destructive: true, showsChevron: false) {
                        model.beginClear([kind])
                    }
                    .disabled(model.count(of: kind) == 0)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            Text(value).ssText(.value16).foregroundStyle(SSColor.textStrong).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension HistoryKind {
    var shortTitle: String {
        switch self {
        case .activity: L("Activity")
        case .alerts: L("Alerts")
        case .sessions: L("Sessions")
        }
    }
}

// MARK: - Export (SET-08)

struct ExportView: View {
    @Bindable var model: SettingsModel

    private func info(_ item: ExportItem) -> (SSIcon, String, String) {
        switch item {
        case .device: (.mobile, L("Device specifications"), L("Hardware and software details"))
        case .activity: (.activity, L("Activity history"), L("\(model.log.events.count) records"))
        case .alerts: (.warning, L("Alert history"), L("\(model.log.alerts.count) alerts"))
        case .sessions: (.clock, L("Monitoring session reports"), L("\(model.log.sessions.count) sessions"))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsPage {
                SettingsHeader(title: L("Export Data"), subtitle: L("Take your device monitoring records with you."), onBack: model.goBack)
                HStack {
                    Text(L("What to export")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                    Spacer()
                    Text(L("\(model.exportSelection.count) of \(ExportItem.allCases.count) selected")).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                }
                VStack(spacing: 8) {
                    ForEach(ExportItem.allCases) { item in
                        let (icon, title, subtitle) = info(item)
                        let selected = model.exportSelection.contains(item)
                        Button { model.toggleExport(item) } label: {
                            RowContent(icon: icon, title: title, subtitle: subtitle) {
                                Image(systemName: selected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected ? SSColor.textStrong : SSColor.textFaint)
                            }
                            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? SSColor.textStrong : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                Text(L("Format")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                SettingsGroup {
                    RadioRow(title: "CSV", subtitle: L("Opens in Numbers or a spreadsheet app"), isSelected: model.exportFormat == .csv) { model.exportFormat = .csv; model.resetExport() }
                    RadioRow(title: "JSON", subtitle: L("Structured, with a schema version"), isSelected: model.exportFormat == .json) { model.exportFormat = .json; model.resetExport() }
                }
                Text(L("Device specifications are always a plain-text file. Exports are created on this iPhone; nothing is uploaded."))
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textTertiary)
            }
            footer
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            switch model.exportState {
            case .failed:
                Text(L("Couldn’t create the export. Nothing was saved. Try again.")).ssText(.caption12).foregroundStyle(SSColor.errorText)
            case .ready(let urls):
                Text(L("\(urls.count) files ready")).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            default:
                Text(L("\(model.exportSelection.count) files · All dates")).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            }
            HStack(spacing: 10) {
                Button(L("Cancel")) { model.resetExport(); model.goBack() }
                    .ssText(.value16)
                    .foregroundStyle(SSColor.textStrong)
                    .frame(width: 100, height: 54)
                    .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                switch model.exportState {
                case .ready(let urls):
                    ShareLink(items: urls) {
                        Text(L("Share Export")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SSPrimaryButtonStyle())
                case .generating:
                    Button {} label: {
                        HStack(spacing: 8) { ProgressView().tint(.white); Text(L("Generating…")) }
                    }
                    .buttonStyle(SSPrimaryButtonStyle())
                    .disabled(true)
                default:
                    Button(model.exportState == .failed ? L("Try Again") : L("Export Data")) { Task { await model.generateExport() } }
                        .buttonStyle(SSPrimaryButtonStyle())
                        .disabled(model.exportSelection.isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SSColor.surfaceSubtle)
    }
}

// MARK: - Subscription (SET-09)

struct SubscriptionView: View {
    let model: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsHeader(title: L("Subscription"), subtitle: L("Your SystemScope plan."), onBack: model.goBack)
            SubscriptionCard()
            SettingsGroup(title: L("Plan details")) {
                detail(L("Current plan"), L("Free"))
                detail(L("Status"), L("No active subscription"))
            }
            SettingsGroup(title: L("Premium includes")) {
                ForEach([L("Detailed monitoring"), L("Historical trends"), L("Advanced charts"), L("Custom alerts"), L("Monitoring reports")], id: \.self) { benefit in
                    TickLine(text: benefit).padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            if !model.plans.isEmpty {
                SettingsGroup(title: L("Plans")) {
                    ForEach(model.plans) { plan in
                        detail(plan.title, plan.price)
                    }
                }
            }
            InfoBanner(
                title: L("Purchases aren’t open yet"),
                message: L("Subscriptions will be sold through the App Store. Prices shown come from the store configuration.")
            )
            SettingsGroup(title: L("Manage")) {
                Button { Task { await model.restorePurchases() } } label: {
                    RowContent(icon: .refresh, title: L("Restore Purchases"), subtitle: model.restoreMessage ?? L("Use Premium on another iPhone with the same Apple Account")) { EmptyView() }
                }
                .buttonStyle(.plain)
            }
            if model.dependencies.links.terms != nil || model.dependencies.links.privacyPolicy != nil {
                SettingsGroup {
                    if let terms = model.dependencies.links.terms {
                        Link(destination: terms) { RowContent(title: L("Terms of Use")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                    }
                    if let privacy = model.dependencies.links.privacyPolicy {
                        Link(destination: privacy) { RowContent(title: L("Privacy Policy")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                    }
                }
            }
            Text(L("Payment is handled by Apple. Subscriptions renew automatically unless cancelled at least 24 hours before the renewal date."))
                .ssText(.caption12)
                .foregroundStyle(SSColor.textTertiary)
        }
        .task { await model.loadPlans() }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).ssText(.label15).foregroundStyle(SSColor.textStrong)
            Spacer()
            Text(value).ssText(.body14).foregroundStyle(SSColor.textTertiary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Privacy & Permissions (SET-10)

struct PrivacyView: View {
    let model: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsHeader(title: L("Privacy & Permissions"), subtitle: L("Understand and control your data."), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 12) {
                SSIconView(.shieldTick, size: 22, color: SSColor.textStrong)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                Text(L("Your information. Your control.")).font(.system(size: 24, weight: .bold)).foregroundStyle(SSColor.textStrong)
                Text(L("SystemScope is designed to collect only the information needed to provide your monitoring experience."))
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.75))
                TickLine(text: L("Records stay on this iPhone"))
                TickLine(text: L("You decide what’s kept and for how long"))
                TickLine(text: L("Export or delete your data anytime"))
            }
            // SET-10: only permissions SystemScope actually uses. It never asks for
            // camera or location, so those rows are not shown.
            SettingsGroup(title: L("Permissions"), footer: L("Permissions are managed by iOS. SystemScope only asks when you use a feature that needs one.")) {
                permission(.notification, L("Notifications"), L("Alerts for battery, storage and thermal changes."), model.notificationPermission)
                permission(.activity, L("Motion & Fitness"), L("Used only by the barometer sensor test in Device."), model.motionPermission)
            }
            SettingsGroup(title: L("Data management")) {
                if let privacy = model.dependencies.links.privacyPolicy {
                    Link(destination: privacy) { RowContent(icon: .info, title: L("Privacy Policy")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                }
                SettingsRow(icon: .info, title: L("What SystemScope collects")) { model.sheet = .whatWeCollect }
                SettingsRow(icon: .close, title: L("Clear local data"), subtitle: L("Removes history from this iPhone"), destructive: true, showsChevron: false) { model.beginClear() }
                SettingsRow(icon: .close, title: L("Reset local device profile"), subtitle: L("Restores your iPhone's detected name"), destructive: true, showsChevron: false) { model.dialog = .resetDeviceProfile }
            }
        }
        .task { await model.refreshStatuses() }
    }

    private func permission(_ icon: SSIcon, _ title: String, _ detail: String, _ state: SettingsPermission) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SSIconView(icon, size: 20, color: SSColor.textStrong)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).ssText(.label15).foregroundStyle(SSColor.textStrong)
                Text(detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                switch state {
                case .denied, .restricted:
                    Button(L("Open Settings")) { model.dependencies.openSystemSettings() }
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textStrong)
                case .granted:
                    Button(L("Manage in Settings")) { model.dependencies.openSystemSettings() }
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textStrong)
                case .notDetermined:
                    Text(L("Ask when needed")).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PermissionPill(permission: state)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Support (SET-11)

struct SupportView: View {
    let model: SettingsModel
    @State private var includeDiagnostics = false

    var body: some View {
        let links = model.dependencies.links
        let device = model.device
        SettingsPage {
            SettingsHeader(title: L("Support"), subtitle: L("We’re here to help."), onBack: model.goBack)
            if links.helpCentre != nil || links.supportEmail != nil {
                SettingsGroup(title: L("Get help")) {
                    if let help = links.helpCentre {
                        Link(destination: help) { RowContent(icon: .messageQuestion, title: L("Help Centre"), subtitle: L("Browse common questions and guides")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                    }
                    if let email = links.supportEmail, let url = mailURL(email, subject: L("SystemScope support")) {
                        Link(destination: url) { RowContent(icon: .notification, title: L("Contact Support"), subtitle: L("Get help with SystemScope")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                    }
                    if let email = links.supportEmail, let url = mailURL(email, subject: L("Problem report")) {
                        Link(destination: url) { RowContent(icon: .warning, title: L("Report a Problem"), subtitle: L("Report an unexpected result or app issue")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                    }
                }
            } else {
                InfoBanner(title: L("Support channels open at launch"), message: L("Help articles and contact details will appear here. Until then, you can copy diagnostic information below."))
            }
            SettingsGroup(title: L("Diagnostic information"), footer: L("Never attached automatically. You can review everything before sending.")) {
                ToggleRow(title: L("Include with my message"), subtitle: L("Adds the details below to support requests. Nothing else is shared."), isOn: includeDiagnostics) { includeDiagnostics = $0 }
                info(L("App version"), "\(model.dependencies.appVersion) (\(model.dependencies.buildNumber))")
                info(L("iOS version"), device.osVersion ?? L("Unavailable"))
                info(L("Device model"), device.modelName ?? L("Unknown iPhone model"))
                SettingsRow(icon: .copy, title: L("Copy diagnostic information"), showsChevron: false) { model.copyDiagnostics() }
            }
        }
    }

    private func mailURL(_ address: String, subject: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var body = ""
        if includeDiagnostics { body = "\n\n---\n" + model.diagnosticText }
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }

    private func info(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).ssText(.label15).foregroundStyle(SSColor.textStrong)
            Spacer()
            Text(value).ssText(.body14).foregroundStyle(SSColor.textTertiary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - About (SET-12)

struct AboutView: View {
    let model: SettingsModel

    var body: some View {
        let links = model.dependencies.links
        SettingsPage {
            SettingsHeader(title: L("About"), subtitle: "", onBack: model.goBack)
            VStack(spacing: 10) {
                AppLogo(size: 88)
                Text(verbatim: "SystemScope").font(.system(size: 28, weight: .bold)).foregroundStyle(SSColor.textStrong)
                Text(L("Version \(model.dependencies.appVersion) · Build \(model.dependencies.buildNumber)"))
                    .ssText(.label14)
                    .foregroundStyle(SSColor.textTertiary)
            }
            .frame(maxWidth: .infinity)
            Text(L("SystemScope helps you understand your iPhone through clear device information, resource monitoring and useful insights."))
                .ssText(.bodyMedium16)
                .foregroundStyle(SSColor.textStrong)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            SettingsGroup {
                SettingsRow(icon: .lamp, title: L("What’s New"), value: model.dependencies.appVersion) { model.sheet = .whatsNew }
                if let terms = links.terms {
                    Link(destination: terms) { RowContent(icon: .info, title: L("Terms of Use")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                }
                if let privacy = links.privacyPolicy {
                    Link(destination: privacy) { RowContent(icon: .shieldTick, title: L("Privacy Policy")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                }
                SettingsRow(icon: .cube, title: L("Open Source Licenses")) { model.sheet = .licenses }
                if let website = links.website {
                    Link(destination: website) { RowContent(icon: .wifi, title: L("Website")) { SSIconView(.chevronRight, size: 20, color: SSColor.textFaint) } }
                }
                SettingsRow(icon: .messageQuestion, title: L("Contact")) { model.open(.support) }
            }
            VStack(spacing: 4) {
                Text(L("Made for a better understanding of your device."))
                Text(verbatim: "© \(Calendar.current.component(.year, from: .now)) SystemScope")
            }
            .ssText(.caption12)
            .foregroundStyle(SSColor.textTertiary)
            .frame(maxWidth: .infinity)
        }
    }
}
