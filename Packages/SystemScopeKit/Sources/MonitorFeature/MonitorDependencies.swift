import DeviceInfo
import Foundation

// History-backed content for the Monitor overview. Until alerts, sessions and stored
// observations exist (M3/M4), the unavailable provider returns nothing and the page
// shows empty states; it never invents events or readings.

public struct MonitorAlert: Identifiable, Sendable, Equatable {
    public enum Kind: Sendable {
        case network
        case battery
        case storage
        case thermal
    }

    public enum Severity: Sendable {
        case info
        case attention
        case critical
    }

    public let id: UUID
    public var kind: Kind
    public var severity: Severity
    public var title: String
    public var detail: String
    public var date: Date

    public init(id: UUID = UUID(), kind: Kind, severity: Severity, title: String, detail: String, date: Date) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.detail = detail
        self.date = date
    }
}

public struct MonitorActivity: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var date: Date

    public init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}

public enum MonitorTrendRange: String, CaseIterable, Sendable {
    case today
    case week
    case month
}

/// A stored series for one metric. `segments` are runs of consecutive observations;
/// the space between two segments is a period with no readings and is drawn as a gap,
/// never interpolated as data (MON-04, MON-05).
public struct MonitorTrend: Sendable, Equatable {
    public struct Point: Sendable, Equatable {
        /// Position along the time axis, 0...1.
        public var position: Double
        public var value: Double

        public init(position: Double, value: Double) {
            self.position = position
            self.value = value
        }
    }

    public var title: String
    public var latestValue: Double
    public var unit: String
    public var observationCount: Int
    public var segments: [[Point]]
    public var axisLabels: [String]

    public init(title: String, latestValue: Double, unit: String, observationCount: Int, segments: [[Point]], axisLabels: [String]) {
        self.title = title
        self.latestValue = latestValue
        self.unit = unit
        self.observationCount = observationCount
        self.segments = segments
        self.axisLabels = axisLabels
    }

    public var hasGaps: Bool { segments.count > 1 }
}

public protocol MonitorInsightsProviding: Sendable {
    func alerts() async -> [MonitorAlert]
    func recentActivity() async -> [MonitorActivity]
    /// nil when there are too few stored observations for the range (MON-06).
    func trend(for range: MonitorTrendRange) async -> MonitorTrend?
}

public struct UnavailableMonitorInsights: MonitorInsightsProviding {
    public init() {}
    public func alerts() async -> [MonitorAlert] { [] }
    public func recentActivity() async -> [MonitorActivity] { [] }
    public func trend(for range: MonitorTrendRange) async -> MonitorTrend? { nil }
}

/// Sample content matching the Figma Monitor overview. Debug and previews only.
public struct SampleMonitorInsights: MonitorInsightsProviding {
    public init() {}

    public func alerts() async -> [MonitorAlert] {
        [MonitorAlert(
            kind: .network, severity: .info,
            title: "Network connection changed",
            detail: "Switched from Cellular to Wi-Fi",
            date: .now.addingTimeInterval(-600)
        )]
    }

    public func recentActivity() async -> [MonitorActivity] {
        [
            MonitorActivity(title: "Storage information updated", date: .now.addingTimeInterval(-5)),
            MonitorActivity(title: "Performance session recorded", date: .now.addingTimeInterval(-720)),
            MonitorActivity(title: "Thermal state is Nominal", date: .now.addingTimeInterval(-3_600)),
        ]
    }

    public func trend(for range: MonitorTrendRange) async -> MonitorTrend? {
        guard range == .today else { return nil }
        let morning: [(Double, Double)] = [(0, 82), (0.1, 81.5), (0.2, 79), (0.3, 74), (0.4, 68), (0.5, 64)]
        let afternoon: [(Double, Double)] = [(0.62, 64), (0.7, 68), (0.78, 73), (0.86, 77), (0.94, 80), (1, 81)]
        return MonitorTrend(
            title: "Battery level",
            latestValue: 81,
            unit: "%",
            observationCount: 12,
            segments: [morning, afternoon].map { $0.map { .init(position: $0.0, value: $0.1) } },
            axisLabels: ["6 AM", "9 AM", "12 PM", "3 PM", "Now"]
        )
    }
}

/// Deterministic suggestions from current, supported readings only (PRD §6.7).
public enum MonitorRecommendation: Sendable, Equatable {
    /// Free storage is getting low; carries the free share, 0...1.
    case reviewStorage(freeFraction: Double)
    case considerLowPowerMode

    public static let storageReviewThreshold = 0.30
    public static let lowBatteryThreshold = 0.20

    public static func evaluate(_ summary: DeviceSummary) -> [MonitorRecommendation] {
        var result: [MonitorRecommendation] = []
        if let level = summary.batteryLevel, level <= lowBatteryThreshold, summary.batteryState == .unplugged {
            result.append(.considerLowPowerMode)
        }
        if let free = summary.storageAvailableBytes, let total = summary.storageTotalBytes, total > 0 {
            let fraction = Double(free) / Double(total)
            if fraction <= storageReviewThreshold {
                result.append(.reviewStorage(freeFraction: fraction))
            }
        }
        return result
    }
}
