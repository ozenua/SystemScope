import ActivityStore
import Core
import Foundation
import Observation

func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

public enum SettingsRoute: Hashable, Sendable {
    case myDevice
    case monitoring
    case notifications
    case thresholds
    case appearance
    case data
    case export
    case subscription
    case privacy
    case support
    case about
}

/// Device screens Settings links to; AppShell maps them to Device routes.
public enum SettingsDeviceLink: Sendable {
    case overview
    case specifications
    case hardware
}

public enum SettingsPermission: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
    case restricted
}

/// What Settings shows about this iPhone. Read from the Device tab's model.
public struct SettingsDeviceInfo: Sendable, Equatable {
    public var modelName: String?
    public var modelIdentifier: String?
    public var osVersion: String?
    public var storageCapacity: String?
    public var isIdentified: Bool
    public var lastUpdated: Date?

    public init(modelName: String? = nil, modelIdentifier: String? = nil, osVersion: String? = nil, storageCapacity: String? = nil, isIdentified: Bool = false, lastUpdated: Date? = nil) {
        self.modelName = modelName
        self.modelIdentifier = modelIdentifier
        self.osVersion = osVersion
        self.storageCapacity = storageCapacity
        self.isIdentified = isIdentified
        self.lastUpdated = lastUpdated
    }
}

public struct SettingsPlan: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var price: String

    public init(id: String, title: String, price: String) {
        self.id = id
        self.title = title
        self.price = price
    }
}

/// Links shown in Support and About. Nil hides the row: no placeholder URLs ship.
public struct SettingsLinks: Sendable, Equatable {
    public var helpCentre: URL?
    public var supportEmail: String?
    public var terms: URL?
    public var privacyPolicy: URL?
    public var website: URL?

    public init(helpCentre: URL? = nil, supportEmail: String? = nil, terms: URL? = nil, privacyPolicy: URL? = nil, website: URL? = nil) {
        self.helpCentre = helpCentre
        self.supportEmail = supportEmail
        self.terms = terms
        self.privacyPolicy = privacyPolicy
        self.website = website
    }
}

/// Services Settings needs, injected by AppShell so the feature never imports another.
@MainActor
public struct SettingsDependencies {
    public var deviceInfo: @MainActor () -> SettingsDeviceInfo
    public var refreshDevice: @MainActor () async -> Void
    public var notificationStatus: @Sendable () async -> SettingsPermission
    public var requestNotifications: @Sendable () async -> SettingsPermission
    public var motionStatus: @Sendable () -> SettingsPermission
    public var loadPlans: @Sendable () async -> [SettingsPlan]
    public var restorePurchases: @Sendable () async -> Bool
    public var deviceReport: @MainActor () -> String
    public var links: SettingsLinks
    public var appVersion: String
    public var buildNumber: String
    public var openSystemSettings: @MainActor () -> Void
    public var openDevice: @MainActor (SettingsDeviceLink) -> Void
    public var replayOnboarding: @MainActor () -> Void
    public var copy: @MainActor (String) -> Void

    public init(
        deviceInfo: @escaping @MainActor () -> SettingsDeviceInfo,
        refreshDevice: @escaping @MainActor () async -> Void,
        notificationStatus: @escaping @Sendable () async -> SettingsPermission,
        requestNotifications: @escaping @Sendable () async -> SettingsPermission,
        motionStatus: @escaping @Sendable () -> SettingsPermission,
        loadPlans: @escaping @Sendable () async -> [SettingsPlan],
        restorePurchases: @escaping @Sendable () async -> Bool,
        deviceReport: @escaping @MainActor () -> String,
        links: SettingsLinks = SettingsLinks(),
        appVersion: String,
        buildNumber: String,
        openSystemSettings: @escaping @MainActor () -> Void,
        openDevice: @escaping @MainActor (SettingsDeviceLink) -> Void,
        replayOnboarding: @escaping @MainActor () -> Void,
        copy: @escaping @MainActor (String) -> Void
    ) {
        self.deviceInfo = deviceInfo
        self.refreshDevice = refreshDevice
        self.notificationStatus = notificationStatus
        self.requestNotifications = requestNotifications
        self.motionStatus = motionStatus
        self.loadPlans = loadPlans
        self.restorePurchases = restorePurchases
        self.deviceReport = deviceReport
        self.links = links
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.openSystemSettings = openSystemSettings
        self.openDevice = openDevice
        self.replayOnboarding = replayOnboarding
        self.copy = copy
    }
}

public enum SettingsSheet: String, Identifiable, Sendable {
    case rename
    case clearHistory
    case howMonitoringWorks
    case whatsNew
    case licenses
    case whatWeCollect

    public var id: String { rawValue }
}

public enum SettingsDialog: Equatable, Sendable {
    case resetPreferences
    case resetDeviceProfile
}

