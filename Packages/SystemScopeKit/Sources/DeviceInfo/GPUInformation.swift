import Core
import Foundation
import Metal

public enum GPUCapability: Sendable, Hashable {
    /// Highest supported Apple GPU family, e.g. 9 for Apple9.
    case appleFamily(Int)
    case metal3
    case unifiedMemory
    case float32Filtering
    case rayTracing
    case bcTextureCompression
}

/// GPU identity and capabilities as Metal reports them, plus the two utilisation slots.
public struct GPUInformation: Sendable, Equatable {
    public var name: String?
    public var architecture: String?
    public var metalAvailable: Bool
    public var hasUnifiedMemory: Bool?
    public var supportedCapabilities: [GPUCapability]
    /// Counter sets this GPU can sample (optional advanced capability; varies by model).
    public var counterSets: [String]
    public var recommendedMaxWorkingSetBytes: UInt64?
    /// Every GPU family the device reports, e.g. ["Apple9", "Common3", "Metal3"].
    public var families: [String]
    public var maxThreadsPerThreadgroup: Int?
    public var maxThreadgroupMemoryBytes: Int?
    public var supportsRasterOrderGroups: Bool?
    /// Always nil: iOS has no public source for device-wide GPU utilisation.
    public var deviceWideUtilisation: Double?
    /// Only set when SystemScope has timed one of its own real Metal command buffers.
    public var appGPUExecutionTimeMs: Double?
    public var observedAt: Date

    public init(
        name: String? = nil,
        architecture: String? = nil,
        metalAvailable: Bool = false,
        hasUnifiedMemory: Bool? = nil,
        supportedCapabilities: [GPUCapability] = [],
        counterSets: [String] = [],
        recommendedMaxWorkingSetBytes: UInt64? = nil,
        families: [String] = [],
        maxThreadsPerThreadgroup: Int? = nil,
        maxThreadgroupMemoryBytes: Int? = nil,
        supportsRasterOrderGroups: Bool? = nil,
        deviceWideUtilisation: Double? = nil,
        appGPUExecutionTimeMs: Double? = nil,
        observedAt: Date = .now
    ) {
        self.name = name
        self.architecture = architecture
        self.metalAvailable = metalAvailable
        self.hasUnifiedMemory = hasUnifiedMemory
        self.supportedCapabilities = supportedCapabilities
        self.counterSets = counterSets
        self.recommendedMaxWorkingSetBytes = recommendedMaxWorkingSetBytes
        self.families = families
        self.maxThreadsPerThreadgroup = maxThreadsPerThreadgroup
        self.maxThreadgroupMemoryBytes = maxThreadgroupMemoryBytes
        self.supportsRasterOrderGroups = supportsRasterOrderGroups
        self.deviceWideUtilisation = deviceWideUtilisation
        self.appGPUExecutionTimeMs = appGPUExecutionTimeMs
        self.observedAt = observedAt
    }
}

public protocol GPUInspecting: Sendable {
    func readGPU() async -> DeviceDataResult<GPUInformation>
}

/// Discovers the default Metal device and what it supports. Read-only: it submits no
/// GPU work, so it never produces a utilisation figure.
public struct GPUInformationProvider: GPUInspecting {
    private let performance: GPUPerformanceMonitor?

    public init(performance: GPUPerformanceMonitor? = nil) {
        self.performance = performance
    }

    public func readGPU() async -> DeviceDataResult<GPUInformation> {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return DeviceDataResult(
                value: GPUInformation(),
                scope: .deviceSpecification,
                source: "MTLCreateSystemDefaultDevice",
                status: .unsupported,
                limitations: ["Metal is not available on this device."]
            )
        }

