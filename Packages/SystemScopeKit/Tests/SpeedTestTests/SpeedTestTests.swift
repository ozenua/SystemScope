import DeviceInfo
import Foundation
import Testing
@testable import SpeedTest

// MARK: - Fakes

/// A scripted test server. Transfers "take" a few milliseconds so timing is real.
private struct FakeServer: SpeedTestServerClient {
    var host = "test.example"
    var roundTripsMs: [Double] = [20, 22, 19, 25, 21]
    var reachable = true
    var transferDelay: Duration = .milliseconds(4)

    func fetchConfig() async throws -> SpeedTestServerConfig {
        guard reachable else { throw SpeedTestError.serverUnreachable }
        return SpeedTestServerConfig(serverRegion: "test-region")
    }

    func ping() async throws -> Double {
        guard reachable else { throw URLError(.cannotConnectToHost) }
        try await Task.sleep(for: .milliseconds(1))
        return roundTripsMs.randomElement()!
    }

    func download(bytes: Int, onBytes: @escaping @Sendable (Int) -> Void) async throws -> Int {
        guard reachable else { throw URLError(.cannotConnectToHost) }
        for _ in 0..<4 {
            try await Task.sleep(for: transferDelay)
            onBytes(bytes / 4)
        }
        return bytes / 4 * 4
    }

    func upload(bytes: Int, onBytesSent: @escaping @Sendable (Int) -> Void) async throws -> UploadConfirmation {
        guard reachable else { throw URLError(.cannotConnectToHost) }
        try await Task.sleep(for: transferDelay)
        onBytesSent(bytes)
        return UploadConfirmation(bytesReceived: bytes)
    }
}

private struct FakePath: NetworkPathProviding {
    var initial: ConnectionSnapshot? = ConnectionSnapshot(isConnected: true, interface: .wifi)
    /// When set, the path switches to this after a short delay.
    var switchTo: ConnectionSnapshot?

    func current() async -> ConnectionSnapshot? { initial }

