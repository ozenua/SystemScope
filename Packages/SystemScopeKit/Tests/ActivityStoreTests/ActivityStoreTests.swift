@testable import ActivityStore
import Foundation
import Testing

@MainActor
private func makeLog(
    _ snapshot: ActivitySnapshot = ActivitySnapshot(),
    persistence: InMemoryActivityPersistence? = nil,
    now: Date = .now
) async -> (ActivityLog, InMemoryActivityPersistence) {
    let store = persistence ?? InMemoryActivityPersistence(snapshot: snapshot)
    let log = ActivityLog(persistence: store, now: { now })
    await log.load()
    return (log, store)
}

private func settle() async {
    // Saves run in a detached task after each change.
    for _ in 0..<5 { await Task.yield() }
    try? await Task.sleep(for: .milliseconds(20))
}

@MainActor
struct AlertLifecycleTests {
    private func alert(key: String = "k") -> ActivityAlert {
        ActivityAlert(category: .battery, severity: .information, title: "Low", detail: "d", deduplicationKey: key)
    }

    @Test func openingMarksReadButNeverResolves() async {
        let (log, _) = await makeLog()
        let raised = log.raise(alert())
        log.markRead(alert: raised.id)
        #expect(log.alerts[0].readState == .read)
        #expect(log.alerts[0].resolutionState == .open)
    }

    @Test func resolveAndDismissRecordTheirDates() async {
        let (log, _) = await makeLog()
        let a = log.raise(alert(key: "a"))
        let b = log.raise(alert(key: "b"))
        log.resolve(alert: a.id)
        log.dismiss(alert: b.id)
        let resolved = log.alerts.first { $0.id == a.id }!
        let dismissed = log.alerts.first { $0.id == b.id }!
        #expect(resolved.resolutionState == .resolved && resolved.resolvedAt != nil)
        #expect(dismissed.resolutionState == .dismissed && dismissed.dismissedAt != nil)
        // Read state is independent of resolution.
        #expect(resolved.readState == .unread)
    }

    @Test func sameOpenConditionIsNotRaisedTwice() async {
        let (log, _) = await makeLog()
        let first = log.raise(alert())
        let second = log.raise(alert())
        #expect(first.id == second.id)
        #expect(log.alerts.count == 1)
        log.resolve(alert: first.id)
        log.raise(alert())
        #expect(log.alerts.count == 2)
    }

    @Test func deletionIsNotDismissal() async {
        let (log, _) = await makeLog()
        let raised = log.raise(alert())
        log.deleteAlert(raised.id)
        #expect(log.alerts.isEmpty)
    }
}

@MainActor
struct RecordingRuleTests {
    @Test func firstBatteryReadingIsOnlyABaseline() async {
        let (log, _) = await makeLog()
        log.observeBattery(level: 15, state: .unplugged, lowPowerMode: false)
        #expect(log.events.isEmpty && log.alerts.isEmpty)
    }

    @Test func crossingTheBatteryThresholdRaisesOneAlertAndEvent() async {
        let (log, _) = await makeLog()
        log.observeBattery(level: 21, state: .unplugged, lowPowerMode: false)
        log.observeBattery(level: 20, state: .unplugged, lowPowerMode: false)
        log.observeBattery(level: 19, state: .unplugged, lowPowerMode: false)
        #expect(log.alerts.count == 1)
        let drops = log.events.filter { $0.kind == .batteryLevelDropped }
        #expect(drops.count == 1)
        #expect(drops.first?.relatedAlertID == log.alerts[0].id)
    }

    @Test func chargingAndLowPowerChangesAreRecorded() async {
        let (log, _) = await makeLog()
        log.observeBattery(level: 50, state: .unplugged, lowPowerMode: false)
        log.observeBattery(level: 50, state: .charging, lowPowerMode: true)
        let charging = log.events.contains { $0.kind == .chargingChanged }
        let lowPower = log.events.contains { $0.kind == .lowPowerModeChanged }
        #expect(charging && lowPower)
    }

    @Test func storageAlertOnlyAtTenPercentOrLess() async {
        let (log, _) = await makeLog()
        log.observeStorage(availableBytes: 30, totalBytes: 100)
        #expect(log.alerts.isEmpty)
        log.observeStorage(availableBytes: 10, totalBytes: 100)
        log.observeStorage(availableBytes: 9, totalBytes: 100)
        #expect(log.alerts.count == 1)
    }

