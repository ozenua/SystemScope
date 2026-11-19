import Darwin
import Foundation
import os

/// SystemScope's own process (scope: this app). Never a device-wide figure.
public struct AppResourceSnapshot: Sendable, Equatable {
    /// User + system CPU time used by this process since launch.
    public var cpuTimeSeconds: Double
    /// Physical memory footprint, as iOS counts it against the app's limit.
    public var footprintBytes: UInt64?
    /// How much more this process may allocate before iOS warns or ends it.
    public var availableBytes: UInt64?
    public var observedAt: Date

    public init(cpuTimeSeconds: Double, footprintBytes: UInt64?, availableBytes: UInt64?, observedAt: Date = .now) {
        self.cpuTimeSeconds = cpuTimeSeconds
        self.footprintBytes = footprintBytes
        self.availableBytes = availableBytes
        self.observedAt = observedAt
    }
}

/// Device-wide VM page categories (scope: this iPhone). These overlap with each other
/// and with free memory in iOS's accounting, so they are shown side by side and never
/// summed into a partition of physical RAM (PRD §7.1.1).
public struct DeviceMemoryBreakdown: Sendable, Equatable {
    public var wiredBytes: UInt64
    public var activeBytes: UInt64
    public var compressedBytes: UInt64
    /// active + wired + compressed: the "in use" figure shown elsewhere.
    public var inUseBytes: UInt64 { activeBytes + wiredBytes + compressedBytes }

    public init(wiredBytes: UInt64, activeBytes: UInt64, compressedBytes: UInt64) {
        self.wiredBytes = wiredBytes
        self.activeBytes = activeBytes
        self.compressedBytes = compressedBytes
    }
}

public protocol ResourceSampling: Sendable {
    func appResources() -> AppResourceSnapshot?
    func memoryBreakdown() -> DeviceMemoryBreakdown?
}

/// PROVISIONAL (PRD §7.2, D-03): app CPU comes from getrusage and app memory from
/// task_info TASK_VM_INFO; device memory from host_statistics64. None of these has
/// been through the physical-device and App Review feasibility gate yet.
public struct SystemResourceSampler: ResourceSampling {
    public init() {}

    public func appResources() -> AppResourceSnapshot? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        let seconds = { (time: timeval) in Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        let cpu = seconds(usage.ru_utime) + seconds(usage.ru_stime)

        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let available = os_proc_available_memory()
        return AppResourceSnapshot(
            cpuTimeSeconds: cpu,
            footprintBytes: result == KERN_SUCCESS ? UInt64(info.phys_footprint) : nil,
            availableBytes: available > 0 ? UInt64(available) : nil
        )
    }

    public func memoryBreakdown() -> DeviceMemoryBreakdown? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let page = UInt64(pageSize)
        let bytes = { (pages: UInt64) -> UInt64? in
            let (value, overflow) = pages.multipliedReportingOverflow(by: page)
            return overflow ? nil : value
        }
        guard let wired = bytes(UInt64(stats.wire_count)),
              let active = bytes(UInt64(stats.active_count)),
              let compressed = bytes(UInt64(stats.compressor_page_count)) else { return nil }
        return DeviceMemoryBreakdown(wiredBytes: wired, activeBytes: active, compressedBytes: compressed)
    }
}

/// Sample values matching the Figma Monitor screens. Debug, previews and tests only.
/// CPU time grows slowly so the live chart moves.
public struct SampleResourceSampler: ResourceSampling {
    private let started = ProcessInfo.processInfo.systemUptime

    public init() {}

    public func appResources() -> AppResourceSnapshot? {
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        // About half a core on average, gently varying; always increasing.
        let cpu = 0.54 * elapsed - 0.54 * cos(elapsed / 3)
        return AppResourceSnapshot(cpuTimeSeconds: 1.8 + cpu, footprintBytes: 312_000_000, availableBytes: 2_900_000_000)
    }

    public func memoryBreakdown() -> DeviceMemoryBreakdown? {
        DeviceMemoryBreakdown(wiredBytes: 1_900_000_000, activeBytes: 2_500_000_000, compressedBytes: 800_000_000)
    }
}
