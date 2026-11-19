import DeviceInfo
import Foundation
import Observation
import SpeedTest

/// State and intents for the Home tab and its Network screens (PRD §6.2).
@MainActor
@Observable
public final class HomeModel {
    public enum Route: Hashable, Sendable {
        case network
        case dataUsage
        case gpu
    }

    public enum SpeedTestState: Equatable, Sendable {
        /// The speed-test screen is closed.
        case idle
        /// No test server is set up for this build.
        case unavailable
        case ready
        case running(SpeedTestProgress)
        case completed(InternetSpeedTestResult)
        case failed(SpeedTestError)
    }

    public var path: [Route] = []
    public var isSpeedTestPresented = false
    public var selectedRange: DataUsageRange = .today {
        didSet { Task { await loadUsage() } }
    }

    private var scannedSummary = DeviceSummary()
    public private(set) var gpu: GPUInformation?
    public private(set) var network: NetworkSnapshot?
    public private(set) var performance: PerformanceSnapshot?
    public private(set) var speedTestHistory: [InternetSpeedTestResult] = []
    /// Called once per completed test, so the shell can record it in Activity.
    @ObservationIgnored public var onSpeedTestCompleted: (@MainActor (InternetSpeedTestResult) -> Void)?
    public private(set) var connection: ConnectionSnapshot?
    public var selectedProfile: SpeedTestProfile = .quick
    public private(set) var usage: [DataUsageRange: DataUsageSeries] = [:]
    public private(set) var hasLoaded = false
    public var speedTest: SpeedTestState = .idle

    @ObservationIgnored private let inspector: any DeviceInspecting
    @ObservationIgnored private let networkInspector: any NetworkInspecting
    @ObservationIgnored private let gpuInspector: any GPUInspecting
    @ObservationIgnored private let battery: any BatteryMonitoring
    @ObservationIgnored private let insights: any HomeInsightsProviding
    @ObservationIgnored private let displayNameProvider: @MainActor () -> String
    @ObservationIgnored private let speedTester: any SpeedTestRunning
    @ObservationIgnored private let history: any SpeedTestHistoryStoring
    @ObservationIgnored private let pathMonitor: any NetworkPathProviding
    @ObservationIgnored private var speedTestTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?

    public init(
        inspector: any DeviceInspecting,
        networkInspector: any NetworkInspecting,
        gpuInspector: any GPUInspecting,
        battery: any BatteryMonitoring,
        insights: any HomeInsightsProviding,
        speedTester: any SpeedTestRunning,
        speedTestHistory: any SpeedTestHistoryStoring,
        pathMonitor: any NetworkPathProviding,
        displayName: @escaping @MainActor () -> String
    ) {
        self.inspector = inspector
        self.networkInspector = networkInspector
        self.gpuInspector = gpuInspector
        self.battery = battery
        self.insights = insights
        self.speedTester = speedTester
        self.history = speedTestHistory
        self.pathMonitor = pathMonitor
        self.displayNameProvider = displayName
    }

    public var displayName: String { displayNameProvider() }

    /// Scanned device facts with the live battery reading laid over them, so battery
    /// changes reach the UI as soon as iOS reports them.
    public var summary: DeviceSummary {
        var summary = scannedSummary
        let reading = battery.snapshot
        summary.batteryLevel = reading.level.map { Double($0) / 100 }
        summary.batteryState = reading.state
        return summary
    }

    public var batterySnapshot: BatterySnapshot { battery.snapshot }
    public var health: DeviceHealth { DeviceHealth.evaluate(summary) }
    public var todayUsage: DataUsageSeries? { usage[.today] }
    public var selectedUsage: DataUsageSeries? { usage[selectedRange] }

    /// HOME-08: runs on screen entry and on pull-to-refresh; every call is a real read.
    public func refresh() async {
        battery.start()
        startConnectionMonitoring()
        var fresh = scannedSummary
        for category in [ScanCategory.deviceAndSystem, .memoryAndStorage, .batteryAndThermal] {
            if let value = await inspector.readSnapshot(of: category).value {
                fresh.merge(value)
            }
        }
        scannedSummary = fresh
        network = await networkInspector.readNetwork()
        // Independent of the reads above: a missing GPU never blocks the rest.
        gpu = await gpuInspector.readGPU().value
        performance = await insights.performance()
        speedTestHistory = await history.all()
        usage[.today] = await insights.dataUsage(for: .today)
        hasLoaded = true
    }

    public func loadUsage() async {
        let range = selectedRange
        usage[range] = await insights.dataUsage(for: range)
    }

    public func open(_ route: Route) {
        path.append(route)
    }

    public func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: - Speed test (user initiated only, PRD §10)

    public var latestSpeedTest: InternetSpeedTestResult? { speedTestHistory.first }
    public var isSpeedTestRunning: Bool {
        if case .running = speedTest { true } else { false }
    }

    /// Low Data Mode limits the test to the smallest data budget.
    public var availableProfiles: [SpeedTestProfile] {
        connection?.isConstrained == true ? [.quick] : SpeedTestProfile.allCases
    }

    /// Opens the speed-test screen. Nothing is transferred until the user taps Start.
    public func openSpeedTest() {
        isSpeedTestPresented = true
        if !isSpeedTestRunning {
            speedTest = speedTester.isConfigured ? .ready : .unavailable
        }
        Task {
            connection = await pathMonitor.current()
            speedTestHistory = await history.all()
        }
    }

    public func startSpeedTest() {
        guard speedTester.isConfigured, !isSpeedTestRunning else { return }
        if !availableProfiles.contains(selectedProfile) { selectedProfile = .quick }
        speedTest = .running(SpeedTestProgress(phase: .preparing))
        let events = speedTester.run(profile: selectedProfile, wifiSSID: network?.networkName)
        speedTestTask = Task { [weak self] in
            for await event in events {
                guard let self, !Task.isCancelled else { return }
                switch event {
                case let .progress(progress):
                    self.speedTest = .running(progress)
                case let .completed(result):
                    self.speedTest = .completed(result)
                    self.onSpeedTestCompleted?(result)
                    self.speedTestHistory = await self.history.all()
                case let .failed(error):
                    self.speedTest = .failed(error)
                }
            }
        }
    }

    /// Stops the transfers and discards the partial measurements (PRD §10.3).
    public func cancelSpeedTest() {
        speedTestTask?.cancel()
        speedTestTask = nil
        if isSpeedTestRunning { speedTest = .ready }
    }

    /// Speed tests never continue in the background.
    public func appDidLeaveForeground() {
        cancelSpeedTest()
    }

    /// Closes the screen. The last state stays visible while the sheet animates away;
    /// `speedTestDismissed` clears it.
    public func endSpeedTest() {
        speedTestTask?.cancel()
        speedTestTask = nil
        isSpeedTestPresented = false
    }

    public func speedTestDismissed() {
        speedTestTask?.cancel()
        speedTestTask = nil
        speedTest = .idle
    }

    public func deleteSpeedTest(_ id: InternetSpeedTestResult.ID) async {
        try? await history.delete(id: id)
        speedTestHistory = await history.all()
    }

    // MARK: - Connection monitoring

    /// Follows path changes for as long as the model lives, so the connection type on
    /// screen tracks Wi-Fi and cellular switches.
    private func startConnectionMonitoring() {
        guard connectionTask == nil else { return }
        connectionTask = Task { [weak self, pathMonitor, networkInspector] in
            for await snapshot in pathMonitor.changes() {
                guard let self else { return }
                let changed = self.connection != snapshot
                self.connection = snapshot
                if changed { self.network = await networkInspector.readNetwork() }
            }
        }
    }
}
