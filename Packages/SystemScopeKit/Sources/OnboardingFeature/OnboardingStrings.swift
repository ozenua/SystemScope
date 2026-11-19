import Foundation

// All onboarding copy, sourced from the String Catalog (PRD §15.3).
enum Strings {
    // Common
    static let appName = String(localized: "SystemScope", bundle: .module)
    static let continueAction = String(localized: "Continue", bundle: .module)
    static let skip = String(localized: "Skip", bundle: .module)
    static let back = String(localized: "Back", bundle: .module)
    static let unavailable = String(localized: "Unavailable", bundle: .module)
    static let ok = String(localized: "OK", bundle: .module)
    static func step(_ current: Int) -> String {
        String(localized: "Step \(current) of \(OnboardingModel.totalSteps)", bundle: .module)
    }

    // Intro
    static let intro1Title = String(localized: "Welcome to SystemScope", bundle: .module)
    static let intro1Body = String(localized: "Monitor performance, storage, battery and more from one place.", bundle: .module)
    static let intro2Title = String(localized: "Everything in\none place", bundle: .module)
    static let intro2Body = String(localized: "Memory, storage, battery and network activity, keep track of the things that matter.", bundle: .module)
    static let intro3Title = String(localized: "Understand your device. Stay ahead.", bundle: .module)
    static let intro3Body = String(localized: "Spot changes, understand device conditions and get useful recommendations", bundle: .module)
    static let identifyMyDevice = String(localized: "Identify my device", bundle: .module)
    static let introIllustration = String(localized: "Sample SystemScope dashboard", bundle: .module)

    // Intro illustration (sample UI inside the phone mock)
    static let mockOverview = String(localized: "Overview", bundle: .module)
    static let mockMyIPhone = String(localized: "My iPhone", bundle: .module)
    static let mockSample = String(localized: "Sample", bundle: .module)
    static let mockDeviceHealth = String(localized: "Device health", bundle: .module)
    static let mockCPU = String(localized: "CPU", bundle: .module)
    static let mockBattery = String(localized: "Battery", bundle: .module)
    static let mockStorage = String(localized: "Storage", bundle: .module)
    static let mockNetwork = String(localized: "Network", bundle: .module)
    static let mockThermal = String(localized: "Thermal", bundle: .module)
    static let mockActivity = String(localized: "Activity", bundle: .module)
    static let mockGood = String(localized: "Good", bundle: .module)
    static let mockNormal = String(localized: "Normal", bundle: .module)
    static let mockChangeSpotted = String(localized: "Change spotted", bundle: .module)
    static let mockStorageWentUp = String(localized: "Storage use went up", bundle: .module)
    static let mockPerformance = String(localized: "Performance", bundle: .module)
    static let mockCPUAndMemory = String(localized: "CPU & memory", bundle: .module)
    static let mockUsedAndAvailable = String(localized: "Used & available", bundle: .module)
    static let mockLevelAndCharging = String(localized: "Level & charging", bundle: .module)
    static let mockConnectivityAndData = String(localized: "Connectivity & data", bundle: .module)
    static let mockUsed = String(localized: "Used", bundle: .module)
    static let mockFree = String(localized: "Free", bundle: .module)

    // Meet your device
    static let yourIPhone = String(localized: "Your iPhone", bundle: .module)
    static let deviceIdentification = String(localized: "Device identification", bundle: .module)
    static let deviceModel = String(localized: "Device model", bundle: .module)
    static let iosVersion = String(localized: "iOS version", bundle: .module)
    static let processor = String(localized: "Processor", bundle: .module)
    static let memory = String(localized: "Memory", bundle: .module)
    static let identifyAgain = String(localized: "Identify again", bundle: .module)
    static let identifying = String(localized: "Identifying", bundle: .module)
    static let unknownModel = String(localized: "Unknown iPhone model", bundle: .module)
    static func iosVersionValue(_ version: String) -> String {
        String(localized: "iOS \(version)", bundle: .module)
    }

