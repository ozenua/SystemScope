import ActivityStore
import Foundation
import HomeFeature
import MonitorFeature

/// Bridges the shared persisted activity document into the Home and Monitor insight
/// protocols without coupling either feature to the Activity store.
struct ActivityInsightsProvider: HomeInsightsProviding, MonitorInsightsProviding {
    private let source: @Sendable @MainActor () -> ActivitySnapshot
    private let calendar: Calendar

    init(source: @escaping @Sendable @MainActor () -> ActivitySnapshot, calendar: Calendar = .current) {
        self.source = source
        self.calendar = calendar
    }

    private func snapshot() async -> ActivitySnapshot {
        await MainActor.run { source() }
    }

    func performance() async -> PerformanceSnapshot? { nil }

    func dataUsage(for range: DataUsageRange) async -> DataUsageSeries? {
        let observations = await filteredObservations(for: range)
        let network = observations.filter { $0.receivedBytes != nil || $0.sentBytes != nil }
        guard network.count >= 2 else { return nil }
        let first = network.last!
        let last = network.first!
        let received = difference(last.receivedBytes, first.receivedBytes)
        let sent = difference(last.sentBytes, first.sentBytes)
        let total = received + sent
        guard total > 0 else { return nil }

        let bucketCount = range == .today ? 24 : range == .week ? 7 : range == .month ? 30 : 12
        let buckets = bucketObservations(network, count: bucketCount, range: range)
        let amounts = buckets.map { bucket -> (Int64, Int64) in
            guard let newest = bucket.first, let oldest = bucket.last else { return (0, 0) }
            let down = difference(newest.receivedBytes, oldest.receivedBytes)
            let up = difference(newest.sentBytes, oldest.sentBytes)
            return (down, up)
        }
        let maxBucket = max(amounts.map { $0.0 + $0.1 }.max() ?? 0, 1)
        return DataUsageSeries(
            totalBytes: total,
            bars: amounts.map {
                .init(total: Double($0.0 + $0.1) / Double(maxBucket),
                      download: Double($0.0) / Double(max($0.0 + $0.1, 1)))
            },
            axisLabels: labels(for: range)
        )
    }

    func alerts() async -> [MonitorAlert] {
        let alerts = await snapshot().alerts
        return alerts.filter { $0.resolutionState != .dismissed }.prefix(5).map {
            MonitorAlert(
                id: $0.id,
                kind: kind(for: $0.category),
                severity: severity(for: $0.severity),
                title: $0.title,
                detail: $0.detail,
                date: $0.createdAt
            )
        }
    }

    func recentActivity() async -> [MonitorActivity] {
        let events = await snapshot().events
        return events.prefix(5).map {
            MonitorActivity(id: $0.id, title: $0.title, date: $0.timestamp)
        }
    }

    func trend(for range: MonitorTrendRange) async -> MonitorTrend? {
        let usageRange: DataUsageRange = switch range {
        case .today: .today
        case .week: .week
        case .month: .month
        }
        let observations = await filteredObservations(for: usageRange)
            .compactMap { observation -> (Date, Double)? in
                guard let level = observation.batteryLevel else { return nil }
                return (observation.date, Double(level))
            }
            .sorted { $0.0 < $1.0 }
        guard observations.count >= 2, let start = observations.first?.0, let end = observations.last?.0,
              end > start else { return nil }
        let gap = max((end.timeIntervalSince(start) / 5), 60)
        var segments: [[MonitorTrend.Point]] = [[]]
        var previousDate: Date?
        for (date, value) in observations {
            if let previousDate, date.timeIntervalSince(previousDate) > gap {
                segments.append([])
            }
            segments[segments.count - 1].append(.init(
                position: date.timeIntervalSince(start) / end.timeIntervalSince(start),
                value: value
            ))
            previousDate = date
        }
        return MonitorTrend(
            title: "Battery level",
            latestValue: observations.last!.1,
            unit: "%",
            observationCount: observations.count,
            segments: segments.filter { !$0.isEmpty },
            axisLabels: labels(for: usageRange)
        )
    }

    private func filteredObservations(for range: DataUsageRange) async -> [DeviceObservation] {
        let snapshot = await snapshot()
        let interval: DateComponents = switch range {
        case .today: DateComponents(day: 1)
        case .week: DateComponents(day: 7)
        case .month: DateComponents(month: 1)
        case .sixMonths: DateComponents(month: 6)
        case .year: DateComponents(year: 1)
        }
        let cutoff = calendar.date(byAdding: interval, to: .now.addingTimeInterval(-1)) ?? .distantPast
        return snapshot.observations.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
    }

    private func bucketObservations(_ observations: [DeviceObservation], count: Int, range: DataUsageRange) -> [[DeviceObservation]] {
        guard let newest = observations.first?.date, let oldest = observations.last?.date else { return [] }
        let duration = max(newest.timeIntervalSince(oldest), 1)
        return (0..<count).map { index in
            let lower = oldest.addingTimeInterval(duration * Double(index) / Double(count))
            let upper = oldest.addingTimeInterval(duration * Double(index + 1) / Double(count))
            return observations.filter { $0.date >= lower && (index == count - 1 ? $0.date <= upper : $0.date < upper) }
                .sorted { $0.date > $1.date }
        }
    }

    private func labels(for range: DataUsageRange) -> [String] {
        switch range {
        case .today: ["12 AM", "6 AM", "12 PM", "6 PM"]
        case .week: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        case .month: ["1", "8", "15", "22", "Today"]
        case .sixMonths: ["1", "3", "5", "6"]
        case .year: ["Jan", "Apr", "Jul", "Oct"]
        }

    }

    private func difference(_ newer: UInt64?, _ older: UInt64?) -> Int64 {
        guard let newer, let older, newer >= older else { return 0 }
        return Int64(min(newer - older, UInt64(Int64.max)))
    }

    private func kind(for category: ActivityCategory) -> MonitorAlert.Kind {
        switch category {
        case .network: .network
        case .battery: .battery
        case .storage: .storage
        case .thermal: .thermal
        default: .network
        }
    }

    private func severity(for severity: AlertSeverity) -> MonitorAlert.Severity {
        switch severity {
        case .information: .info
        case .attention: .attention
        case .critical: .critical
        }
    }
}
