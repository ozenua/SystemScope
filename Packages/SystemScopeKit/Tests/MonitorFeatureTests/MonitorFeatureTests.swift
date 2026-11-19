import DeviceInfo
import Foundation
import SpeedTest
import Testing
@testable import MonitorFeature

struct MonitorRecommendationTests {
    @Test func plentyOfStorageAndBatteryGivesNoRecommendation() {
        let summary = DeviceSummary(
            storageAvailableBytes: 600, storageTotalBytes: 1_000, batteryLevel: 0.8, batteryState: .unplugged
        )
        #expect(MonitorRecommendation.evaluate(summary).isEmpty)
    }

    @Test func lowFreeStorageSuggestsAReview() {
        let summary = DeviceSummary(storageAvailableBytes: 270, storageTotalBytes: 1_000)
        #expect(MonitorRecommendation.evaluate(summary) == [.reviewStorage(freeFraction: 0.27)])
    }

    @Test func lowBatterySuggestsLowPowerModeOnlyWhenNotCharging() {
        var summary = DeviceSummary(batteryLevel: 0.15, batteryState: .unplugged)
        #expect(MonitorRecommendation.evaluate(summary) == [.considerLowPowerMode])
        summary.batteryState = .charging
        #expect(MonitorRecommendation.evaluate(summary).isEmpty)
    }

    /// PRD §6.7: nothing is recommended from readings that are unavailable.
    @Test func unavailableReadingsProduceNoRecommendation() {
        #expect(MonitorRecommendation.evaluate(DeviceSummary()).isEmpty)
    }
}

@MainActor
struct MonitorModelTests {
    private func makeModel(
        insights: any MonitorInsightsProviding = SampleMonitorInsights(),
        battery: any BatteryMonitoring = SampleBatteryMonitor()
    ) -> MonitorModel {
        MonitorModel(
            inspector: SampleDeviceInspector(),
            networkInspector: SampleNetworkInspector(),
            gpuInspector: SampleGPUInformationProvider(),
            battery: battery,
            resources: SampleResourceSampler(),
            insights: insights,
            speedTestHistory: InMemorySpeedTestRepository(),
            displayName: { "My iPhone" }
        )
    }

    @Test func startsUnloadedThenLoadsEveryReading() async {
        let model = makeModel()
        #expect(!model.hasLoaded)
        #expect(model.lastUpdated == nil)

        await model.refresh()
        #expect(model.hasLoaded)
        #expect(!model.isRefreshing)
        #expect(model.lastUpdated != nil)
        #expect(model.summary.processorCoreCount == 6)
        #expect(model.summary.memoryInUseBytes != nil)
        #expect(model.gpu?.metalAvailable == true)
        #expect(model.network?.interface == .wifi)
        #expect(model.alerts.count == 1)
        #expect(model.activity.count == 3)
        #expect(model.selectedTrend?.hasGaps == true)
    }

    /// With no stored history the page has empty sections, not invented content.
    @Test func withoutHistoryTheSectionsAreEmpty() async {
        let model = makeModel(insights: UnavailableMonitorInsights())
        await model.refresh()
        #expect(model.alerts.isEmpty)
        #expect(model.activity.isEmpty)
        #expect(model.selectedTrend == nil)
    }

    /// An unavailable battery stays unavailable; it is never shown as 0%.
    @Test func unavailableBatteryIsNotZero() async {
        let model = makeModel(battery: SampleBatteryMonitor(level: nil, state: nil))
        await model.refresh()
        #expect(model.summary.batteryLevel == nil)
    }

    @Test func tilesOpenTheirMetricScreen() {
        let model = makeModel()
        model.open(.cpu)
        model.open(.memory)
        #expect(model.path == [.cpu, .memory])
        model.goBack()
        #expect(model.path == [.cpu])
    }

    /// App CPU is a CPU-time delta over elapsed time, so the first sample sets a
    /// baseline and only the second produces a reading.
    @Test func cpuNeedsTwoReadingsAndStaysInRange() async throws {
        let model = makeModel()
        model.sample(includeMemory: true)
        #expect(model.cpuSamples.isEmpty)
        #expect(model.memorySamples.count == 1)
        try await Task.sleep(for: .milliseconds(50))
        model.sample(includeMemory: false)
        let reading = try #require(model.latestCPU)
        #expect((0...100).contains(reading))
        #expect(model.memorySamples.count == 1)
        #expect(model.appResources?.footprintBytes == 312_000_000)
        #expect(model.peakFootprintBytes == 312_000_000)
    }

    @Test func refreshPicksUpTheLatestSpeedTestAndMemoryBreakdown() async {
        let result = InternetSpeedTestResult(
            connection: .wifi, wifiSSID: nil, serverHost: "test.example", serverRegion: nil, profile: .quick,
            measurements: SpeedTestMeasurements(downloadMbps: 85, uploadMbps: 24, idleLatencyMs: 18),
            testDurationSeconds: 14, downloadedBytes: 10, uploadedBytes: 5
        )
        let model = MonitorModel(
            inspector: SampleDeviceInspector(),
            networkInspector: SampleNetworkInspector(),
            gpuInspector: SampleGPUInformationProvider(),
            battery: SampleBatteryMonitor(),
            resources: SampleResourceSampler(),
            insights: UnavailableMonitorInsights(),
            speedTestHistory: InMemorySpeedTestRepository(results: [result]),
            displayName: { "My iPhone" }
        )
        await model.refresh()
        #expect(model.latestSpeedTest == result)
        #expect(model.memoryBreakdown?.inUseBytes == 5_200_000_000)
        #expect(model.network?.isCellularAvailable == true)
        #expect(model.gpu?.families == ["Apple9", "Common3", "Metal3"])
    }

    @Test func rangesWithoutEnoughHistoryHaveNoTrend() async {
        let model = makeModel()
        await model.refresh()
        model.selectedRange = .month
        await model.loadTrend()
        #expect(model.selectedTrend == nil)
    }
}
