import AVFoundation
import CoreLocation
import CoreMotion
import Foundation
import LocalAuthentication
import UIKit

/// Reads the Device tab's details from public APIs. Nothing here prompts for a
/// permission: cameras are enumerated without access (DEV-14), Face ID is checked
/// without evaluating a policy, and location and motion permission are only read.
public struct SystemDeviceDetailsProvider: DeviceDetailsProviding {
    private let catalogue: DeviceCatalogue

    public init(catalogue: DeviceCatalogue = .bundled) {
        self.catalogue = catalogue
    }

    public func readDetails() async -> DeviceDetails? {
        await read()
    }

    @MainActor
    private func read() -> DeviceDetails {
        let identifier = SystemDeviceInspector.hardwareIdentifier()
        let cpu = CPUInformationProvider().read()
        let device = UIDevice.current
        let locale = Locale.current
        return DeviceDetails(
            hardwareIdentifier: identifier,
            cpu: cpu,
            catalogueEntry: identifier.flatMap(catalogue.entry(for:)),
            catalogueVersion: catalogue.version,
            deviceFamily: device.model,
            osName: "iOS",
            osVersion: device.systemVersion,
            osBuild: DeviceDetails.parseBuild(ProcessInfo.processInfo.operatingSystemVersionString),
            architecture: cpu.architecture,
            display: Self.readDisplay(),
            cameras: Self.readCameras(),
            sensors: Self.readSensors(),
            localeName: locale.localizedString(forIdentifier: locale.identifier),
            regionName: locale.region.flatMap { locale.localizedString(forRegionCode: $0.identifier) },
            timeZone: TimeZone.current.identifier,
            observedAt: .now
        )
    }

    /// The instruction set this build runs as.
    static var architecture: String? {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        nil
        #endif
    }

    // MARK: - Display

    @MainActor
    static func readDisplay() -> DisplayDetails? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return nil
        }
        let screen = scene.screen
        let native = screen.nativeBounds.size
        let points = screen.bounds.size
        return DisplayDetails(
            nativeWidthPixels: Int(min(native.width, native.height)),
            nativeHeightPixels: Int(max(native.width, native.height)),
            pointWidth: Double(min(points.width, points.height)),
            pointHeight: Double(max(points.width, points.height)),
            scale: Double(screen.scale),
            maximumFramesPerSecond: screen.maximumFramesPerSecond,
            potentialEDRHeadroom: Double(screen.potentialEDRHeadroom),
            supportsWideColor: screen.traitCollection.displayGamut == .P3,
            brightness: Double(screen.brightness),
            orientation: scene.interfaceOrientation.isLandscape ? .landscape : .portrait,
            appearance: screen.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        )
    }

    // MARK: - Cameras

    static func readCameras() -> [CameraDetails] {
        let physical = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        let zooms = relativeZooms()
        return physical.compactMap { device -> CameraDetails? in
            let kind: CameraKind
            switch device.deviceType {
            case .builtInUltraWideCamera: kind = .ultraWide
            case .builtInTelephotoCamera: kind = .telephoto
            case .builtInTrueDepthCamera: kind = .trueDepth
            case .builtInWideAngleCamera: kind = device.position == .front ? .trueDepth : .wide
            default: return nil
            }
            let formats = device.formats
            let largestPhoto = formats
                .flatMap(\.supportedMaxPhotoDimensions)
                .map { Int($0.width) * Int($0.height) }
                .max()
            let maxRate = formats
                .flatMap(\.videoSupportedFrameRateRanges)
                .map(\.maxFrameRate)
                .max()
            return CameraDetails(
                id: device.uniqueID,
                kind: kind,
                position: device.position == .front ? .front : .back,
                megapixels: largestPhoto.map { Int((Double($0) / 1_000_000).rounded()) },
                aperture: device.lensAperture > 0 ? Double(device.lensAperture) : nil,
                relativeZoom: device.position == .front ? 1 : zooms[kind],
                maxFrameRate: maxRate.map { Int($0.rounded()) },
                supportsHDRVideo: formats.contains(where: \.isVideoHDRSupported),
                maxVideoZoomFactor: Double(device.maxAvailableVideoZoomFactor)
            )
        }
        // A front wide-angle and a TrueDepth camera are the same lens; keep one.
        .reduce(into: [CameraDetails]()) { result, camera in
            if camera.position == .front, result.contains(where: { $0.position == .front }) { return }
            result.append(camera)
        }
    }

    /// Zoom of each back camera relative to the main one, from the virtual device's
    /// switch-over factors (which are relative to its widest lens).
    static func relativeZooms() -> [CameraKind: Double] {
        let virtual = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera],
            mediaType: .video,
            position: .back
        ).devices
        var zooms: [CameraKind: Double] = [.wide: 1]
        for device in virtual {
            let factors = device.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue }
            switch device.deviceType {
            case .builtInTripleCamera where factors.count == 2:
                zooms[.ultraWide] = 1 / factors[0]
                zooms[.telephoto] = factors[1] / factors[0]
            case .builtInDualWideCamera where factors.count == 1:
                zooms[.ultraWide] = zooms[.ultraWide] ?? 1 / factors[0]
            case .builtInDualCamera where factors.count == 1:
                zooms[.telephoto] = zooms[.telephoto] ?? factors[0]
            default:
                break
            }
        }
        return zooms
    }

    // MARK: - Sensors

    @MainActor
    static func readSensors() -> [SensorStatus] {
        let motion = CMMotionManager()
        func present(_ available: Bool) -> SensorAvailability { available ? .available : .notPresent }

        let barometer: SensorAvailability = if !CMAltimeter.isRelativeAltitudeAvailable() {
            .notPresent
        } else if [.denied, .restricted].contains(CMAltimeter.authorizationStatus()) {
            .permissionRequired
        } else {
            .available
        }

        // Turning proximity monitoring on only sticks where the sensor exists.
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        let hasProximity = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = false

        let location: SensorAvailability = switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: .available
        default: .permissionRequired
        }

        // Reads the biometry type without evaluating a policy, so no prompt appears.
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let faceID: SensorAvailability = context.biometryType == .faceID ? .supported : .notPresent

        let hasLiDAR = !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInLiDARDepthCamera],
            mediaType: .video,
            position: .back
        ).devices.isEmpty

        return [
            SensorStatus(kind: .accelerometer, availability: present(motion.isAccelerometerAvailable)),
            SensorStatus(kind: .gyroscope, availability: present(motion.isGyroAvailable)),
            SensorStatus(kind: .magnetometer, availability: present(motion.isMagnetometerAvailable)),
            SensorStatus(kind: .barometer, availability: barometer),
            SensorStatus(kind: .proximity, availability: present(hasProximity)),
            // No public API reports the ambient light sensor.
            SensorStatus(kind: .ambientLight, availability: .unknown),
            SensorStatus(kind: .location, availability: location),
            SensorStatus(kind: .faceID, availability: faceID),
            SensorStatus(kind: .lidar, availability: hasLiDAR ? .supported : .notPresent),
        ]
    }
}

