import Core
@testable import DeviceFeature
import DeviceInfo
import Foundation
import Testing

private struct FailingInspector: DeviceInspecting {
    func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary> {
        DeviceDataResult(value: nil, scope: .unavailable, source: "test", status: .failed)
    }
}

/// Succeeds until `fail` is set, then returns nothing.
private final class SwitchableDetails: DeviceDetailsProviding, @unchecked Sendable {
    var fail = false
    func readDetails() async -> DeviceDetails? { fail ? nil : SampleDeviceDetailsProvider.details }
}

private final class SwitchableInspector: DeviceInspecting, @unchecked Sendable {
    var fail = false
    func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary> {
        fail ? await FailingInspector().readSnapshot(of: category) : await SampleDeviceInspector().readSnapshot(of: category)
    }
}

@MainActor
private func makeModel(
    inspector: any DeviceInspecting = SampleDeviceInspector(),
    details: any DeviceDetailsProviding = SampleDeviceDetailsProvider(),
    tester: any SensorTesting = SampleSensorTester(delay: .zero),
    copied: CopyLog = CopyLog()
) -> DeviceModel {
    let defaults = UserDefaults(suiteName: "DeviceFeatureTests-\(UUID().uuidString)")!
    return DeviceModel(
        preferences: AppPreferences(defaults: defaults),
        inspector: inspector,
        details: details,
        networkInspector: SampleNetworkInspector(),
        gpuInspector: SampleGPUInformationProvider(),
        battery: SampleBatteryMonitor(),
        sensorTester: tester,
        copy: { copied.values.append($0) }
    )
}

@MainActor
private final class CopyLog {
    var values: [String] = []
}

@MainActor
struct DeviceModelTests {
    @Test func loadsSummaryDetailsAndIdentification() async {
        let model = makeModel()
        #expect(!model.hasLoaded)
        await model.refresh()
        #expect(model.hasLoaded)
        #expect(model.summary.modelName == "iPhone 15 Pro")
        #expect(model.details?.osBuild == "22C152")
        #expect(model.identification == .identified)
        #expect(model.lastUpdated != nil)
        #expect(!model.refreshFailed)
    }

    @Test func unknownIdentifierFallsBackToUnknown() async {
        var details = SampleDeviceDetailsProvider.details
        details.catalogueEntry = nil
        details.hardwareIdentifier = "iPhone99,1"
        let model = makeModel(inspector: FailingInspector(), details: SampleDeviceDetailsProvider(details: details))
        await model.refresh()
        #expect(model.hasLoaded)
        #expect(model.identification == .unknown)
        #expect(model.specifications == nil)
    }

    @Test func failedRefreshKeepsLastValuesAndTimestamp() async {
        let inspector = SwitchableInspector()
        let details = SwitchableDetails()
        let model = makeModel(inspector: inspector, details: details)
        await model.refresh()
        let firstUpdate = model.lastUpdated
        inspector.fail = true
        details.fail = true
        await model.refresh()
        #expect(model.refreshFailed)
        #expect(model.lastUpdated == firstUpdate)
        #expect(model.summary.modelName == "iPhone 15 Pro")
        // A later success clears the error.
        inspector.fail = false
        details.fail = false
        await model.refresh()
        #expect(!model.refreshFailed)
    }

    @Test func firstLoadFailureIsNotShownAsLoaded() async {
        let model = makeModel(inspector: FailingInspector(), details: SampleDeviceDetailsProvider(details: nil))
        await model.refresh()
        #expect(model.refreshFailed)
        #expect(!model.hasLoaded)
    }

    @Test func renameTrimsValidatesAndLimits() {
        let model = makeModel()
        model.beginRename()
        #expect(model.sheet == .rename)
        model.renameDraft = "   "
        #expect(!model.saveRename())
        #expect(model.renameError)
        #expect(model.sheet == .rename)
        model.renameDraft = String(repeating: "a", count: 60)
        #expect(model.renameDraft.count == AppPreferences.deviceDisplayNameLimit)
        #expect(!model.renameError)
        model.renameDraft = "  Work phone  "
        #expect(model.saveRename())
        #expect(model.displayName == "Work phone")
        #expect(model.sheet == nil)
        #expect(model.toast != nil)
    }

    @Test func copyAllIncludesFallbacksAndShowsConfirmation() async {
        let log = CopyLog()
        let model = makeModel(copied: log)
        await model.refresh()
        model.copyAllSpecifications()
        let text = try! #require(log.values.first)
        #expect(text.contains("iPhone16,1"))
        #expect(text.contains("Build number: 22C152"))
        #expect(!text.contains(": 0\n"))
        #expect(model.toast != nil)
    }

    @Test func sensorTestRunsOnlyWhenAsked() async {
        let model = makeModel()
        await model.refresh()
        #expect(model.sensorTests.isEmpty)
        await model.runTest(.barometer)
        #expect(model.sensorTests[.barometer] == .finished(.passed(samples: 50)))
        // Sensors without a test never start one.
        await model.runTest(.ambientLight)
        #expect(model.sensorTests[.ambientLight] == nil)
    }

    @Test func navigationAppendsAndPops() {
        let model = makeModel()
        model.open(.processor)
        model.open(.graphics)
        #expect(model.path == [.processor, .graphics])
        model.goBack()
        #expect(model.path == [.processor])
    }
}

struct DeviceFormattingTests {
    @Test func parsesBuildFromVersionString() {
        #expect(DeviceDetails.parseBuild("Version 18.2 (Build 22C152)") == "22C152")
        #expect(DeviceDetails.parseBuild("Version 18.2") == nil)
    }

    @Test func storageRoundsToAdvertisedCapacity() {
        #expect(DeviceFormat.storage(255_000_000_000) == "256 GB")
        #expect(DeviceFormat.storage(990_000_000_000) == "1 TB")
        #expect(DeviceFormat.storage(nil) == nil)
    }

    @Test func shortChipDropsVendor() {
        #expect(DeviceFormat.shortChip("Apple A17 Pro") == "A17 Pro")
    }

    @Test func displayHelpersReportNilWhenUnread() {
        #expect(DeviceFormat.pixels(nil) == nil)
        #expect(DisplayDetails().isProMotion == nil)
        #expect(DisplayDetails(maximumFramesPerSecond: 120).isProMotion == true)
        #expect(DisplayDetails(potentialEDRHeadroom: 1).isHDR == false)
    }
}
