import SwiftUI

/// Monochrome icons exported from Figma (template-rendered, tint with foregroundStyle).
public enum SSIcon: String, Sendable {
    case cpu = "icon-cpu"
    case battery = "icon-battery"
    case storage = "icon-driver"
    case wifi = "icon-wifi"
    case thermometer = "icon-thermometer"
    case activity = "icon-activity"
    case statusUp = "icon-status-up"
    case mobile = "icon-mobile"
    case mobileAlt = "icon-mobile-alt"
    case notification = "icon-notification"
    case shieldTick = "icon-shield-tick"
    case tickCircle = "icon-tick-circle"
    case crown = "icon-crown"
    case spinner = "icon-spinner"
    case bell = "icon-bell"
    case lightning = "icon-lightning"
    case temperature = "icon-temperature"
    case signal = "icon-signal"
    case arrowDown = "icon-arrow-down"
    case arrowUp = "icon-arrow-up"
    case arrowRight = "icon-arrow-right"
    case arrowCircleRight = "icon-arrow-circle-right"
    case tickCircleBold = "icon-tick-circle-bold"
    case wifiBold = "icon-wifi-bold"
    case navHome = "nav-home"
    case navMonitor = "nav-monitor"
    case navActivity = "nav-activity"
    case navSettings = "nav-settings"
    case navHomeOutline = "nav-home-outline"
    case navMonitorBold = "nav-monitor-bold"
    case refresh = "icon-refresh"
    case cpuSetting = "icon-cpu-setting"
    case cpuCharge = "icon-cpu-charge"
    case cube = "icon-cube"
    case lamp = "icon-lamp"
    case clock = "icon-clock"
    case bolt = "icon-bolt"
    case info = "icon-info"
    case copy = "icon-copy"
    case radar = "icon-radar"
    case chevronDown = "icon-chevron-down"
    case cellular = "icon-cellular"
    case more = "icon-more"
    case edit = "icon-edit"
    case monitor = "icon-monitor"
    case camera = "icon-camera"
    case monitorMobile = "icon-monitor-mobile"
    case navDeviceBold = "nav-device-bold"
    case close = "icon-close"
    case warning = "icon-warning"
    case chevronRight = "icon-chevron-right"
    case search = "icon-search"
    case filter = "icon-filter"
    case timer = "icon-timer"
    case tempCold = "icon-temp-cold"
    case batteryFull = "icon-battery-full"
    case navActivityBold = "nav-activity-bold"
    case brush = "icon-brush"
    case messageQuestion = "icon-message-question"
    case navSettingsBold = "nav-settings-bold"
}

/// Full-colour artwork exported from Figma.
public enum SSArtwork: String, Sendable {
    case logo
    case mockSparkline = "mock-sparkline"
    case mockActivityLine = "mock-activity-line"
    case radio
    case radioSelected = "radio-selected"
    case scanRingOuter = "scan-ring-outer"
    case scanRingInner = "scan-ring-inner"
    case scanArc = "scan-arc"
    case scanHead = "scan-head"
    case scanSweep = "scan-sweep"
    case gaugeGlow = "gauge-glow"
    case gaugeTicks = "gauge-ticks"
    case gaugeTrack = "gauge-track"
    case gaugeRingOuter = "gauge-ring-outer"
    case gaugeRingInner = "gauge-ring-inner"
    case gaugeDiscOuter = "gauge-disc-outer"
    case gaugeDiscInner = "gauge-disc-inner"
    case gaugeNeedle = "gauge-needle"
    case gaugeHub = "gauge-hub"
    case deviceBack = "device-back"
}

public extension Image {
    init(_ icon: SSIcon) {
        self.init(icon.rawValue, bundle: .module)
    }

    init(_ artwork: SSArtwork) {
        self.init(artwork.rawValue, bundle: .module)
    }
}

/// A decorative icon at a fixed size. Hidden from VoiceOver; label the parent instead.
public struct SSIconView: View {
    private let icon: SSIcon
    private let size: CGFloat
    private let color: Color

    public init(_ icon: SSIcon, size: CGFloat, color: Color = SSColor.ink) {
        self.icon = icon
        self.size = size
        self.color = color
    }

    public var body: some View {
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

public struct AppLogo: View {
    private let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Image(SSArtwork.logo)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(verbatim: "SystemScope"))
    }
}
