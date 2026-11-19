import Foundation

// Records for the Activity tab (PRD §6.5, §8.2). Everything is stored on this iPhone
// only. Payloads are versioned so the schema can change without guessing.

public enum ActivityCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case performance
    case battery
    case network
    case thermal
    case storage
    case sessions

    public var id: String { rawValue }
}

public enum ReadState: String, Codable, Sendable {
    case unread
    case read
}

/// A labelled value captured with an event, alert or session, with its unit already
/// applied. Kept as text so a reading is shown exactly as it was recorded.
public struct ActivityMeasurement: Codable, Sendable, Equatable, Hashable {
    public var label: String
    public var value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// What produced an event, so the detail screen can link to the right place.
public enum ActivityEventKind: String, Codable, Sendable {
    case speedTestCompleted
    case batteryObservation
    case batteryLevelDropped
    case chargingChanged
    case lowPowerModeChanged
    case thermalStateChanged
    case networkChanged
    case storageUpdated
    case memoryWarning
    case sessionEnded
}

/// ActivityEvent (PRD §8.2).
public struct ActivityEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: ActivityEventKind
    public var category: ActivityCategory
    public var title: String
    public var detail: String
    /// A sentence for "What happened" on the detail screen.
    public var explanation: String?
    public var timestamp: Date
    public var readState: ReadState
    public var measurements: [ActivityMeasurement]
    /// "This iPhone", "This app" and so on (ACT-02).
    public var scope: String
    /// The API or component that produced the reading (ACT-02).
    public var source: String
    public var relatedAlertID: UUID?
    public var relatedSessionID: UUID?
    public var payloadVersion: Int

    public init(
        id: UUID = UUID(),
        kind: ActivityEventKind,
        category: ActivityCategory,
        title: String,
        detail: String,
        explanation: String? = nil,
        timestamp: Date = .now,
        readState: ReadState = .read,
        measurements: [ActivityMeasurement] = [],
        scope: String,
        source: String,
        relatedAlertID: UUID? = nil,
        relatedSessionID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.category = category
        self.title = title
        self.detail = detail
        self.explanation = explanation
        self.timestamp = timestamp
        self.readState = readState
        self.measurements = measurements
        self.scope = scope
        self.source = source
        self.relatedAlertID = relatedAlertID
        self.relatedSessionID = relatedSessionID
        self.payloadVersion = 1
    }
}

public enum AlertSeverity: Int, Codable, Sendable, Comparable, CaseIterable {
    case information = 0
    case attention = 1
    case critical = 2

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Resolution is independent of read state (PRD §6.5). There is no `expired` state:
/// no expiry policy exists yet.
public enum ResolutionState: String, Codable, Sendable {
    case open
    case resolved
    case dismissed
}

/// Alert (PRD §8.2).
public struct ActivityAlert: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var category: ActivityCategory
    public var severity: AlertSeverity
    public var title: String
    public var detail: String
    public var explanation: String?
    public var createdAt: Date
    public var readState: ReadState
    public var resolutionState: ResolutionState
    public var resolvedAt: Date?
    public var dismissedAt: Date?
    /// Readings and the threshold at the moment the alert was raised.
    public var thresholdSnapshot: [ActivityMeasurement]
    public var recommendation: ActivityRecommendation?
    /// One open alert per key: the same condition is not raised twice.
    public var deduplicationKey: String
    public var payloadVersion: Int

    public init(
        id: UUID = UUID(),
        category: ActivityCategory,
        severity: AlertSeverity,
        title: String,
        detail: String,
        explanation: String? = nil,
        createdAt: Date = .now,
        readState: ReadState = .unread,
        resolutionState: ResolutionState = .open,
        resolvedAt: Date? = nil,
        dismissedAt: Date? = nil,
        thresholdSnapshot: [ActivityMeasurement] = [],
        recommendation: ActivityRecommendation? = nil,
        deduplicationKey: String
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.detail = detail
        self.explanation = explanation
        self.createdAt = createdAt
        self.readState = readState
        self.resolutionState = resolutionState
        self.resolvedAt = resolvedAt
        self.dismissedAt = dismissedAt
        self.thresholdSnapshot = thresholdSnapshot
        self.recommendation = recommendation
        self.deduplicationKey = deduplicationKey
        self.payloadVersion = 1
    }

    public var needsAttention: Bool { resolutionState == .open }
}