    // Set up monitoring
    static let monitoringTitle = String(localized: "Stay informed, on your terms.", bundle: .module)
    static let monitoringBody = String(localized: "Notifications let SystemScope tell you when a threshold is crossed. Other permissions are only asked for when you use a feature that needs them.", bundle: .module)
    static let notifications = String(localized: "Notifications", bundle: .module)
    static let notificationsDetail = String(localized: "Device monitoring alerts", bundle: .module)
    static let enable = String(localized: "Enable", bundle: .module)
    static let enabled = String(localized: "Enabled", bundle: .module)
    static let notAllowed = String(localized: "Not allowed", bundle: .module)
    static let notificationsDeniedDetail = String(localized: "Off. You can allow notifications in iPhone Settings.", bundle: .module)
    static let privacyNote = String(localized: "SystemScope only asks when a feature needs it. You can change access anytime in Settings.", bundle: .module)
    static let askedWhenUsed = String(localized: "ASKED ONLY WHEN YOU USE THEM", bundle: .module)
    static let location = String(localized: "Location", bundle: .module)
    static let locationReason = String(localized: "· Only to show your Wi‑Fi network name", bundle: .module)
    static let camera = String(localized: "Camera", bundle: .module)
    static let cameraReason = String(localized: "· Only for the camera test in Device", bundle: .module)
    static let motion = String(localized: "Motion & Fitness", bundle: .module)
    static let motionReason = String(localized: "· Only for sensor tests that need it", bundle: .module)
    static let maybeLater = String(localized: "Maybe later", bundle: .module)

    // Inspect your device
    static let inspectTitle = String(localized: "Getting your device ready.", bundle: .module)
    static let inspectBody = String(localized: "Scanning everything iOS shares about your iPhone.", bundle: .module)
    static let categoryDevice = String(localized: "Device & system", bundle: .module)
    static let categoryMemory = String(localized: "Memory & storage", bundle: .module)
    static let categoryBattery = String(localized: "Battery & thermal", bundle: .module)
    static let categoryNetwork = String(localized: "Network & connectivity", bundle: .module)
    static let categoryDisplay = String(localized: "Display & cameras", bundle: .module)
    static let categorySensors = String(localized: "Sensors", bundle: .module)
    static let statusComplete = String(localized: "Complete", bundle: .module)
    static let statusInProgress = String(localized: "In progress", bundle: .module)
    static let statusUpNext = String(localized: "Up next", bundle: .module)
    static let statusPartial = String(localized: "Partial", bundle: .module)
    static let statusPermissionNeeded = String(localized: "Permission needed", bundle: .module)
    static let statusNotSupported = String(localized: "Not supported", bundle: .module)
    static let statusNotVerified = String(localized: "Not verified", bundle: .module)
    static let stageDevice = String(localized: "Reading device information", bundle: .module)
    static let stageMemory = String(localized: "Reading memory and storage", bundle: .module)
    static let stageBattery = String(localized: "Reading battery and thermal state", bundle: .module)
    static let stageNetwork = String(localized: "Reading network information", bundle: .module)
    static let stageDisplay = String(localized: "Reading display and cameras", bundle: .module)
    static let stageSensors = String(localized: "Checking sensor availability", bundle: .module)
    static let stageDone = String(localized: "Scan complete", bundle: .module)
    static let stageWaiting = String(localized: "Preparing scan", bundle: .module)
    static func progressCount(_ current: Int, _ total: Int) -> String {
        String(localized: "\(current) of \(total)", bundle: .module)
    }

