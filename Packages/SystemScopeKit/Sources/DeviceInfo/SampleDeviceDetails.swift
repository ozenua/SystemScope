import Core
import Foundation

/// Deterministic Device-tab values matching the Figma screens. For previews, tests and
/// the Debug-only `-UseSampleDevice` launch argument; never wire this into Release.
public struct SampleDeviceDetailsProvider: DeviceDetailsProviding {
    private let details: DeviceDetails?

    public init(details: DeviceDetails? = SampleDeviceDetailsProvider.details) {
        self.details = details
    }

    public func readDetails() async -> DeviceDetails? { details }

    public static let specifications = DeviceSpecifications(
        source: "Sample data",
        confidence: .verifiedCatalogue,
        chipFamily: "A-series",
        processNanometres: 3,
        releaseYear: 2023,
        transistorsBillions: 19,
        gpuCoreCount: 6,
        neuralEngineCoreCount: 16,
        instructionCapabilities: "NEON · PAC",
        memoryType: "LPDDR5",
        displayName: "Super Retina XDR",
        panelTechnology: "OLED",
        screenDiagonalInches: 6.1,
        pixelDensity: 460,
        peakBrightnessNits: 1_600,
        minimumRefreshHz: 1,
        alwaysOn: true,
        wifiStandard: "Wi-Fi 6E",
        cellular: "5G",
        bluetoothVersion: "5.3",
        nfc: "Reader mode",
        ultraWideband: "2nd-gen chip",
        gnss: "Dual-frequency",
        satellite: "Emergency SOS",
        port: "USB-C",
        fastCharging: "About 50% in 30 min",
        wirelessCharging: "MagSafe · Qi2 · up to 15 W"
    )

    public static let details = DeviceDetails(
        hardwareIdentifier: "iPhone16,1",
        catalogueEntry: DeviceCatalogue.Entry(
            modelName: "iPhone 15 Pro",
            processor: "Apple A17 Pro",
            specifications: specifications
        ),
        catalogueVersion: "sample",
        deviceFamily: "iPhone",
        osName: "iOS",
        osVersion: "18.2",
        osBuild: "22C152",
        architecture: "arm64",
        display: DisplayDetails(
            nativeWidthPixels: 1179,
            nativeHeightPixels: 2556,
            pointWidth: 393,
            pointHeight: 852,
            scale: 3,
            maximumFramesPerSecond: 120,
            potentialEDRHeadroom: 8,
            supportsWideColor: true,
            brightness: 0.64,
            orientation: .portrait,
            appearance: .light
        ),
        cameras: [
            CameraDetails(id: "wide", kind: .wide, position: .back, megapixels: 48, aperture: 1.78, relativeZoom: 1, maxFrameRate: 60, supportsHDRVideo: true, maxVideoZoomFactor: 15),
            CameraDetails(id: "ultra", kind: .ultraWide, position: .back, megapixels: 12, aperture: 2.2, relativeZoom: 0.5, maxFrameRate: 60, supportsHDRVideo: true, maxVideoZoomFactor: 15),
            CameraDetails(id: "tele", kind: .telephoto, position: .back, megapixels: 12, aperture: 2.8, relativeZoom: 3, maxFrameRate: 60, supportsHDRVideo: true, maxVideoZoomFactor: 15),
            CameraDetails(id: "front", kind: .trueDepth, position: .front, megapixels: 12, aperture: 1.9, relativeZoom: 1, maxFrameRate: 60, supportsHDRVideo: true, maxVideoZoomFactor: 5),
        ],
        sensors: [
            SensorStatus(kind: .accelerometer, availability: .available),
            SensorStatus(kind: .gyroscope, availability: .available),
            SensorStatus(kind: .magnetometer, availability: .available),
            SensorStatus(kind: .barometer, availability: .available),
            SensorStatus(kind: .proximity, availability: .available),
            SensorStatus(kind: .ambientLight, availability: .unknown),
            SensorStatus(kind: .location, availability: .permissionRequired),
            SensorStatus(kind: .faceID, availability: .supported),
            SensorStatus(kind: .lidar, availability: .supported),
        ],
        localeName: "English (United States)",
        regionName: "United States",
        timeZone: "America/New_York"
    )
}

/// Sensor tests that finish quickly with a fixed result.
public struct SampleSensorTester: SensorTesting {
    private let result: SensorTestResult
    private let delay: Duration

    public init(result: SensorTestResult = .passed(samples: 50), delay: Duration = .seconds(2)) {
        self.result = result
        self.delay = delay
    }

    public func test(_ sensor: SensorKind) async -> SensorTestResult {
        try? await Task.sleep(for: delay)
        return sensor.isTestable ? result : .unavailable
    }
}
