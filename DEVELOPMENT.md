# SystemScope — Development Reference

A system-monitoring iOS app that surfaces real-time and historical device metrics: CPU, memory, GPU, battery, thermal, storage and network. The app reads live data through Apple frameworks and presents it in a consistent Figma-designed UI.

---

## Project Layout

```
SystemScope/
├── SystemScope.xcodeproj          # Xcode project — app target only
├── SystemScope/                   # App-level sources
│   ├── SystemScopeApp.swift       # @main entry point
│   ├── Assets.xcassets            # App icons and launch assets
│   └── PrivacyInfo.xcprivacy      # Privacy manifest
├── Packages/SystemScopeKit/       # Local Swift package — all feature code
│   ├── Package.swift              # Module graph, Swift 6
│   ├── Sources/                   # 13 targets
│   └── Tests/                     # 11 test targets
├── .github/workflows/ci.yml       # GitHub Actions CI
└── Tools/
    └── speedtest-dev-server.py    # Local speed-test server for development
```

---

## Module Graph

```
AppShell ──┬──> OnboardingFeature ──> Core, DesignSystem, DeviceInfo
           ├──> HomeFeature       ──> Core, DesignSystem, DeviceInfo, SpeedTest
           ├──> MonitorFeature    ──> Core, DesignSystem, DeviceInfo, SpeedTest, ActivityStore
           ├──> DeviceFeature     ──> Core, DesignSystem, DeviceInfo, StorageFeature
           ├──> ActivityFeature   ──> Core, DesignSystem, ActivityStore
           ├──> SettingsFeature   ──> Core, DesignSystem, ActivityStore
           ├──> ActivityStore     ──> Core
           ├──> SpeedTest         ──> Core, DeviceInfo
           └──> DeviceInfo        ──> Core
                Core
                DesignSystem      ──> Core
                StorageFeature    ──> Core, DesignSystem, DeviceInfo
```

**Rule:** feature modules never import each other. All cross-feature routing happens through closures injected by `AppShell`.

---

## Modules

### Core
Shared value types and protocols.

| File | Contents |
|------|----------|
| `AppPreferences.swift` | Persists `hasCompletedOnboarding`, `deviceDisplayName` and `UserSettings` to `UserDefaults` |
| `UserSettings.swift` | The user preferences model — monitoring, notifications, thresholds, appearance. Versioned `Codable`, stored as one document. `resetPreferences()` never touches the device profile or history |
| `ByteFormatting.swift` | Storage and byte-count formatters |
| `DeviceDataResult.swift` | `DeviceDataResult<T>` — a value that may be unavailable on this device; never shown as zero |

### DesignSystem
All UI building blocks. Features import nothing else for layout primitives.

| File | Contents |
|------|----------|
| `Tokens.swift` | `SSColor` adaptive colour tokens, `SSScreenBackground` |
| `Typography.swift` | `.ssText(_:)` modifier, all type styles |
| `Icons.swift` | `SSIcon` enum + `SSIconView` |
| `Buttons.swift` | `SSPrimaryButtonStyle`, `SSBackButton`, `CircleButton` |
| `Components.swift` | `SummaryCard`, `ChipRow`, `EmptyStateCard`, `DateHeader`, `SwipeActionRow` |
| `TabBar.swift` | `SSTabBar` and `SSTabBarItem` — the custom dark tab bar |
| `BottomSheet.swift` | `SSBottomSheetChrome`, `SSBottomSheetTitleRow` |
| `BackSwipe.swift` | `.backSwipe(_:)` view modifier — pan-from-left gesture |
| `FadeInNavigation.swift` | `.ssFadeInNavigationDestination()` — cross-fade push instead of slide |

### DeviceInfo
Live readings from iOS system APIs. Each provider has a `Sample*` fake for use in previews and `-UseSampleDevice` builds.

| Provider | Data |
|----------|------|
| `SystemDeviceInspector` | CPU, memory, storage, thermal snapshots via `DeviceInspecting` |
| `SystemNetworkInspector` | Wi-Fi SSID/BSSID/signal, cellular carrier, bytes sent/received |
| `GPUInformationProvider` | GPU renderer, VRAM, utilisation via `IOKit` |
| `BatteryMonitor` | Battery level, charge state, low-power mode via `UIDevice` |
| `SystemResourceSampler` | Periodic CPU/memory samples for the Monitor chart |
| `SystemDeviceDetailsProvider` | Model name from `DeviceCatalogue`, screen specs, sensor list |
| `StorageInformationProvider` | App, photo and document storage breakdown |
| `NetworkPathMonitor` | Live NWPathMonitor wrapper |

`DeviceSummary` is the flat struct that features read; `DeviceDetails` carries the full hardware specification.

`DeviceCatalogue` maps hardware identifiers (e.g. `iPhone17,2`) to human-readable names and specification constants for known models.

### ActivityStore
Persistent event log. Writes to `Application Support/SystemScope/activity.json` as a versioned `ActivitySnapshot`.

