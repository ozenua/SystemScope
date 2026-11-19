import Core
import Foundation

/// Deterministic sample values matching the Figma screens. For previews, tests and
/// the Debug-only `-UseSampleDevice` launch argument; never wire this into Release.
public struct SampleDeviceInspector: DeviceInspecting {
    public init() {}

    public static let summary = DeviceSummary(
        modelName: "iPhone 15 Pro",
        modelIdentifier: "iPhone16,1",
        osVersion: "18.2",
        processor: "Apple A17 Pro",
        physicalMemoryBytes: 8 * 1_073_741_824,
        memoryInUseBytes: 5_583_457_485,
        storageAvailableBytes: 68_600_000_000,
        storageTotalBytes: 256_000_000_000,
        batteryLevel: 0.82,
        batteryState: .unplugged,
        thermalState: .nominal,
        processorCoreCount: 6,
        performanceCoreCount: 2,
        efficiencyCoreCount: 4,
        activeCoreCount: 6
    )

    public func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary> {
        let all = Self.summary
        let value: DeviceSummary = switch category {
        case .deviceAndSystem:
            DeviceSummary(
                modelName: all.modelName,
                modelIdentifier: all.modelIdentifier,
                osVersion: all.osVersion,
                processor: all.processor,
                processorCoreCount: all.processorCoreCount,
                performanceCoreCount: all.performanceCoreCount,
                efficiencyCoreCount: all.efficiencyCoreCount,
                activeCoreCount: all.activeCoreCount
            )
        case .memoryAndStorage:
            DeviceSummary(
                physicalMemoryBytes: all.physicalMemoryBytes,
                memoryInUseBytes: all.memoryInUseBytes,
                storageAvailableBytes: all.storageAvailableBytes,
                storageTotalBytes: all.storageTotalBytes
            )
        case .batteryAndThermal:
            DeviceSummary(
                batteryLevel: all.batteryLevel,
                batteryState: all.batteryState,
                thermalState: all.thermalState
            )
        case .networkAndConnectivity, .displayAndCameras, .sensors:
            DeviceSummary()
        }
        return DeviceDataResult(value: value, scope: .thisIPhone, source: "Sample data", status: .available)
    }
}