    // Your device is ready
    static let setupComplete = String(localized: "Setup complete", bundle: .module)
    static let readyTitle = String(localized: "Your device is ready.", bundle: .module)
    static let readyBody = String(localized: "Start exploring your iPhone with SystemScope.", bundle: .module)
    static let storage = String(localized: "Storage", bundle: .module)
    static let battery = String(localized: "Battery", bundle: .module)
    static let thermalState = String(localized: "Thermal state", bundle: .module)
    static let iosThermalState = String(localized: "iOS thermal state", bundle: .module)
    static let physicalMemory = String(localized: "Physical memory", bundle: .module)
    static let notReported = String(localized: "Not reported by iOS", bundle: .module)
    static let notCharging = String(localized: "Not charging", bundle: .module)
    static let charging = String(localized: "Charging", bundle: .module)
    static let fullyCharged = String(localized: "Fully charged", bundle: .module)
    static let thermalNominal = String(localized: "Nominal", bundle: .module)
    static let thermalFair = String(localized: "Fair", bundle: .module)
    static let thermalSerious = String(localized: "Serious", bundle: .module)
    static let thermalCritical = String(localized: "Critical", bundle: .module)
    static let unavailableNote = String(localized: "Some details aren't shared by iOS on this device. They're shown as unavailable.", bundle: .module)
    static func storageFree(_ amount: String) -> String {
        String(localized: "\(amount) free", bundle: .module)
    }
    static func ofTotal(_ amount: String) -> String {
        String(localized: "of \(amount)", bundle: .module)
    }
    static func inUseOf(_ amount: String) -> String {
        String(localized: "in use of \(amount)", bundle: .module)
    }
    static let premiumBadge = String(localized: "PREMIUM", bundle: .module)
    static let premiumIntroTitle = String(localized: "See more. Understand more.", bundle: .module)
    static let premiumIntroBody = String(localized: "Unlock detailed monitoring, historical trends, advanced charts and personalized device insights.", bundle: .module)
    static let premiumChips = [
        String(localized: "Detailed monitoring", bundle: .module),
        String(localized: "Performance history", bundle: .module),
        String(localized: "Storage trends", bundle: .module),
        String(localized: "Reports", bundle: .module),
        String(localized: "Diagnostics", bundle: .module),
    ]
    static let explorePremium = String(localized: "Explore Premium", bundle: .module)
    static let continueWithPreview = String(localized: "Continue with preview", bundle: .module)

    // Premium
    static let restore = String(localized: "Restore", bundle: .module)
    static let premiumTitle = String(localized: "Get the complete picture.", bundle: .module)
    static let premiumBody = String(localized: "Unlock everything SystemScope has to offer.", bundle: .module)
    static let premiumBenefits = [
        String(localized: "Full dashboard", bundle: .module),
        String(localized: "Detailed resources", bundle: .module),
        String(localized: "Performance history", bundle: .module),
        String(localized: "Longer history", bundle: .module),
        String(localized: "Custom alerts", bundle: .module),
        String(localized: "Advanced charts", bundle: .module),
        String(localized: "Exportable reports", bundle: .module),
        String(localized: "Future diagnostics", bundle: .module),
    ]
    static let monthly = String(localized: "Monthly", bundle: .module)
    static let annual = String(localized: "Annual", bundle: .module)
    static let perMonth = String(localized: "per month", bundle: .module)
    static let perYear = String(localized: "per year", bundle: .module)
    static func perYearWithMonthly(_ monthlyPrice: String) -> String {
        String(localized: "per year · \(monthlyPrice)/mo", bundle: .module)
    }
    static func savePercent(_ percent: Int) -> String {
        String(localized: "Save \(percent)%", bundle: .module)
    }
    static let selected = String(localized: "Selected", bundle: .module)
    static let plansUnavailable = String(localized: "Plans aren't available right now.", bundle: .module)
    static let startPremium = String(localized: "Start Premium", bundle: .module)
    static let paymentTerms = String(localized: "Payment is charged to your Apple ID. Your subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Cancel anytime in Settings.", bundle: .module)
    static let termsOfUse = String(localized: "Terms of Use", bundle: .module)
    static let privacyPolicy = String(localized: "Privacy Policy", bundle: .module)
    static let restorePurchases = String(localized: "Restore Purchases", bundle: .module)
    static let noticePurchasesTitle = String(localized: "Purchases aren't available yet", bundle: .module)
    static let noticePurchasesBody = String(localized: "Premium can't be purchased or restored in this build.", bundle: .module)
    static let noticeNothingToRestoreTitle = String(localized: "Nothing to restore", bundle: .module)
    static let noticeNothingToRestoreBody = String(localized: "No previous Premium purchase was found for this Apple ID.", bundle: .module)
    static let noticeLegalTitle = String(localized: "Not available yet", bundle: .module)
    static let noticeLegalBody = String(localized: "This document hasn't been published yet.", bundle: .module)
}
