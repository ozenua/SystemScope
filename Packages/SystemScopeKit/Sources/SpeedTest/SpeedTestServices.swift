import Foundation

/// Idle latency: HTTP round trips to the lightweight ping endpoint.
enum LatencyTestService {
    /// Returns the valid round trips in order. One warm-up request opens the
    /// connection and is thrown away; failed requests are discarded.
    static func measure(client: any SpeedTestServerClient, samples: Int) async throws -> [Double] {
        _ = try? await client.ping()
        var roundTrips: [Double] = []
        for _ in 0..<samples {
            try Task.checkCancellation()
            if let roundTrip = try? await client.ping(), roundTrip > 0 {
                roundTrips.append(roundTrip)
            }
        }
        guard roundTrips.count >= 3 else { throw SpeedTestError.serverUnreachable }
        return roundTrips
    }
}

/// Latency while a transfer is running. Runs until cancelled.
enum LoadedLatencyService {
    static func sample(client: any SpeedTestServerClient) async -> Double? {
        var roundTrips: [Double] = []
        while !Task.isCancelled {
            if let roundTrip = try? await client.ping(), roundTrip > 0 {
                roundTrips.append(roundTrip)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        // One sample is not a measurement of anything.
        return roundTrips.count >= 2 ? SpeedTestMath.median(roundTrips) : nil
    }
}

/// Picks the candidate server with the lowest median latency.
enum SpeedTestServerSelector {
    static func select(from clients: [any SpeedTestServerClient]) async throws -> any SpeedTestServerClient {
        var best: (client: any SpeedTestServerClient, latency: Double)?
        for client in clients {
            guard let roundTrips = try? await LatencyTestService.measure(client: client, samples: 3),
                  let median = SpeedTestMath.median(roundTrips) else { continue }
            if best == nil || median < best!.latency {
                best = (client, median)
            }
        }
        guard let best else { throw SpeedTestError.serverUnreachable }
        return best.client
    }
}

struct ThroughputResult: Sendable {
    var mbps: Double
    var bytes: Int64
    var loadedLatencyMs: Double?
}

/// Shared shape of the download and upload phases: several connections transfer
/// progressively larger payloads until the time limit or data budget is reached, while
/// latency is sampled alongside.
enum TransferTestService {
    static let firstPayloadBytes = 250_000

    /// Doubles the payload after each completed request (adaptive sizing).
    static func nextPayload(after bytes: Int, cap: Int) -> Int {
        min(bytes * 2, cap)
    }

    static func download(
        client: any SpeedTestServerClient,
        duration: Duration,
        budgetBytes: Int,
        onLive: @escaping @Sendable (Double?, Int64) -> Void
    ) async throws -> ThroughputResult {
        let meter = ByteMeter(budget: budgetBytes)
        let latency = try await run(connections: 4, duration: duration, client: client, meter: meter, onLive: onLive) {
            var size = firstPayloadBytes
            while !Task.isCancelled {
                let granted = meter.reserve(size)
                guard granted > 0 else { return }
                // Bytes are counted as they arrive, so an interrupted download still
                // contributes what it genuinely received.
                _ = try? await client.download(bytes: granted) { meter.add($0) }
                size = nextPayload(after: size, cap: 25_000_000)
            }
        }
        guard let mbps = meter.sustainedMbps() else {
            throw meter.totalBytes == 0 ? SpeedTestError.serverUnreachable : SpeedTestError.invalidMeasurement
        }
        return ThroughputResult(mbps: mbps, bytes: meter.totalBytes, loadedLatencyMs: latency)
    }

    static func upload(
        client: any SpeedTestServerClient,
        duration: Duration,
        budgetBytes: Int,
        onLive: @escaping @Sendable (Double?, Int64) -> Void
    ) async throws -> ThroughputResult {
        // `sent` drives the live display; only `confirmed` (bytes the server says it
        // received) counts towards the result.
        let sent = ByteMeter(budget: budgetBytes)
        let confirmed = ByteMeter(budget: budgetBytes)
        let started = ProcessInfo.processInfo.systemUptime
        let lastConfirmation = LastTime()
        let latency = try await run(connections: 3, duration: duration, client: client, meter: sent, onLive: onLive) {
            var size = firstPayloadBytes
            while !Task.isCancelled {
                let granted = sent.reserve(size)
                guard granted > 0 else { return }
                if let confirmation = try? await client.upload(bytes: granted, onBytesSent: { sent.add($0) }) {
                    confirmed.add(confirmation.bytesReceived)
                    lastConfirmation.mark()
                }
                size = nextPayload(after: size, cap: 8_000_000)
            }
        }
        guard let finished = lastConfirmation.value,
              let mbps = SpeedTestMath.mbps(bytes: confirmed.totalBytes, seconds: finished - started) else {
            throw sent.totalBytes == 0 ? SpeedTestError.serverUnreachable : SpeedTestError.invalidMeasurement
        }
        return ThroughputResult(mbps: mbps, bytes: confirmed.totalBytes, loadedLatencyMs: latency)
    }

    /// Runs `worker` on each connection until the deadline, reporting live throughput
    /// and sampling loaded latency. Returns the loaded latency.
    private static func run(
        connections: Int,
        duration: Duration,
        client: any SpeedTestServerClient,
        meter: ByteMeter,
        onLive: @escaping @Sendable (Double?, Int64) -> Void,
        worker: @escaping @Sendable () async -> Void
    ) async throws -> Double? {
        let latencyTask = Task { await LoadedLatencyService.sample(client: client) }
        let reporter = Task {
            while true {
                try? await Task.sleep(for: .milliseconds(200))
                // Checked after the sleep: a cancelled sleep returns at once, and a
                // report sent then would arrive after this phase had ended.
                if Task.isCancelled { return }
                onLive(meter.recentMbps(), meter.totalBytes)
            }
        }

        await withTaskGroup(of: Finished.self) { group in
            for _ in 0..<connections {
                group.addTask {
                    await worker()
                    return .worker
                }
            }
            group.addTask {
                try? await Task.sleep(for: duration)
                return .deadline
            }
            // Stop at whichever comes first: the deadline, or every worker out of budget.
            var running = connections
            for await finished in group {
                if finished == .deadline { break }
                running -= 1
                if running == 0 { break }
            }
            group.cancelAll()
        }

        reporter.cancel()
        await reporter.value
        latencyTask.cancel()
        let latency = await latencyTask.value
        try Task.checkCancellation()
        return latency
    }
}

private enum Finished: Sendable {
    case worker
    case deadline
}

private final class LastTime: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval?
    func mark() { lock.withLock { time = ProcessInfo.processInfo.systemUptime } }
    var value: TimeInterval? { lock.withLock { time } }
}
