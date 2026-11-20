import ActivityStore
import Core
import DeviceFeature
import DeviceInfo
import Foundation
import HomeFeature
import MonitorFeature
import OnboardingFeature
import SettingsFeature
import SpeedTest
import UIKit
import UserNotifications

/// The app's injected services (PRD §4.2). Features receive protocols from here so
/// previews and tests can substitute deterministic fakes.
@MainActor
public struct AppEnvironment {
    public let preferences: AppPreferences
    public let inspector: any DeviceInspecting
    public let networkInspector: any NetworkInspecting
    public let gpuInspector: any GPUInspecting
    public let battery: any BatteryMonitoring
    public let resources: any ResourceSampling
    public let homeInsights: any HomeInsightsProviding
    public let monitorInsights: any MonitorInsightsProviding
    public let speedTester: any SpeedTestRunning
    public let speedTestHistory: any SpeedTestHistoryStoring
    public let pathMonitor: any NetworkPathProviding
    public let notifications: any NotificationAuthorizing
    public let premium: any PremiumOffering
    public let deviceDetails: any DeviceDetailsProviding
    public let sensorTester: any SensorTesting
    public let activityPersistence: any ActivityPersisting
    /// Support, legal and website links. Empty until they exist: no placeholder URLs.
    public let settingsLinks: SettingsLinks
    /// Debug only: start onboarding at a specific step.
    public let initialOnboardingStep: OnboardingModel.Step
    /// Debug only: open this Monitor screen at launch.
    public let initialMonitorRoute: MonitorRoute?
    /// Debug only: open this Device screen at launch.
    public let initialDeviceRoute: DeviceRoute?
    /// Debug only: open the Activity tab, optionally on `alerts`, `sessions` or `search`.
    public let initialActivityRoute: String?
    /// Debug only: open the Settings tab, optionally on one of its screens.
    public let initialSettingsRoute: String?

    public init(
        preferences: AppPreferences,
        inspector: any DeviceInspecting,
        networkInspector: any NetworkInspecting,
        gpuInspector: any GPUInspecting,
        battery: any BatteryMonitoring,
        resources: any ResourceSampling,
        homeInsights: any HomeInsightsProviding,
        monitorInsights: any MonitorInsightsProviding = UnavailableMonitorInsights(),
        speedTester: any SpeedTestRunning,
        speedTestHistory: any SpeedTestHistoryStoring,
        pathMonitor: any NetworkPathProviding = NetworkPathMonitor(),
        notifications: any NotificationAuthorizing,
        premium: any PremiumOffering,
        deviceDetails: any DeviceDetailsProviding = SystemDeviceDetailsProvider(),
        sensorTester: any SensorTesting = SystemSensorTester(),
        activityPersistence: any ActivityPersisting = FileActivityPersistence(),
        settingsLinks: SettingsLinks = SettingsLinks(),
        initialOnboardingStep: OnboardingModel.Step = .splash,
        initialMonitorRoute: MonitorRoute? = nil,
        initialDeviceRoute: DeviceRoute? = nil,
        initialActivityRoute: String? = nil,
        initialSettingsRoute: String? = nil
    ) {
        self.preferences = preferences
        self.inspector = inspector
        self.networkInspector = networkInspector
        self.gpuInspector = gpuInspector
        self.battery = battery
        self.resources = resources
        self.homeInsights = homeInsights
        self.monitorInsights = monitorInsights
        self.speedTester = speedTester
        self.speedTestHistory = speedTestHistory
        self.pathMonitor = pathMonitor
        self.notifications = notifications
        self.premium = premium
        self.initialOnboardingStep = initialOnboardingStep
        self.initialMonitorRoute = initialMonitorRoute
        self.deviceDetails = deviceDetails
        self.sensorTester = sensorTester
        self.activityPersistence = activityPersistence
        self.settingsLinks = settingsLinks
        self.initialDeviceRoute = initialDeviceRoute
        self.initialActivityRoute = initialActivityRoute
        self.initialSettingsRoute = initialSettingsRoute
    }

