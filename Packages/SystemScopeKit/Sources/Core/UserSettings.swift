import Foundation

/// User preferences from Settings (PRD §6.6). Stored as one versioned document in
/// UserDefaults. The device display name, onboarding state and first-registered date
/// live outside it, so "Reset preferences" never touches them (SET-14).
public struct UserSettings: Codable, Sendable, Equatable {
    public enum Theme: String, Codable, Sendable, CaseIterable {
        case light
        case dark
        case system
    }

    /// The lowest thermal state that raises an alert (SET-05).
    public enum ThermalThreshold: String, Codable, Sendable, CaseIterable {
        case fair
        case serious
        case critical
    }

    public enum NotificationCategory: String, Codable, Sendable, CaseIterable {
        case battery
        case storage
        case thermal
        case network
        case monitoring
    }

    public var version = 1

    // SET-03 Monitoring. There is no background interval: iOS does not allow one.
    public var refreshOnEntry = true
    public var autoRefreshDuringSessions = true
    public var showHistoricalTrends = true
    /// Monitor overview tiles the user hid, by route name.
    public var hiddenMonitorTiles: Set<String> = []

    // SET-04 Notifications.
    public var notificationsEnabled = true
    public var disabledNotificationCategories: Set<NotificationCategory> = [.network]

    // SET-05 Thresholds.
    public var thresholdAlertsEnabled = true
    public var lowBatteryPercent = 20
    public var lowStoragePercent = 10
    public var thermalThreshold: ThermalThreshold = .serious

    // SET-06 Appearance.
    public var theme: Theme = .light
    public var compactLayout = false
    public var showMetricDescriptions = true
    public var showTechnicalValues = false
    public var reduceAnimations = false

    public init() {}

    public static let lowBatteryRange = 5...50
    public static let lowStorageRange = 5...30
    public static let thresholdStep = 5

    public func isEnabled(_ category: NotificationCategory) -> Bool {
        notificationsEnabled && !disabledNotificationCategories.contains(category)
    }

    /// How many threshold alerts are on, for the Settings overview.
    public var activeThresholdCount: Int {
        thresholdAlertsEnabled ? 3 : 0
    }

    // Section defaults, for the per-screen "Restore defaults" actions.
    public mutating func restoreMonitoringDefaults() {
        let defaults = UserSettings()
        refreshOnEntry = defaults.refreshOnEntry
        autoRefreshDuringSessions = defaults.autoRefreshDuringSessions
        showHistoricalTrends = defaults.showHistoricalTrends
        hiddenMonitorTiles = defaults.hiddenMonitorTiles
    }

    public mutating func restoreNotificationDefaults() {
        let defaults = UserSettings()
        notificationsEnabled = defaults.notificationsEnabled
        disabledNotificationCategories = defaults.disabledNotificationCategories
    }

    public mutating func restoreThresholdDefaults() {
        let defaults = UserSettings()
        thresholdAlertsEnabled = defaults.thresholdAlertsEnabled
        lowBatteryPercent = defaults.lowBatteryPercent
        lowStoragePercent = defaults.lowStoragePercent
        thermalThreshold = defaults.thermalThreshold
    }

    public mutating func restoreAppearanceDefaults() {
        let defaults = UserSettings()
        theme = defaults.theme
        compactLayout = defaults.compactLayout
        showMetricDescriptions = defaults.showMetricDescriptions
        showTechnicalValues = defaults.showTechnicalValues
        reduceAnimations = defaults.reduceAnimations
    }
}
