import Core
import Foundation

// Readings for the Device tab (DEV-01 to DEV-13). Every field is optional: nil means
// SystemScope could not read or look up the value, and screens must say so instead of
// showing a placeholder figure (DEV-05, DEV-06).

/// Static specifications for one model that no public API reports (screen size, chip
/// process, radio standards and so on). Comes from the versioned device catalogue
/// (DEV-15) with its own source and confidence, so screens can label it.
public struct DeviceSpecifications: Sendable, Equatable {
    public var source: String
    public var confidence: Confidence

    // Chip
    public var chipFamily: String?
    public var processNanometres: Int?
    public var releaseYear: Int?
    public var transistorsBillions: Int?
    public var gpuCoreCount: Int?
    public var neuralEngineCoreCount: Int?
    public var instructionCapabilities: String?
    // Memory
    public var memoryType: String?
    // Display
    public var displayName: String?
    public var panelTechnology: String?
    public var screenDiagonalInches: Double?
    public var pixelDensity: Int?
    public var peakBrightnessNits: Int?
    public var minimumRefreshHz: Int?
    public var alwaysOn: Bool?
    // Connectivity
    public var wifiStandard: String?
    public var cellular: String?
    public var bluetoothVersion: String?
    public var nfc: String?
    public var ultraWideband: String?
    public var gnss: String?
    public var satellite: String?
    public var port: String?
    // Power
    public var fastCharging: String?
    public var wirelessCharging: String?

    public init(
        source: String,
        confidence: Confidence,
        chipFamily: String? = nil,
        processNanometres: Int? = nil,
        releaseYear: Int? = nil,
        transistorsBillions: Int? = nil,
        gpuCoreCount: Int? = nil,
        neuralEngineCoreCount: Int? = nil,
        instructionCapabilities: String? = nil,
        memoryType: String? = nil,
        displayName: String? = nil,
        panelTechnology: String? = nil,
        screenDiagonalInches: Double? = nil,
        pixelDensity: Int? = nil,
        peakBrightnessNits: Int? = nil,
        minimumRefreshHz: Int? = nil,
        alwaysOn: Bool? = nil,
        wifiStandard: String? = nil,
        cellular: String? = nil,
        bluetoothVersion: String? = nil,
        nfc: String? = nil,
        ultraWideband: String? = nil,
        gnss: String? = nil,
        satellite: String? = nil,
        port: String? = nil,
        fastCharging: String? = nil,
        wirelessCharging: String? = nil
    ) {
        self.source = source
        self.confidence = confidence
        self.chipFamily = chipFamily
        self.processNanometres = processNanometres
        self.releaseYear = releaseYear
        self.transistorsBillions = transistorsBillions
        self.gpuCoreCount = gpuCoreCount
        self.neuralEngineCoreCount = neuralEngineCoreCount
        self.instructionCapabilities = instructionCapabilities
        self.memoryType = memoryType
        self.displayName = displayName
        self.panelTechnology = panelTechnology
        self.screenDiagonalInches = screenDiagonalInches
        self.pixelDensity = pixelDensity
        self.peakBrightnessNits = peakBrightnessNits
        self.minimumRefreshHz = minimumRefreshHz
        self.alwaysOn = alwaysOn
        self.wifiStandard = wifiStandard
        self.cellular = cellular
        self.bluetoothVersion = bluetoothVersion
        self.nfc = nfc
        self.ultraWideband = ultraWideband
        self.gnss = gnss
        self.satellite = satellite
        self.port = port
        self.fastCharging = fastCharging
        self.wirelessCharging = wirelessCharging
    }
}

public enum DisplayOrientation: String, Sendable {
    case portrait
    case landscape
}

public enum DisplayAppearance: String, Sendable {
    case light
    case dark
}

/// The screen as UIKit reports it.
public struct DisplayDetails: Sendable, Equatable {
    public var nativeWidthPixels: Int?
    public var nativeHeightPixels: Int?
    public var pointWidth: Double?
    public var pointHeight: Double?
    public var scale: Double?
    public var maximumFramesPerSecond: Int?
    /// Extended dynamic range headroom the screen can reach; above 1 means HDR.
    public var potentialEDRHeadroom: Double?
    public var supportsWideColor: Bool?
    /// 0...1
    public var brightness: Double?
    public var orientation: DisplayOrientation?
    public var appearance: DisplayAppearance?

    public init(
        nativeWidthPixels: Int? = nil,
        nativeHeightPixels: Int? = nil,
        pointWidth: Double? = nil,
        pointHeight: Double? = nil,
        scale: Double? = nil,
        maximumFramesPerSecond: Int? = nil,
        potentialEDRHeadroom: Double? = nil,
        supportsWideColor: Bool? = nil,
        brightness: Double? = nil,
        orientation: DisplayOrientation? = nil,
        appearance: DisplayAppearance? = nil
    ) {
        self.nativeWidthPixels = nativeWidthPixels
        self.nativeHeightPixels = nativeHeightPixels
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.scale = scale
        self.maximumFramesPerSecond = maximumFramesPerSecond
        self.potentialEDRHeadroom = potentialEDRHeadroom
        self.supportsWideColor = supportsWideColor
        self.brightness = brightness
        self.orientation = orientation
        self.appearance = appearance
    }

    public var isHDR: Bool? { potentialEDRHeadroom.map { $0 > 1 } }
    public var isProMotion: Bool? { maximumFramesPerSecond.map { $0 > 60 } }
}

public enum CameraPosition: String, Sendable {
    case back
    case front
}

