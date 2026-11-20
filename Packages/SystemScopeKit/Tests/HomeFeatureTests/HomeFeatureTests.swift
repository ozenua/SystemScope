import DeviceInfo
import Foundation
import SpeedTest
import Testing
@testable import HomeFeature

struct DeviceHealthTests {
    private let base = DeviceSummary(
        storageAvailableBytes: 100, storageTotalBytes: 200,
        batteryLevel: 0.8, batteryState: .unplugged, thermalState: .nominal
    )

    @Test func allInputsWithinLimitsIsHealthy() {
        #expect(DeviceHealth.evaluate(base) == .healthy)
    }

    @Test func lowBatteryNeedsAttentionOnlyWhenNotCharging() {
        var summary = base
        summary.batteryLevel = 0.12
        #expect(DeviceHealth.evaluate(summary) == .attention)
        summary.batteryState = .charging
        #expect(DeviceHealth.evaluate(summary) == .healthy)
    }

    @Test func lowStorageAndThermalStatesEscalate() {
        var summary = base
        summary.storageAvailableBytes = 10
        #expect(DeviceHealth.evaluate(summary) == .attention)
        summary.thermalState = .critical
        #expect(DeviceHealth.evaluate(summary) == .critical)
    }

    /// HOME-06: a missing input is never silently treated as healthy.
    @Test func missingInputIsPartialNotHealthy() {
        var summary = base
        summary.batteryLevel = nil
        #expect(DeviceHealth.evaluate(summary) == .partial)
    }
}

/// Replays a fixed list of events, like a test server that always behaves the same.
private struct ScriptedSpeedTest: SpeedTestRunning {
    var events: [SpeedTestEvent]
    var isConfigured: Bool { true }

    func run(profile: SpeedTestProfile, wifiSSID: String?) -> AsyncStream<SpeedTestEvent> {
        AsyncStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

private struct FixedPath: NetworkPathProviding {
    var snapshot = ConnectionSnapshot(isConnected: true, interface: .wifi)
    func current() async -> ConnectionSnapshot? { snapshot }
    func changes() -> AsyncStream<ConnectionSnapshot> {
        AsyncStream { $0.yield(snapshot) }
    }
}

private final class SequencedNetworkInspector: NetworkInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: NetworkSnapshot

    init(_ snapshot: NetworkSnapshot) {
        self.snapshot = snapshot
    }

    func readNetwork() async -> NetworkSnapshot {
        lock.withLock { snapshot }
    }

    func update(to snapshot: NetworkSnapshot) {
        lock.withLock { self.snapshot = snapshot }
    }
}

@MainActor
struct HomeModelTests {
    private let completed = InternetSpeedTestResult(
        connection: .wifi, wifiSSID: nil, serverHost: "test.example", serverRegion: nil, profile: .quick,
        measurements: SpeedTestMeasurements(downloadMbps: 85.4, uploadMbps: 24.8, idleLatencyMs: 21, jitterMs: 3),
        testDurationSeconds: 9, downloadedBytes: 10, uploadedBytes: 5
    )

    private func makeModel(
        insights: any HomeInsightsProviding = SampleHomeInsights(),
        battery: any BatteryMonitoring = SampleBatteryMonitor(),
        speedTester: any SpeedTestRunning = UnconfiguredSpeedTest(),
        history: any SpeedTestHistoryStoring = InMemorySpeedTestRepository(),
        path: FixedPath = FixedPath(),
        networkInspector: any NetworkInspecting = SampleNetworkInspector()
    ) -> HomeModel {
        HomeModel(
            inspector: SampleDeviceInspector(),
            networkInspector: networkInspector,
            gpuInspector: SampleGPUInformationProvider(),
            battery: battery,
            insights: insights,
            speedTester: speedTester,
            speedTestHistory: history,
            pathMonitor: path,
            displayName: { "My iPhone" }
        )
    }

