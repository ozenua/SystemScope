import ActivityStore
import Core
import DeviceInfo
import Foundation
import Observation
import SpeedTest
import UIKit

public enum MonitorRoute: String, Hashable, Sendable {
    case cpu
    case memory
    case gpu
    case storage
    case battery
    case thermal
    case network
}

/// SystemScope's own CPU use over one sampling interval, as a share of every core.
public struct CPUSample: Sendable, Equatable {
    public var date: Date
    public var percent: Double
}

public struct MemorySample: Sendable, Equatable {
    public var date: Date
    public var inUseBytes: UInt64
}

/// A thermal state change observed while SystemScope was open.
public struct ThermalChange: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var from: ThermalCondition?
    public var to: ThermalCondition
    public var date: Date
}

public enum CPURange: String, CaseIterable, Sendable {
    case live
    case fiveMinutes
    case fifteenMinutes
    case hour

    /// Seconds of history the chart covers.
    public var window: TimeInterval {
        switch self {
        case .live: 60
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .hour: 3_600
        }
    }

    var tickStep: TimeInterval {
        switch self {
        case .live: 15
        case .fiveMinutes: 60
        case .fifteenMinutes: 300
        case .hour: 900
        }
    }
}

/// Live (this session) or stored history ranges.
public enum HistoryRange: String, CaseIterable, Sendable {
    case live
    case today
    case week
    case month
}

/// State and intents for the Monitor tab: the overview (MON-01) and the seven metric
/// screens (MON-02 to MON-08).
@MainActor
@Observable
public final class MonitorModel {
    public var path: [MonitorRoute] = []
    public private(set) var hasLoaded = false
    public private(set) var isRefreshing = false
    public private(set) var lastUpdated: Date?
    public private(set) var gpu: GPUInformation?
    public private(set) var network: NetworkSnapshot?
    public private(set) var alerts: [MonitorAlert] = []
    public private(set) var activity: [MonitorActivity] = []
    public private(set) var trends: [MonitorTrendRange: MonitorTrend] = [:]
    public private(set) var latestSpeedTest: InternetSpeedTestResult?
    public var selectedRange: MonitorTrendRange = .today {
        didSet { Task { await loadTrend() } }
    }

    // Live session (PRD §9): one continuous foreground period on the Monitor tab.
    // Moving between Monitor screens keeps the same session.
    public private(set) var sessionStart: Date?
    public private(set) var cpuSamples: [CPUSample] = []
    public private(set) var memorySamples: [MemorySample] = []
    public private(set) var appResources: AppResourceSnapshot?
    public private(set) var memoryBreakdown: DeviceMemoryBreakdown?
    public private(set) var peakFootprintBytes: UInt64?
    public private(set) var lastMemoryWarning: Date?
    public private(set) var thermalChanges: [ThermalChange] = []
    public var cpuRange: CPURange = .live
    public var memoryRange: HistoryRange = .live

    private var scannedSummary = DeviceSummary()
    @ObservationIgnored private var sessionStartCPUTime: Double?
    @ObservationIgnored private var lastCPUReading: (cpu: Double, uptime: TimeInterval)?

    @ObservationIgnored private let inspector: any DeviceInspecting
    @ObservationIgnored private let networkInspector: any NetworkInspecting
    @ObservationIgnored private let gpuInspector: any GPUInspecting
    @ObservationIgnored private let battery: any BatteryMonitoring
    @ObservationIgnored private let resources: any ResourceSampling
    @ObservationIgnored private let insights: any MonitorInsightsProviding
    @ObservationIgnored private let speedTestHistory: any SpeedTestHistoryStoring
    @ObservationIgnored private let displayNameProvider: @MainActor () -> String
    @ObservationIgnored private let activityLog: ActivityLog?
    @ObservationIgnored private var activitySessionID: UUID?
    /// Settings › Monitoring preferences (SET-03), read live.
    @ObservationIgnored public var userSettings: @MainActor () -> UserSettings = { UserSettings() }

    /// Samples kept in memory: one hour at one per second. Nothing is persisted.
    static let maximumSamples = 3_600

    public init(
        inspector: any DeviceInspecting,
        networkInspector: any NetworkInspecting,
        gpuInspector: any GPUInspecting,
        battery: any BatteryMonitoring,
        resources: any ResourceSampling,
        insights: any MonitorInsightsProviding,
        speedTestHistory: any SpeedTestHistoryStoring,
        displayName: @escaping @MainActor () -> String,
        activityLog: ActivityLog? = nil
    ) {
        self.inspector = inspector
        self.networkInspector = networkInspector
        self.gpuInspector = gpuInspector
        self.battery = battery
        self.resources = resources
        self.insights = insights
        self.speedTestHistory = speedTestHistory
        self.displayNameProvider = displayName
        self.activityLog = activityLog
    }

