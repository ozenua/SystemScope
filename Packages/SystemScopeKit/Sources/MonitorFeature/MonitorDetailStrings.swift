import Foundation

// Copy for the metric screens (MON-02 to MON-08).
extension Strings {
    // Shared
    static let back = String(localized: "Back", bundle: .module)
    static let now = String(localized: "Now", bundle: .module)
    static let technicalDetails = String(localized: "Technical details", bundle: .module)
    static let expanded = String(localized: "Expanded", bundle: .module)
    static let collapsed = String(localized: "Collapsed", bundle: .module)
    static let historyNotRecorded = String(localized: "SystemScope doesn't store readings over time yet, so there's nothing to chart for this range.", bundle: .module)
    static let collectingReadings = String(localized: "Collecting readings…", bundle: .module)
    static let updatedJustNow = String(localized: "Updated just now", bundle: .module)
    static let liveSession = String(localized: "Live session", bundle: .module)
    static let source = String(localized: "Source", bundle: .module)
    static let scope = String(localized: "Scope", bundle: .module)
    static let measured = String(localized: "Measured", bundle: .module)
    static let sampling = String(localized: "Sampling", bundle: .module)
    static let thisApp = String(localized: "This app", bundle: .module)
    static let deviceSpecification = String(localized: "Device specification", bundle: .module)
    static let yes = String(localized: "Yes", bundle: .module)
    static let no = String(localized: "No", bundle: .module)
    static let supported = String(localized: "Supported", bundle: .module)
    static let notSupported = String(localized: "Not supported", bundle: .module)
    static let notAvailable = String(localized: "Not available", bundle: .module)
    static let noHistory = String(localized: "No history", bundle: .module)
    static let live = String(localized: "Live", bundle: .module)
    static let fiveMinutes = String(localized: "5 min", bundle: .module)
    static let fifteenMinutes = String(localized: "15 min", bundle: .module)
    static let oneHour = String(localized: "1 hour", bundle: .module)
    static let recommendations = String(localized: "Recommendations", bundle: .module)
    static func updatedAt(_ time: String) -> String {
        String(localized: "Updated \(time)", bundle: .module)
    }

    // CPU
    static let cpuTitle = String(localized: "CPU", bundle: .module)
    static let cpuSubtitle = String(localized: "Processor information and SystemScope’s CPU activity", bundle: .module)
    static let chip = String(localized: "Chip", bundle: .module)
    static let architecture = String(localized: "Architecture", bundle: .module)
    static let totalCores = String(localized: "Total cores", bundle: .module)
    static let activeCores = String(localized: "Active cores", bundle: .module)
    static let physicalRAM = String(localized: "Physical RAM", bundle: .module)
    static let appCPU = String(localized: "SystemScope CPU", bundle: .module)
    static let appCPUInfo = String(localized: "CPU time SystemScope used in the last second, as a share of all cores.", bundle: .module)
    static let low = String(localized: "Low", bundle: .module)
    static let moderate = String(localized: "Moderate", bundle: .module)
    static let high = String(localized: "High", bundle: .module)
    static let copy = String(localized: "Copy", bundle: .module)
    static let copied = String(localized: "Copied", bundle: .module)
    static let session = String(localized: "Session", bundle: .module)
    static let average = String(localized: "Average", bundle: .module)
    static let peak = String(localized: "Peak", bundle: .module)
    static let appOnlyNote = String(localized: "App-only. iOS doesn’t expose total device CPU.", bundle: .module)
    static let activity = String(localized: "Activity", bundle: .module)
    static let appActivity = String(localized: "App activity", bundle: .module)
    static let sessionAverage = String(localized: "Session average", bundle: .module)
    static let cpuTimeUsed = String(localized: "CPU time used by SystemScope", bundle: .module)
    static let secondsThisSession = String(localized: "s this session", bundle: .module)
    static let sessionHistory = String(localized: "Session history", bundle: .module)
    static let noSessions = String(localized: "No saved sessions yet", bundle: .module)
    static let noSessionsDetail = String(localized: "Sessions will be listed once SystemScope keeps a history.", bundle: .module)
    static let cpuTechnicalCaption = String(localized: "Measurement source, sampling and limitations", bundle: .module)
    static let cpuSource = String(localized: "getrusage (this process)", bundle: .module)
    static let cpuSampling = String(localized: "Every second while Monitor is open", bundle: .module)
    static let cpuLimitation = String(localized: "Provisional: this measurement hasn't been validated on physical devices yet.", bundle: .module)
    static func cpuSummary(_ value: String, _ average: String, _ peak: String) -> String {
        String(localized: "SystemScope CPU \(value), average \(average), peak \(peak)", bundle: .module)
    }
    static func coreDescription(_ total: Int, _ performance: Int, _ efficiency: Int) -> String {
        String(localized: "\(total) (\(performance) performance + \(efficiency) efficiency)", bundle: .module)
    }

