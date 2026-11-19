import DeviceInfo
import Foundation

/// How much data a test may use. Budgets are caps, not predictions: the actual
/// bytes transferred are tracked and reported with every result.
public enum SpeedTestProfile: String, Codable, CaseIterable, Sendable {
    case quick
    case standard

    /// Total cap across download and upload.
    public var dataBudgetBytes: Int {
        switch self {
        case .quick: 15_000_000
        case .standard: 45_000_000
        }
    }

    /// Longest time spent on each of the download and upload phases.
    var phaseDuration: Duration {
        switch self {
        case .quick: .seconds(4)
        case .standard: .seconds(8)
        }
    }

    var latencySamples: Int {
        switch self {
        case .quick: 10
        case .standard: 15
        }
    }

    var downloadBudgetBytes: Int { dataBudgetBytes * 2 / 3 }
    var uploadBudgetBytes: Int { dataBudgetBytes - downloadBudgetBytes }
}

public enum SpeedTestPhase: String, Sendable, CaseIterable {
    case preparing
    case latency
    case download
    case upload
    case completing
}

/// Every figure is measured against the test server, or nil. Nothing is estimated.
public struct SpeedTestMeasurements: Codable, Sendable, Equatable {
    public var downloadMbps: Double?
    public var uploadMbps: Double?
    /// Median HTTP round trip with no transfer running. Not an ICMP ping.
    public var idleLatencyMs: Double?
    public var downloadLatencyMs: Double?
    public var uploadLatencyMs: Double?
    public var jitterMs: Double?
    /// Always nil: packet loss needs dedicated UDP infrastructure that does not exist yet.
    public var packetLossPercentage: Double?

    public init(
        downloadMbps: Double? = nil,
        uploadMbps: Double? = nil,
        idleLatencyMs: Double? = nil,
        downloadLatencyMs: Double? = nil,
        uploadLatencyMs: Double? = nil,
        jitterMs: Double? = nil,
        packetLossPercentage: Double? = nil
    ) {
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.idleLatencyMs = idleLatencyMs
        self.downloadLatencyMs = downloadLatencyMs
        self.uploadLatencyMs = uploadLatencyMs
        self.jitterMs = jitterMs
        self.packetLossPercentage = packetLossPercentage
    }
}

public struct SpeedTestProgress: Sendable, Equatable {
    public var phase: SpeedTestPhase
    /// Live throughput for the running transfer phase.
    public var liveMbps: Double?
    public var measurements: SpeedTestMeasurements
    public var serverHost: String?
    public var serverRegion: String?
    public var transferredBytes: Int64

    public init(
        phase: SpeedTestPhase,
        liveMbps: Double? = nil,
        measurements: SpeedTestMeasurements = .init(),
        serverHost: String? = nil,
        serverRegion: String? = nil,
        transferredBytes: Int64 = 0
    ) {
        self.phase = phase
        self.liveMbps = liveMbps
        self.measurements = measurements
        self.serverHost = serverHost
        self.serverRegion = serverRegion
        self.transferredBytes = transferredBytes
    }
}

/// A completed test. Only fully successful tests are ever stored.
public struct InternetSpeedTestResult: Codable, Identifiable, Sendable, Equatable {
    /// Bumped whenever the measurement method changes, so old and new results are
    /// never silently compared (PRD §8.3).
    public static let currentMethodVersion = 1

    public let id: UUID
    public let timestamp: Date
    public let connection: NetworkInterfaceKind
    public let wifiSSID: String?
    public let serverHost: String
    public let serverRegion: String?
    public let profile: SpeedTestProfile
    public let measurements: SpeedTestMeasurements
    public let testDurationSeconds: Double
    public let downloadedBytes: Int64
    public let uploadedBytes: Int64
    public let methodVersion: Int

    public var transferredBytes: Int64 { downloadedBytes + uploadedBytes }

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        connection: NetworkInterfaceKind,
        wifiSSID: String?,
        serverHost: String,
        serverRegion: String?,
        profile: SpeedTestProfile,
        measurements: SpeedTestMeasurements,
        testDurationSeconds: Double,
        downloadedBytes: Int64,
        uploadedBytes: Int64,
        methodVersion: Int = InternetSpeedTestResult.currentMethodVersion
    ) {
        self.id = id
        self.timestamp = timestamp
        self.connection = connection
        self.wifiSSID = wifiSSID
        self.serverHost = serverHost
        self.serverRegion = serverRegion
        self.profile = profile
        self.measurements = measurements
        self.testDurationSeconds = testDurationSeconds
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.methodVersion = methodVersion
    }
}

public enum SpeedTestError: Error, Sendable, Equatable {
    /// No test server is set up for this build.
    case notConfigured
    case noConnection
    case serverUnreachable
    /// The network path changed mid-test, which invalidates the measurements.
    case networkChanged
    case timedOut
    /// Too few valid samples to report a figure.
    case invalidMeasurement
    case alreadyRunning
}

public enum SpeedTestEvent: Sendable, Equatable {
    case progress(SpeedTestProgress)
    case completed(InternetSpeedTestResult)
    case failed(SpeedTestError)
}

/// Runs one user-initiated test. Ending the stream's consumer cancels the test.
public protocol SpeedTestRunning: Sendable {
    var isConfigured: Bool { get }
    func run(profile: SpeedTestProfile, wifiSSID: String?) -> AsyncStream<SpeedTestEvent>
}

/// What ships until a test server exists: every attempt reports `notConfigured`.
public struct UnconfiguredSpeedTest: SpeedTestRunning {
    public init() {}
    public var isConfigured: Bool { false }

    public func run(profile: SpeedTestProfile, wifiSSID: String?) -> AsyncStream<SpeedTestEvent> {
        AsyncStream { continuation in
            continuation.yield(.failed(.notConfigured))
            continuation.finish()
        }
    }
}
