// swift-tools-version: 6.0
import PackageDescription

// Module boundaries follow PRD §4.1–4.2: features depend on Core, DesignSystem and
// service protocols, never on each other. Add a target here only when a milestone
// actually needs it.
let package = Package(
    name: "SystemScopeKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppShell", targets: ["AppShell"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "DesignSystem", dependencies: ["Core"], resources: [.process("Resources")]),
        .target(name: "DeviceInfo", dependencies: ["Core"]),
        .target(
            name: "OnboardingFeature",
            dependencies: ["Core", "DesignSystem", "DeviceInfo"],
            resources: [.process("Resources")]
        ),
        .target(name: "SpeedTest", dependencies: ["Core", "DeviceInfo"]),
        .target(name: "ActivityStore", dependencies: ["Core"], resources: [.process("Resources")]),
        .target(
            name: "HomeFeature",
            dependencies: ["Core", "DesignSystem", "DeviceInfo", "SpeedTest"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MonitorFeature",
            dependencies: ["Core", "DesignSystem", "DeviceInfo", "SpeedTest", "ActivityStore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "DeviceFeature",
            dependencies: ["Core", "DesignSystem", "DeviceInfo"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "ActivityFeature",
            dependencies: ["Core", "DesignSystem", "ActivityStore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "SettingsFeature",
            dependencies: ["Core", "DesignSystem", "ActivityStore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "AppShell",
            dependencies: ["Core", "DesignSystem", "DeviceInfo", "SpeedTest", "OnboardingFeature", "HomeFeature", "MonitorFeature", "DeviceFeature", "ActivityStore", "ActivityFeature", "SettingsFeature"]
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "DeviceInfoTests", dependencies: ["DeviceInfo"]),
        .testTarget(name: "OnboardingFeatureTests", dependencies: ["OnboardingFeature"]),
        .testTarget(name: "HomeFeatureTests", dependencies: ["HomeFeature", "SpeedTest"]),
        .testTarget(name: "MonitorFeatureTests", dependencies: ["MonitorFeature", "SpeedTest"]),
        .testTarget(name: "DeviceFeatureTests", dependencies: ["DeviceFeature", "DeviceInfo", "Core"]),
        .testTarget(name: "ActivityStoreTests", dependencies: ["ActivityStore"]),
        .testTarget(name: "ActivityFeatureTests", dependencies: ["ActivityFeature", "ActivityStore"]),
        .testTarget(name: "SettingsFeatureTests", dependencies: ["SettingsFeature", "ActivityStore", "Core"]),
        .testTarget(name: "SpeedTestTests", dependencies: ["SpeedTest", "DeviceInfo"]),
    ],
    swiftLanguageModes: [.v6]
)