| File | Contents |
|------|----------|
| `ActivityModels.swift` | `ActivityEvent`, `ActivityAlert`, `ActivitySession`, `DeviceObservation`, `ActivitySnapshot` |
| `ActivityLog.swift` | `@MainActor` observable store: load, observe, record, alert generation, threshold logic, `clear(_:)` |
| `ActivityPersistence.swift` | `ActivityPersisting` protocol; `FileActivityPersistence`, `InMemoryActivityPersistence` |
| `SampleActivity.swift` | `SampleActivity.snapshot()` — a week of realistic synthetic data |

Alert types: battery low, storage low, thermal elevated/critical, network change, memory warning.

### OnboardingFeature
First-run flow. Five steps: Splash → Welcome → Permissions → Ready.

- `OnboardingModel` owns the step state and the `onFinish` closure.
- `OnboardingFlowView` renders each step with the Figma-spec full-bleed layout.
- `RootView` (AppShell) swaps the onboarding flow out for `MainTabView` as soon as `hasCompletedOnboarding` flips.

### HomeFeature
The landing tab. Shows a quick-look summary card, today's activity, and an Internet Speed Test entry point.

- `HomeModel` polls `DeviceInspecting` and `ActivityLog` for the summary values.
- `HomeInsightsProviding` supplies historical comparison text. In production builds it falls back to `ActivityInsightsProvider` (computed from the persisted log) until a backend exists.

### MonitorFeature
Live monitoring across seven metric screens reachable from the overview.

| Screen | Route |
|--------|-------|
| CPU overview + history chart | `.cpu` |
| Memory breakdown | `.memory` |
| GPU utilisation | `.gpu` |
| Battery level, state and history | `.battery` |
| Thermal state | `.thermal` |
| Storage usage | `.storage` |
| Network throughput | `.network` |

`MonitorModel` drives all screens. `userSettings` is a closure injected by `MainTabView` so the model never imports `Core` preferences directly.

Tiles the user hides are stored in `UserSettings.hiddenMonitorTiles` as route name strings.

### DeviceFeature
The Device tab: a full hardware profile for the current iPhone.

- `DeviceModel` loads `DeviceDetails` from `DeviceDetailsProviding`.
- Eleven detail screens cover: General, Processor, Memory, Display, Camera, Connectivity, Sensors, Battery, Operating System, Storage, and Graphics.
- `DeviceView` links each metric line to the matching Monitor screen via `onOpenMonitor` closures; `MainTabView` handles the navigation.
- Sheets (`deviceSheets`) are applied at the shell root so they survive `MainTabView` body updates.
- `identification` state: `.identified` when the catalogue has an entry, `.unidentified` when it only has a hardware identifier, `.unknown` when neither is available.

### StorageFeature
Detailed storage breakdown: app data, photos, documents, and duplicate detection.

| File | Contents |
|------|----------|
| `DocumentStorageAnalyzer.swift` | Scans document sizes in the app's container |
| `PhotoStorageAnalyzer.swift` | Reads photo library usage via `Photos` |
| `DuplicateMediaDetector.swift` | Hash-based duplicate photo detection |

### ActivityFeature
History and event log browser.

Navigation: Overview → Event Detail, Alerts list, Alert Detail, Sessions list, Session Detail, Search.

- `ActivityModel` reads `ActivityLog` and drives the feed.
- Filtering by category chip and date range; swipe-to-delete, mark-read.
- Sheets (`activitySheets`) applied at the shell root.
- `ActivityObserver` (AppShell) records events every 30 seconds and on `NSNotification` triggers while the app is in the foreground. iOS provides nothing in the background.

### SettingsFeature
Ten Settings screens plus the overview.

| Route | Screen |
|-------|--------|
| `.monitoring` | Refresh and display preferences |
| `.notifications` | Per-category notification toggles |
| `.thresholds` | Battery, storage and thermal alert levels |
| `.appearance` | Theme, compact layout, reduce animations |
| `.data` | History size, retention, export |
| `.export` | Copy device report as text |
| `.privacy` | Motion and notification permission status |
| `.support` | Feedback and help links |
| `.about` | Version, open-source licences |
| `.myDevice` | Rename the device; jump to Device tab |

`SettingsModel` takes all external dependencies as closures via `SettingsDependencies` so it never imports another feature.

Sheets (`settingsSheets`) applied at the shell root.

### SpeedTest
Internet speed test via a custom server protocol.

- `SpeedTestCoordinator` runs download and upload measurements against one or more `SpeedTestServerClient` instances.
- `SpeedTestMath` computes Mbps from raw byte counts and timing.
- `SpeedTestRepository` persists results to `Application Support` for the history chart.
- `UnconfiguredSpeedTest` is returned in production builds until `AppEnvironment.productionSpeedTestServers` is populated.

For development, `Tools/speedtest-dev-server.py` runs a local server. Pass its URL with `-SpeedTestServer http://<mac-ip>:8787`.

### AppShell
Assembles all features. Never imported by any feature module.