    // Memory
    static let memorySubtitle = String(localized: "Device memory and app diagnostics", bundle: .module)
    static let memoryInUse = String(localized: "Memory in use", bundle: .module)
    static let wired = String(localized: "Wired", bundle: .module)
    static let active = String(localized: "Active", bundle: .module)
    static let compressed = String(localized: "Compressed", bundle: .module)
    static let inUse = String(localized: "In use", bundle: .module)
    static func thisIPhoneOf(_ total: String) -> String {
        String(localized: "This iPhone · of \(total)", bundle: .module)
    }
    static let appDiagnostics = String(localized: "SystemScope app diagnostics", bundle: .module)
    static let appFootprint = String(localized: "App memory footprint", bundle: .module)
    static func peakValue(_ value: String) -> String {
        String(localized: "Peak \(value)", bundle: .module)
    }
    static func systemScopeUses(_ value: String) -> String {
        String(localized: "SystemScope · \(value)", bundle: .module)
    }
    static let restOfIPhone = String(localized: "Rest of iPhone · not visible to apps", bundle: .module)
    static let currentFootprint = String(localized: "Current process footprint", bundle: .module)
    static let availableProcessMemory = String(localized: "Available process memory", bundle: .module)
    static let peakFootprint = String(localized: "Peak process footprint", bundle: .module)
    static let lastMemoryWarning = String(localized: "Last memory warning", bundle: .module)
    static let noneThisSession = String(localized: "None this session", bundle: .module)
    static let memorySource = String(localized: "host_statistics64 · task_vm_info", bundle: .module)
    static let memoryLimitation = String(localized: "iOS keeps RAM in use by design — low free memory is normal. These figures are provisional until validated on physical devices.", bundle: .module)
    static let historicalObservations = String(localized: "Historical observations", bundle: .module)
    static let noObservations = String(localized: "No stored observations yet", bundle: .module)
    static let noObservationsDetail = String(localized: "Peaks and memory warnings from past sessions will appear here.", bundle: .module)
    static let memoryUnavailableDetail = String(localized: "Device memory statistics couldn't be read.", bundle: .module)

    // GPU
    static let gpuSubtitle = String(localized: "Graphics capabilities and available performance information", bundle: .module)
    static func gpuFamily(_ number: Int) -> String {
        String(localized: "Apple\(number) GPU family", bundle: .module)
    }
    static let noLiveGPU = String(localized: "No live GPU usage", bundle: .module)
    static let noLiveGPUDetail = String(localized: "iOS doesn’t share GPU utilization, clock speed or system-wide GPU activity. SystemScope shows capabilities instead.", bundle: .module)
    static let performanceReports = String(localized: "Performance reports", bundle: .module)
    static let noReports = String(localized: "No reports yet", bundle: .module)
    static let noReportsDetail = String(localized: "SystemScope doesn't collect iOS performance reports yet.", bundle: .module)
    static let reportsNote = String(localized: "Reports are delivered by iOS at most once a day, so they're never a live reading.", bundle: .module)
    static let metalCompatibility = String(localized: "Metal compatibility", bundle: .module)
    static let metalVersion = String(localized: "Metal version", bundle: .module)
    static let gpuFamilies = String(localized: "GPU families", bundle: .module)
    static let unifiedMemory = String(localized: "Unified memory", bundle: .module)
    static let maxThreads = String(localized: "Max threads per group", bundle: .module)
    static let rayTracing = String(localized: "Ray tracing", bundle: .module)
    static let rasterOrderGroups = String(localized: "Raster order groups", bundle: .module)
    static let gpuTechnicalCaption = String(localized: "Device inspection source and rendering features", bundle: .module)
    static let capabilityRayTracing = String(localized: "Hardware ray tracing", bundle: .module)
    static let capabilityUnifiedMemory = String(localized: "Unified memory", bundle: .module)
    static let capabilityFloatFiltering = String(localized: "32-bit float filtering", bundle: .module)
    static let capabilityBC = String(localized: "BC textures", bundle: .module)
    static let workingSet = String(localized: "Recommended working set", bundle: .module)

