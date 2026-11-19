import Core
import Foundation

public enum BatteryChargeState: String, Sendable {
    case unplugged
    case charging
    case full
}

public enum ThermalCondition: String, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

/// The device facts onboarding shows. Every field is optional: nil means the value
/// is unavailable and must be rendered as such, never as zero (ONB-08).
public struct DeviceSummary: Sendable, Equatable {
    public var modelName: String?
    public var modelIdentifier: String?
    public var osVersion: String?
    public var processor: String?
    public var physicalMemoryBytes: UInt64?
    /// Stays nil until the host_statistics64 feasibility gate (§7.2) passes.
    public var memoryInUseBytes: UInt64?
    public var storageAvailableBytes: Int64?
    public var storageTotalBytes: Int64?
    /// 0...1
    public var batteryLevel: Double?
    public var batteryState: BatteryChargeState?
    public var thermalState: ThermalCondition?
    /// GPU name as Metal reports it.
    public var gpuName: String?
    /// Logical processor cores.
    public var processorCoreCount: Int?
    /// Performance/efficiency split. Only from a verified source; nil otherwise.
    public var performanceCoreCount: Int?
    public var efficiencyCoreCount: Int?
    /// Cores currently enabled for use.
    public var activeCoreCount: Int?

    public init(
        modelName: String? = nil,
        modelIdentifier: String? = nil,
        osVersion: String? = nil,
        processor: String? = nil,
        physicalMemoryBytes: UInt64? = nil,
        memoryInUseBytes: UInt64? = nil,
        storageAvailableBytes: Int64? = nil,
        storageTotalBytes: Int64? = nil,
        batteryLevel: Double? = nil,
        batteryState: BatteryChargeState? = nil,
        thermalState: ThermalCondition? = nil,
        gpuName: String? = nil,
        processorCoreCount: Int? = nil,
        performanceCoreCount: Int? = nil,
        efficiencyCoreCount: Int? = nil,
        activeCoreCount: Int? = nil
    ) {
        self.modelName = modelName
        self.modelIdentifier = modelIdentifier
        self.osVersion = osVersion
        self.processor = processor
        self.physicalMemoryBytes = physicalMemoryBytes
        self.memoryInUseBytes = memoryInUseBytes
        self.storageAvailableBytes = storageAvailableBytes
        self.storageTotalBytes = storageTotalBytes
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.thermalState = thermalState
        self.gpuName = gpuName
        self.processorCoreCount = processorCoreCount
        self.performanceCoreCount = performanceCoreCount
        self.efficiencyCoreCount = efficiencyCoreCount
        self.activeCoreCount = activeCoreCount
    }

    /// Takes every field `other` has a value for; keeps the rest.
    public mutating func merge(_ other: DeviceSummary) {
        modelName = other.modelName ?? modelName
        modelIdentifier = other.modelIdentifier ?? modelIdentifier
        osVersion = other.osVersion ?? osVersion
        processor = other.processor ?? processor
        physicalMemoryBytes = other.physicalMemoryBytes ?? physicalMemoryBytes
        memoryInUseBytes = other.memoryInUseBytes ?? memoryInUseBytes
        storageAvailableBytes = other.storageAvailableBytes ?? storageAvailableBytes
        storageTotalBytes = other.storageTotalBytes ?? storageTotalBytes
        batteryLevel = other.batteryLevel ?? batteryLevel
        batteryState = other.batteryState ?? batteryState
        thermalState = other.thermalState ?? thermalState
        gpuName = other.gpuName ?? gpuName
        processorCoreCount = other.processorCoreCount ?? processorCoreCount
        performanceCoreCount = other.performanceCoreCount ?? performanceCoreCount
        efficiencyCoreCount = other.efficiencyCoreCount ?? efficiencyCoreCount
        activeCoreCount = other.activeCoreCount ?? activeCoreCount
    }
}

/// The categories of the first-run scan, in display order.
public enum ScanCategory: String, CaseIterable, Sendable {
    case deviceAndSystem
    case memoryAndStorage
    case batteryAndThermal
    case networkAndConnectivity
    case displayAndCameras
    case sensors
}

/// Reads one scan category. The result's value holds only that category's fields.
public protocol DeviceInspecting: Sendable {
    func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary>
}
