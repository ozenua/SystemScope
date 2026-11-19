import Testing
import UIKit
@testable import DeviceInfo

struct DeviceCatalogueTests {
    @Test func knownIdentifierResolves() {
        let entry = DeviceCatalogue.bundled.entry(for: "iPhone16,1")
        #expect(entry?.modelName == "iPhone 15 Pro")
        #expect(entry?.processor == "Apple A17 Pro")
    }

    @Test func unknownIdentifierFallsBackToNil() {
        #expect(DeviceCatalogue.bundled.entry(for: "iPhone99,9") == nil)
    }
}

struct DeviceSummaryTests {
    @Test func mergeKeepsExistingValuesWhenOtherIsNil() {
        var summary = DeviceSummary(modelName: "iPhone 15 Pro", batteryLevel: 0.5)
        summary.merge(DeviceSummary(osVersion: "18.2", batteryLevel: 0.8))
        #expect(summary.modelName == "iPhone 15 Pro")
        #expect(summary.osVersion == "18.2")
        #expect(summary.batteryLevel == 0.8)
        #expect(summary.memoryInUseBytes == nil)
    }
}

struct BatterySnapshotTests {
    @Test func levelIsRoundedToAWholePercentage() {
        let snapshot = BatterySnapshot(rawLevel: 0.874, rawState: .charging)
        #expect(snapshot.level == 87)
        #expect(snapshot.state == .charging)
        #expect(snapshot.isAvailable)
    }

    /// UIDevice reports -1 when the level is unknown: unavailable, never 0%.
    @Test func unknownLevelIsUnavailableNotZero() {
        let snapshot = BatterySnapshot(rawLevel: -1, rawState: .unknown)
        #expect(snapshot.level == nil)
        #expect(snapshot.state == nil)
        #expect(!snapshot.isAvailable)
    }

    @Test func fullAndUnpluggedStatesMap() {
        #expect(BatterySnapshot(rawLevel: 1, rawState: .full).state == .full)
        #expect(BatterySnapshot(rawLevel: 0.5, rawState: .unplugged).state == .unplugged)
    }
}

struct GPUTests {
    @Test func executionTimeRejectsMissingOrInvertedTimestamps() {
        #expect(GPUPerformanceMonitor.executionTimeMs(start: 0, end: 1) == nil)
        #expect(GPUPerformanceMonitor.executionTimeMs(start: 2, end: 1) == nil)
        #expect(GPUPerformanceMonitor.executionTimeMs(start: 1, end: 1.25) == 250)
    }

    /// Whatever the hardware, the provider never reports device-wide utilisation,
    /// and reports no app figure because SystemScope submits no GPU work.
    @Test func providerNeverReportsUtilisation() async {
        let result = await GPUInformationProvider().readGPU()
        #expect(result.value?.deviceWideUtilisation == nil)
        #expect(result.value?.appGPUExecutionTimeMs == nil)
        if result.value?.metalAvailable == true {
            #expect(result.scope == .deviceSpecification)
        } else {
            #expect(result.status == .unsupported)
        }
    }
}