    public var displayName: String { displayNameProvider() }

    /// Scanned readings with the live battery value laid over them.
    public var summary: DeviceSummary {
        var summary = scannedSummary
        let reading = battery.snapshot
        summary.batteryLevel = reading.level.map { Double($0) / 100 }
        summary.batteryState = reading.state
        return summary
    }

    public var batterySnapshot: BatterySnapshot { battery.snapshot }
    public var recommendations: [MonitorRecommendation] { MonitorRecommendation.evaluate(summary) }
    public var selectedTrend: MonitorTrend? { trends[selectedRange] }

    public func open(_ route: MonitorRoute) {
        path.append(route)
    }

    public func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Reads every category again. Each read is independent: one that fails leaves
    /// its tile unavailable without blocking the rest. Earlier readings stay on
    /// screen until the new ones arrive.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        battery.start()
        var fresh = scannedSummary
        for category in [ScanCategory.deviceAndSystem, .memoryAndStorage, .batteryAndThermal] {
            if let value = await inspector.readSnapshot(of: category).value {
                fresh.merge(value)
            }
        }
        scannedSummary = fresh
        network = await networkInspector.readNetwork()
        gpu = await gpuInspector.readGPU().value
        memoryBreakdown = resources.memoryBreakdown()
        alerts = await insights.alerts()
        activity = await insights.recentActivity()
        trends[selectedRange] = await insights.trend(for: selectedRange)
        latestSpeedTest = await speedTestHistory.all().first
        lastUpdated = .now
        hasLoaded = true
    }

    public func loadTrend() async {
        let range = selectedRange
        trends[range] = await insights.trend(for: range)
    }

    // MARK: - Live session

    /// Runs while the Monitor tab is visible and the app is active (MON-03): samples
    /// app CPU and device memory once a second, re-reads everything every 15 seconds,
    /// and records thermal changes and memory warnings. Returns when cancelled; the
    /// session ends with it and its samples are discarded.
    public func runSession() async {
        startSession()
        defer { endSession() }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                var tick = 0
                while !Task.isCancelled {
                    if tick % 15 == 0, await self?.shouldRefresh(atTick: tick) == true {
                        await self?.refresh()
                    }
                    await self?.sample(includeMemory: true)
                    tick += 1
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            group.addTask { [weak self] in
                let changes = NotificationCenter.default
                    .notifications(named: ProcessInfo.thermalStateDidChangeNotification)
                    .map { _ in () }
                for await _ in changes {
                    await self?.recordThermalChange()
                }
            }
            group.addTask { [weak self] in
                let warnings = NotificationCenter.default
                    .notifications(named: UIApplication.didReceiveMemoryWarningNotification)
                    .map { _ in () }
                for await _ in warnings {
                    await self?.recordMemoryWarning()
                }
            }
            await group.waitForAll()
        }
    }

    /// Entry refresh is optional except before the first reading; later refreshes
    /// follow "Automatic refresh during active sessions" (SET-03).
    func shouldRefresh(atTick tick: Int) -> Bool {
        let settings = userSettings()
        return tick == 0 ? settings.refreshOnEntry || !hasLoaded : settings.autoRefreshDuringSessions
    }

    private func startSession() {
        sessionStart = .now
        cpuSamples = []
        memorySamples = []
        peakFootprintBytes = nil
        lastCPUReading = nil
        sessionStartCPUTime = resources.appResources()?.cpuTimeSeconds
        activitySessionID = activityLog?.beginSession(
            .performance,
            metrics: [ActivityText.cpu, ActivityText.memory, ActivityText.thermal, ActivityText.battery]
        )
    }

    private func endSession() {
        recordSessionEnd()
        sessionStart = nil
        lastCPUReading = nil
    }

    /// Saves the session summary (PRD §6.5). A session that ends because the app left
    /// the foreground is interrupted, not completed.
    private func recordSessionEnd() {
        guard let id = activitySessionID, let activityLog else { return }
        activitySessionID = nil
        let backgrounded = UIApplication.shared.applicationState != .active
        var summary: [ActivityMeasurement] = []
        if let peak = peakCPU { summary.append(ActivityMeasurement(ActivityText.highestCPU, MonitorFormat.percent(peak))) }
        if let low = cpuSamples.map(\.percent).min() { summary.append(ActivityMeasurement(ActivityText.lowestCPU, MonitorFormat.percent(low))) }
        if let footprint = peakFootprintBytes { summary.append(ActivityMeasurement(ActivityText.peakFootprint, ByteFormatting.memory(footprint, fractionDigits: 1))) }
        var unavailable: [String] = []
        if cpuSamples.isEmpty { unavailable.append(ActivityText.cpu) }
        if memorySamples.isEmpty { unavailable.append(ActivityText.memory) }
        activityLog.endSession(
            id,
            status: backgrounded ? .interrupted : .completed,
            interruptionReason: backgrounded ? ActivityText.backgrounded : nil,
            observationCount: cpuSamples.count + memorySamples.count,
            summary: summary,
            metricsUnavailable: unavailable
        )
    }

    func sample(includeMemory: Bool) {
        let uptime = ProcessInfo.processInfo.systemUptime
        if let app = resources.appResources() {
            appResources = app
            if let footprint = app.footprintBytes {
                peakFootprintBytes = max(peakFootprintBytes ?? 0, footprint)
            }
            if let previous = lastCPUReading, uptime > previous.uptime {
                // CPU-time delta over elapsed time, normalised to every core (0–100%).
                let cores = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
                let percent = max(0, (app.cpuTimeSeconds - previous.cpu) / ((uptime - previous.uptime) * cores) * 100)
                cpuSamples.append(CPUSample(date: .now, percent: min(percent, 100)))
                if cpuSamples.count > Self.maximumSamples { cpuSamples.removeFirst() }
            }
            lastCPUReading = (app.cpuTimeSeconds, uptime)
        }
        if includeMemory, let breakdown = resources.memoryBreakdown() {
            memoryBreakdown = breakdown
            memorySamples.append(MemorySample(date: .now, inUseBytes: breakdown.inUseBytes))
            if memorySamples.count > Self.maximumSamples { memorySamples.removeFirst() }
        }
    }

    private func recordThermalChange() async {
        let previous = scannedSummary.thermalState
        if let value = await inspector.readSnapshot(of: .batteryAndThermal).value {
            scannedSummary.merge(value)
        }
        guard let current = scannedSummary.thermalState, current != previous else { return }
        thermalChanges.insert(ThermalChange(from: previous, to: current, date: .now), at: 0)
        if let id = activitySessionID {
            activityLog?.addTimelineEntry(
                session: id,
                title: ActivityText.thermalChanged,
                detail: "\(previous?.title ?? "–") → \(current.title)"
            )
        }
    }

    private func recordMemoryWarning() {
        lastMemoryWarning = .now
        if let id = activitySessionID {
            activityLog?.addTimelineEntry(session: id, title: ActivityText.memoryWarning, detail: ActivityText.memoryWarningDetail)
        }
    }

    // MARK: - Session statistics

    public var latestCPU: Double? { cpuSamples.last?.percent }
    public var averageCPU: Double? {
        cpuSamples.isEmpty ? nil : cpuSamples.map(\.percent).reduce(0, +) / Double(cpuSamples.count)
    }
    public var peakCPU: Double? { cpuSamples.map(\.percent).max() }

    /// CPU time SystemScope has used since this Monitor session began.
    public var sessionCPUTime: Double? {
        guard let start = sessionStartCPUTime, let now = appResources?.cpuTimeSeconds else { return nil }
        return max(0, now - start)
    }

    public var averageMemory: UInt64? {
        memorySamples.isEmpty ? nil : memorySamples.map(\.inUseBytes).reduce(0, +) / UInt64(memorySamples.count)
    }
}

/// Copy written into Activity session records.
enum ActivityText {
    static var cpu: String { String(localized: "CPU app activity", bundle: .module) }
    static var memory: String { String(localized: "Memory footprint", bundle: .module) }
    static var thermal: String { String(localized: "Thermal state", bundle: .module) }
    static var battery: String { String(localized: "Battery level", bundle: .module) }
    static var highestCPU: String { String(localized: "Highest CPU activity", bundle: .module) }
    static var lowestCPU: String { String(localized: "Lowest CPU activity", bundle: .module) }
    static var peakFootprint: String { String(localized: "Peak memory footprint", bundle: .module) }
    static var backgrounded: String { String(localized: "Stopped when SystemScope left the foreground.", bundle: .module) }
    static var thermalChanged: String { String(localized: "Thermal state changed", bundle: .module) }
    static var memoryWarning: String { String(localized: "Memory warning", bundle: .module) }
    static var memoryWarningDetail: String { String(localized: "iOS asked SystemScope to free memory", bundle: .module) }
}
