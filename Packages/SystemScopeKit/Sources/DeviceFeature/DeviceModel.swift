import Core
import DeviceInfo
import Foundation
import Observation
import UIKit

/// The ten Device detail screens (DEV-02 to DEV-11 in Figma order).
public enum DeviceRoute: String, Hashable, Sendable, CaseIterable {
    case general
    case processor
    case memory
    case display
    case camera
    case connectivity
    case sensors
    case battery
    case operatingSystem
    case graphics
}

/// Monitor screens a Device page links to. AppShell maps these to Monitor routes, so
/// the two features never import each other.
public enum DeviceMonitorLink: Sendable {
    case cpu
    case memory
    case gpu
    case battery
    case network
}

/// DEV-13: a single specification with its source, shown in a sheet.
public struct SpecSheetContent: Identifiable, Sendable, Equatable {
    public struct Row: Sendable, Equatable {
        public var label: String
        public var value: String
    }

    public var id: String { title }
    public var title: String
    public var value: String
    public var detail: String
    public var rows: [Row]
    public var source: String
}

public enum DeviceSheet: Identifiable, Equatable {
    case actions
    case rename
    case spec(SpecSheetContent)
    case sensor(SensorKind)

    public var id: String {
        switch self {
        case .actions: "actions"
        case .rename: "rename"
        case .spec(let content): "spec-\(content.id)"
        case .sensor(let kind): "sensor-\(kind.rawValue)"
        }
    }
}

public enum SensorTestState: Equatable, Sendable {
    case running
    case finished(SensorTestResult)
}

/// How sure SystemScope is about the model (DEV-01, DEV-04).
public enum IdentificationStatus: Sendable {
    /// Hardware identifier found in the catalogue, with a chip.
    case identified
    /// Found, but some catalogue fields are missing.
    case partial
    /// Identifier not in the catalogue.
    case unknown
}

@MainActor
@Observable
public final class DeviceModel {
    public var path: [DeviceRoute] = []
    public var sheet: DeviceSheet?
    public private(set) var hasLoaded = false
    public private(set) var isRefreshing = false
    /// Set when the latest refresh failed; earlier readings stay on screen (DEV-10).
    public private(set) var refreshFailed = false
    public private(set) var lastUpdated: Date?
    public private(set) var details: DeviceDetails?
    public private(set) var gpu: GPUInformation?
    public private(set) var network: NetworkSnapshot?
    public private(set) var toast: String?
    public private(set) var sensorTests: [SensorKind: SensorTestState] = [:]

    // Rename (DEV-12 in Figma, DEV-07 in the PRD).
    public var renameDraft = "" {
        didSet {
            if renameDraft.count > AppPreferences.deviceDisplayNameLimit {
                renameDraft = String(renameDraft.prefix(AppPreferences.deviceDisplayNameLimit))
            }
            if renameError, !trimmedDraft.isEmpty { renameError = false }
        }
    }
    public private(set) var renameError = false

    private var scannedSummary = DeviceSummary()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let inspector: any DeviceInspecting
    @ObservationIgnored private let detailsProvider: any DeviceDetailsProviding
    @ObservationIgnored private let networkInspector: any NetworkInspecting
    @ObservationIgnored private let gpuInspector: any GPUInspecting
    @ObservationIgnored private let battery: any BatteryMonitoring
    @ObservationIgnored private let sensorTester: any SensorTesting
    @ObservationIgnored private let copyToPasteboard: @MainActor (String) -> Void

    public init(
        preferences: AppPreferences,
        inspector: any DeviceInspecting,
        details: any DeviceDetailsProviding,
        networkInspector: any NetworkInspecting,
        gpuInspector: any GPUInspecting,
        battery: any BatteryMonitoring,
        sensorTester: any SensorTesting,
        copy: @escaping @MainActor (String) -> Void = { UIPasteboard.general.string = $0 }
    ) {
        self.preferences = preferences
        self.inspector = inspector
        self.detailsProvider = details
        self.networkInspector = networkInspector
        self.gpuInspector = gpuInspector
        self.battery = battery
        self.sensorTester = sensorTester
        self.copyToPasteboard = copy
    }