/// SET-13 clear-history flow.
public enum ClearFlowState: Equatable, Sendable {
    case choosing
    case confirming
    case deleting
    case succeeded(Int)
    case failed
}

/// SET-08 export flow.
public enum ExportState: Equatable, Sendable {
    case idle
    case generating
    case ready([URL])
    case failed
}

public enum ExportItem: String, CaseIterable, Sendable, Identifiable {
    case device
    case activity
    case alerts
    case sessions

    public var id: String { rawValue }
}

public enum ExportFormat: String, CaseIterable, Sendable {
    case csv
    case json
}

@MainActor
@Observable
public final class SettingsModel {
    public var path: [SettingsRoute] = []
    public var sheet: SettingsSheet?
    public var dialog: SettingsDialog?
    public private(set) var toast: String?
    public private(set) var notificationPermission: SettingsPermission = .notDetermined
    public private(set) var motionPermission: SettingsPermission = .notDetermined
    public private(set) var plans: [SettingsPlan] = []
    public private(set) var restoreMessage: String?
    public private(set) var isRefreshingDevice = false

    // Rename
    public var renameDraft = ""
    public private(set) var renameError = false

    // Clear history (SET-13)
    public var clearSelection: Set<HistoryKind> = [.activity]
    public private(set) var clearState: ClearFlowState = .choosing

    // Export (SET-08)
    public var exportSelection: Set<ExportItem> = [.device, .activity]
    public var exportFormat: ExportFormat = .csv
    public private(set) var exportState: ExportState = .idle

    public let preferences: AppPreferences
    public let log: ActivityLog
    public let dependencies: SettingsDependencies
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    public init(preferences: AppPreferences, log: ActivityLog, dependencies: SettingsDependencies) {
        self.preferences = preferences
        self.log = log
        self.dependencies = dependencies
    }

    public var settings: UserSettings { preferences.settings }
    public var displayName: String { preferences.deviceDisplayName }
    public var device: SettingsDeviceInfo { dependencies.deviceInfo() }

    public func update(_ change: (inout UserSettings) -> Void) {
        var copy = preferences.settings
        change(&copy)
        preferences.settings = copy
    }

    // MARK: - Loading

    public func refreshStatuses() async {
        notificationPermission = await dependencies.notificationStatus()
        motionPermission = dependencies.motionStatus()
        await log.loadIfNeeded()
    }

    public func loadPlans() async {
        plans = await dependencies.loadPlans()
    }

    // MARK: - Navigation

    public func open(_ route: SettingsRoute) {
        path.append(route)
    }

    public func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: - Notifications (SET-04)

    /// The master switch asks iOS first when permission is undecided. When it was
    /// denied, the switch cannot turn notifications on; the screen offers Settings.
    public func setNotificationsEnabled(_ enabled: Bool) async {
        if enabled, notificationPermission == .notDetermined {
            notificationPermission = await dependencies.requestNotifications()
        }
        update { $0.notificationsEnabled = enabled && notificationPermission == .granted }
    }

    /// Whether alerts will actually be delivered: preference and iOS permission.
    public var notificationsDelivered: Bool {
        settings.notificationsEnabled && notificationPermission == .granted
    }

    public func setCategory(_ category: UserSettings.NotificationCategory, enabled: Bool) {
        update {
            if enabled { $0.disabledNotificationCategories.remove(category) } else { $0.disabledNotificationCategories.insert(category) }
        }
    }

    // MARK: - Device (SET-02)

    public func beginRename() {
        renameDraft = displayName
        renameError = false
        sheet = .rename
    }

    @discardableResult
    public func saveRename() -> Bool {
        guard preferences.setDeviceDisplayName(renameDraft) else {
            renameError = true
            return false
        }
        sheet = nil
        showToast(L("Device name updated"))
        return true
    }

    public func refreshDevice() async {
        isRefreshingDevice = true
        await dependencies.refreshDevice()
        isRefreshingDevice = false
        showToast(L("Device information refreshed"))
    }

    public func resetDeviceProfile() {
        preferences.resetDeviceProfile()
        dialog = nil
        showToast(L("Device profile reset"))
    }

    // MARK: - Reset preferences (SET-14)

    /// Preferences only: the device profile, subscription and history are kept.
    public func resetPreferences() {
        preferences.resetPreferences()
        dialog = nil
        showToast(L("Preferences reset"))
    }

    // MARK: - Data & History (SET-07, SET-13)

    public var measuredSizes: [HistoryKind: Int] { log.measuredSizes() }
    public var measuredTotal: Int { measuredSizes.values.reduce(0, +) }

    public func count(of kind: HistoryKind) -> Int {
        switch kind {
        case .activity: log.events.count
        case .alerts: log.alerts.count
        case .sessions: log.sessions.filter { $0.status != .active }.count
        }
    }

    public func beginClear(_ preselected: Set<HistoryKind>? = nil) {
        clearSelection = preselected ?? Set(HistoryKind.allCases.filter { count(of: $0) > 0 })
        clearState = .choosing
        sheet = .clearHistory
    }