| File | Contents |
|------|----------|
| `AppEnvironment.swift` | Service container. `AppEnvironment.live()` creates all real providers; debug builds honour launch arguments |
| `RootView.swift` | Chooses between `OnboardingFlowView` and `MainTabView` |
| `MainTabView.swift` | Five-tab layout with the custom `SSTabBar`; sheet modifiers applied here |
| `ActivityObserver.swift` | Foreground background observer; `AlertNotifier` posts `UNUserNotificationCenter` requests |
| `ActivityInsightsProvider.swift` | Derives historical comparison text from the persisted `ActivityLog` |

---

## App Entry Point

```
SystemScopeApp (@main)
  └── RootView(environment: AppEnvironment.live())
        ├── OnboardingFlowView   (first run)
        └── MainTabView          (returning user)
              ├── Home tab       ← HomeView(model: HomeModel)
              ├── Monitor tab    ← MonitorView(model: MonitorModel)
              ├── Device tab     ← DeviceView(model: DeviceModel)
              ├── Activity tab   ← ActivityView(model: ActivityModel)
              └── Settings tab   ← SettingsView(model: SettingsModel)
```

Sheets that must survive tab switches are applied by `MainTabView`:
- `.speedTestSheet(model: home)`
- `.deviceSheets(model: device)`
- `.activitySheets(model: activity)`
- `.settingsSheets(model: settings)`

---

## User Preferences

`AppPreferences` (Core) owns three separate namespaces in `UserDefaults`:

| Key | Type | Reset scope |
|-----|------|-------------|
| `hasCompletedOnboarding` | `Bool` | Never (or `-ResetOnboarding`) |
| `deviceDisplayName` | `String` | "Reset local device profile" only |
| `settings` | `UserSettings` (versioned JSON) | "Reset preferences" |

`UserSettings.version = 1`. Future changes increment the version and migrate on first load.

---

## Debug Launch Arguments

All arguments are `DEBUG`-only and ignored in release builds.

| Argument | Effect |
|----------|--------|
| `-SkipOnboarding` | Mark onboarding complete at launch |
| `-ResetOnboarding` | Force first-run onboarding |
| `-UseSampleDevice` | Inject `Sample*` providers for all hardware reads |
| `-EmptyActivity` | Use an empty activity log (requires `-UseSampleDevice`) |
| `-OnboardingStep <step>` | Start onboarding at a named step |
| `-MonitorRoute <route>` | Open a Monitor detail screen at launch |
| `-DeviceRoute <route>` | Open a Device detail screen at launch |
| `-ActivityRoute <alerts\|sessions\|search>` | Open Activity on a sub-screen |
| `-SettingsRoute <screen>` | Open Settings on a sub-screen |
| `-SpeedTestServer <url>` | Point the speed test at a local server |

Set these in Xcode under **Product › Scheme › Edit Scheme › Run › Arguments**.

---

## CI

`.github/workflows/ci.yml` runs on every push and pull request to `main`.

1. Checks out the repository on `macos-15`.
2. Selects the newest available Xcode.
3. Picks any available iPhone simulator.
4. Builds `SystemScope.xcodeproj` with `xcodebuild build`.
5. Runs `xcodebuild test -scheme SystemScopeKit` for all package tests.

---

## Testing

Each module has a matching test target. Tests use `InMemoryActivityPersistence`, `Sample*` providers, and manual clocks — never real device APIs.

```
CoreTests
DeviceInfoTests
OnboardingFeatureTests
HomeFeatureTests
MonitorFeatureTests
DeviceFeatureTests
StorageFeatureTests
ActivityStoreTests
ActivityFeatureTests
SettingsFeatureTests
SpeedTestTests
```

---

## Key Conventions

**Unavailable values** — `DeviceDataResult<T>` distinguishes "unavailable on this hardware" from zero. Views never show `0` for a reading that cannot be taken; they show "Unavailable" or "—".

**No cross-feature imports** — features communicate through closures and protocols injected by `AppShell`. A feature never imports another feature.

**Root-level sheets** — sheets that must survive a `@State` update on the tab view are always attached with `.modifier()` in `MainTabView`, not inside the feature's own view tree.

**Swift 6** — the package compiles with `swiftLanguageModes: [.v6]`. All shared state crossing actor boundaries must be `Sendable` or use explicit isolation.

**Sample providers** — every real provider has a `Sample*` counterpart in `DeviceInfo` or `ActivityStore` for use in Xcode Previews and the `-UseSampleDevice` debug mode.

---

## Repository

Remote: `https://github.com/ozenua/SystemScope`  
Default branch: `main`  
Push status: not yet pushed (authentication pending for the `ozenua` account).

---

## What Is Not Yet Implemented

| Item | Note |
|------|------|
| Production speed-test servers | `AppEnvironment.productionSpeedTestServers` is an empty array; the speed test shows "unavailable" until this is populated |
| StoreKit / premium | `SamplePremiumOffering` is wired in. Real StoreKit configuration is deferred to a later milestone |
| Terms of Use / Privacy Policy URLs | `SettingsLinks` is empty; the footer links are hidden until real URLs are set |
| Push to GitHub | The remote exists; the first push is blocked on the `ozenua` GitHub account credentials |
