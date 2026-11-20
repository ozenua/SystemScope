import ActivityStore
import Core
import DesignSystem
import SwiftUI

// SET-02 My Device, SET-03 Monitoring, SET-04 Notifications, SET-05 Thresholds,
// SET-06 Appearance.

// MARK: - My Device (SET-02)

struct MyDeviceView: View {
    let model: SettingsModel

    var body: some View {
        let device = model.device
        SettingsPage {
            SettingsHeader(title: L("My Device"), subtitle: L("The identity SystemScope uses for this iPhone."), onBack: model.goBack)
            HStack(spacing: 14) {
                SSIconView(.mobile, size: 30, color: SSColor.textStrong)
                    .frame(width: 60, height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName).font(.system(size: 22, weight: .bold)).foregroundStyle(SSColor.textStrong)
                    Text([device.modelName ?? L("Unknown iPhone model"), device.osVersion.map { L("iOS \($0)") }].compactMap { $0 }.joined(separator: " · "))
                        .ssText(.captionMedium13)
                        .foregroundStyle(SSColor.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 0) {
                stat(L("Model"), device.modelIdentifier ?? L("Unavailable"))
                Rectangle().fill(SSColor.border).frame(width: 1)
                stat(L("Storage"), device.storageCapacity ?? L("Unavailable"))
                Rectangle().fill(SSColor.border).frame(width: 1)
                stat(L("Status"), device.isIdentified ? L("Identified") : L("Partial"))
            }
            .fixedSize(horizontal: false, vertical: true)
            SettingsGroup(title: L("Device name"), footer: L("Shown on Home, in Activity and in exported reports. Only stored on this iPhone.")) {
                SettingsRow(icon: .edit, title: L("Display name"), value: model.displayName) { model.beginRename() }
            }
            SettingsGroup(title: L("Device information")) {
                SettingsRow(icon: .monitorMobile, title: L("Specifications"), subtitle: L("Chip, memory, display and cameras")) { model.dependencies.openDevice(.specifications) }
                SettingsRow(icon: .cpu, title: L("Hardware information"), subtitle: L("Sensors, connectivity and battery")) { model.dependencies.openDevice(.hardware) }
                SettingsRow(icon: .mobile, title: L("Open Device Overview")) { model.dependencies.openDevice(.overview) }
            }
            SettingsGroup(title: L("Device actions")) {
                Button { Task { await model.refreshDevice() } } label: {
                    RowContent(
                        icon: .refresh,
                        title: L("Refresh device information"),
                        subtitle: device.lastUpdated.map { L("Last updated \(SettingsFormat.relative($0))") }
                    ) {
                        if model.isRefreshingDevice { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshingDevice)
                SettingsRow(icon: .close, title: L("Reset local device profile"), subtitle: L("Restores your iPhone's detected name. History is kept."), destructive: true, showsChevron: false) {
                    model.dialog = .resetDeviceProfile
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

// MARK: - Monitoring (SET-03)

struct MonitoringSettingsView: View {
    let model: SettingsModel

    static let tiles: [(id: String, icon: SSIcon, title: String)] = [
        ("cpu", .cpu, L("CPU")),
        ("memory", .cpuSetting, L("Memory")),
        ("gpu", .cube, L("GPU")),
        ("storage", .storage, L("Storage")),
        ("battery", .batteryFull, L("Battery")),
        ("thermal", .tempCold, L("Thermal")),
        ("network", .wifi, L("Network")),
    ]

    var body: some View {
        let settings = model.settings
        SettingsPage {
            SettingsHeader(title: L("Monitoring"), subtitle: L("Customize your monitoring experience."), onBack: model.goBack)
            SettingsGroup(title: L("Monitoring preferences")) {
                ToggleRow(title: L("Refresh on page entry"), subtitle: L("Update available measurements whenever you open a monitoring page."), isOn: settings.refreshOnEntry) { value in
                    model.update { $0.refreshOnEntry = value }
                }
                ToggleRow(title: L("Automatic refresh during active sessions"), subtitle: L("Refresh supported metrics while you’re actively using Monitor."), isOn: settings.autoRefreshDuringSessions) { value in
                    model.update { $0.autoRefreshDuringSessions = value }
                }
                ToggleRow(title: L("Show historical trends"), subtitle: L("Display previously recorded observations."), isOn: settings.showHistoricalTrends) { value in
                    model.update { $0.showHistoricalTrends = value }
                }
                ToggleRow(title: L("Monitoring session summaries"), subtitle: L("Save summaries of completed monitoring sessions."), isOn: model.log.settings.recordSessions) { value in
                    model.log.updateSettings { $0.recordSessions = value }
                }
            }
            InfoBanner(
                title: L("About background monitoring"),
                message: L("iOS limits how often apps can measure in the background, so SystemScope refreshes when you open a page or during an active session.")
            )
            SettingsGroup(title: L("Show on Monitor"), footer: L("Hiding a resource only removes it from the Monitor overview. It doesn’t turn anything off on your iPhone.")) {
                ForEach(Self.tiles, id: \.id) { tile in
                    ToggleRow(icon: tile.icon, title: tile.title, isOn: !settings.hiddenMonitorTiles.contains(tile.id)) { visible in
                        model.update {
                            if visible { $0.hiddenMonitorTiles.remove(tile.id) } else { $0.hiddenMonitorTiles.insert(tile.id) }
                        }
                    }
                }
            }
            SettingsGroup {
                SettingsRow(icon: .refresh, title: L("Restore defaults"), showsChevron: false) {
                    model.update { $0.restoreMonitoringDefaults() }
                    model.log.updateSettings { $0.recordSessions = true }
                    model.showToast(L("Monitoring defaults restored"))
                }
                SettingsRow(icon: .info, title: L("How monitoring works")) { model.sheet = .howMonitoringWorks }
            }
        }
    }
}

// MARK: - Notifications (SET-04)

struct NotificationSettingsView: View {
    let model: SettingsModel

    static let categories: [(UserSettings.NotificationCategory, SSIcon, String, String)] = [
        (.battery, .batteryFull, L("Battery alerts"), L("Low battery · Battery status changes")),
        (.storage, .storage, L("Storage alerts"), L("Low available storage · Threshold reached")),
        (.thermal, .tempCold, L("Thermal alerts"), L("Elevated thermal state · Serious condition")),
        (.network, .wifi, L("Network alerts"), L("Connection changes · Speed test completed")),
        (.monitoring, .activity, L("Monitoring alerts"), L("Session completed · Collection errors")),
    ]

    var body: some View {
        let settings = model.settings
        let denied = model.notificationPermission == .denied || model.notificationPermission == .restricted
        SettingsPage {
            SettingsHeader(title: L("Notifications"), subtitle: L("Choose what deserves your attention."), onBack: model.goBack)
            if denied {
                // SET-04: show the real system status and a way to change it.
                VStack(alignment: .leading, spacing: 12) {
                    InfoBanner(
                        icon: .warning,
                        title: L("Notifications are turned off for SystemScope"),
                        message: L("iOS isn’t allowing SystemScope to send notifications. You can change this in Settings."),
                        tint: SSColor.errorText
                    )
                    Button(L("Open Settings")) { model.dependencies.openSystemSettings() }
                        .buttonStyle(SSPrimaryButtonStyle())
                }
            }
            SettingsGroup {
                ToggleRow(
                    icon: .notification,
                    title: L("Allow Notifications"),
                    subtitle: L("Receive important updates about your device."),
                    isOn: model.notificationsDelivered,
                    isEnabled: !denied
                ) { value in
                    Task { await model.setNotificationsEnabled(value) }
                }
            }
            SettingsGroup(title: L("Alert categories")) {
                ForEach(Self.categories, id: \.0) { category, icon, title, subtitle in
                    ToggleRow(
                        icon: icon,
                        title: title,
                        subtitle: subtitle,
                        isOn: !settings.disabledNotificationCategories.contains(category),
                        isEnabled: model.notificationsDelivered
                    ) { value in
                        model.setCategory(category, enabled: value)
                    }
                }
            }
            SettingsGroup {
                SettingsRow(
                    icon: .warning,
                    title: L("Alert Thresholds"),
                    subtitle: ThresholdsView.summary(settings)
                ) { model.open(.thresholds) }
            }
            Text(L("Preview")).ssText(.section18).foregroundStyle(SSColor.textStrong)
            NotificationPreview(title: L("Storage running low"), message: L("Your iPhone has less available storage than your configured threshold."))
            SettingsGroup {
                SettingsRow(icon: .navSettings, title: L("Open iOS Notification Settings")) { model.dependencies.openSystemSettings() }
                SettingsRow(icon: .refresh, title: L("Restore notification defaults"), showsChevron: false) {
                    model.update { $0.restoreNotificationDefaults() }
                    model.showToast(L("Notification defaults restored"))
                }
            }
        }
        .task { await model.refreshStatuses() }
    }
}

struct NotificationPreview: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SSIconView(.activity, size: 18, color: .white)
                .frame(width: 38, height: 38)
                .background(SSColor.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "SystemScope").ssText(.labelSemibold14)
                    Spacer()
                    Text(L("now")).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                }
                Text(title).ssText(.labelSemibold14)
                Text(message).ssText(.caption13)
            }
            .foregroundStyle(SSColor.textStrong)
        }
        .padding(14)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(12)
        .background(SSColor.lilac.opacity(0.5), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L("Notification preview: \(title). \(message)")))
    }
}

// MARK: - Thresholds (SET-05)

struct ThresholdsView: View {
    let model: SettingsModel
    @State private var draft: UserSettings
    @State private var confirmLeave = false

    init(model: SettingsModel) {
        self.model = model
        _draft = State(initialValue: model.settings)
    }

    private var hasChanges: Bool {
        draft.thresholdAlertsEnabled != model.settings.thresholdAlertsEnabled
            || draft.lowBatteryPercent != model.settings.lowBatteryPercent
            || draft.lowStoragePercent != model.settings.lowStoragePercent
            || draft.thermalThreshold != model.settings.thermalThreshold
    }

    static func summary(_ settings: UserSettings) -> String {
        guard settings.thresholdAlertsEnabled else { return L("Threshold alerts off") }
        return L("Battery \(settings.lowBatteryPercent)% · Storage \(settings.lowStoragePercent)% · Thermal \(thermalLabel(settings.thermalThreshold))")
    }

    static func thermalLabel(_ value: UserSettings.ThermalThreshold) -> String {
        switch value {
        case .fair: L("Fair")
        case .serious: L("Serious")
        case .critical: L("Critical")
        }
    }

    var body: some View {
        SettingsPage {
            SettingsHeader(
                title: L("Alert Thresholds"),
                subtitle: L("Decide when SystemScope should notify you."),
                onBack: { hasChanges ? (confirmLeave = true) : model.goBack() }
            ) {
                if hasChanges {
                    Button(L("Save")) { save() }
                        .ssText(.labelSemibold14)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(SSColor.ink, in: Capsule())
                }
            }
            if hasChanges {
                InfoBanner(title: L("Unsaved changes"), message: L("Save to apply your new thresholds, or go back to discard them."))
            }
            SettingsGroup {
                ToggleRow(icon: .warning, title: L("Threshold alerts"), subtitle: L("Notify me when a value crosses a threshold below."), isOn: draft.thresholdAlertsEnabled) {
                    draft.thresholdAlertsEnabled = $0
                }
            }
            Group {
                sliderCard(
                    section: L("Battery"), title: L("Low battery"), detail: L("Notify me when battery reaches this level."),
                    value: $draft.lowBatteryPercent, range: UserSettings.lowBatteryRange
                )
                sliderCard(
                    section: L("Storage"), title: L("Low storage"), detail: L("Notify me when available storage falls below this percentage."),
                    value: $draft.lowStoragePercent, range: UserSettings.lowStorageRange
                )
                SettingsGroup(title: L("Thermal conditions"), footer: L("Thermal states are defined by iOS and can’t be changed. You choose the lowest state that should notify you.")) {
                    RadioRow(title: L("Fair"), subtitle: L("Notify early, as soon as your iPhone starts to warm."), isSelected: draft.thermalThreshold == .fair) { draft.thermalThreshold = .fair }
                    RadioRow(title: L("Serious"), subtitle: L("Recommended. Performance may be reduced."), isSelected: draft.thermalThreshold == .serious) { draft.thermalThreshold = .serious }
                    RadioRow(title: L("Critical"), subtitle: L("Only when iOS takes strong action to cool down."), isSelected: draft.thermalThreshold == .critical) { draft.thermalThreshold = .critical }
                }
            }
            .disabled(!draft.thresholdAlertsEnabled)
            .opacity(draft.thresholdAlertsEnabled ? 1 : 0.5)
            SettingsGroup {
                Button {
                    draft.restoreThresholdDefaults()
                } label: {
                    RowContent(icon: .refresh, title: L("Reset to recommended defaults"), subtitle: Self.summary(UserSettings())) { EmptyView() }
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(L("Save your threshold changes?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(L("Save changes")) { save(); model.goBack() }
            Button(L("Discard changes"), role: .destructive) { model.goBack() }
            Button(L("Keep editing"), role: .cancel) {}
        }
    }

    private func save() {
        model.update {
            $0.thresholdAlertsEnabled = draft.thresholdAlertsEnabled
            $0.lowBatteryPercent = draft.lowBatteryPercent
            $0.lowStoragePercent = draft.lowStoragePercent
            $0.thermalThreshold = draft.thermalThreshold
        }
        draft = model.settings
        model.showToast(L("Thresholds saved"))
    }

    private func sliderCard(section: String, title: String, detail: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section).ssText(.section18).foregroundStyle(SSColor.textStrong)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).ssText(.label15).foregroundStyle(SSColor.textStrong)
                        Text(detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                    }
                    Spacer()
                    Text("\(value.wrappedValue)%").font(.system(size: 22, weight: .bold)).foregroundStyle(SSColor.textStrong)
                }
                Slider(
                    value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(UserSettings.thresholdStep)
                )
                .tint(SSColor.textStrong)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text("\(value.wrappedValue)%"))
                HStack {
                    Text("\(range.lowerBound)%")
                    Spacer()
                    Text("\(range.upperBound)%")
                }
                .ssText(.caption12)
                .foregroundStyle(SSColor.textTertiary)
                .accessibilityHidden(true)
            }
            .padding(16)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Appearance (SET-06)

struct AppearanceView: View {
    let model: SettingsModel

    static func label(_ theme: UserSettings.Theme) -> String {
        switch theme {
        case .light: L("Light")
        case .dark: L("Dark")
        case .system: L("System")
        }
    }

    var body: some View {
        let settings = model.settings
        SettingsPage {
            SettingsHeader(title: L("Appearance"), subtitle: L("Make SystemScope feel right."), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Theme")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                HStack(spacing: 8) {
                    ForEach(UserSettings.Theme.allCases, id: \.self) { theme in
                        ThemeOption(theme: theme, isSelected: settings.theme == theme, isAvailable: theme == .light) {
                            model.update { $0.theme = theme }
                        }
                    }
                }
                Text(L("Light is the SystemScope look for now. Dark and System arrive with the dark palette."))
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textTertiary)
            }
            SettingsGroup(title: L("Display preferences")) {
                ToggleRow(title: L("Compact layout"), subtitle: L("Display more information with reduced spacing."), isOn: settings.compactLayout) { value in
                    model.update { $0.compactLayout = value }
                }
                ToggleRow(title: L("Show metric descriptions"), subtitle: L("Display explanations alongside technical measurements."), isOn: settings.showMetricDescriptions) { value in
                    model.update { $0.showMetricDescriptions = value }
                }
                ToggleRow(title: L("Show technical values"), subtitle: L("Display additional technical information where available."), isOn: settings.showTechnicalValues) { value in
                    model.update { $0.showTechnicalValues = value }
                }
            }
            SettingsGroup(title: L("Motion"), footer: L("Animations are reduced automatically when Reduce Motion is on in iOS Settings.")) {
                ToggleRow(title: L("Reduce animations"), subtitle: L("Minimize interface animations."), isOn: settings.reduceAnimations) { value in
                    model.update { $0.reduceAnimations = value }
                }
            }
            SettingsGroup {
                SettingsRow(icon: .refresh, title: L("Restore appearance defaults"), showsChevron: false) {
                    model.update { $0.restoreAppearanceDefaults() }
                    model.showToast(L("Appearance defaults restored"))
                }
            }
        }
    }
}

/// Theme preview card with a radio label.
struct ThemeOption: View {
    let theme: UserSettings.Theme
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                preview
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack(spacing: 6) {
                    Image(isSelected ? SSArtwork.radioSelected : SSArtwork.radio).resizable().frame(width: 18, height: 18)
                    Text(AppearanceView.label(theme)).ssText(.label14).foregroundStyle(SSColor.textStrong)
                }
                if !isAvailable {
                    Text(L("Soon")).ssText(.chip12).foregroundStyle(SSColor.textTertiary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(isSelected ? SSColor.textStrong : SSColor.border, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.6)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(isAvailable ? "" : L("Not available yet")))
    }

    @ViewBuilder
    private var preview: some View {
        switch theme {
        case .light: mock(dark: false)
        case .dark: mock(dark: true)
        case .system:
            HStack(spacing: 0) {
                mock(dark: false)
                mock(dark: true)
            }
        }
    }

    private func mock(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(dark ? Color.white : Color.black).frame(width: 24, height: 4)
            RoundedRectangle(cornerRadius: 6).fill(dark ? Color(hex: 0x3A3550) : SSColor.lilac).frame(height: 24)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4).fill(dark ? Color(hex: 0x2A2A2A) : Color.white).frame(height: 10)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(dark ? Color(hex: 0x111111) : SSColor.chipBackground)
    }
}
