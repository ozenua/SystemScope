import Foundation

public enum SpeedTestMath {
    public static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Mean absolute difference between consecutive round trips. Needs two samples.
    public static func jitter(_ roundTripsMs: [Double]) -> Double? {
        guard roundTripsMs.count >= 2 else { return nil }
        let differences = zip(roundTripsMs.dropFirst(), roundTripsMs).map { abs($0 - $1) }
        return differences.reduce(0, +) / Double(differences.count)
    }

    /// Decimal megabits per second (1 Mbps = 1,000,000 bit/s). nil for an empty or
    /// zero-length transfer.
    public static func mbps(bytes: Int64, seconds: Double) -> Double? {
        guard bytes > 0, seconds > 0 else { return nil }
        return Double(bytes) * 8 / (seconds * 1_000_000)
    }
}

/// Thread-safe running byte count with timestamps, shared by concurrent transfers.
final class ByteMeter: @unchecked Sendable {
    private struct Sample {
        let time: TimeInterval
        let total: Int64
    }

    private let lock = NSLock()
    private var samples: [Sample] = []
    private var total: Int64 = 0
    private var reserved = 0
    private let budget: Int

    init(budget: Int) {
        self.budget = budget
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func add(_ bytes: Int) {
        guard bytes > 0 else { return }
        lock.withLock {
            total += Int64(bytes)
            samples.append(Sample(time: Self.now, total: total))
        }
    }

    var totalBytes: Int64 { lock.withLock { total } }

    /// Claims up to `bytes` of the remaining data budget; 0 when it is used up.
    func reserve(_ bytes: Int) -> Int {
        lock.withLock {
            let granted = max(0, min(bytes, budget - reserved))
            reserved += granted
            return granted
        }
    }

    /// Throughput over the most recent `window` seconds, for the live indicator.
    func recentMbps(window: TimeInterval = 1) -> Double? {
        lock.withLock {
            guard let last = samples.last else { return nil }
            let start = samples.first { $0.time >= last.time - window } ?? last
            return SpeedTestMath.mbps(bytes: last.total - start.total, seconds: last.time - start.time)
        }
    }

    /// Sustained throughput: the first `rampUp` fraction of the transfer window is left
    /// out so connection setup and slow start do not drag the figure down.
    func sustainedMbps(rampUp: Double = 0.2) -> Double? {
        lock.withLock {
            guard let first = samples.first, let last = samples.last, last.time > first.time else { return nil }
            let cutoff = first.time + (last.time - first.time) * rampUp
            let start = samples.last { $0.time <= cutoff } ?? first
            return SpeedTestMath.mbps(bytes: last.total - start.total, seconds: last.time - start.time)
        }
    }
}
