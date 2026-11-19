import Foundation

// All Monitor copy, sourced from the String Catalog (PRD §15.3).
enum Strings {
    static let title = String(localized: "Monitor", bundle: .module)
    static let subtitle = String(localized: "Device performance & resources", bundle: .module)
    static let refresh = String(localized: "Refresh", bundle: .module)
    static let refreshing = String(localized: "Refreshing… Showing your last readings until new ones arrive.", bundle: .module)
    static let collecting = String(localized: "Collecting available measurements…", bundle: .module)
    static let monitoringActive = String(localized: "Monitoring active", bundle: .module)
    static let monitoringPaused = String(localized: "Monitoring paused", bundle: .module)
    static let standardMonitoring = String(localized: "Standard monitoring", bundle: .module)
    static let unknownModel = String(localized: "Unknown iPhone model", bundle: .module)
    static let unavailable = String(localized: "Unavailable", bundle: .module)
    static let viewAll = String(localized: "View all", bundle: .module)
    static func lastUpdate(_ time: String) -> String {
        String(localized: "Last successful update \(time)", bundle: .module)
    }
    static func iosVersion(_ version: String) -> String {
        String(localized: "iOS \(version)", bundle: .module)
    }

    // Tiles
    static let processor = String(localized: "Processor", bundle: .module)
    static let deviceSpec = String(localized: "Device spec", bundle: .module)
    static let cores = String(localized: "cores", bundle: .module)
    static let processorUnavailable = String(localized: "Core count isn't reported on this device.", bundle: .module)
    static func coreSplit(_ performance: Int, _ efficiency: Int) -> String {
        String(localized: "\(performance)P + \(efficiency)E", bundle: .module)
    }
    static let memory = String(localized: "Memory", bundle: .module)
    static let thisIPhone = String(localized: "This iPhone", bundle: .module)
    static let memoryUnavailable = String(localized: "Memory in use couldn't be read.", bundle: .module)
    static func inUseOf(_ total: String) -> String {
        String(localized: "in use of \(total)", bundle: .module)
    }
    static let battery = String(localized: "Battery", bundle: .module)
    static let level = String(localized: "Level", bundle: .module)
    static let charging = String(localized: "Charging", bundle: .module)
    static let notCharging = String(localized: "Not charging", bundle: .module)
    static let fullyCharged = String(localized: "Fully charged", bundle: .module)
    static let batteryUnavailable = String(localized: "Battery level not reported by iOS.", bundle: .module)
    static let thermal = String(localized: "Thermal", bundle: .module)
    static let systemState = String(localized: "System state", bundle: .module)
    static let thermalNominal = String(localized: "Nominal", bundle: .module)
    static let thermalFair = String(localized: "Fair", bundle: .module)
    static let thermalSerious = String(localized: "Serious", bundle: .module)
    static let thermalCritical = String(localized: "Critical", bundle: .module)
    static let operatingNormally = String(localized: "Operating normally", bundle: .module)
    static let slightlyWarm = String(localized: "Slightly warm", bundle: .module)
    static let runningHot = String(localized: "Running hot", bundle: .module)
    static let tooHot = String(localized: "Needs to cool down", bundle: .module)
    static let thermalUnavailable = String(localized: "Thermal state couldn't be read.", bundle: .module)
    static let storage = String(localized: "Storage", bundle: .module)
    static let percentUsed = String(localized: "% used", bundle: .module)
    static let storageUnavailable = String(localized: "Storage capacity couldn't be read.", bundle: .module)
    static func usedOf(_ used: String, _ total: String) -> String {
        String(localized: "\(used) of \(total)", bundle: .module)
    }
    static func available(_ amount: String) -> String {
        String(localized: "\(amount) available", bundle: .module)
    }
    static let gpu = String(localized: "GPU", bundle: .module)
    static let graphicsCapability = String(localized: "Graphics capability", bundle: .module)
    static let metal = String(localized: "Metal", bundle: .module)
    static let metal3 = String(localized: "Metal 3", bundle: .module)
    static let gpuUnavailable = String(localized: "GPU details couldn't be read.", bundle: .module)
    static func appleFamily(_ number: Int) -> String {
        String(localized: "Apple\(number) family", bundle: .module)
    }
    static let network = String(localized: "Network", bundle: .module)
    static let trafficSinceRestart = String(localized: "Device traffic since restart", bundle: .module)
    static let networkUnavailable = String(localized: "Traffic counters aren't available for this connection.", bundle: .module)
    static let offline = String(localized: "Offline", bundle: .module)
    static let wifiConnected = String(localized: "Wi-Fi connected", bundle: .module)
    static let cellularConnected = String(localized: "Cellular connected", bundle: .module)
    static let ethernetConnected = String(localized: "Ethernet connected", bundle: .module)
    static let connected = String(localized: "Connected", bundle: .module)

    // Sections
    static let alerts = String(localized: "Alerts", bundle: .module)
    static let noAlerts = String(localized: "No alerts", bundle: .module)
    static let noAlertsDetail = String(localized: "Alerts appear here when a reading crosses one of your thresholds.", bundle: .module)
    static let info = String(localized: "Info", bundle: .module)
    static let attention = String(localized: "Attention", bundle: .module)
    static let critical = String(localized: "Critical", bundle: .module)
    static let trends = String(localized: "Trends", bundle: .module)
    static let today = String(localized: "Today", bundle: .module)
    static let sevenDays = String(localized: "7 Days", bundle: .module)
    static let thirtyDays = String(localized: "30 Days", bundle: .module)
    static let insufficientHistory = String(localized: "Not enough history yet", bundle: .module)
    static let insufficientHistoryDetail = String(localized: "Trends appear once SystemScope has recorded enough readings while open.", bundle: .module)
    static let noReadingsWhileClosed = String(localized: "No readings while SystemScope was closed", bundle: .module)
    static func observations(_ count: Int) -> String {
        String(localized: "\(count) observations", bundle: .module)
    }
    static func trendSummary(_ title: String, _ value: String, _ count: Int) -> String {
        String(localized: "\(title), latest \(value), from \(count) observations", bundle: .module)
    }
    static let recentActivity = String(localized: "Recent activity", bundle: .module)
    static let noActivity = String(localized: "No activity yet", bundle: .module)
    static let noActivityDetail = String(localized: "Events and monitoring sessions will be listed here.", bundle: .module)
    static let recommended = String(localized: "Recommended", bundle: .module)
    static let reviewStorageTitle = String(localized: "Review downloaded content", bundle: .module)
    static func reviewStorageDetail(_ percent: String) -> String {
        String(localized: "\(percent) of storage is available. Offloading unused apps keeps space free.", bundle: .module)
    }
    static let lowPowerTitle = String(localized: "Consider Low Power Mode", bundle: .module)
    static let lowPowerDetail = String(localized: "Battery is low and not charging. Low Power Mode can be turned on in iPhone Settings.", bundle: .module)
}
