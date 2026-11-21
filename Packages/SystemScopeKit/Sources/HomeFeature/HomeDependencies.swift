import DeviceInfo
import Foundation

// Data the Home flow shows beyond the device summary. Every optional is a real
// product state: nil means iOS does not expose it or nothing has been recorded yet.

/// Device-wide processor activity. iOS exposes no public API for this (PRD §1.5),
/// so only sample providers return a value.
public struct PerformanceSnapshot: Sendable, Equatable {
    public var cpu: Double
    public var gpu: Double
    public var inactive: Double

    public init(cpu: Double, gpu: Double, inactive: Double) {
        self.cpu = cpu
        self.gpu = gpu
        self.inactive = inactive
    }
}

public enum DataUsageRange: String, CaseIterable, Sendable {
    case today
    case week
    case month
    case sixMonths
    case year
}

public struct DataUsageSeries: Sendable, Equatable {
    public struct Bar: Sendable, Equatable {
        /// Total traffic for the bucket, 0...1 of the tallest bucket.
        public var total: Double
        /// Downloaded share of the bucket, 0...1 of the tallest bucket.
        public var download: Double

        public init(total: Double, download: Double) {
            self.total = total
            self.download = download
        }
    }

    public var totalBytes: Int64
    public var bars: [Bar]
    public var axisLabels: [String]

    public init(totalBytes: Int64, bars: [Bar], axisLabels: [String]) {
        self.totalBytes = totalBytes
        self.bars = bars
        self.axisLabels = axisLabels
    }
}

public protocol HomeInsightsProviding: Sendable {
    func performance() async -> PerformanceSnapshot?
    /// nil when there is not enough recorded history for the range (MON-06).
    func dataUsage(for range: DataUsageRange) async -> DataUsageSeries?
}

/// Empty production fallback when no observation store is available.
public struct UnavailableHomeInsights: HomeInsightsProviding {
    public init() {}

    public func performance() async -> PerformanceSnapshot? { nil }
    public func dataUsage(for range: DataUsageRange) async -> DataUsageSeries? { nil }
}

/// Sample values matching the Figma Home screens. Debug and previews only.
/// Speed tests are never sampled: they only ever come from a real test server.
public struct SampleHomeInsights: HomeInsightsProviding {
    public init() {}

    public func performance() async -> PerformanceSnapshot? {
        PerformanceSnapshot(cpu: 0.08, gpu: 0.08, inactive: 0.89)
    }

    public func dataUsage(for range: DataUsageRange) async -> DataUsageSeries? {
        guard range == .today else { return nil }
        let totals: [Double] = [96, 131, 74, 74, 131, 74, 131, 74, 74, 131, 74, 96, 96, 131, 96, 131, 74, 131, 96, 131, 96, 131]
        let downloads: [Double] = [59, 88, 41, 41, 88, 35, 88, 41, 35, 88, 41, 59, 59, 88, 59, 88, 33, 88, 59, 88, 59, 88]
        return DataUsageSeries(
            totalBytes: 24_700_000_000,
            bars: zip(totals, downloads).map { .init(total: $0 / 131, download: $1 / 131) },
            axisLabels: ["12 AM", "3 AM", "6 AM", "9 AM", "12 PM", "3 PM"]
        )
    }
}

/// Overall status shown on Home (HOME-06). Derived only from supported readings.
public enum DeviceHealth: Sendable, Equatable {
    case healthy
    case attention
    case critical
    /// A required input is unavailable, so no reliable conclusion can be made.
    case partial

    public static let lowBatteryThreshold = 0.20
    public static let lowStorageThreshold = 0.10

    public static func evaluate(_ summary: DeviceSummary) -> DeviceHealth {
        if summary.thermalState == .critical { return .critical }

        var needsAttention = summary.thermalState == .serious
        if let level = summary.batteryLevel, level <= lowBatteryThreshold, summary.batteryState == .unplugged {
            needsAttention = true
        }
        if let free = summary.storageAvailableBytes, let total = summary.storageTotalBytes, total > 0,
           Double(free) / Double(total) <= lowStorageThreshold {
            needsAttention = true
        }
        if needsAttention { return .attention }

        let hasAllInputs = summary.thermalState != nil
            && summary.batteryLevel != nil
            && summary.storageAvailableBytes != nil
            && summary.storageTotalBytes != nil
        return hasAllInputs ? .healthy : .partial
    }
}
