import Foundation

/// PRD §2.4 — every value carries one of these scopes.
public enum MeasurementScope: String, Sendable, Codable {
    case thisIPhone
    case thisApp
    case deviceSpecification
    case estimated
    case unavailable
}

/// PRD §6.8 — per-category outcome of a provider read.
public enum DataStatus: String, Sendable, Codable {
    case available
    case partial
    case permissionRequired
    case unsupported
    case notVerified
    case stale
    case failed
}

/// PRD §6.4 DEV-05.
public enum Confidence: String, Sendable, Codable {
    case verifiedOnDevice
    case verifiedCatalogue
    case derived
    case unknown
}

public enum PermissionState: String, Sendable, Codable {
    case notRequired
    case notDetermined
    case granted
    case denied
}

/// The common provider result contract from PRD §6.8.
public struct DeviceDataResult<Value: Sendable>: Sendable {
    public var value: Value?
    public var scope: MeasurementScope
    public var source: String
    public var observedAt: Date
    public var status: DataStatus
    public var confidence: Confidence
    public var permissionState: PermissionState
    public var limitations: [String]
    public var errorCode: String?

    public init(
        value: Value?,
        scope: MeasurementScope,
        source: String,
        observedAt: Date = .now,
        status: DataStatus,
        confidence: Confidence = .verifiedOnDevice,
        permissionState: PermissionState = .notRequired,
        limitations: [String] = [],
        errorCode: String? = nil
    ) {
        self.value = value
        self.scope = scope
        self.source = source
        self.observedAt = observedAt
        self.status = status
        self.confidence = confidence
        self.permissionState = permissionState
        self.limitations = limitations
        self.errorCode = errorCode
    }
}
