import ActivityStore
import Foundation
import Observation

func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

public enum ActivityRoute: Hashable, Sendable {
    case event(UUID)
    case alerts
    case alert(UUID)
    case sessions
    case session(UUID)
    case search
}

/// Monitor screens Activity links to; AppShell maps them to Monitor routes.
public enum ActivityMonitorLink: Sendable {
    case cpu
    case memory
    case battery
    case thermal
    case network
    case storage
}

/// The category chips on the overview (ACT-01).
public enum ActivityChip: String, CaseIterable, Sendable, Identifiable {
    case all
    case alerts
    case performance
    case battery
    case network
    case thermal
    case storage
    case sessions

    public var id: String { rawValue }

    var category: ActivityCategory? {
        switch self {
        case .all, .alerts: nil
        case .performance: .performance
        case .battery: .battery
        case .network: .network
        case .thermal: .thermal
        case .storage: .storage
        case .sessions: .sessions
        }
    }
}

/// ACT-08 filters.
public struct ActivityFilters: Equatable, Sendable {
    public enum DateRange: String, CaseIterable, Sendable {
        case today
        case sevenDays
        case thirtyDays
        case all
    }

    public enum Status: String, CaseIterable, Sendable {
        case all
        case unread
        case needsAttention
        case resolved
    }

    public enum Sort: String, CaseIterable, Sendable {
        case newest
        case oldest
        case severity
    }

    /// Empty means every category.
    public var categories: Set<ActivityCategory> = []
    public var dateRange: DateRange = .all
    public var status: Status = .all
    public var sort: Sort = .newest

    public init() {}

    public var isDefault: Bool { self == ActivityFilters() }
}

/// One row in a feed: an event, an alert or a session.
public enum ActivityItem: Identifiable, Equatable, Sendable {
    case event(ActivityEvent)
    case alert(ActivityAlert)
    case session(MonitoringSessionRecord)

    public var id: UUID {
        switch self {
        case .event(let event): event.id
        case .alert(let alert): alert.id
        case .session(let session): session.id
        }
    }

    public var date: Date {
        switch self {
        case .event(let event): event.timestamp
        case .alert(let alert): alert.createdAt
        case .session(let session): session.startedAt
        }
    }

    public var category: ActivityCategory {
        switch self {
        case .event(let event): event.category
        case .alert(let alert): alert.category
        case .session: .sessions
        }
    }

    public var title: String {
        switch self {
        case .event(let event): event.title
        case .alert(let alert): alert.title
        case .session(let session): ActivityText.sessionTitle(session.type)
        }
    }

    public var detail: String {
        switch self {
        case .event(let event): event.detail
        case .alert(let alert): alert.detail
        case .session(let session): ActivityText.sessionDetail(session)
        }
    }

    public var isUnread: Bool {
        switch self {
        case .event(let event): event.readState == .unread
        case .alert(let alert): alert.readState == .unread
        case .session: false
        }
    }

    public var isResolved: Bool {
        if case .alert(let alert) = self { return alert.resolutionState != .open }
        return false
    }

    public var needsAttention: Bool {
        if case .alert(let alert) = self { return alert.resolutionState == .open }
        return false
    }

    var severity: AlertSeverity? {
        if case .alert(let alert) = self { return alert.severity }
        return nil
    }

    var route: ActivityRoute {
        switch self {
        case .event(let event): .event(event.id)
        case .alert(let alert): .alert(alert.id)
        case .session(let session): .session(session.id)
        }
    }
}

/// A date group in a feed: Today, Yesterday, a weekday, or Older activity.
public struct ActivitySection: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var items: [ActivityItem]
}

public enum ClearHistoryState: Equatable, Sendable {
    case idle
    case confirming
    case deleting
    case succeeded(Int)
    case failed
}

public enum ActivitySheet: String, Identifiable, Sendable {
    case filters
    case settings

    public var id: String { rawValue }
}

@MainActor
@Observable
public final class ActivityModel {
    public var path: [ActivityRoute] = []
    public var sheet: ActivitySheet?
    public var chip: ActivityChip = .all {
        didSet { visibleLimit = Self.pageSize }
    }
    public var filters = ActivityFilters() {
        didSet { visibleLimit = Self.pageSize }
    }
    public var alertChip: AlertChip = .all
    public var sessionRange: SessionRange = .all
    public var searchQuery = ""
    public var searchScope: SearchScope = .all
    public var collapsedSections: Set<String> = []
    public private(set) var visibleLimit = ActivityModel.pageSize
    public private(set) var clearState: ClearHistoryState = .idle
    public private(set) var toast: String?