    @Test func thermalElevationRaisesAnAlertLinkedToTheEvent() async {
        let (log, _) = await makeLog()
        log.thermalChanged(from: "Nominal", to: "Fair", elevated: false, critical: false)
        #expect(log.alerts.isEmpty)
        log.thermalChanged(from: "Fair", to: "Serious", elevated: true, critical: false)
        #expect(log.alerts.count == 1 && log.alerts[0].severity == .attention)
        #expect(log.events[0].relatedAlertID == log.alerts[0].id)
    }

    @Test func networkChangeNeedsABaseline() async {
        let (log, _) = await makeLog()
        log.observeNetwork("Wi-Fi")
        log.observeNetwork("Wi-Fi")
        #expect(log.events.isEmpty)
        log.observeNetwork("Cellular")
        #expect(log.events.count == 1)
    }
}

@MainActor
struct SessionLifecycleTests {
    @Test func sessionsEndCompletedOrInterruptedAndLogAnEvent() async {
        let (log, _) = await makeLog()
        let id = try! #require(log.beginSession(.performance, metrics: ["CPU"]))
        #expect(log.sessions[0].status == .active)
        log.endSession(id, status: .interrupted, interruptionReason: "Backgrounded", observationCount: 12, summary: [])
        #expect(log.sessions[0].status == .interrupted)
        #expect(log.sessions[0].endedAt != nil)
        #expect(log.events[0].relatedSessionID == id)
    }

    @Test func noSessionWhenRecordingIsOff() async {
        let (log, _) = await makeLog()
        log.updateSettings { $0.recordSessions = false }
        #expect(log.beginSession(.network, metrics: []) == nil)
    }

    @Test func abandonedActiveSessionsBecomeInterrupted() async {
        let stale = MonitoringSessionRecord(type: .battery, status: .active)
        let (log, _) = await makeLog(ActivitySnapshot(sessions: [stale]))
        log.closeAbandonedSessions()
        #expect(log.sessions[0].status == .interrupted)
        #expect(log.sessions[0].interruptionReason != nil)
    }
}

@MainActor
struct PersistenceTests {
    @Test func clearHistoryRemovesEventsOnlyAndPersists() async throws {
        let snapshot = SampleActivity.snapshot()
        let (log, store) = await makeLog(snapshot)
        let removed = try await log.clearHistory()
        #expect(removed == snapshot.events.count)
        #expect(log.events.isEmpty)
        #expect(log.alerts.count == snapshot.alerts.count)
        #expect(log.sessions.count == snapshot.sessions.count)
        #expect(await store.stored.events.isEmpty)
        #expect(await store.stored.settings == snapshot.settings)
    }

    @Test func failedClearLeavesHistoryUnchanged() async {
        let snapshot = SampleActivity.snapshot()
        let store = InMemoryActivityPersistence(snapshot: snapshot)
        let (log, _) = await makeLog(persistence: store)
        await store.setFailures(loads: false, saves: true)
        await #expect(throws: ActivityPersistenceError.self) { try await log.clearHistory() }
        #expect(log.events.count == snapshot.events.count)
    }

    @Test func failedLoadIsReported() async {
        let store = InMemoryActivityPersistence(failLoads: true)
        let log = ActivityLog(persistence: store)
        await log.load()
        #expect(log.loadState == .failed)
    }

    @Test func retentionDropsOldEventsButKeepsOpenAlerts() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-40 * 86_400)
        let snapshot = ActivitySnapshot(
            events: [ActivityEvent(kind: .memoryWarning, category: .performance, title: "Old", detail: "", timestamp: old, scope: "", source: "")],
            alerts: [ActivityAlert(category: .storage, severity: .attention, title: "Open", detail: "", createdAt: old, deduplicationKey: "o")]
        )
        let (log, store) = await makeLog(snapshot, now: now)
        #expect(log.events.isEmpty)
        #expect(log.alerts.count == 1)
        await settle()
        #expect(await store.stored.events.isEmpty)
    }

    @Test func recentSearchesAreDeduplicatedAndCapped() async {
        let (log, _) = await makeLog()
        for index in 0..<15 { log.addRecentSearch("query \(index)") }
        log.addRecentSearch("QUERY 14")
        #expect(log.recentSearches.count == ActivityLog.recentSearchLimit)
        #expect(log.recentSearches.first == "QUERY 14")
        log.clearRecentSearches()
        #expect(log.recentSearches.isEmpty)
    }

    @Test func fileRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("activity-\(UUID().uuidString).json")
        let store = FileActivityPersistence(url: url)
        let snapshot = SampleActivity.snapshot()
        try await store.save(snapshot)
        let loaded = try await store.load()
        #expect(loaded.events.count == snapshot.events.count)
        #expect(loaded.alerts.map(\.id) == snapshot.alerts.map(\.id))
        try? FileManager.default.removeItem(at: url)
    }
}
