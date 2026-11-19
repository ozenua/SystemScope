import Core
import Foundation
import Observation

func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// The single source of truth for activity, alerts and sessions. Monitor, Home and the
/// Activity tab share one instance; every change is saved to the persistence layer.
///
/// Events are recorded only while SystemScope is open: iOS gives the app no
/// background readings, so the feed never claims to cover time it could not observe.
@MainActor
@Observable
public final class ActivityLog {
    public enum LoadState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed
    }

    public private(set) var loadState: LoadState = .idle
    public private(set) var snapshot = ActivitySnapshot()
    /// Set when the latest save failed. The change stays on screen and is retried
    /// with the next save, so nothing is silently discarded (PRD §13).
    public private(set) var lastSaveFailed = false

    @ObservationIgnored private let persistence: any ActivityPersisting
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    // Last readings seen this launch. The first reading is a baseline, not an event.
    @ObservationIgnored private var lastBattery: (level: Int?, state: BatteryLevelState?, lowPower: Bool)?
    @ObservationIgnored private var lastNetwork: String?

    public static let recentSearchLimit = 10

    /// Thresholds from Settings › Alert Thresholds (SET-05). The shell keeps them in sync.
    @ObservationIgnored public var batteryAlertThreshold = 20
    @ObservationIgnored public var storageAlertFraction = 0.10
    /// When false, readings are still recorded as events but no alert is raised.
    @ObservationIgnored public var alertsEnabled = true
    /// Called once for each newly raised alert, for local notifications.
    @ObservationIgnored public var onAlertRaised: (@MainActor (ActivityAlert) -> Void)?

    public init(
        persistence: any ActivityPersisting,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.now = now
    }

    public var events: [ActivityEvent] { snapshot.events }
    public var alerts: [ActivityAlert] { snapshot.alerts }
    public var sessions: [MonitoringSessionRecord] { snapshot.sessions }
    public var settings: ActivitySettings { snapshot.settings }
    public var recentSearches: [String] { snapshot.recentSearches }

    // MARK: - Loading

    /// Loads the stored document and applies the retention setting (PRD §8.4).
    public func load() async {
        loadState = .loading
        do {
            var loaded = try await persistence.load()
            let pruned = Self.applyRetention(to: &loaded, now: now(), calendar: calendar)
            snapshot = loaded
            loadState = .loaded
            if pruned { await persist() }
        } catch {
            loadState = .failed
        }
    }

    public func loadIfNeeded() async {
        guard loadState == .idle || loadState == .failed else { return }
        await load()
    }

    /// Removes events and finished sessions older than the retention period. Open
    /// alerts are kept whatever their age: resolution is the user's decision.
    @discardableResult
    static func applyRetention(to snapshot: inout ActivitySnapshot, now: Date, calendar: Calendar) -> Bool {
        guard let days = snapshot.settings.retention.days,
              let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else { return false }
        let before = (snapshot.events.count, snapshot.alerts.count, snapshot.sessions.count)
        snapshot.events.removeAll { $0.timestamp < cutoff }
        snapshot.alerts.removeAll { $0.createdAt < cutoff && $0.resolutionState != .open }
        snapshot.sessions.removeAll { ($0.endedAt ?? now) < cutoff }
        return before != (snapshot.events.count, snapshot.alerts.count, snapshot.sessions.count)
    }

    private func persist() async {
        do {
            try await persistence.save(snapshot)
            lastSaveFailed = false
        } catch {
            lastSaveFailed = true
        }
    }

    private func mutate(_ change: (inout ActivitySnapshot) -> Void) {
        change(&snapshot)
        Task { await persist() }
    }

    // MARK: - Events

    public func record(_ event: ActivityEvent) {
        guard snapshot.settings.recordActivity else { return }
        mutate { $0.events.insert(event, at: 0) }
    }

    public func markRead(event id: UUID) {
        guard let index = snapshot.events.firstIndex(where: { $0.id == id }),
              snapshot.events[index].readState == .unread else { return }
        mutate { $0.events[index].readState = .read }
    }

    public func setRead(event id: UUID, _ read: Bool) {
        guard let index = snapshot.events.firstIndex(where: { $0.id == id }) else { return }
        mutate { $0.events[index].readState = read ? .read : .unread }
    }

    public func deleteEvent(_ id: UUID) {
        mutate { $0.events.removeAll { $0.id == id } }
    }

    /// ACT-10, ACT-11: removes activity events only. Alerts, sessions, the device
    /// profile and preferences stay. Saved before the change is shown, so a failed
    /// write leaves everything as it was. Returns how many events were removed.
    @discardableResult
    public func clearHistory() async throws -> Int {
        var cleared = snapshot
        let count = cleared.events.count
        cleared.events.removeAll()
        try await persistence.save(cleared)
        snapshot = cleared
        lastSaveFailed = false
        return count
    }

    /// SET-13: removes the chosen kinds of history in one write. Nothing changes on
    /// screen unless the write succeeds. Returns how many records were removed.
    @discardableResult
    public func clear(_ kinds: Set<HistoryKind>) async throws -> Int {
        var cleared = snapshot
        var count = 0
        if kinds.contains(.activity) { count += cleared.events.count; cleared.events.removeAll() }
        if kinds.contains(.alerts) { count += cleared.alerts.count; cleared.alerts.removeAll() }
        if kinds.contains(.sessions) {
            // An active session keeps recording; only finished ones are removed.
            let finished = cleared.sessions.filter { $0.status != .active }
            count += finished.count
            cleared.sessions.removeAll { $0.status != .active }
        }
        try await persistence.save(cleared)
        snapshot = cleared
        lastSaveFailed = false
        return count
    }

    /// Bytes each kind of history takes, measured by encoding it as stored (SET-07).
    public func measuredSizes() -> [HistoryKind: Int] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        func size<T: Encodable>(_ value: T) -> Int { (try? encoder.encode(value).count) ?? 0 }
        return [
            .activity: size(snapshot.events),
            .alerts: size(snapshot.alerts),
            .sessions: size(snapshot.sessions),
        ]
    }

    public var oldestRecord: Date? {
        (snapshot.events.map(\.timestamp) + snapshot.alerts.map(\.createdAt) + snapshot.sessions.map(\.startedAt)).min()
    }

    // MARK: - Alerts (PRD §6.5 alert lifecycle)

    /// Raises an alert unless one with the same key is still open. Returns the alert
    /// that is open for the key.
    @discardableResult
    public func raise(_ alert: ActivityAlert) -> ActivityAlert {
        if let open = snapshot.alerts.first(where: { $0.deduplicationKey == alert.deduplicationKey && $0.resolutionState == .open }) {
            return open
        }
        guard alertsEnabled else { return alert }
        mutate { $0.alerts.insert(alert, at: 0) }
        onAlertRaised?(alert)
        return alert
    }

    /// ACT-04: opening marks the alert read and never resolves it.
    public func markRead(alert id: UUID) {
        guard let index = snapshot.alerts.firstIndex(where: { $0.id == id }),
              snapshot.alerts[index].readState == .unread else { return }
        mutate { $0.alerts[index].readState = .read }
    }

    public func markUnread(alert id: UUID) {
        guard let index = snapshot.alerts.firstIndex(where: { $0.id == id }) else { return }
        mutate { $0.alerts[index].readState = .unread }
    }

    /// ACT-05: resolution is an explicit user action.
    public func resolve(alert id: UUID) {
        guard let index = snapshot.alerts.firstIndex(where: { $0.id == id }) else { return }
        let date = now()
        mutate {
            $0.alerts[index].resolutionState = .resolved
            $0.alerts[index].resolvedAt = date
            $0.alerts[index].dismissedAt = nil
        }
    }

    public func reopen(alert id: UUID) {
        guard let index = snapshot.alerts.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            $0.alerts[index].resolutionState = .open
            $0.alerts[index].resolvedAt = nil
            $0.alerts[index].dismissedAt = nil
        }
    }

    public func dismiss(alert id: UUID) {
        guard let index = snapshot.alerts.firstIndex(where: { $0.id == id }) else { return }
        let date = now()
        mutate {
            $0.alerts[index].resolutionState = .dismissed
            $0.alerts[index].dismissedAt = date
        }
    }

    /// Deletion removes the record; it is not dismissal (PRD §6.5).
    public func deleteAlert(_ id: UUID) {
        mutate { $0.alerts.removeAll { $0.id == id } }
    }

    // MARK: - Sessions (PRD §6.5 session lifecycle)

    /// Starts a session when recording is on. Returns nil when it is off.
    public func beginSession(_ type: SessionType, metrics: [String]) -> UUID? {
        guard snapshot.settings.recordSessions else { return nil }
        let session = MonitoringSessionRecord(type: type, startedAt: now(), metricsIncluded: metrics)
        mutate { $0.sessions.insert(session, at: 0) }
        return session.id
    }

    public func addTimelineEntry(session id: UUID, title: String, detail: String) {
        guard let index = snapshot.sessions.firstIndex(where: { $0.id == id }) else { return }
        let entry = SessionTimelineEntry(date: now(), title: title, detail: detail)
        mutate { $0.sessions[index].timeline.append(entry) }
    }

    /// Ends a session as completed or, when the app left the foreground, interrupted.
    public func endSession(
        _ id: UUID,
        status: SessionStatus,
        interruptionReason: String? = nil,
        observationCount: Int,
        summary: [ActivityMeasurement],
        metricsUnavailable: [String] = [],
        alertsGenerated: Int = 0
    ) {
        guard let index = snapshot.sessions.firstIndex(where: { $0.id == id }) else { return }
        let date = now()
        let session = snapshot.sessions[index]
        let minutes = max(1, Int((date.timeIntervalSince(session.startedAt) / 60).rounded()))
        mutate {
            $0.sessions[index].endedAt = date
            $0.sessions[index].status = status
            $0.sessions[index].interruptionReason = interruptionReason
            $0.sessions[index].observationCount = observationCount
            $0.sessions[index].summary = summary
            $0.sessions[index].metricsUnavailable = metricsUnavailable
            $0.sessions[index].alertsGenerated = alertsGenerated
        }
        let title = status == .interrupted ? L("Monitoring session interrupted") : L("Monitoring session ended")
        record(ActivityEvent(
            kind: .sessionEnded,
            category: .sessions,
            title: title,
            detail: L("\(minutes) minutes recorded"),
            explanation: interruptionReason,
            timestamp: date,
            measurements: [
                ActivityMeasurement(L("Duration"), L("\(minutes) min")),
                ActivityMeasurement(L("Observations"), "\(observationCount)"),
            ],
            scope: L("This app"),
            source: L("SystemScope monitoring session"),
            relatedSessionID: id
        ))
    }

    public func deleteSession(_ id: UUID) {
        mutate { $0.sessions.removeAll { $0.id == id } }
    }

    /// Marks sessions left `active` by a previous launch as interrupted: they cannot
    /// have continued while SystemScope was closed.
    public func closeAbandonedSessions(except current: UUID? = nil) {
        let abandoned = snapshot.sessions.indices.filter {
            snapshot.sessions[$0].status == .active && snapshot.sessions[$0].id != current
        }
        guard !abandoned.isEmpty else { return }
        mutate { snapshot in
            for index in abandoned {
                snapshot.sessions[index].status = .interrupted
                snapshot.sessions[index].endedAt = snapshot.sessions[index].timeline.last?.date ?? snapshot.sessions[index].startedAt
                snapshot.sessions[index].interruptionReason = L("Stopped when SystemScope was closed.")
            }
        }
    }

    // MARK: - Settings and search

    public func updateSettings(_ change: (inout ActivitySettings) -> Void) {
        mutate {
            change(&$0.settings)
            Self.applyRetention(to: &$0, now: now(), calendar: calendar)
        }
    }

    /// ACT-07: recent searches are local, deduplicated and capped at 10.
    public func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate {
            $0.recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            $0.recentSearches.insert(trimmed, at: 0)
            if $0.recentSearches.count > Self.recentSearchLimit {
                $0.recentSearches.removeLast($0.recentSearches.count - Self.recentSearchLimit)
            }
        }
    }

    public func clearRecentSearches() {
        mutate { $0.recentSearches.removeAll() }
    }
}