public enum CameraKind: String, Sendable, CaseIterable {
    case ultraWide
    case wide
    case telephoto
    case trueDepth
}

/// One physical camera, enumerated without asking for camera permission (DEV-14).
public struct CameraDetails: Identifiable, Sendable, Equatable {
    public var id: String
    public var kind: CameraKind
    public var position: CameraPosition
    /// Largest still the camera can capture.
    public var megapixels: Int?
    public var aperture: Double?
    /// Zoom relative to the main camera (0.5, 1, 3…), from the virtual device's
    /// switch-over factors. Nil where iOS does not report it.
    public var relativeZoom: Double?
    public var maxFrameRate: Int?
    public var supportsHDRVideo: Bool?
    public var maxVideoZoomFactor: Double?

    public init(
        id: String,
        kind: CameraKind,
        position: CameraPosition,
        megapixels: Int? = nil,
        aperture: Double? = nil,
        relativeZoom: Double? = nil,
        maxFrameRate: Int? = nil,
        supportsHDRVideo: Bool? = nil,
        maxVideoZoomFactor: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.megapixels = megapixels
        self.aperture = aperture
        self.relativeZoom = relativeZoom
        self.maxFrameRate = maxFrameRate
        self.supportsHDRVideo = supportsHDRVideo
        self.maxVideoZoomFactor = maxVideoZoomFactor
    }
}

public enum SensorKind: String, Sendable, CaseIterable, Identifiable {
    case accelerometer
    case gyroscope
    case magnetometer
    case barometer
    case proximity
    case ambientLight
    case location
    case faceID
    case lidar

    public var id: String { rawValue }

    /// Whether SystemScope offers a user-started test for this sensor (DEV-12).
    public var isTestable: Bool {
        switch self {
        case .accelerometer, .gyroscope, .magnetometer, .barometer: true
        case .proximity, .ambientLight, .location, .faceID, .lidar: false
        }
    }
}

/// What SystemScope can say about a sensor without testing it (DEV-11). None of these
/// means faulty (DEV-13).
public enum SensorAvailability: String, Sendable {
    /// The API reports the sensor and apps can read it.
    case available
    /// Present, but iOS does not let apps read it directly.
    case supported
    /// Reading it needs a permission the user has not granted.
    case permissionRequired
    /// iOS reports no such sensor on this device.
    case notPresent
    /// No public API says either way.
    case unknown
}

public enum SensorTestResult: Sendable, Equatable {
    case passed(samples: Int)
    case noReadings
    case permissionDenied
    case unavailable
}

public struct SensorStatus: Sendable, Equatable, Identifiable {
    public var kind: SensorKind
    public var availability: SensorAvailability
    public var id: SensorKind { kind }

    public init(kind: SensorKind, availability: SensorAvailability) {
        self.kind = kind
        self.availability = availability
    }
}

/// Everything the Device tab shows beyond `DeviceSummary`.
public struct DeviceDetails: Sendable, Equatable {
    public var hardwareIdentifier: String?
    public var cpu: CPUInformation?
    /// Nil when the identifier is not in the catalogue (DEV-04).
    public var catalogueEntry: DeviceCatalogue.Entry?
    public var catalogueVersion: String
    public var deviceFamily: String?
    public var osName: String?
    public var osVersion: String?
    public var osBuild: String?
    public var architecture: String?
    public var display: DisplayDetails?
    public var cameras: [CameraDetails]
    public var sensors: [SensorStatus]
    public var localeName: String?
    public var regionName: String?
    public var timeZone: String?
    public var observedAt: Date

    public init(
        hardwareIdentifier: String? = nil,
        cpu: CPUInformation? = nil,
        catalogueEntry: DeviceCatalogue.Entry? = nil,
        catalogueVersion: String = DeviceCatalogue.bundled.version,
        deviceFamily: String? = nil,
        osName: String? = nil,
        osVersion: String? = nil,
        osBuild: String? = nil,
        architecture: String? = nil,
        display: DisplayDetails? = nil,
        cameras: [CameraDetails] = [],
        sensors: [SensorStatus] = [],
        localeName: String? = nil,
        regionName: String? = nil,
        timeZone: String? = nil,
        observedAt: Date = .now
    ) {
        self.hardwareIdentifier = hardwareIdentifier
        self.cpu = cpu
        self.catalogueEntry = catalogueEntry
        self.catalogueVersion = catalogueVersion
        self.deviceFamily = deviceFamily
        self.osName = osName
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.architecture = architecture
        self.display = display
        self.cameras = cameras
        self.sensors = sensors
        self.localeName = localeName
        self.regionName = regionName
        self.timeZone = timeZone
        self.observedAt = observedAt
    }

    public var specifications: DeviceSpecifications? { catalogueEntry?.specifications }

    /// "Build 22C152" out of "Version 18.2 (Build 22C152)".
    public static func parseBuild(_ versionString: String) -> String? {
        guard let range = versionString.range(of: "Build ") else { return nil }
        let rest = versionString[range.upperBound...]
        let build = rest.prefix { $0 != ")" && $0 != " " }
        return build.isEmpty ? nil : String(build)
    }
}

public protocol DeviceDetailsProviding: Sendable {
    /// Returns nil only when nothing at all could be read.
    func readDetails() async -> DeviceDetails?
}

/// Runs a short sensor test, only ever after the user asks for it (DEV-12).
public protocol SensorTesting: Sendable {
    func test(_ sensor: SensorKind) async -> SensorTestResult
}