        var capabilities: [GPUCapability] = []
        let appleFamilies: [(MTLGPUFamily, Int)] = [
            (.apple9, 9), (.apple8, 8), (.apple7, 7), (.apple6, 6), (.apple5, 5),
            (.apple4, 4), (.apple3, 3), (.apple2, 2), (.apple1, 1),
        ]
        if let highest = appleFamilies.first(where: { device.supportsFamily($0.0) }) {
            capabilities.append(.appleFamily(highest.1))
        }
        if device.supportsFamily(.metal3) { capabilities.append(.metal3) }
        if device.hasUnifiedMemory { capabilities.append(.unifiedMemory) }
        if device.supports32BitFloatFiltering { capabilities.append(.float32Filtering) }
        if device.supportsRaytracing { capabilities.append(.rayTracing) }
        if device.supportsBCTextureCompression { capabilities.append(.bcTextureCompression) }

        // Highest Apple family only, then the common and Metal families.
        var families = appleFamilies.first { device.supportsFamily($0.0) }.map { ["Apple\($0.1)"] } ?? []
        if device.supportsFamily(.common3) { families.append("Common3") }
        else if device.supportsFamily(.common2) { families.append("Common2") }
        else if device.supportsFamily(.common1) { families.append("Common1") }
        if device.supportsFamily(.metal3) { families.append("Metal3") }

        let information = GPUInformation(
            name: device.name.isEmpty ? nil : device.name,
            architecture: String(describing: device.architecture),
            metalAvailable: true,
            hasUnifiedMemory: device.hasUnifiedMemory,
            supportedCapabilities: capabilities,
            counterSets: (device.counterSets ?? []).map(\.name),
            recommendedMaxWorkingSetBytes: UInt64(device.recommendedMaxWorkingSetSize),
            families: families,
            maxThreadsPerThreadgroup: device.maxThreadsPerThreadgroup.width,
            maxThreadgroupMemoryBytes: device.maxThreadgroupMemoryLength > 0 ? device.maxThreadgroupMemoryLength : nil,
            supportsRasterOrderGroups: device.areRasterOrderGroupsSupported,
            appGPUExecutionTimeMs: await performance?.latestExecutionTimeMs
        )
        return DeviceDataResult(
            value: information,
            scope: .deviceSpecification,
            source: "MTLDevice",
            status: information.name == nil ? .partial : .available,
            limitations: ["Device-wide GPU utilisation is not exposed to apps."]
        )
    }
}

/// Times SystemScope's own Metal command buffers (scope: this app). It never creates
/// GPU work itself; attach it to a command buffer the app genuinely needs to run.
public actor GPUPerformanceMonitor {
    public private(set) var latestExecutionTimeMs: Double?

    public init() {}

    /// Records the GPU execution time of `commandBuffer` once it completes.
    /// Call before committing the buffer.
    public nonisolated func measure(_ commandBuffer: any MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { [weak self] buffer in
            guard let milliseconds = Self.executionTimeMs(start: buffer.gpuStartTime, end: buffer.gpuEndTime) else {
                return
            }
            Task { await self?.record(milliseconds) }
        }
    }

    private func record(_ milliseconds: Double) {
        latestExecutionTimeMs = milliseconds
    }

    /// nil for missing or inverted timestamps.
    public static func executionTimeMs(start: CFTimeInterval, end: CFTimeInterval) -> Double? {
        guard start > 0, end > start else { return nil }
        return (end - start) * 1000
    }
}

/// Sample values matching the Figma device. Debug, previews and tests only.
public struct SampleGPUInformationProvider: GPUInspecting {
    public init() {}

    public func readGPU() async -> DeviceDataResult<GPUInformation> {
        DeviceDataResult(
            value: GPUInformation(
                name: "Apple A17 Pro GPU",
                architecture: "Apple GPU architecture",
                metalAvailable: true,
                hasUnifiedMemory: true,
                supportedCapabilities: [.appleFamily(9), .metal3, .unifiedMemory, .float32Filtering, .rayTracing],
                recommendedMaxWorkingSetBytes: 5_726_623_061,
                families: ["Apple9", "Common3", "Metal3"],
                maxThreadsPerThreadgroup: 1_024,
                maxThreadgroupMemoryBytes: 32_768,
                supportsRasterOrderGroups: true
            ),
            scope: .deviceSpecification,
            source: "Sample data",
            status: .available
        )
    }
}