    // MARK: - Readings

    public var displayName: String { preferences.deviceDisplayName }
    public var firstRegistered: Date { preferences.firstRegistered }

    /// Scanned readings with the live battery value laid over them.
    public var summary: DeviceSummary {
        var summary = scannedSummary
        let reading = battery.snapshot
        summary.batteryLevel = reading.level.map { Double($0) / 100 }
        summary.batteryState = reading.state
        return summary
    }

    public var batterySnapshot: BatterySnapshot { battery.snapshot }
    public var specifications: DeviceSpecifications? { details?.specifications }

    public var identification: IdentificationStatus {
        guard let entry = details?.catalogueEntry ?? catalogueEntryFromSummary else { return .unknown }
        return entry.processor == nil ? .partial : .identified
    }

    private var catalogueEntryFromSummary: DeviceCatalogue.Entry? {
        scannedSummary.modelName.map { DeviceCatalogue.Entry(modelName: $0, processor: scannedSummary.processor) }
    }

    /// Reads everything again. DEV-10: when the identity read fails, the previous
    /// values and their timestamp stay and the error banner explains it.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        battery.start()
        var fresh = scannedSummary
        var identityRead = false
        for category in [ScanCategory.deviceAndSystem, .memoryAndStorage, .batteryAndThermal] {
            if let value = await inspector.readSnapshot(of: category).value {
                fresh.merge(value)
                if category == .deviceAndSystem { identityRead = true }
            }
        }
        let newDetails = await detailsProvider.readDetails()
        guard identityRead || newDetails != nil else {
            refreshFailed = true
            hasLoaded = hasLoaded || lastUpdated != nil
            return
        }
        scannedSummary = fresh
        if let newDetails { details = newDetails }
        network = await networkInspector.readNetwork()
        gpu = await gpuInspector.readGPU().value
        refreshFailed = false
        lastUpdated = .now
        hasLoaded = true
    }

    /// First load only; later visits keep what is on screen.
    public func loadIfNeeded() async {
        guard !hasLoaded, lastUpdated == nil else { return }
        await refresh()
    }

    // MARK: - Navigation

    public func open(_ route: DeviceRoute) {
        sheet = nil
        path.append(route)
    }

    public func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: - Rename

    private var trimmedDraft: String { renameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func beginRename() {
        renameDraft = displayName
        renameError = false
        sheet = .rename
    }

    /// Saves the local display name only (PRD §2.3). Returns false when it is empty.
    @discardableResult
    public func saveRename() -> Bool {
        guard preferences.setDeviceDisplayName(renameDraft) else {
            renameError = true
            return false
        }
        sheet = nil
        showToast(String(localized: "Device name updated", bundle: .module))
        return true
    }

    // MARK: - Copy (DEV-08)

    public func copy(_ text: String, confirmation: String? = nil) {
        copyToPasteboard(text)
        showToast(confirmation ?? String(localized: "Copied to clipboard", bundle: .module))
    }

    /// Plain-text specification report, for exports elsewhere in the app.
    public var reportText: String { DeviceReport.text(for: self) }

    public func copyAllSpecifications() {
        sheet = nil
        copy(DeviceReport.text(for: self), confirmation: String(localized: "Specifications copied", bundle: .module))
    }

    public func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Sensors (DEV-11 to DEV-13)

    public func status(of sensor: SensorKind) -> SensorAvailability {
        details?.sensors.first { $0.kind == sensor }?.availability ?? .unknown
    }

    /// Only ever called from the Run Test button (DEV-12).
    public func runTest(_ sensor: SensorKind) async {
        guard sensor.isTestable, sensorTests[sensor] != .running else { return }
        sensorTests[sensor] = .running
        let result = await sensorTester.test(sensor)
        sensorTests[sensor] = .finished(result)
    }
}