    public func toggleClear(_ kind: HistoryKind) {
        if clearSelection.contains(kind) { clearSelection.remove(kind) } else { clearSelection.insert(kind) }
    }

    public var clearCount: Int { clearSelection.map(count(of:)).reduce(0, +) }

    public func confirmClear() {
        guard !clearSelection.isEmpty else { return }
        clearState = .confirming
    }

    public func backToChoosing() {
        clearState = .choosing
    }

    public func performClear() async {
        clearState = .deleting
        do {
            let removed = try await log.clear(clearSelection)
            clearState = .succeeded(removed)
        } catch {
            clearState = .failed
        }
    }

    public func finishClear() {
        sheet = nil
        clearState = .choosing
    }

    // MARK: - Export (SET-08)

    public func toggleExport(_ item: ExportItem) {
        if exportSelection.contains(item) { exportSelection.remove(item) } else { exportSelection.insert(item) }
        exportState = .idle
    }

    public func exportCount(_ item: ExportItem) -> Int? {
        switch item {
        case .device: nil
        case .activity: log.events.count
        case .alerts: log.alerts.count
        case .sessions: log.sessions.count
        }
    }

    /// Writes one file per selected item into a fresh temporary folder.
    public func generateExport() async {
        guard !exportSelection.isEmpty else { return }
        exportState = .generating
        let files = ExportWriter.files(
            items: exportSelection,
            format: exportFormat,
            snapshot: log.snapshot,
            deviceReport: dependencies.deviceReport()
        )
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SystemScope-Export-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var urls: [URL] = []
            for (name, contents) in files {
                let url = folder.appendingPathComponent(name)
                try contents.write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
            exportState = .ready(urls)
        } catch {
            exportState = .failed
        }
    }

    public func resetExport() {
        exportState = .idle
    }

    // MARK: - Subscription (SET-09)

    public func restorePurchases() async {
        restoreMessage = nil
        let restored = await dependencies.restorePurchases()
        restoreMessage = restored ? L("Purchases restored.") : L("No purchases to restore for this Apple Account.")
    }

    // MARK: - Support (SET-11)

    /// Shown to the user before anything is attached or copied.
    public var diagnosticText: String {
        let info = device
        return [
            "SystemScope \(dependencies.appVersion) (\(dependencies.buildNumber))",
            "iOS \(info.osVersion ?? L("Unavailable"))",
            "\(info.modelName ?? L("Unknown iPhone model")) (\(info.modelIdentifier ?? L("Unavailable")))",
        ].joined(separator: "\n")
    }

    public func copyDiagnostics() {
        dependencies.copy(diagnosticText)
        showToast(L("Diagnostic information copied"))
    }

    // MARK: - Toast

    public func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

/// Builds export files. Versioned so a later import or review knows the schema.
private struct ExportEnvelope<V: Encodable>: Encodable {
    let schemaVersion: Int
    let records: V
}

enum ExportWriter {
    static let schemaVersion = 1

    static func files(items: Set<ExportItem>, format: ExportFormat, snapshot: ActivitySnapshot, deviceReport: String) -> [(String, String)] {
        var files: [(String, String)] = []
        let ext = format.rawValue
        if items.contains(.device) {
            files.append(("device.txt", deviceReport))
        }
        if items.contains(.activity) {
            files.append(("activity.\(ext)", format == .csv
                ? csv(header: ["timestamp", "category", "title", "detail", "read"], rows: snapshot.events.map { [iso($0.timestamp), $0.category.rawValue, $0.title, $0.detail, $0.readState.rawValue] })
                : json(snapshot.events)))
        }
        if items.contains(.alerts) {
            files.append(("alerts.\(ext)", format == .csv
                ? csv(header: ["created", "category", "severity", "title", "detail", "read", "resolution"], rows: snapshot.alerts.map { [iso($0.createdAt), $0.category.rawValue, "\($0.severity)", $0.title, $0.detail, $0.readState.rawValue, $0.resolutionState.rawValue] })
                : json(snapshot.alerts)))
        }
        if items.contains(.sessions) {
            files.append(("sessions.\(ext)", format == .csv
                ? csv(header: ["started", "ended", "type", "status", "observations", "interruption"], rows: snapshot.sessions.map { [iso($0.startedAt), $0.endedAt.map(iso) ?? "", $0.type.rawValue, $0.status.rawValue, "\($0.observationCount)", $0.interruptionReason ?? ""] })
                : json(snapshot.sessions)))
        }
        return files
    }

    private static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private static func csv(header: [String], rows: [[String]]) -> String {
        func field(_ text: String) -> String { "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        return ([header.joined(separator: ",")] + rows.map { $0.map(field).joined(separator: ",") }).joined(separator: "\n")
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(ExportEnvelope(schemaVersion: schemaVersion, records: value))) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