public struct ActivityRecommendation: Codable, Sendable, Equatable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}

public enum SessionStatus: String, Codable, Sendable {
    case active
    case paused
    case completed
    case interrupted
    case failed
}

public enum SessionType: String, Codable, Sendable, CaseIterable {
    case performance
    case network
    case battery
}

public struct SessionTimelineEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var title: String
    public var detail: String

    public init(id: UUID = UUID(), date: Date, title: String, detail: String) {
        self.id = id
        self.date = date
        self.title = title
        self.detail = detail
    }
}

/// MonitoringSession (PRD §8.2): one continuous foreground monitoring period.
public struct MonitoringSessionRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var type: SessionType
    public var startedAt: Date
    public var endedAt: Date?
    public var status: SessionStatus
    public var interruptionReason: String?
    public var metricsIncluded: [String]
    /// Metrics that could not be read during the session (PRD §6.5).
    public var metricsUnavailable: [String]
    public var observationCount: Int
    public var summary: [ActivityMeasurement]
    public var timeline: [SessionTimelineEntry]
    public var alertsGenerated: Int
    public var payloadVersion: Int

    public init(
        id: UUID = UUID(),
        type: SessionType,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        status: SessionStatus = .active,
        interruptionReason: String? = nil,
        metricsIncluded: [String] = [],
        metricsUnavailable: [String] = [],
        observationCount: Int = 0,
        summary: [ActivityMeasurement] = [],
        timeline: [SessionTimelineEntry] = [],
        alertsGenerated: Int = 0
    ) {
        self.id = id
        self.type = type
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.interruptionReason = interruptionReason
        self.metricsIncluded = metricsIncluded
        self.metricsUnavailable = metricsUnavailable
        self.observationCount = observationCount
        self.summary = summary
        self.timeline = timeline
        self.alertsGenerated = alertsGenerated
        self.payloadVersion = 1
    }

    public var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}

public enum ActivityRetention: String, Codable, Sendable, CaseIterable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case indefinitely

    public var days: Int? {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .indefinitely: nil
        }
    }
}

/// ACT-09 Activity settings.
public struct ActivitySettings: Codable, Sendable, Equatable {
    public var groupByDate = true
    public var showResolvedAlerts = true
    public var compactRows = false
    public var retention: ActivityRetention = .thirtyDays
    public var recordSessions = true
    /// When off, no new activity events are recorded (SET-07). Alerts still are.
    public var recordActivity = true

    public init() {}

    enum CodingKeys: String, CodingKey {
        case groupByDate, showResolvedAlerts, compactRows, retention, recordSessions, recordActivity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groupByDate = try c.decodeIfPresent(Bool.self, forKey: .groupByDate) ?? true
        showResolvedAlerts = try c.decodeIfPresent(Bool.self, forKey: .showResolvedAlerts) ?? true
        compactRows = try c.decodeIfPresent(Bool.self, forKey: .compactRows) ?? false
        retention = try c.decodeIfPresent(ActivityRetention.self, forKey: .retention) ?? .thirtyDays
        recordSessions = try c.decodeIfPresent(Bool.self, forKey: .recordSessions) ?? true
        recordActivity = try c.decodeIfPresent(Bool.self, forKey: .recordActivity) ?? true
    }
}

/// Everything persisted, as one versioned document.
public struct ActivitySnapshot: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version = ActivitySnapshot.currentVersion
    public var events: [ActivityEvent] = []
    public var alerts: [ActivityAlert] = []
    public var sessions: [MonitoringSessionRecord] = []
    /// Newest first, at most 10 (ACT-07).
    public var recentSearches: [String] = []
    public var settings = ActivitySettings()

    public init(
        events: [ActivityEvent] = [],
        alerts: [ActivityAlert] = [],
        sessions: [MonitoringSessionRecord] = [],
        recentSearches: [String] = [],
        settings: ActivitySettings = ActivitySettings()
    ) {
        self.events = events
        self.alerts = alerts
        self.sessions = sessions
        self.recentSearches = recentSearches
        self.settings = settings
    }
}

/// What "Clear history" can remove (SET-13). The device profile and preferences are
/// never included (ACT-11).
public enum HistoryKind: String, Sendable, CaseIterable, Identifiable {
    case activity
    case alerts
    case sessions

    public var id: String { rawValue }
}