    /// Real providers. Debug builds honour these launch arguments:
    /// `-ResetOnboarding`, `-SkipOnboarding`, `-UseSampleDevice`, `-OnboardingStep <step>`,
    /// `-MonitorRoute <cpu|memory|gpu|storage|battery|thermal|network>`,
    /// `-DeviceRoute <general|processor|memory|display|camera|connectivity|sensors|battery|operatingSystem|graphics>`,
    /// `-SettingsRoute <overview|device|monitoring|notifications|thresholds|appearance|data|export|subscription|privacy|support|about>`,
    /// `-ActivityRoute <alerts|sessions|search>`, `-EmptyActivity` (with `-UseSampleDevice`),
    /// `-SpeedTestServer <url>`.
    public static func live() -> AppEnvironment {
        let preferences = AppPreferences(detectedDeviceName: UIDevice.current.name)
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ResetOnboarding") {
            preferences.hasCompletedOnboarding = false
        }
        if arguments.contains("-SkipOnboarding") {
            preferences.hasCompletedOnboarding = true
        }
        let step = arguments.firstIndex(of: "-OnboardingStep")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
            .flatMap(OnboardingModel.Step.init(rawValue:))
        let useSample = arguments.contains("-UseSampleDevice")
        let monitorRoute = arguments.firstIndex(of: "-MonitorRoute")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
            .flatMap(MonitorRoute.init(rawValue:))
        let settingsRoute = arguments.firstIndex(of: "-SettingsRoute")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let activityRoute = arguments.firstIndex(of: "-ActivityRoute")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let deviceRoute = arguments.firstIndex(of: "-DeviceRoute")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
            .flatMap(DeviceRoute.init(rawValue:))
        // Debug only: point the speed test at a development server, e.g.
        // `-SpeedTestServer http://127.0.0.1:8787` with Tools/speedtest-dev-server.py.
        let servers = arguments.firstIndex(of: "-SpeedTestServer")
            .flatMap { arguments.indices.contains($0 + 1) ? URL(string: arguments[$0 + 1]) : nil }
            .map { [$0] } ?? productionSpeedTestServers
        let history = FileSpeedTestRepository()
        return AppEnvironment(
            preferences: preferences,
            inspector: useSample ? SampleDeviceInspector() : SystemDeviceInspector(),
            networkInspector: useSample ? SampleNetworkInspector() : SystemNetworkInspector(),
            gpuInspector: useSample ? SampleGPUInformationProvider() : GPUInformationProvider(),
            battery: useSample ? SampleBatteryMonitor() : BatteryMonitor(),
            resources: useSample ? SampleResourceSampler() : SystemResourceSampler(),
            homeInsights: useSample ? SampleHomeInsights() : UnavailableHomeInsights(),
            monitorInsights: useSample ? SampleMonitorInsights() : UnavailableMonitorInsights(),
            speedTester: makeSpeedTester(servers: servers, history: history),
            speedTestHistory: history,
            notifications: SystemNotificationAuthorizer(),
            // Sample plans until StoreKit and its local configuration land in M6.
            premium: SamplePremiumOffering(),
            deviceDetails: useSample ? SampleDeviceDetailsProvider() : SystemDeviceDetailsProvider(),
            sensorTester: useSample ? SampleSensorTester() : SystemSensorTester(),
            activityPersistence: useSample
                ? InMemoryActivityPersistence(snapshot: arguments.contains("-EmptyActivity") ? ActivitySnapshot() : SampleActivity.snapshot())
                : FileActivityPersistence(),
            initialOnboardingStep: step ?? .splash,
            initialMonitorRoute: monitorRoute,
            initialDeviceRoute: deviceRoute,
            initialActivityRoute: activityRoute,
            initialSettingsRoute: settingsRoute
        )
        #else
        let history = FileSpeedTestRepository()
        return AppEnvironment(
            preferences: preferences,
            inspector: SystemDeviceInspector(),
            networkInspector: SystemNetworkInspector(),
            gpuInspector: GPUInformationProvider(),
            battery: BatteryMonitor(),
            resources: SystemResourceSampler(),
            homeInsights: UnavailableHomeInsights(),
            speedTester: makeSpeedTester(servers: productionSpeedTestServers, history: history),
            speedTestHistory: history,
            notifications: SystemNotificationAuthorizer(),
            premium: UnavailablePremiumOffering()
        )
        #endif
    }
}

extension AppEnvironment {
    /// The production test servers. Empty until the speed-test backend is deployed and
    /// the provider decision (PRD D-06) is made; with none, the app says the speed test
    /// is unavailable instead of measuring against someone else's service.
    static let productionSpeedTestServers: [URL] = []

    static func makeSpeedTester(servers: [URL], history: any SpeedTestHistoryStoring) -> any SpeedTestRunning {
        guard !servers.isEmpty else { return UnconfiguredSpeedTest() }
        let transport = SpeedTestTransport()
        return SpeedTestCoordinator(
            clients: servers.map { HTTPSpeedTestClient(baseURL: $0, transport: transport) },
            path: NetworkPathMonitor(),
            history: history
        )
    }
}

/// Local-notification authorisation through UserNotifications (PRD §12).
public struct SystemNotificationAuthorizer: NotificationAuthorizing {
    public init() {}

    public func currentPermission() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .notDetermined
        }
    }

    public func requestPermission() async -> NotificationPermission {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted ? .granted : .denied
    }
}
