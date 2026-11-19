import ActivityStore
import Core
import Foundation
@testable import SettingsFeature
import Testing

@MainActor
private final class Probe {
    var permission: SettingsPermission = .notDetermined
    var requested = false
    var copied: [String] = []
}

@MainActor
private func makeModel(
    snapshot: ActivitySnapshot = SampleActivity.snapshot(),
    failSaves: Bool = false,
    probe: Probe = Probe()
) async -> (SettingsModel, AppPreferences) {
    let preferences = AppPreferences(defaults: UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!)
    let log = ActivityLog(persistence: InMemoryActivityPersistence(snapshot: snapshot, failSaves: failSaves))
    await log.load()
    let model = SettingsModel(
        preferences: preferences,
        log: log,
        dependencies: SettingsDependencies(
            deviceInfo: { SettingsDeviceInfo(modelName: "iPhone 15 Pro", modelIdentifier: "iPhone16,1", osVersion: "18.2", isIdentified: true) },
            refreshDevice: {},
            notificationStatus: { await probe.permission },
            requestNotifications: {
                await MainActor.run { probe.requested = true; probe.permission = .granted }
                return .granted
            },
            motionStatus: { .notDetermined },
            loadPlans: { [SettingsPlan(id: "y", title: "Yearly", price: "$29.99")] },
            restorePurchases: { false },
            deviceReport: { "Model: iPhone 15 Pro" },
            appVersion: "1.0.0",
            buildNumber: "112",
            openSystemSettings: {},
            openDevice: { _ in },
            replayOnboarding: {},
            copy: { probe.copied.append($0) }
        )
    )
    return (model, preferences)
}

@MainActor
struct SettingsPreferencesTests {
    @Test func defaultsMatchThePRD() {
        let settings = UserSettings()
        #expect(settings.lowBatteryPercent == 20)
        #expect(settings.lowStoragePercent == 10)
        #expect(settings.thermalThreshold == .serious)
        #expect(UserSettings.lowBatteryRange == 5...50)
        #expect(UserSettings.lowStorageRange == 5...30)
        #expect(settings.theme == .light)
    }

    @Test func settingsPersistAcrossLaunches() {
        let defaults = UserDefaults(suiteName: "SettingsPersist-\(UUID().uuidString)")!
        let first = AppPreferences(defaults: defaults)
        first.settings.lowBatteryPercent = 35
        first.settings.hiddenMonitorTiles = ["gpu"]
        let second = AppPreferences(defaults: defaults)
        #expect(second.settings.lowBatteryPercent == 35)
        #expect(second.settings.hiddenMonitorTiles == ["gpu"])
    }

    @Test func resetPreferencesKeepsProfileAndOnboarding() async {
        let (model, preferences) = await makeModel()
        preferences.setDeviceDisplayName("Work phone")
        preferences.hasCompletedOnboarding = true
        model.update { $0.lowBatteryPercent = 40; $0.compactLayout = true }
        let events = model.log.events.count
        model.resetPreferences()
        #expect(preferences.settings == UserSettings())
        #expect(preferences.deviceDisplayName == "Work phone")
        #expect(preferences.hasCompletedOnboarding)
        #expect(model.log.events.count == events)
    }

    @Test func resetDeviceProfileRestoresDefaultName() async {
        let (model, preferences) = await makeModel()
        preferences.setDeviceDisplayName("Work phone")
        model.resetDeviceProfile()
        #expect(preferences.deviceDisplayName == AppPreferences.defaultDeviceDisplayName)
    }
}

@MainActor
struct SettingsModelTests {
    @Test func notificationSwitchAsksOnlyWhenUndecided() async {
        let probe = Probe()
        let (model, _) = await makeModel(probe: probe)
        await model.refreshStatuses()
        await model.setNotificationsEnabled(true)
        #expect(probe.requested)
        #expect(model.notificationsDelivered)
    }

    @Test func deniedPermissionKeepsNotificationsOff() async {
        let probe = Probe()
        probe.permission = .denied
        let (model, _) = await makeModel(probe: probe)
        await model.refreshStatuses()
        await model.setNotificationsEnabled(true)
        #expect(!probe.requested)
        #expect(!model.notificationsDelivered)
    }

