import AVFoundation
import Core
import CoreMotion
import Foundation
import Network
import UIKit

/// Reads the public, permission-free device information the first-run scan needs
/// (ONB-03, ONB-06). Anything behind a §7.2 feasibility gate is reported as a
/// limitation rather than measured.
public struct SystemDeviceInspector: DeviceInspecting {
    private let catalogue: DeviceCatalogue

    public init(catalogue: DeviceCatalogue = .bundled) {
        self.catalogue = catalogue
    }

    public func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary> {
        switch category {
        case .deviceAndSystem: await readIdentity()
        case .memoryAndStorage: readMemoryAndStorage()
        case .batteryAndThermal: await readBatteryAndThermal()
        case .networkAndConnectivity: await readNetwork()
        case .displayAndCameras: await readDisplayCamerasAndGraphics()
        case .sensors: readSensors()
        }
    }

    // MARK: - Categories

    @MainActor
    private func readIdentity() -> DeviceDataResult<DeviceSummary> {
        let identifier = Self.hardwareIdentifier()
        let entry = identifier.flatMap(catalogue.entry(for:))
        let cpu = CPUInformationProvider().read()
        let summary = DeviceSummary(
            modelName: entry?.modelName,
            modelIdentifier: identifier,
            osVersion: UIDevice.current.systemVersion,
            processor: entry?.processor,
            processorCoreCount: cpu.physicalCores,
            performanceCoreCount: cpu.performanceCores,
            efficiencyCoreCount: cpu.efficiencyCores,
            activeCoreCount: cpu.logicalCores
        )
        let complete = entry?.processor != nil
        return DeviceDataResult(
            value: summary,
            scope: .deviceSpecification,
            source: "uname, UIDevice.systemVersion, device catalogue \(catalogue.version)",
            status: complete ? .available : .partial,
            confidence: entry == nil ? .unknown : .derived,
            limitations: complete ? [] : ["Model or processor is not in the device catalogue."]
        )
    }

    private func readMemoryAndStorage() -> DeviceDataResult<DeviceSummary> {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
        ])
        let summary = DeviceSummary(
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            memoryInUseBytes: Self.memoryInUseBytes(),
            storageAvailableBytes: values?.volumeAvailableCapacityForImportantUsage,
            storageTotalBytes: values?.volumeTotalCapacity.map(Int64.init)
        )
        let hasStorage = summary.storageAvailableBytes != nil && summary.storageTotalBytes != nil
        return DeviceDataResult(
            value: summary,
            scope: .thisIPhone,
            source: "ProcessInfo.physicalMemory, URLResourceValues volume capacity",
            status: hasStorage ? .available : .partial,
            limitations: ["Memory in use is a provisional host_statistics64 reading pending the feasibility gate."]
        )
    }

    @MainActor
    private func readBatteryAndThermal() -> DeviceDataResult<DeviceSummary> {
        let battery = BatteryMonitor.readCurrent()
        let thermal: ThermalCondition? = switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: nil
        }
        let summary = DeviceSummary(
            batteryLevel: battery.level.map { Double($0) / 100 },
            batteryState: battery.state,
            thermalState: thermal
        )
        let complete = summary.batteryLevel != nil && thermal != nil
        return DeviceDataResult(
            value: summary,
            scope: .thisIPhone,
            source: "UIDevice battery monitoring, ProcessInfo.thermalState",
            status: complete ? .available : .partial,
            limitations: complete ? [] : ["Battery level is not reported on this device."]
        )
    }

    private func readNetwork() async -> DeviceDataResult<DeviceSummary> {
        let reachable = await NetworkPathMonitor().current()?.isConnected
        return DeviceDataResult(
            value: DeviceSummary(),
            scope: .thisIPhone,
            source: "NWPathMonitor",
            status: reachable == nil ? .failed : .partial,
            limitations: ["Interface byte counters are not read until the getifaddrs gate passes."],
            errorCode: reachable == nil ? "network.path.timeout" : nil
        )
    }

    /// Display, cameras and GPU are read independently: one missing does not fail the others.
    private func readDisplayCamerasAndGraphics() async -> DeviceDataResult<DeviceSummary> {
        var result = await readDisplayAndCameras()
        let gpu = await GPUInformationProvider().readGPU()
        result.value?.gpuName = gpu.value?.name
        result.source += ", MTLDevice"
        if gpu.status != .available {
            if result.status == .available { result.status = .partial }
            result.limitations.append("GPU information is unavailable.")
        }
        return result
    }

    @MainActor
    private func readDisplayAndCameras() -> DeviceDataResult<DeviceSummary> {
        let hasScreen = UIApplication.shared.connectedScenes.contains { $0 is UIWindowScene }
        // Enumeration only: no camera permission is requested (DEV-14).
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        let complete = hasScreen && !cameras.isEmpty
        return DeviceDataResult(
            value: DeviceSummary(),
            scope: .deviceSpecification,
            source: "UIWindowScene.screen, AVCaptureDevice.DiscoverySession",
            status: complete ? .available : .partial,
            limitations: complete ? [] : ["No cameras were enumerated on this device."]
        )
    }

    private func readSensors() -> DeviceDataResult<DeviceSummary> {
        let motion = CMMotionManager()
        let anyAvailable = motion.isAccelerometerAvailable
            || motion.isGyroAvailable
            || motion.isMagnetometerAvailable
            || CMAltimeter.isRelativeAltitudeAvailable()
        return DeviceDataResult(
            value: DeviceSummary(),
            scope: .deviceSpecification,
            source: "CoreMotion availability checks",
            status: anyAvailable ? .available : .unsupported,
            limitations: ["API capability only. No sensor test is run during a passive scan."]
        )
    }

    // MARK: - Helpers

    static func hardwareIdentifier() -> String? {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        guard uname(&info) == 0 else { return nil }
        let identifier = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return identifier.isEmpty ? nil : identifier
    }

    /// Device-wide memory in use from Mach host VM statistics.
    ///
    /// PROVISIONAL (PRD §7.1.1, §7.2): counts active + wired + compressor pages. This
    /// accounting model has not been through the physical-device feasibility gate.
    static func memoryInUseBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let (bytes, overflow) = pages.multipliedReportingOverflow(by: UInt64(pageSize))
        return overflow ? nil : bytes
    }
}
