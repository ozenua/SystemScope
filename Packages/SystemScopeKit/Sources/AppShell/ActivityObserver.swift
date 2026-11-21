import ActivityStore
import Core
import DeviceInfo
import Foundation
import SpeedTest
import UIKit
import UserNotifications

/// Feeds the activity log while SystemScope is in the foreground: battery, storage,
/// network and thermal readings every 30 seconds and on system notifications. iOS
/// gives the app nothing in the background, so nothing is recorded then.
@MainActor
final class ActivityObserver {
    let log: ActivityLog
    let inspector: any DeviceInspecting
    let networkInspector: any NetworkInspecting
    let battery: any BatteryMonitoring
    let settings: @MainActor () -> UserSettings
    private var lastThermal: ThermalCondition?

    static let interval: Duration = .seconds(30)

    init(log: ActivityLog, inspector: any DeviceInspecting, networkInspector: any NetworkInspecting, battery: any BatteryMonitoring, settings: @escaping @MainActor () -> UserSettings) {
        self.settings = settings
        self.log = log
        self.inspector = inspector
        self.networkInspector = networkInspector
        self.battery = battery
    }

    /// Runs until cancelled (the scene leaves the foreground).
    func run() async {
        await log.loadIfNeeded()
        battery.start()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                while !Task.isCancelled {
                    await observe()
                    try? await Task.sleep(for: Self.interval)
                }
            }
            for name in [
                ProcessInfo.thermalStateDidChangeNotification,
                Notification.Name.NSProcessInfoPowerStateDidChange,
                UIDevice.batteryStateDidChangeNotification,
            ] {
                group.addTask { [self] in
                    for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
                        await observe()
                    }
                }
            }
            group.addTask { [self] in
                for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification).map({ _ in () }) {
                    await recordMemoryWarning()
                }
            }
        }
    }

    private func recordMemoryWarning() {
        log.recordMemoryWarning()
    }

    private func observe() async {
        guard log.loadState == .loaded else { return }
        let settings = settings()
        Self.apply(settings, to: log)
        let reading = battery.snapshot
        log.observeBattery(level: reading.level, state: reading.state.map(Self.levelState), lowPowerMode: reading.isLowPowerModeEnabled)

        let storage = await inspector.readSnapshot(of: .memoryAndStorage).value
        if let storage {
            log.observeStorage(availableBytes: storage.storageAvailableBytes, totalBytes: storage.storageTotalBytes)
        }
        if let thermal = await inspector.readSnapshot(of: .batteryAndThermal).value?.thermalState {
            if let previous = lastThermal, previous != thermal {
                log.thermalChanged(
                    from: Self.name(previous),
                    to: Self.name(thermal),
                    elevated: Self.rank(thermal) >= Self.rank(settings.thermalThreshold),
                    critical: thermal == .critical
                )
            }
            lastThermal = thermal
        }
        let network = await networkInspector.readNetwork()
        log.observeNetwork(Self.describe(network))
        log.recordObservation(DeviceObservation(
            batteryLevel: reading.level,
            storageAvailableBytes: storage?.storageAvailableBytes,
            storageTotalBytes: storage?.storageTotalBytes,
            receivedBytes: network.receivedBytes,
            sentBytes: network.sentBytes,
            networkInterface: Self.describe(network)
        ))
    }

    /// Settings › Alert Thresholds (SET-05) applied to the recording rules.
    static func apply(_ settings: UserSettings, to log: ActivityLog) {
        log.alertsEnabled = settings.thresholdAlertsEnabled
        log.batteryAlertThreshold = settings.lowBatteryPercent
        log.storageAlertFraction = Double(settings.lowStoragePercent) / 100
    }

    static func rank(_ thermal: ThermalCondition) -> Int {
        switch thermal {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical: 3
        }
    }

    static func rank(_ threshold: UserSettings.ThermalThreshold) -> Int {
        switch threshold {
        case .fair: 1
        case .serious: 2
        case .critical: 3
        }
    }

    static func levelState(_ state: BatteryChargeState) -> BatteryLevelState {
        switch state {
        case .unplugged: .unplugged
        case .charging: .charging
        case .full: .full
        }
    }

    static func name(_ thermal: ThermalCondition) -> String {
        switch thermal {
        case .nominal: String(localized: "Nominal")
        case .fair: String(localized: "Fair")
        case .serious: String(localized: "Serious")
        case .critical: String(localized: "Critical")
        }
    }

    static func describe(_ network: NetworkSnapshot?) -> String? {
        guard let network, network.isConnected == true else { return nil }
        return switch network.interface {
        case .wifi: String(localized: "Wi-Fi")
        case .cellular: String(localized: "Cellular")
        case .wired: String(localized: "Wired")
        case .other, nil: String(localized: "Other network")
        }
    }

    /// The Activity record for a completed speed test.
    static func event(for result: InternetSpeedTestResult) -> ActivityEvent {
        func mbps(_ value: Double?) -> String {
            value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) Mbps" } ?? String(localized: "Unavailable")
        }
        let measurements = result.measurements
        let connection: String = switch result.connection {
        case .wifi: String(localized: "Wi-Fi")
        case .cellular: String(localized: "Cellular")
        case .wired: String(localized: "Wired")
        case .other: String(localized: "Other network")
        }
        var rows = [
            ActivityMeasurement(String(localized: "Download speed"), mbps(measurements.downloadMbps)),
            ActivityMeasurement(String(localized: "Upload speed"), mbps(measurements.uploadMbps)),
        ]
        if let latency = measurements.idleLatencyMs {
            rows.append(ActivityMeasurement(String(localized: "Latency"), "\(Int(latency.rounded())) ms"))
        }
        rows.append(ActivityMeasurement(String(localized: "Network type"), connection))
        rows.append(ActivityMeasurement(String(localized: "Test duration"), "\(Int(result.testDurationSeconds.rounded())) s"))
        return ActivityEvent(
            kind: .speedTestCompleted,
            category: .network,
            title: String(localized: "Speed test completed"),
            detail: "\(mbps(measurements.downloadMbps)) \(String(localized: "download")) · \(mbps(measurements.uploadMbps)) \(String(localized: "upload"))",
            explanation: String(localized: "Your connection recorded a download speed of \(mbps(measurements.downloadMbps)) and an upload speed of \(mbps(measurements.uploadMbps)) over \(connection)."),
            timestamp: result.timestamp,
            measurements: rows,
            scope: String(localized: "This iPhone"),
            source: String(localized: "SystemScope speed test (\(result.serverHost))")
        )
    }
}

/// Posts a local notification for each new alert the user has allowed (SET-04).
@MainActor
enum AlertNotifier {
    static func post(_ alert: ActivityAlert, settings: UserSettings) {
        let category: UserSettings.NotificationCategory = switch alert.category {
        case .battery: .battery
        case .storage: .storage
        case .thermal: .thermal
        case .network: .network
        case .performance, .sessions: .monitoring
        }
        guard settings.isEnabled(category) else { return }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.detail
        content.sound = .default
        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: nil)
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