    // Storage
    static let storageSubtitle = String(localized: "Storage capacity and available space", bundle: .module)
    static let estimatedUsed = String(localized: "Estimated used capacity", bundle: .module)
    static func percentUsedValue(_ percent: Int) -> String {
        String(localized: "\(percent)% used", bundle: .module)
    }
    static func ofTotal(_ total: String) -> String {
        String(localized: "of \(total)", bundle: .module)
    }
    static func usedLegend(_ value: String) -> String {
        String(localized: "Used · \(value)", bundle: .module)
    }
    static func availableLegend(_ value: String) -> String {
        String(localized: "Available · \(value)", bundle: .module)
    }
    static let availableLabel = String(localized: "Available", bundle: .module)
    static let totalVolume = String(localized: "Total volume", bundle: .module)
    static let thisWeek = String(localized: "This week", bundle: .module)
    static let storageNote = String(localized: "Categories like Photos or Apps aren’t shown. iOS doesn’t let apps read the full iPhone Storage breakdown.", bundle: .module)
    static let usageTrend = String(localized: "Usage trend", bundle: .module)
    static let reviewLargeFiles = String(localized: "Review large files", bundle: .module)
    static let reviewLargeFilesDetail = String(localized: "Large videos and downloads are the quickest way to free up space.", bundle: .module)
    static let reviewDownloads = String(localized: "Review downloaded content", bundle: .module)
    static let reviewDownloadsDetail = String(localized: "Offline media in apps like Music and Podcasts can add up. Manage it in Settings › General › iPhone Storage.", bundle: .module)
    static let storageTechnicalCaption = String(localized: "Volume capacity source and update time", bundle: .module)
    static let storageSource = String(localized: "Volume capacity for important usage", bundle: .module)

    // Battery
    static let batterySubtitle = String(localized: "Charge, charging and available battery information", bundle: .module)
    static let batteryLevel = String(localized: "Battery level", bundle: .module)
    static let state = String(localized: "State", bundle: .module)
    static let lowPowerMode = String(localized: "Low Power Mode", bundle: .module)
    static let on = String(localized: "On", bundle: .module)
    static let off = String(localized: "Off", bundle: .module)
    static let updated = String(localized: "Updated", bundle: .module)
    static let unknown = String(localized: "Unknown", bundle: .module)
    static let batteryActivity = String(localized: "Battery activity", bundle: .module)
    static let batteryInformation = String(localized: "Battery information", bundle: .module)
    static let batteryState = String(localized: "Battery state", bundle: .module)
    static let batteryHealth = String(localized: "Battery Health", bundle: .module)
    static let inSettings = String(localized: "In Settings › Battery", bundle: .module)
    static let batteryNote = String(localized: "Cycle count, maximum capacity and battery temperature aren’t available to apps. You can find battery health in iOS Settings.", bundle: .module)
    static let lowPowerRecommendation = String(localized: "Use Low Power Mode when you need it", bundle: .module)
    static let lowPowerRecommendationDetail = String(localized: "Turn it on in Control Center or Settings › Battery.", bundle: .module)
    static let batteryTechnicalCaption = String(localized: "Battery state source and observation times", bundle: .module)
    static let batterySource = String(localized: "UIDevice battery monitoring", bundle: .module)
    static let batterySampling = String(localized: "When iOS reports a change", bundle: .module)

