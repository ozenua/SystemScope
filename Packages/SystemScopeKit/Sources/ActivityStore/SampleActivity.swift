import Foundation

/// Figma sample history, dated relative to now. For previews, tests and the
/// Debug-only `-UseSampleDevice` launch argument; never wired into Release.
public enum SampleActivity {
    public static func snapshot(now: Date = .now, calendar: Calendar = .current) -> ActivitySnapshot {
        let today = calendar.startOfDay(for: now)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let batteryAlert = ActivityAlert(
            category: .battery, severity: .information,
            title: "Battery level is low",
            detail: "Your battery reached your 20% alert threshold.",
            explanation: "Your battery reached 20%, the threshold you set for battery alerts. Your iPhone wasn’t charging at the time.",
            createdAt: at(0, 9, 15),
            thresholdSnapshot: [
                .init("Battery level", "20%"), .init("Alert threshold", "20%"),
                .init("Charging state", "Not charging"), .init("Low Power Mode", "Off"),
                .init("Measured", "9:15:02 AM"),
            ],
            recommendation: .init(title: "Consider turning on Low Power Mode", detail: "It reduces background activity until you can charge your iPhone."),
            deduplicationKey: "sample.battery"
        )
        let storageAlert = ActivityAlert(
            category: .storage, severity: .attention,
            title: "Storage running low",
            detail: "Available storage is below 10% of capacity.",
            createdAt: at(-1, 19, 40), readState: .read,
            thresholdSnapshot: [.init("Available", "21.4 GB"), .init("Capacity", "256 GB")],
            deduplicationKey: "sample.storage"
        )
        let thermalAlert = ActivityAlert(
            category: .thermal, severity: .critical,
            title: "Elevated thermal condition",
            detail: "Your device entered the Serious thermal state.",
            createdAt: at(-1, 16, 12), readState: .read,
            resolutionState: .resolved, resolvedAt: at(-1, 17, 0),
            thresholdSnapshot: [.init("Previous state", "Fair"), .init("New state", "Serious")],
            deduplicationKey: "sample.thermal"
        )
        let olderAlerts = [
            ActivityAlert(category: .network, severity: .information, title: "Connection lost", detail: "Wi-Fi disconnected for 4 minutes.",
                          createdAt: at(-5, 10, 5), readState: .read, resolutionState: .resolved, resolvedAt: at(-5, 11, 0), deduplicationKey: "sample.net"),
            ActivityAlert(category: .battery, severity: .information, title: "Battery level is low", detail: "Your battery reached your 20% alert threshold.",
                          createdAt: at(-5, 21, 30), readState: .read, resolutionState: .resolved, resolvedAt: at(-5, 22, 0), deduplicationKey: "sample.battery.old"),
        ]

        let network = MonitoringSessionRecord(
            type: .network, startedAt: at(0, 9, 30), status: .active,
            metricsIncluded: ["Connectivity", "Data transferred", "Path changes"], observationCount: 720
        )
        let performance = MonitoringSessionRecord(
            type: .performance, startedAt: at(0, 8, 32), endedAt: at(0, 8, 50), status: .completed,
            metricsIncluded: ["CPU app activity", "Memory footprint", "Thermal state", "Battery level"],
            observationCount: 216,
            summary: [
                .init("Highest CPU activity", "23%"), .init("Lowest CPU activity", "4%"),
                .init("Peak memory footprint", "420 MB"),
            ],
            timeline: [
                .init(date: at(0, 8, 37), title: "Thermal state changed", detail: "Fair → Nominal"),
                .init(date: at(0, 8, 38), title: "Memory peak", detail: "420 MB footprint"),
                .init(date: at(0, 8, 44), title: "CPU activity peak", detail: "23% app activity"),
            ]
        )
        let yesterdayNetwork = MonitoringSessionRecord(
            type: .network, startedAt: at(-1, 14, 55), endedAt: at(-1, 15, 20), status: .completed,
            metricsIncluded: ["Connectivity", "Data transferred", "Path changes"], observationCount: 300
        )
        let battery = MonitoringSessionRecord(
            type: .battery, startedAt: at(-8, 18, 10), endedAt: at(-8, 18, 16), status: .interrupted,
            interruptionReason: "Stopped when SystemScope was closed.",
            metricsIncluded: ["Battery level", "Charging state", "Low Power Mode"], observationCount: 72
        )

        let events: [ActivityEvent] = [
            .init(kind: .speedTestCompleted, category: .network, title: "Speed test completed",
                  detail: "256.8 Mbps download · 96.4 Mbps upload",
                  explanation: "Your connection recorded a download speed of 256.8 Mbps and an upload speed of 96.4 Mbps over Wi-Fi.",
                  timestamp: at(0, 9, 42),
                  measurements: [.init("Download speed", "256.8 Mbps"), .init("Upload speed", "96.4 Mbps"),
                                 .init("Latency", "18 ms"), .init("Network type", "Wi-Fi"), .init("Test duration", "14 s")],
                  scope: "This iPhone", source: "SystemScope speed test"),
            .init(kind: .batteryLevelDropped, category: .battery, title: "Battery level dropped", detail: "Battery reached 20%",
                  explanation: batteryAlert.explanation, timestamp: at(0, 9, 15), readState: .unread,
                  measurements: batteryAlert.thresholdSnapshot, scope: "This iPhone", source: "UIDevice.batteryLevel", relatedAlertID: batteryAlert.id),
            .init(kind: .sessionEnded, category: .sessions, title: "Monitoring session ended", detail: "18 minutes recorded",
                  timestamp: at(0, 8, 50), measurements: [.init("Duration", "18 min"), .init("Observations", "216")],
                  scope: "This app", source: "SystemScope monitoring session", relatedSessionID: performance.id),
            .init(kind: .thermalStateChanged, category: .thermal, title: "Thermal state changed", detail: "Device entered Fair state",
                  explanation: "iOS reported that your iPhone’s thermal state rose from Nominal to Fair. This is common during charging, heavy use or in warm surroundings.",
                  timestamp: at(0, 8, 25), readState: .unread,
                  measurements: [.init("Previous state", "Nominal"), .init("New state", "Fair"), .init("Time of transition", "8:25:14 AM")],
                  scope: "This iPhone", source: "ProcessInfo.thermalState"),
            .init(kind: .storageUpdated, category: .storage, title: "Storage information updated", detail: "42 GB available",
                  timestamp: at(0, 8, 10), measurements: [.init("Available", "42 GB"), .init("Capacity", "256 GB")],
                  scope: "This iPhone", source: "FileManager volume capacity"),
            .init(kind: .batteryObservation, category: .battery, title: "Battery observation", detail: "Battery at 85%",
                  timestamp: at(-1, 21, 30), measurements: [.init("Battery level", "85%")], scope: "This iPhone", source: "UIDevice.batteryLevel"),
            .init(kind: .networkChanged, category: .network, title: "Network connection changed", detail: "Connected to Wi-Fi",
                  timestamp: at(-1, 18, 45), measurements: [.init("Before", "Cellular"), .init("After", "Wi-Fi")], scope: "This iPhone", source: "NWPathMonitor"),
            .init(kind: .sessionEnded, category: .sessions, title: "Monitoring session completed", detail: "25 minutes recorded",
                  timestamp: at(-1, 15, 20), scope: "This app", source: "SystemScope monitoring session", relatedSessionID: yesterdayNetwork.id),
        ] + (0..<6).map { index in
            .init(kind: .batteryObservation, category: .battery, title: index.isMultiple(of: 2) ? "Charging started" : "Charging stopped",
                  detail: index.isMultiple(of: 2) ? "Plugged in at \(30 + index)%" : "Unplugged at 100%",
                  timestamp: at(-5, 8 + index * 2, 10), scope: "This iPhone", source: "UIDevice.batteryState")
        } + (0..<42).map { index in
            .init(kind: .batteryObservation, category: [.battery, .network, .thermal, .storage][index % 4],
                  title: ["Battery observation", "Network connection changed", "Thermal state changed", "Storage information updated"][index % 4],
                  detail: ["Battery at \(90 - index)%", "Connected to Wi-Fi", "Device entered Nominal state", "\(40 + index % 5) GB available"][index % 4],
                  timestamp: at(-6 - index / 4, 9 + index % 9, 0), scope: "This iPhone", source: "Sample data")
        }

        return ActivitySnapshot(
            events: events,
            alerts: [batteryAlert, storageAlert, thermalAlert] + olderAlerts,
            sessions: [network, performance, yesterdayNetwork, battery],
            recentSearches: ["battery", "thermal", "speed test"]
        )
    }
}
