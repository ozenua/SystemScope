import Foundation

public struct StorageInformation: Sendable, Equatable {
    public let totalBytes: Int64
    public let availableBytes: Int64

    public init(totalBytes: Int64, availableBytes: Int64) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    public var usedBytes: Int64 {
        max(0, totalBytes - availableBytes)
    }

    public var utilization: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(usedBytes) / Double(totalBytes)
    }
}

public enum StorageInformationError: Error, LocalizedError, Sendable {
    case capacityUnavailable
    case invalidCapacity

    public var errorCode: String {
        switch self {
        case .capacityUnavailable: "storage.capacity_unavailable"
        case .invalidCapacity: "storage.capacity_invalid"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .capacityUnavailable: "Device storage capacity is unavailable."
        case .invalidCapacity: "Device storage capacity returned an invalid value."
        }
    }
}

public struct StorageInformationProvider: Sendable {
    public init() {}

    public func read() throws -> StorageInformation {
        let container = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let values = try container.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
        ])
        guard let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else {
            throw StorageInformationError.capacityUnavailable
        }

        let totalBytes = Int64(total)
        guard totalBytes > 0, available >= 0, available <= totalBytes else {
            throw StorageInformationError.invalidCapacity
        }
        return StorageInformation(totalBytes: totalBytes, availableBytes: available)
    }
}
