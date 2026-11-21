import ActivityFeature
import ActivityStore
import Core
import DesignSystem
import DeviceFeature
import HomeFeature
import MonitorFeature
import CoreMotion
import DeviceInfo
import OnboardingFeature
import SettingsFeature
import SwiftUI

enum AppTab: String, CaseIterable, Sendable {
    case home
    case monitor
    case device
    case activity
    case settings

    var title: String {
        switch self {
        case .home: "Home"
        case .monitor: "Monitor"
        case .device: "Device"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    /// Filled icon for the selected state, for the tabs Figma draws one for.
    var selectedIcon: SSIcon? {
        switch self {
        case .home: .navHome
        case .monitor: .navMonitorBold
        case .device: .navDeviceBold
        case .activity: .navActivityBold
        case .settings: .navSettingsBold
        }
    }

    var icon: SSIcon {
        switch self {
        case .home: .navHomeOutline
        case .monitor: .navMonitor
        case .device: .mobile
        case .activity: .navActivity
        case .settings: .navSettings
        }
    }
}

/// The five primary tabs (PRD §1.3) inside the dark shell from Figma: content sits in a
/// panel with rounded lower corners above the custom tab bar. Tabs stay alive when
/// hidden so each keeps its navigation and scroll state (PRD §4.4).
struct MainTabView: View {
    let environment: AppEnvironment
    @State private var selection: AppTab = .home
    @State private var home: HomeModel
    @State private var monitor: MonitorModel
    @State private var device: DeviceModel
    @State private var activityLog: ActivityLog
    @State private var activity: ActivityModel
    @State private var settings: SettingsModel?
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        let preferences = environment.preferences
        let log = ActivityLog(persistence: environment.activityPersistence)
        let persistedInsights = ActivityInsightsProvider(source: { log.snapshot })
        _activityLog = State(initialValue: log)
        _home = State(initialValue: HomeModel(
            inspector: environment.inspector,
            networkInspector: environment.networkInspector,
            gpuInspector: environment.gpuInspector,
            battery: environment.battery,
            insights: environment.homeInsights is UnavailableHomeInsights ? persistedInsights : environment.homeInsights,
            speedTester: environment.speedTester,
            speedTestHistory: environment.speedTestHistory,
            pathMonitor: environment.pathMonitor,
            displayName: { preferences.deviceDisplayName }
        ))
        _selection = State(initialValue: environment.initialSettingsRoute != nil ? .settings
            : environment.initialActivityRoute != nil ? .activity
            : environment.initialDeviceRoute != nil ? .device
            : environment.initialMonitorRoute != nil ? .monitor : .home)
        let monitorModel = MonitorModel(
            inspector: environment.inspector,
            networkInspector: environment.networkInspector,
            gpuInspector: environment.gpuInspector,
            battery: environment.battery,
            resources: environment.resources,
            insights: environment.monitorInsights is UnavailableMonitorInsights ? persistedInsights : environment.monitorInsights,
            speedTestHistory: environment.speedTestHistory,
            displayName: { preferences.deviceDisplayName },
            activityLog: log
        )
        monitorModel.userSettings = { preferences.settings }
        if let route = environment.initialMonitorRoute { monitorModel.path = [route] }
        _monitor = State(initialValue: monitorModel)
        let deviceModel = DeviceModel(
            preferences: preferences,
            inspector: environment.inspector,
            details: environment.deviceDetails,
            networkInspector: environment.networkInspector,
            gpuInspector: environment.gpuInspector,
            battery: environment.battery,
            sensorTester: environment.sensorTester
        )
        if let route = environment.initialDeviceRoute { deviceModel.path = [route] }
        _device = State(initialValue: deviceModel)
        let activityModel = ActivityModel(log: log, copy: { UIPasteboard.general.string = $0 })
        switch environment.initialActivityRoute {
        case "alerts": activityModel.path = [.alerts]
        case "sessions": activityModel.path = [.sessions]
        case "search": activityModel.path = [.search]
        default: break
        }
        _activity = State(initialValue: activityModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    content(for: tab)
                        .opacity(tab == selection ? 1 : 0)
                        .allowsHitTesting(tab == selection)
                        .accessibilityHidden(tab != selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A backdrop behind the status bar, so scrolled content never shows
            // through the clock and indicators. The zero-height frame grows to
            // exactly the top safe-area inset.
            .overlay(alignment: .top) {
                SSColor.backgroundTop
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0, alignment: .top)
            }
            .clipShape(ContentPanelShape())

            SSTabBar(
                items: AppTab.allCases.map { SSTabBarItem(id: $0, icon: $0.icon, selectedIcon: $0.selectedIcon, label: $0.title) },
                selection: $selection
            )
        }
        .background(SSColor.shell.ignoresSafeArea())
        .speedTestSheet(model: home)
        .deviceSheets(model: device)
        .activitySheets(model: activity)
        .modifier(OptionalSettingsSheets(model: settings))
        // Settings › Appearance › Reduce animations (SET-06).
        .transaction { transaction in
            if environment.preferences.settings.reduceAnimations { transaction.animation = nil }
        }
        // Records activity while the app is in the foreground (PRD §6.5).
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await ActivityObserver(
                log: activityLog,
                inspector: environment.inspector,
                networkInspector: environment.networkInspector,
                battery: environment.battery,
                settings: { [preferences = environment.preferences] in preferences.settings }
            ).run()
        }
        .task {
            await activityLog.loadIfNeeded()
            activityLog.closeAbandonedSessions()
            ActivityObserver.apply(environment.preferences.settings, to: activityLog)
            activityLog.onAlertRaised = { [preferences = environment.preferences] alert in
                AlertNotifier.post(alert, settings: preferences.settings)
            }
            if settings == nil { settings = makeSettingsModel() }
            home.onSpeedTestCompleted = { [activityLog] result in
                activityLog.record(ActivityObserver.event(for: result))
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch environment.preferences.settings.theme {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(model: home) { selection = .activity }
        case .monitor:
            MonitorView(
                model: monitor,
                isActive: selection == .monitor,
                onOpenActivity: { selection = .activity },
                onRunSpeedTest: { home.openSpeedTest() }
            )
        case .settings:
            // ONB-11: "Replay onboarding" lives in the Settings overview's More menu.
            if let settings {
                SettingsView(model: settings)
            } else {
                Color.clear
            }
        case .device:
            DeviceView(model: device) { link in
                // Device pages link to the matching Monitor screen (PRD §6.4).
                let route: MonitorRoute = switch link {
                case .cpu: .cpu
                case .memory: .memory
                case .gpu: .gpu
                case .battery: .battery
                case .network: .network
                }
                monitor.path = [route]
                selection = .monitor
            }
        case .activity:
            ActivityView(model: activity) { link in
                let route: MonitorRoute = switch link {
                case .cpu: .cpu
                case .memory: .memory
                case .battery: .battery
                case .thermal: .thermal
                case .network: .network
                case .storage: .storage
                }
                monitor.path = [route]
                selection = .monitor
            }
        }
    }
}

/// Rounds the content panel's lower corners while leaving everything above it
/// (the area under the status bar) unclipped.
private struct ContentPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let extended = CGRect(x: rect.minX, y: rect.minY - 400, width: rect.width, height: rect.height + 400)
        return UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous)
            .path(in: extended)
    }
}