// MARK: - Sensor tests

/// Short sensor tests through Core Motion, started only from an explicit tap (DEV-12).
/// The barometer test is what triggers the Motion & Fitness permission prompt, in
/// context. A test that receives readings passes; one that gets none reports that,
/// never "faulty" (DEV-13).
public struct SystemSensorTester: SensorTesting {
    public static let duration: Duration = .seconds(5)

    public init() {}

    public func test(_ sensor: SensorKind) async -> SensorTestResult {
        await run(sensor)
    }

    @MainActor
    private func run(_ sensor: SensorKind) async -> SensorTestResult {
        let motion = CMMotionManager()
        motion.accelerometerUpdateInterval = 0.1
        motion.gyroUpdateInterval = 0.1
        motion.magnetometerUpdateInterval = 0.1
        let counter = SampleCounter()
        switch sensor {
        case .accelerometer:
            guard motion.isAccelerometerAvailable else { return .unavailable }
            motion.startAccelerometerUpdates(to: .main) { data, _ in if data != nil { counter.increment() } }
            try? await Task.sleep(for: Self.duration)
            motion.stopAccelerometerUpdates()
        case .gyroscope:
            guard motion.isGyroAvailable else { return .unavailable }
            motion.startGyroUpdates(to: .main) { data, _ in if data != nil { counter.increment() } }
            try? await Task.sleep(for: Self.duration)
            motion.stopGyroUpdates()
        case .magnetometer:
            guard motion.isMagnetometerAvailable else { return .unavailable }
            motion.startMagnetometerUpdates(to: .main) { data, _ in if data != nil { counter.increment() } }
            try? await Task.sleep(for: Self.duration)
            motion.stopMagnetometerUpdates()
        case .barometer:
            guard CMAltimeter.isRelativeAltitudeAvailable() else { return .unavailable }
            let altimeter = CMAltimeter()
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in if data != nil { counter.increment() } }
            try? await Task.sleep(for: Self.duration)
            altimeter.stopRelativeAltitudeUpdates()
            if [.denied, .restricted].contains(CMAltimeter.authorizationStatus()) { return .permissionDenied }
        case .proximity, .ambientLight, .location, .faceID, .lidar:
            return .unavailable
        }
        return counter.value > 0 ? .passed(samples: counter.value) : .noReadings
    }
}

private final class SampleCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int { lock.withLock { count } }
}