    private func waitUntilFinished(_ model: HomeModel) async {
        for _ in 0..<200 where model.isSpeedTestRunning {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func refreshLoadsDeviceAndNetwork() async {
        let model = makeModel()
        await model.refresh()
        #expect(model.summary.modelName == "iPhone 15 Pro")
        #expect(model.network?.interface == .wifi)
        #expect(model.todayUsage != nil)
        #expect(model.health == .healthy)
    }

    @Test func networkRefreshUsesLatestInterfaceCounters() async {
        let initial = NetworkSnapshot(isConnected: true, interface: .wifi, receivedBytes: 100, sentBytes: 20)
        let inspector = SequencedNetworkInspector(initial)
        let model = makeModel(networkInspector: inspector)

        await model.refresh()
        #expect(model.network?.receivedBytes == 100)
        inspector.update(to: NetworkSnapshot(isConnected: true, interface: .wifi, receivedBytes: 200, sentBytes: 40))
        await model.refreshNetwork()
        #expect(model.network?.receivedBytes == 200)
        #expect(model.network?.sentBytes == 40)
    }

    /// The live battery reading wins over the scanned one, and "unknown" stays unknown.
    @Test func batteryComesFromTheMonitorAndIsNeverZeroWhenUnavailable() async {
        let model = makeModel(battery: SampleBatteryMonitor(level: nil, state: nil))
        await model.refresh()
        #expect(model.summary.batteryLevel == nil)
        #expect(model.summary.batteryState == nil)
        #expect(model.health == .partial)
    }

    @Test func gpuLoadsWithoutADeviceWideUtilisationFigure() async {
        let model = makeModel()
        await model.refresh()
        #expect(model.gpu?.name == "Apple A17 Pro GPU")
        #expect(model.gpu?.deviceWideUtilisation == nil)
        #expect(model.gpu?.appGPUExecutionTimeMs == nil)
    }

    /// Values iOS does not expose stay nil rather than becoming zero.
    @Test func unavailableInsightsStayUnavailable() async {
        let model = makeModel(insights: UnavailableHomeInsights())
        await model.refresh()
        #expect(model.performance == nil)
        #expect(model.todayUsage == nil)
        #expect(model.latestSpeedTest == nil)
    }

    /// Even with sample data on, there is no speed result until a real test has run.
    @Test func sampleDataNeverIncludesASpeedResult() async {
        let model = makeModel(insights: SampleHomeInsights())
        await model.refresh()
        #expect(model.latestSpeedTest == nil)
    }

    @Test func speedTestWithoutAServerReportsUnavailable() {
        let model = makeModel()
        model.openSpeedTest()
        #expect(model.isSpeedTestPresented)
        #expect(model.speedTest == .unavailable)
        model.startSpeedTest()
        #expect(model.speedTest == .unavailable)
    }

    /// Opening the screen transfers nothing: the test waits for an explicit start.
    @Test func openingTheScreenDoesNotStartATest() {
        let model = makeModel(speedTester: ScriptedSpeedTest(events: [.completed(completed)]))
        model.openSpeedTest()
        #expect(model.speedTest == .ready)
    }

    @Test func completedTestBecomesTheLatestResult() async {
        let history = InMemorySpeedTestRepository(results: [completed])
        let model = makeModel(speedTester: ScriptedSpeedTest(events: [.completed(completed)]), history: history)
        model.openSpeedTest()
        model.startSpeedTest()
        await waitUntilFinished(model)
        #expect(model.speedTest == .completed(completed))
        #expect(model.latestSpeedTest == completed)
    }

    @Test func failedTestShowsTheFailureAndNoResult() async {
        let model = makeModel(speedTester: ScriptedSpeedTest(events: [.failed(.networkChanged)]))
        model.openSpeedTest()
        model.startSpeedTest()
        await waitUntilFinished(model)
        #expect(model.speedTest == .failed(.networkChanged))
        #expect(model.latestSpeedTest == nil)
    }

    @Test func lowDataModeLimitsTheTestToTheQuickProfile() async {
        let path = FixedPath(snapshot: ConnectionSnapshot(isConnected: true, interface: .cellular, isExpensive: true, isConstrained: true))
        let model = makeModel(speedTester: ScriptedSpeedTest(events: []), path: path)
        await model.refresh()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(model.availableProfiles == [.quick])
    }

    @Test func deletingAResultRemovesItFromHistory() async {
        let model = makeModel(history: InMemorySpeedTestRepository(results: [completed]))
        await model.refresh()
        #expect(model.speedTestHistory.count == 1)
        await model.deleteSpeedTest(completed.id)
        #expect(model.speedTestHistory.isEmpty)
    }
}