private struct OptionalSettingsSheets: ViewModifier {
    let model: SettingsModel?

    func body(content: Content) -> some View {
        if let model { content.settingsSheets(model: model) } else { content }
    }
}

extension MainTabView {
    /// Settings gets its services as closures, so it never imports another feature.
    func makeSettingsModel() -> SettingsModel {
        let environment = environment
        let device = device
        let notifications = environment.notifications
        let premium = environment.premium
        let info = Bundle.main.infoDictionary
        let model = SettingsModel(
            preferences: environment.preferences,
            log: activityLog,
            dependencies: SettingsDependencies(
                deviceInfo: {
                    let summary = device.summary
                    return SettingsDeviceInfo(
                        modelName: summary.modelName,
                        modelIdentifier: summary.modelIdentifier ?? device.details?.hardwareIdentifier,
                        osVersion: summary.osVersion,
                        storageCapacity: summary.storageTotalBytes.map { ByteFormatting.storage($0, fractionDigits: 0) },
                        isIdentified: device.identification == .identified,
                        lastUpdated: device.lastUpdated
                    )
                },
                refreshDevice: { await device.refresh() },
                notificationStatus: {
                    switch await notifications.currentPermission() {
                    case .granted: .granted
                    case .denied: .denied
                    case .notDetermined: .notDetermined
                    }
                },
                requestNotifications: {
                    switch await notifications.requestPermission() {
                    case .granted: .granted
                    case .denied: .denied
                    case .notDetermined: .notDetermined
                    }
                },
                motionStatus: {
                    switch CMAltimeter.authorizationStatus() {
                    case .authorized: .granted
                    case .denied: .denied
                    case .restricted: .restricted
                    default: .notDetermined
                    }
                },
                loadPlans: {
                    await premium.loadPlans().map { plan in
                        SettingsPlan(
                            id: plan.id,
                            title: plan.period == .yearly ? String(localized: "Yearly") : String(localized: "Monthly"),
                            price: plan.displayPrice
                        )
                    }
                },
                restorePurchases: { await premium.restorePurchases() == .purchased },
                deviceReport: { device.reportText },
                links: environment.settingsLinks,
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "1.0",
                buildNumber: info?["CFBundleVersion"] as? String ?? "1",
                openSystemSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                },
                openDevice: { link in
                    switch link {
                    case .overview: device.path = []
                    case .specifications: device.path = [.general]
                    case .hardware: device.path = [.sensors]
                    }
                    selection = .device
                },
                replayOnboarding: { environment.preferences.hasCompletedOnboarding = false },
                copy: { UIPasteboard.general.string = $0 }
            )
        )
        switch environment.initialSettingsRoute {
        case "device": model.path = [.myDevice]
        case "monitoring": model.path = [.monitoring]
        case "notifications": model.path = [.notifications]
        case "thresholds": model.path = [.thresholds]
        case "appearance": model.path = [.appearance]
        case "data": model.path = [.data]
        case "export": model.path = [.export]
        case "subscription": model.path = [.subscription]
        case "privacy": model.path = [.privacy]
        case "support": model.path = [.support]
        case "about": model.path = [.about]
        default: break
        }
        return model
    }
}