// MARK: - Recording rules

/// Battery charge state as the recorder sees it. Mirrors DeviceInfo without
/// depending on it.
public enum BatteryLevelState: String, Sendable {
    case unplugged
    case charging
    case full
}

public extension ActivityLog {
    private var today: String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// Battery readings while the app is open. Raises the low-battery alert at the
    /// threshold while unplugged, and records charging and Low Power Mode changes.
    func observeBattery(level: Int?, state: BatteryLevelState?, lowPowerMode: Bool) {
        defer { lastBattery = (level, state, lowPowerMode) }
        guard let previous = lastBattery else { return }

        if let level, state == .unplugged, level <= batteryAlertThreshold,
           (previous.level ?? 100) > batteryAlertThreshold || previous.state != .unplugged {
            let readings = [
                ActivityMeasurement(L("Battery level"), "\(level)%"),
                ActivityMeasurement(L("Alert threshold"), "\(batteryAlertThreshold)%"),
                ActivityMeasurement(L("Charging state"), L("Not charging")),
                ActivityMeasurement(L("Low Power Mode"), lowPowerMode ? L("On") : L("Off")),
                ActivityMeasurement(L("Measured"), now().formatted(date: .omitted, time: .standard)),
            ]
            let alert = raise(ActivityAlert(
                category: .battery,
                severity: .information,
                title: L("Battery level is low"),
                detail: L("Your battery reached your \(batteryAlertThreshold)% alert threshold."),
                explanation: L("Your battery reached \(level)%, at or below the \(batteryAlertThreshold)% alert threshold. Your iPhone wasn’t charging at the time."),
                createdAt: now(),
                thresholdSnapshot: readings,
                recommendation: lowPowerMode ? nil : ActivityRecommendation(
                    title: L("Consider turning on Low Power Mode"),
                    detail: L("It reduces background activity until you can charge your iPhone.")
                ),
                deduplicationKey: "battery.low.\(today)"
            ))
            record(ActivityEvent(
                kind: .batteryLevelDropped,
                category: .battery,
                title: L("Battery level dropped"),
                detail: L("Battery reached \(level)%"),
                explanation: alert.explanation,
                timestamp: now(),
                readState: .unread,
                measurements: readings,
                scope: L("This iPhone"),
                source: "UIDevice.batteryLevel",
                relatedAlertID: alert.id
            ))
        }

        if let state, let old = previous.state, state != old, state != .full || old == .unplugged {
            let charging = state != .unplugged
            record(ActivityEvent(
                kind: .chargingChanged,
                category: .battery,
                title: charging ? L("Charging started") : L("Charging stopped"),
                detail: level.map { charging ? L("Plugged in at \($0)%") : L("Unplugged at \($0)%") } ?? "",
                timestamp: now(),
                measurements: [ActivityMeasurement(L("Battery level"), level.map { "\($0)%" } ?? L("Unavailable"))],
                scope: L("This iPhone"),
                source: "UIDevice.batteryState"
            ))
        }

        if lowPowerMode != previous.lowPower {
            record(ActivityEvent(
                kind: .lowPowerModeChanged,
                category: .battery,
                title: lowPowerMode ? L("Low Power Mode turned on") : L("Low Power Mode turned off"),
                detail: level.map { L("At \($0)% battery") } ?? "",
                timestamp: now(),
                scope: L("This iPhone"),
                source: "ProcessInfo.isLowPowerModeEnabled"
            ))
        }
    }