    func changes() -> AsyncStream<ConnectionSnapshot> {
        AsyncStream { continuation in
            if let initial { continuation.yield(initial) }
            guard let switchTo else { return }
            let task = Task {
                try? await Task.sleep(for: .milliseconds(40))
                continuation.yield(switchTo)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private func runTest(
    server: FakeServer = FakeServer(),
    path: FakePath = FakePath(),
    history: InMemorySpeedTestRepository = InMemorySpeedTestRepository()
) async -> [SpeedTestEvent] {
    let coordinator = SpeedTestCoordinator(
        clients: [server], path: path, history: history,
        overallTimeout: .seconds(10), phaseDuration: .milliseconds(150)
    )
    var events: [SpeedTestEvent] = []
    for await event in coordinator.run(profile: .quick, wifiSSID: nil) {
        events.append(event)
    }
    return events
}

// MARK: - Maths

struct SpeedTestMathTests {
    @Test func medianHandlesOddEvenAndEmpty() {
        #expect(SpeedTestMath.median([30, 10, 20]) == 20)
        #expect(SpeedTestMath.median([10, 20, 30, 40]) == 25)
        #expect(SpeedTestMath.median([]) == nil)
    }

    /// Mean absolute difference of consecutive samples: (2 + 3 + 6) / 3.
    @Test func jitterIsMeanAbsoluteConsecutiveDifference() throws {
        let jitter = try #require(SpeedTestMath.jitter([10, 12, 9, 15]))
        #expect(abs(jitter - 11.0 / 3) < 0.0001)
        #expect(SpeedTestMath.jitter([10]) == nil)
    }

    /// 25 MB in 2 s is 100 Mbps in decimal megabits.
    @Test func throughputUsesDecimalMegabits() {
        #expect(SpeedTestMath.mbps(bytes: 25_000_000, seconds: 2) == 100)
        #expect(SpeedTestMath.mbps(bytes: 0, seconds: 2) == nil)
        #expect(SpeedTestMath.mbps(bytes: 100, seconds: 0) == nil)
    }

    @Test func dataBudgetIsNeverExceeded() {
        let meter = ByteMeter(budget: 1_000)
        #expect(meter.reserve(600) == 600)
        #expect(meter.reserve(600) == 400)
        #expect(meter.reserve(600) == 0)
    }

    @Test func payloadsGrowUpToTheCap() {
        #expect(TransferTestService.nextPayload(after: 250_000, cap: 8_000_000) == 500_000)
        #expect(TransferTestService.nextPayload(after: 6_000_000, cap: 8_000_000) == 8_000_000)
    }
}

// MARK: - Coordinator

struct SpeedTestCoordinatorTests {
    @Test func completedTestHasEveryRequiredFigureAndIsSaved() async throws {
        let history = InMemorySpeedTestRepository()
        let events = await runTest(history: history)

        guard case let .completed(result) = try #require(events.last) else {
            Issue.record("expected a completed test, got \(String(describing: events.last))")
            return
        }
        let measured = result.measurements
        #expect((measured.downloadMbps ?? 0) > 0)
        #expect((measured.uploadMbps ?? 0) > 0)
        #expect(measured.idleLatencyMs != nil)
        #expect(measured.jitterMs != nil)
        #expect(measured.packetLossPercentage == 0)
        #expect(result.connection == .wifi)
        #expect(result.serverHost == "test.example")
        #expect(result.serverRegion == "test-region")
        #expect(result.transferredBytes > 0)
        #expect(result.transferredBytes <= Int64(SpeedTestProfile.quick.dataBudgetBytes))
        #expect(await history.all() == [result])
    }

    @Test func packetLossCountsFailedLatencyProbes() async throws {
        let result = try await LatencyTestService.measure(
            client: FailingPingServer(),
            samples: 5
        )
        #expect(result.roundTrips.count == 4)
        #expect(result.packetLossPercentage == 20)
    }

    @Test func progressReportsPhasesInOrder() async {
        let phases = await runTest().compactMap { event -> SpeedTestPhase? in
            if case let .progress(progress) = event { progress.phase } else { nil }
        }
        var seen: [SpeedTestPhase] = []
        for phase in phases where seen.last != phase { seen.append(phase) }
        #expect(seen == [.preparing, .latency, .download, .upload, .completing])
    }

    @Test func unreachableServerFailsAndSavesNothing() async {
        let history = InMemorySpeedTestRepository()
        let events = await runTest(server: FakeServer(reachable: false), history: history)
        #expect(events.last == .failed(.serverUnreachable))
        #expect(await history.all().isEmpty)
    }

    @Test func noConnectionFailsBeforeAnyTransfer() async {
        let events = await runTest(path: FakePath(initial: ConnectionSnapshot(isConnected: false, interface: nil)))
        #expect(events.last == .failed(.noConnection))
    }

    /// A network switch mid-test never produces a successful result.
    @Test func networkChangeInvalidatesTheTest() async {
        let history = InMemorySpeedTestRepository()
        let path = FakePath(switchTo: ConnectionSnapshot(isConnected: true, interface: .cellular, isExpensive: true))
        let events = await runTest(server: FakeServer(transferDelay: .milliseconds(30)), path: path, history: history)
        #expect(events.last == .failed(.networkChanged))
        #expect(await history.all().isEmpty)
    }

    @Test func withoutAServerTheTestIsNotConfigured() async {
        let coordinator = SpeedTestCoordinator(clients: [], path: FakePath(), history: InMemorySpeedTestRepository())
        #expect(!coordinator.isConfigured)
        var events: [SpeedTestEvent] = []
        for await event in coordinator.run(profile: .quick, wifiSSID: nil) { events.append(event) }
        #expect(events == [.failed(.notConfigured)])
    }
}

private struct FailingPingServer: SpeedTestServerClient {
    var host = "test.example"
    let state = PingState()

    func fetchConfig() async throws -> SpeedTestServerConfig {
        SpeedTestServerConfig(serverRegion: "test-region")
    }

    func ping() async throws -> Double {
        try await Task.sleep(for: .milliseconds(1))
        if state.next() == 2 {
            throw URLError(.networkConnectionLost)
        }
        return 20
    }

    func download(bytes: Int, onBytes: @escaping @Sendable (Int) -> Void) async throws -> Int { bytes }

    func upload(bytes: Int, onBytesSent: @escaping @Sendable (Int) -> Void) async throws -> UploadConfirmation {
        onBytesSent(bytes)
        return UploadConfirmation(bytesReceived: bytes)
    }
}

private final class PingState: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

// MARK: - History

struct SpeedTestRepositoryTests {
    private func result(_ date: Date) -> InternetSpeedTestResult {
        InternetSpeedTestResult(
            timestamp: date, connection: .wifi, wifiSSID: nil, serverHost: "test.example", serverRegion: nil,
            profile: .quick, measurements: SpeedTestMeasurements(downloadMbps: 85.4, uploadMbps: 24.8),
            testDurationSeconds: 9, downloadedBytes: 10, uploadedBytes: 5
        )
    }

    @Test func fileStorePersistsNewestFirstAndDeletes() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "speedtest-\(UUID().uuidString)/history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let older = result(Date(timeIntervalSince1970: 1_000))
        let newer = result(Date(timeIntervalSince1970: 2_000))
        let store = FileSpeedTestRepository(fileURL: url)
        try await store.save(older)
        try await store.save(newer)

        // A fresh instance reads what was written to disk.
        let reopened = FileSpeedTestRepository(fileURL: url)
        #expect(await reopened.all().map(\.id) == [newer.id, older.id])

        try await reopened.delete(id: newer.id)
        #expect(await FileSpeedTestRepository(fileURL: url).all().map(\.id) == [older.id])
    }
}