    public let log: ActivityLog
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let copyToPasteboard: @MainActor (String) -> Void
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    /// Items per page in the overview feed (ACT-01 pagination).
    public static let pageSize = 30

    public init(
        log: ActivityLog,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        copy: @escaping @MainActor (String) -> Void
    ) {
        self.log = log
        self.calendar = calendar
        self.now = now
        self.copyToPasteboard = copy
    }

    // MARK: - Loading

    public var isLoading: Bool { log.loadState == .idle || log.loadState == .loading }
    public var loadFailed: Bool { log.loadState == .failed }

    public func load() async { await log.loadIfNeeded() }
    public func retry() async { await log.load() }

    // MARK: - Summary (ACT-01)

    public var todayCount: Int { log.events.filter { calendar.isDate($0.timestamp, inSameDayAs: now()) }.count }
    public var openAlertCount: Int { log.alerts.filter { $0.resolutionState == .open }.count }
    public var sessionsToday: Int { log.sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: now()) }.count }
    public var lastActivity: Date? { log.events.map(\.timestamp).max() }
    /// No chip or filter is narrowing the feed.
    public var isUnfiltered: Bool { filters.isDefault && (chip == .all || chip == .sessions) }
    public var hasAnyHistory: Bool { !log.events.isEmpty || !log.alerts.isEmpty || !log.sessions.isEmpty }

    // MARK: - Overview feed

    /// Every item the chip and filters allow, before pagination.
    public var filteredItems: [ActivityItem] {
        var items: [ActivityItem]
        switch chip {
        case .alerts:
            items = log.alerts.map(ActivityItem.alert)
        case .sessions:
            items = log.events.filter { $0.category == .sessions }.map(ActivityItem.event)
        default:
            items = log.events.map(ActivityItem.event)
            if let category = chip.category { items = items.filter { $0.category == category } }
        }
        if !log.settings.showResolvedAlerts { items = items.filter { !$0.isResolved } }
        return apply(filters, to: items)
    }

    func apply(_ filters: ActivityFilters, to items: [ActivityItem]) -> [ActivityItem] {
        var result = items
        if !filters.categories.isEmpty { result = result.filter { filters.categories.contains($0.category) } }
        if let start = startDate(for: filters.dateRange) { result = result.filter { $0.date >= start } }
        switch filters.status {
        case .all: break
        case .unread: result = result.filter(\.isUnread)
        case .needsAttention: result = result.filter(\.needsAttention)
        case .resolved: result = result.filter(\.isResolved)
        }
        switch filters.sort {
        case .newest: result.sort { $0.date > $1.date }
        case .oldest: result.sort { $0.date < $1.date }
        case .severity:
            result.sort {
                let lhs = $0.severity?.rawValue ?? -1, rhs = $1.severity?.rawValue ?? -1
                return lhs == rhs ? $0.date > $1.date : lhs > rhs
            }
        }
        return result
    }

    private func startDate(for range: ActivityFilters.DateRange) -> Date? {
        let today = calendar.startOfDay(for: now())
        return switch range {
        case .today: today
        case .sevenDays: calendar.date(byAdding: .day, value: -6, to: today)
        case .thirtyDays: calendar.date(byAdding: .day, value: -29, to: today)
        case .all: nil
        }
    }

    public var feedSections: [ActivitySection] {
        let page = Array(filteredItems.prefix(visibleLimit))
        guard log.settings.groupByDate, filters.sort != .severity else {
            return page.isEmpty ? [] : [ActivitySection(id: "all", title: L("All activity"), items: page)]
        }
        return sections(for: page)
    }

    public var canLoadMore: Bool { filteredItems.count > visibleLimit }

    public func loadMore() { visibleLimit += Self.pageSize }

    /// Groups by Today, Yesterday, a named day within the last week, then Older.
    func sections(for items: [ActivityItem]) -> [ActivitySection] {
        let today = calendar.startOfDay(for: now())
        var order: [String] = []
        var groups: [String: (title: String, items: [ActivityItem])] = [:]
        for item in items {
            let day = calendar.startOfDay(for: item.date)
            let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            let key: String
            let title: String
            switch days {
            case ...0: key = "today"; title = L("Today")
            case 1: key = "yesterday"; title = L("Yesterday")
            case 2...6:
                key = "day-\(Int(day.timeIntervalSince1970))"
                title = day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
            default: key = "older"; title = L("Older activity")
            }
            if groups[key] == nil { order.append(key); groups[key] = (title, []) }
            groups[key]?.items.append(item)
        }
        return order.map { ActivitySection(id: $0, title: groups[$0]!.title, items: groups[$0]!.items) }
    }

    public func toggleSection(_ id: String) {
        if collapsedSections.contains(id) { collapsedSections.remove(id) } else { collapsedSections.insert(id) }
    }

    /// Default collapse: everything older than yesterday starts folded, as in Figma.
    public func isCollapsed(_ section: ActivitySection) -> Bool {
        collapsedSections.contains(section.id) != (section.id != "today" && section.id != "yesterday" && section.id != "all")
    }

    // MARK: - Alerts (ACT-03)

    public enum AlertChip: String, CaseIterable, Sendable {
        case all
        case unresolved
        case resolved
        case critical
        case attention
        case information
    }

    public var alertSections: [ActivitySection] {
        let alerts = log.alerts.filter { alert in
            switch alertChip {
            case .all: true
            case .unresolved: alert.resolutionState == .open
            case .resolved: alert.resolutionState != .open
            case .critical: alert.severity == .critical
            case .attention: alert.severity == .attention
            case .information: alert.severity == .information
            }
        }
        return sections(for: alerts.sorted { $0.createdAt > $1.createdAt }.map(ActivityItem.alert))
    }

    public var alertsThisMonth: Int {
        log.alerts.filter { calendar.isDate($0.createdAt, equalTo: now(), toGranularity: .month) }.count
    }

    public var resolvedAlertCount: Int { log.alerts.filter { $0.resolutionState != .open }.count }

    // MARK: - Sessions (ACT-05)

    public enum SessionRange: String, CaseIterable, Sendable {
        case all
        case today
        case week
        case month
    }

    public var sessionSections: [ActivitySection] {
        let today = calendar.startOfDay(for: now())
        let start: Date? = switch sessionRange {
        case .all: nil
        case .today: today
        case .week: calendar.date(byAdding: .day, value: -6, to: today)
        case .month: calendar.dateInterval(of: .month, for: now())?.start
        }
        let sessions = log.sessions.filter { start == nil || $0.startedAt >= start! }.sorted { $0.startedAt > $1.startedAt }
        return sections(for: sessions.map(ActivityItem.session))
    }

    public var sessionsThisMonth: Int {
        log.sessions.filter { calendar.isDate($0.startedAt, equalTo: now(), toGranularity: .month) }.count
    }

    /// Recorded time across finished sessions.
    public var monitoredTotal: TimeInterval {
        log.sessions.compactMap(\.duration).reduce(0, +)
    }

    // MARK: - Search (ACT-06, ACT-07)

    public enum SearchScope: String, CaseIterable, Sendable {
        case all
        case alerts
        case events
        case sessions
    }

    /// Matches title, detail, category and the formatted date.
    public var searchResults: [ActivityItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var items: [ActivityItem] = []
        if searchScope == .all || searchScope == .events { items += log.events.map(ActivityItem.event) }
        if searchScope == .all || searchScope == .alerts { items += log.alerts.map(ActivityItem.alert) }
        if searchScope == .all || searchScope == .sessions { items += log.sessions.map(ActivityItem.session) }
        return items
            .filter { item in
                let haystack = [
                    item.title, item.detail, ActivityText.categoryName(item.category),
                    item.date.formatted(date: .complete, time: .shortened),
                ]
                return haystack.contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .sorted { $0.date > $1.date }
    }

    public var searchSections: [ActivitySection] {
        let today = calendar.startOfDay(for: now())
        let results = searchResults
        let todayItems = results.filter { $0.date >= today }
        let earlier = results.filter { $0.date < today }
        return [
            ActivitySection(id: "search-today", title: L("Today"), items: todayItems),
            ActivitySection(id: "search-earlier", title: L("Earlier"), items: earlier),
        ].filter { !$0.items.isEmpty }
    }

    public func commitSearch() {
        log.addRecentSearch(searchQuery)
    }

    // MARK: - Lookups

    public func event(_ id: UUID) -> ActivityEvent? { log.events.first { $0.id == id } }
    public func alert(_ id: UUID) -> ActivityAlert? { log.alerts.first { $0.id == id } }
    public func session(_ id: UUID) -> MonitoringSessionRecord? { log.sessions.first { $0.id == id } }

    // MARK: - Navigation and actions

    public func open(_ route: ActivityRoute) {
        path.append(route)
        // ACT-04: opening marks read, never resolves.
        switch route {
        case .event(let id):
            log.markRead(event: id)
            if let alertID = event(id)?.relatedAlertID { log.markRead(alert: alertID) }
        case .alert(let id): log.markRead(alert: id)
        default: break
        }
    }

    public func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    public func toggleRead(_ item: ActivityItem) {
        switch item {
        case .event(let event): log.setRead(event: event.id, event.readState == .unread)
        case .alert(let alert):
            if alert.readState == .unread { log.markRead(alert: alert.id) } else { log.markUnread(alert: alert.id) }
        case .session: break
        }
    }

    public func delete(_ item: ActivityItem) {
        switch item {
        case .event(let event): log.deleteEvent(event.id)
        case .alert(let alert): log.deleteAlert(alert.id)
        case .session(let session): log.deleteSession(session.id)
        }
        if case .some(let last) = path.last, last == item.route { path.removeLast() }
        showToast(deletedMessage(item))
    }

    private func deletedMessage(_ item: ActivityItem) -> String {
        switch item {
        case .event: L("Event deleted")
        case .alert: L("Alert deleted")
        case .session: L("Session deleted")
        }
    }

    public func copy(_ text: String) {
        copyToPasteboard(text)
        showToast(L("Copied to clipboard"))
    }

    public func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Clear history (ACT-10, ACT-11)

    /// The number of records "Clear history" will remove. Alerts and sessions stay.
    public var clearableCount: Int { log.events.count }

    public func requestClearHistory() {
        sheet = nil
        clearState = .confirming
    }

    public func cancelClearHistory() {
        clearState = .idle
    }

    public func confirmClearHistory() async {
        clearState = .deleting
        do {
            let removed = try await log.clearHistory()
            clearState = .succeeded(removed)
            collapsedSections = []
            visibleLimit = Self.pageSize
        } catch {
            clearState = .failed
        }
    }

    public func finishClearHistory() {
        clearState = .idle
    }

    // MARK: - Export

    /// CSV of every event, alert and session. Written to a temporary file for the share sheet.
    public func exportCSV() -> String {
        func field(_ text: String) -> String { "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        let formatter = ISO8601DateFormatter()
        var rows = ["type,timestamp,category,title,detail,state"]
        for event in log.events {
            rows.append(["event", formatter.string(from: event.timestamp), event.category.rawValue, field(event.title), field(event.detail), event.readState.rawValue].joined(separator: ","))
        }
        for alert in log.alerts {
            rows.append(["alert", formatter.string(from: alert.createdAt), alert.category.rawValue, field(alert.title), field(alert.detail), alert.resolutionState.rawValue].joined(separator: ","))
        }
        for session in log.sessions {
            rows.append(["session", formatter.string(from: session.startedAt), session.type.rawValue, field(ActivityText.sessionTitle(session.type)), field(ActivityText.sessionDetail(session)), session.status.rawValue].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    public func exportFileURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SystemScope-Activity.csv")
        do {
            try exportCSV().write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Plain-text copy of an item's details.
    public func detailsText(_ item: ActivityItem) -> String {
        var lines = [item.title, item.date.formatted(date: .abbreviated, time: .standard), item.detail]
        switch item {
        case .event(let event):
            lines += event.measurements.map { "\($0.label): \($0.value)" }
            lines.append(L("Source: \(event.source)"))
        case .alert(let alert):
            lines += alert.thresholdSnapshot.map { "\($0.label): \($0.value)" }
        case .session(let session):
            lines += session.summary.map { "\($0.label): \($0.value)" }
            lines.append(L("Observations: \(session.observationCount)"))
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

/// Copy shared by the model and views.
enum ActivityText {
    static func categoryName(_ category: ActivityCategory) -> String {
        switch category {
        case .performance: L("Performance")
        case .battery: L("Battery")
        case .network: L("Network")
        case .thermal: L("Thermal")
        case .storage: L("Storage")
        case .sessions: L("Sessions")
        }
    }

    static func sessionTitle(_ type: SessionType) -> String {
        switch type {
        case .performance: L("Performance monitoring")
        case .network: L("Network monitoring")
        case .battery: L("Battery monitoring")
        }
    }

    static func sessionDetail(_ session: MonitoringSessionRecord) -> String {
        switch session.status {
        case .active, .paused: L("Recording")
        case .completed: session.duration.map { L("\(minutes($0)) minutes recorded") } ?? L("Completed")
        case .interrupted: session.duration.map { L("Session ended after \(minutes($0)) minutes") } ?? L("Interrupted")
        case .failed: L("Failed")
        }
    }

    static func minutes(_ interval: TimeInterval) -> Int {
        max(1, Int((interval / 60).rounded()))
    }
}