    @Test func clearFlowRemovesOnlyChosenKinds() async {
        let (model, _) = await makeModel()
        let alerts = model.log.alerts.count
        model.beginClear([.activity, .sessions])
        let expected = model.clearCount
        model.confirmClear()
        #expect(model.clearState == .confirming)
        await model.performClear()
        #expect(model.clearState == .succeeded(expected))
        #expect(model.log.events.isEmpty)
        #expect(model.log.alerts.count == alerts)
        // The active session is still recording and stays.
        #expect(model.log.sessions.allSatisfy { $0.status == .active })
    }

    @Test func clearFailureChangesNothing() async {
        let (model, _) = await makeModel(failSaves: true)
        let events = model.log.events.count
        model.beginClear([.activity])
        model.confirmClear()
        await model.performClear()
        #expect(model.clearState == .failed)
        #expect(model.log.events.count == events)
    }

    @Test func exportWritesOneFilePerSelection() async throws {
        let (model, _) = await makeModel()
        model.exportSelection = [.device, .activity, .alerts]
        model.exportFormat = .json
        await model.generateExport()
        guard case .ready(let urls) = model.exportState else {
            Issue.record("Export did not finish")
            return
        }
        #expect(urls.count == 3)
        let names = Set(urls.map(\.lastPathComponent))
        #expect(names == ["device.txt", "activity.json", "alerts.json"])
        let json = try String(contentsOf: urls.first { $0.lastPathComponent == "activity.json" }!, encoding: .utf8)
        #expect(json.contains("\"schemaVersion\" : 1"))
    }

    @Test func measuredSizesComeFromStoredRecords() async {
        let (model, _) = await makeModel()
        #expect(model.measuredTotal > 0)
        let (empty, _) = await makeModel(snapshot: ActivitySnapshot())
        #expect(empty.measuredTotal <= 6)
    }

    @Test func renameValidatesAndSaves() async {
        let (model, preferences) = await makeModel()
        model.beginRename()
        model.renameDraft = "   "
        #expect(!model.saveRename())
        #expect(model.renameError)
        model.renameDraft = "Lab iPhone"
        #expect(model.saveRename())
        #expect(preferences.deviceDisplayName == "Lab iPhone")
    }

    @Test func diagnosticsAreCopiedOnlyWhenAsked() async {
        let probe = Probe()
        let (model, _) = await makeModel(probe: probe)
        #expect(probe.copied.isEmpty)
        model.copyDiagnostics()
        #expect(probe.copied.first?.contains("iPhone16,1") == true)
    }
}

@MainActor
struct ThresholdRuleTests {
    @Test func customBatteryThresholdIsUsed() async {
        let log = ActivityLog(persistence: InMemoryActivityPersistence())
        await log.load()
        log.batteryAlertThreshold = 35
        log.observeBattery(level: 40, state: .unplugged, lowPowerMode: false)
        log.observeBattery(level: 35, state: .unplugged, lowPowerMode: false)
        #expect(log.alerts.count == 1)
    }

    @Test func disabledThresholdAlertsRaiseNothing() async {
        let log = ActivityLog(persistence: InMemoryActivityPersistence())
        await log.load()
        log.alertsEnabled = false
        log.observeStorage(availableBytes: 1, totalBytes: 100)
        #expect(log.alerts.isEmpty)
    }

    @Test func raisedAlertsAreReportedForNotifications() async {
        let log = ActivityLog(persistence: InMemoryActivityPersistence())
        await log.load()
        var raised: [ActivityAlert] = []
        log.onAlertRaised = { raised.append($0) }
        log.observeStorage(availableBytes: 1, totalBytes: 100)
        log.observeStorage(availableBytes: 1, totalBytes: 100)
        #expect(raised.count == 1)
    }

    @Test func turningActivityHistoryOffStopsNewEvents() async {
        let log = ActivityLog(persistence: InMemoryActivityPersistence())
        await log.load()
        log.updateSettings { $0.recordActivity = false }
        log.recordMemoryWarning()
        #expect(log.events.isEmpty)
    }
}
