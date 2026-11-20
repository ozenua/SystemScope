import DeviceInfo
import Foundation

/// Runs one complete test: prepare, idle latency, download, upload, then validate and
/// save. A test either completes with every required figure or fails; it never
/// reports partial results as a success.
public final class SpeedTestCoordinator: SpeedTestRunning, @unchecked Sendable {
    private let clients: [any SpeedTestServerClient]
    private let path: any NetworkPathProviding
    private let history: any SpeedTestHistoryStoring
    private let overallTimeout: Duration
    private let phaseDurationOverride: Duration?

    private let lock = NSLock()
    private var isRunning = false

    /// - Parameter clients: one per candidate test server. Empty means not configured.
    public init(
        clients: [any SpeedTestServerClient],
        path: any NetworkPathProviding,
        history: any SpeedTestHistoryStoring,
        overallTimeout: Duration = .seconds(60),
        phaseDuration: Duration? = nil
    ) {
        self.clients = clients
        self.path = path
        self.history = history
        self.overallTimeout = overallTimeout
        self.phaseDurationOverride = phaseDuration
    }

    public var isConfigured: Bool { !clients.isEmpty }

    public func run(profile: SpeedTestProfile, wifiSSID: String?) -> AsyncStream<SpeedTestEvent> {
        AsyncStream { continuation in
            guard isConfigured else {
                continuation.yield(.failed(.notConfigured))
                continuation.finish()
                return
            }
            // One test at a time.
            let claimed = lock.withLock {
                if isRunning { return false }
                isRunning = true
                return true
            }
            guard claimed else {
                continuation.yield(.failed(.alreadyRunning))
                continuation.finish()
                return
            }

            // Once the outcome is decided, late progress from a cancelled phase is dropped
            // so the final event is always the outcome.
            let gate = OutcomeGate()
            let task = Task {
                defer { lock.withLock { isRunning = false } }
                do {
                    let result = try await execute(profile: profile, wifiSSID: wifiSSID) { progress in
                        gate.whileOpen { continuation.yield(.progress(progress)) }
                    }
                    gate.close { continuation.yield(.completed(result)) }
                } catch is CancellationError {
                    // The user cancelled: partial results are discarded, nothing to report.
                    gate.close {}
                } catch {
                    let failure = Self.classify(error)
                    gate.close { continuation.yield(.failed(failure)) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func classify(_ error: Error) -> SpeedTestError {
        if let error = error as? SpeedTestError { return error }
        if let error = error as? URLError, error.code == .timedOut { return .timedOut }
        return .serverUnreachable
    }

    /// Races the measurement against a network-change watcher and an overall timeout.
    private func execute(
        profile: SpeedTestProfile,
        wifiSSID: String?,
        report: @escaping @Sendable (SpeedTestProgress) -> Void
    ) async throws -> InternetSpeedTestResult {
        report(SpeedTestProgress(phase: .preparing))
        guard let connection = await path.current(), connection.isConnected, let interface = connection.interface else {
            throw SpeedTestError.noConnection
        }

        return try await withThrowingTaskGroup(of: InternetSpeedTestResult?.self) { group in
            group.addTask { [self] in
                try await measure(profile: profile, interface: interface, wifiSSID: wifiSSID, report: report)
            }
            group.addTask { [path] in
                for await change in path.changes() where change.interface != interface || !change.isConnected {
                    throw SpeedTestError.networkChanged
                }
                return nil
            }
            group.addTask { [overallTimeout] in
                try await Task.sleep(for: overallTimeout)
                throw SpeedTestError.timedOut
            }
            defer { group.cancelAll() }
            while let finished = try await group.next() {
                if let finished { return finished }
            }
            throw SpeedTestError.invalidMeasurement
        }
    }

    private func measure(
        profile: SpeedTestProfile,
        interface: NetworkInterfaceKind,
        wifiSSID: String?,
        report: @escaping @Sendable (SpeedTestProgress) -> Void
    ) async throws -> InternetSpeedTestResult {
        let started = ProcessInfo.processInfo.systemUptime
        let phaseDuration = phaseDurationOverride ?? profile.phaseDuration

        // Preparing: pick the nearest server, then confirm it really answers.
        let client = try await SpeedTestServerSelector.select(from: clients)
        let config = try await client.fetchConfig()
        var progress = SpeedTestProgress(phase: .latency, serverHost: client.host, serverRegion: config.serverRegion)
        report(progress)

        // Idle latency and jitter, from the same ordered samples.
        let latency = try await LatencyTestService.measure(client: client, samples: profile.latencySamples)
        progress.measurements.idleLatencyMs = SpeedTestMath.median(latency.roundTrips)
        progress.measurements.jitterMs = SpeedTestMath.jitter(latency.roundTrips)
        progress.measurements.packetLossPercentage = latency.packetLossPercentage

        progress.phase = .download
        report(progress)
        let live = LiveReporter(base: progress, report: report)
        let download = try await TransferTestService.download(
            client: client, duration: phaseDuration, budgetBytes: profile.downloadBudgetBytes
        ) { mbps, bytes in
            live.send(mbps: mbps, bytes: bytes)
        }
        progress.measurements.downloadMbps = download.mbps
        progress.measurements.downloadLatencyMs = download.loadedLatencyMs
        progress.transferredBytes = download.bytes

        progress.phase = .upload
        progress.liveMbps = nil
        report(progress)
        let uploadLive = LiveReporter(base: progress, report: report)
        let upload = try await TransferTestService.upload(
            client: client, duration: phaseDuration, budgetBytes: profile.uploadBudgetBytes
        ) { mbps, bytes in
            uploadLive.send(mbps: mbps, bytes: download.bytes + bytes)
        }
        progress.measurements.uploadMbps = upload.mbps
        progress.measurements.uploadLatencyMs = upload.loadedLatencyMs
        progress.transferredBytes = download.bytes + upload.bytes

        progress.phase = .completing
        progress.liveMbps = nil
        report(progress)

        let result = InternetSpeedTestResult(
            connection: interface,
            wifiSSID: wifiSSID,
            serverHost: client.host,
            serverRegion: config.serverRegion,
            profile: profile,
            measurements: progress.measurements,
            testDurationSeconds: ProcessInfo.processInfo.systemUptime - started,
            downloadedBytes: download.bytes,
            uploadedBytes: upload.bytes
        )
        try Task.checkCancellation()
        // A result that cannot be saved is still a real measurement; show it anyway.
        try? await history.save(result)
        return result
    }
}

private final class OutcomeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isClosed = false

    func whileOpen(_ action: () -> Void) {
        lock.withLock { if !isClosed { action() } }
    }

    func close(_ action: () -> Void) {
        lock.withLock {
            guard !isClosed else { return }
            isClosed = true
            action()
        }
    }
}

/// Stamps live throughput onto the current progress snapshot.
private struct LiveReporter: Sendable {
    let base: SpeedTestProgress
    let report: @Sendable (SpeedTestProgress) -> Void

    func send(mbps: Double?, bytes: Int64) {
        var progress = base
        progress.liveMbps = mbps
        progress.transferredBytes = bytes
        report(progress)
    }
}