    // Thermal
    static let thermalSubtitle = String(localized: "Your iPhone’s current system thermal state", bundle: .module)
    static let currentThermalState = String(localized: "Current thermal state", bundle: .module)
    static let normal = String(localized: "Normal", bundle: .module)
    static let elevated = String(localized: "Elevated", bundle: .module)
    static let thermalNote = String(localized: "iOS reports thermal states, not temperatures. SystemScope never shows °C or °F readings.", bundle: .module)
    static let whatEachStateMeans = String(localized: "What each state means", bundle: .module)
    static let fairMeaning = String(localized: "Slightly elevated", bundle: .module)
    static let seriousMeaning = String(localized: "High thermal condition", bundle: .module)
    static let criticalMeaning = String(localized: "Significant thermal condition", bundle: .module)
    static let stateHistory = String(localized: "State history", bundle: .module)
    static let recentChanges = String(localized: "Recent changes", bundle: .module)
    static let noChanges = String(localized: "No changes this session", bundle: .module)
    static let noChangesDetail = String(localized: "Changes are recorded while SystemScope is open.", bundle: .module)
    static func change(_ from: String, _ to: String) -> String {
        String(localized: "\(from) → \(to)", bundle: .module)
    }
    static func lastChange(_ time: String, _ change: String) -> String {
        String(localized: "Last change \(time) · \(change)", bundle: .module)
    }
    static let heatTitle = String(localized: "How heat affects performance", bundle: .module)
    static let heatDetail = String(localized: "At Serious and Critical, iOS may slow things down, dim the display or pause charging to protect your iPhone.", bundle: .module)
    static let warmTitle = String(localized: "If your iPhone feels warm", bundle: .module)
    static let warmDetail = String(localized: "Remove the case, move out of direct sunlight and pause games or camera use.", bundle: .module)
    static let thermalTechnicalCaption = String(localized: "ProcessInfo thermal state and change events", bundle: .module)
    static let thermalSource = String(localized: "ProcessInfo.thermalState", bundle: .module)

    // Network
    static let networkSubtitle = String(localized: "Connection and device traffic", bundle: .module)
    static let speedTest = String(localized: "Speed test", bundle: .module)
    static let runSpeedTest = String(localized: "Run Speed Test", bundle: .module)
    static let connectedTo = String(localized: "Connected to", bundle: .module)
    static let connection = String(localized: "Connection", bundle: .module)
    static let notConnected = String(localized: "Not connected", bundle: .module)
    static let internetConnected = String(localized: "Internet connected", bundle: .module)
    static let noInternet = String(localized: "No internet connection", bundle: .module)
    static let download = String(localized: "Download", bundle: .module)
    static let upload = String(localized: "Upload", bundle: .module)
    static let notTested = String(localized: "Not tested", bundle: .module)
    static let noSpeedTest = String(localized: "No speed test yet", bundle: .module)
    static func lastSpeedTest(_ date: String, _ interface: String, _ seconds: String) -> String {
        String(localized: "Last speed test \(date) · \(interface) · \(seconds) s", bundle: .module)
    }
    static let latency = String(localized: "Latency", bundle: .module)
    static let deviceTraffic = String(localized: "Device traffic", bundle: .module)
    static let cellular = String(localized: "Cellular", bundle: .module)
    static let wifi = String(localized: "Wi-Fi", bundle: .module)
    static let ethernet = String(localized: "Ethernet", bundle: .module)
    static let otherNetwork = String(localized: "Other network", bundle: .module)
    static let availableValue = String(localized: "Available", bundle: .module)
    static let sinceRestart = String(localized: "Since restart", bundle: .module)
    static func sinceRestartOn(_ interface: String) -> String {
        String(localized: "Since restart · \(interface)", bundle: .module)
    }
    static let trafficNote = String(localized: "Observed device traffic on the active connection. Resets on restart, and isn't a carrier billing figure.", bundle: .module)
    static let networkDetails = String(localized: "Network details", bundle: .module)
    static let connectedVerified = String(localized: "Connected · Internet verified", bundle: .module)
    static let connectedOnly = String(localized: "Connected", bundle: .module)
    static let availableNotInUse = String(localized: "Available · not in use", bundle: .module)
    static let inUseNow = String(localized: "In use", bundle: .module)
    static let networkName = String(localized: "Network name", bundle: .module)
    static let interface = String(localized: "Interface", bundle: .module)
    static let ipVersions = String(localized: "IP versions", bundle: .module)
    static let expensiveConstrained = String(localized: "Expensive / constrained", bundle: .module)
    static let signalStrength = String(localized: "Signal strength", bundle: .module)
    static let networkNameNote = String(localized: "Network name needs Apple's Wi-Fi information entitlement, which SystemScope doesn't have yet. Signal strength isn't available on iOS.", bundle: .module)
    static let networkHealth = String(localized: "Network health", bundle: .module)
    static let basedOnConnection = String(localized: "Based on the current connection", bundle: .module)
    static let good = String(localized: "Good", bundle: .module)
    static let limited = String(localized: "Limited", bundle: .module)
}