    /// Storage readings. Raises one alert while free space is at or below the threshold.
    func observeStorage(availableBytes: Int64?, totalBytes: Int64?) {
        guard let available = availableBytes, let total = totalBytes, total > 0 else { return }
        let fraction = Double(available) / Double(total)
        guard fraction <= storageAlertFraction else { return }
        let free = ByteFormatting.storage(available)
        raise(ActivityAlert(
            category: .storage,
            severity: .attention,
            title: L("Storage running low"),
            detail: L("Available storage is below \(Int(storageAlertFraction * 100))% of capacity."),
            explanation: L("Only \(free) of \(ByteFormatting.storage(total)) is available. Some features may stop working when storage is full."),
            createdAt: now(),
            thresholdSnapshot: [
                ActivityMeasurement(L("Available"), free),
                ActivityMeasurement(L("Capacity"), ByteFormatting.storage(total)),
                ActivityMeasurement(L("Alert threshold"), "\(Int(storageAlertFraction * 100))%"),
            ],
            recommendation: ActivityRecommendation(
                title: L("Review large apps and media"),
                detail: L("Settings › General › iPhone Storage shows what uses the most space.")
            ),
            deduplicationKey: "storage.low"
        ))
    }

    /// A thermal change seen while the app is open. Serious and critical raise alerts.
    func thermalChanged(from: String?, to: String, elevated: Bool, critical: Bool) {
        var alertID: UUID?
        if elevated {
            let alert = raise(ActivityAlert(
                category: .thermal,
                severity: critical ? .critical : .attention,
                title: L("Elevated thermal condition"),
                detail: L("Your device entered the \(to) thermal state."),
                explanation: L("iOS reported the \(to) thermal state. iOS may reduce performance until the device cools."),
                createdAt: now(),
                thresholdSnapshot: [
                    ActivityMeasurement(L("Previous state"), from ?? L("Unknown")),
                    ActivityMeasurement(L("New state"), to),
                ],
                recommendation: ActivityRecommendation(
                    title: L("Let your iPhone cool down"),
                    detail: L("Close demanding apps, stop charging for a while or move out of the sun.")
                ),
                deduplicationKey: "thermal.\(to)"
            ))
            alertID = alert.id
        }
        record(ActivityEvent(
            kind: .thermalStateChanged,
            category: .thermal,
            title: L("Thermal state changed"),
            detail: L("Device entered \(to) state"),
            explanation: L("iOS reported that your iPhone’s thermal state changed from \(from ?? L("an unknown state")) to \(to)."),
            timestamp: now(),
            readState: elevated ? .unread : .read,
            measurements: [
                ActivityMeasurement(L("Previous state"), from ?? L("Unknown")),
                ActivityMeasurement(L("New state"), to),
                ActivityMeasurement(L("Time of transition"), now().formatted(date: .omitted, time: .standard)),
            ],
            scope: L("This iPhone"),
            source: "ProcessInfo.thermalState",
            relatedAlertID: alertID
        ))
    }

    /// Network interface changes. The first reading is the baseline.
    func observeNetwork(_ description: String?) {
        defer { lastNetwork = description }
        guard let previous = lastNetwork, previous != description else { return }
        let now = description ?? L("No connection")
        record(ActivityEvent(
            kind: .networkChanged,
            category: .network,
            title: L("Network connection changed"),
            detail: description.map { L("Connected to \($0)") } ?? L("Disconnected"),
            timestamp: self.now(),
            measurements: [
                ActivityMeasurement(L("Before"), previous),
                ActivityMeasurement(L("After"), now),
            ],
            scope: L("This iPhone"),
            source: "NWPathMonitor"
        ))
    }

    func recordMemoryWarning() {
        record(ActivityEvent(
            kind: .memoryWarning,
            category: .performance,
            title: L("Memory warning received"),
            detail: L("iOS asked SystemScope to free memory"),
            timestamp: now(),
            scope: L("This app"),
            source: "UIApplication.didReceiveMemoryWarningNotification"
        ))
    }
}
