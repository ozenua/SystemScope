# SystemScope

Native iPhone app (SwiftUI, Swift 6, iOS 17+). The implementation baseline is
[docs/SystemScope-Developer-PRD-v1.2.md](docs/SystemScope-Developer-PRD-v1.2.md).

## Layout

```
SystemScope.xcodeproj        App target (thin: @main, asset catalog, privacy manifest)
SystemScope/
Packages/SystemScopeKit/     All product code, one SwiftPM target per module
  Sources/
    Core/                    Scope/status types, DeviceDataResult, AppPreferences
    DesignSystem/            Tokens, typography, buttons, components, Figma assets
    DeviceInfo/              DeviceInspecting, system + sample providers, device catalogue
    OnboardingFeature/       First-run flow (model, screens, strings)
    SpeedTest/               Speed-test engine: server client, measurements, coordinator, history
    HomeFeature/             Home, Network, Data Usage, GPU, speed-test screen
    MonitorFeature/          Monitor overview and the seven metric screens (MON-01 to MON-08)
    DeviceFeature/           Device overview, ten detail screens and sheets (DEV-01 to DEV-13)
    ActivityStore/           ActivityLog: events, alerts, sessions, settings; local JSON persistence
    ActivityFeature/         Activity feed, alerts, sessions, search, filters, settings (ACT-01 to ACT-10)
    SettingsFeature/         Settings overview and its 13 screens (SET-01 to SET-14)
    AppShell/                AppEnvironment (dependency injection), RootView, tab shell
  Tests/
```

Module rules follow PRD §4.2: features depend on Core, DesignSystem and service
protocols, never on each other. Add a target when a milestone needs it.

## Build, run, test

Open `SystemScope.xcodeproj` and run the `SystemScope` scheme, or:

```bash
xcodebuild -project SystemScope.xcodeproj -scheme SystemScope -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
cd Packages/SystemScopeKit && xcodebuild test -scheme SystemScopeKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Debug-only launch arguments:

| Argument | Effect |
|---|---|
| `-ResetOnboarding` | Show onboarding again |
| `-SkipOnboarding` | Go straight to the tabs |
| `-UseSampleDevice` | Use the Figma sample values (device, network, usage) instead of real reads. Never fakes a speed test |
| `-MonitorRoute <screen>` | Open a Monitor screen at launch: `cpu`, `memory`, `gpu`, `storage`, `battery`, `thermal` or `network` |
| `-DeviceRoute <screen>` | Open a Device screen at launch: `general`, `processor`, `memory`, `display`, `camera`, `connectivity`, `sensors`, `battery`, `operatingSystem` or `graphics` |
| `-SettingsRoute <screen>` | Open the Settings tab: `overview`, `device`, `monitoring`, `notifications`, `thresholds`, `appearance`, `data`, `export`, `subscription`, `privacy`, `support` or `about` |
| `-ActivityRoute <screen>` | Open the Activity tab: `overview`, `alerts`, `sessions` or `search` |
| `-EmptyActivity` | With `-UseSampleDevice`, start with no activity history |
| `-SpeedTestServer <url>` | Run speed tests against this server, e.g. `http://127.0.0.1:8787` |
| `-OnboardingStep <step>` | Start at `splash`, `intro`, `meetDevice`, `monitoring`, `inspect`, `ready` or `premium` |

## Implementation notes and deviations

Recorded here per PRD §0 until the decision log has a home.

- **Fonts.** Figma uses Inter and Neue Montreal; the app uses system SF (PRD §3.3).
  Headings are constrained to the designed line count at standard text sizes.
- **Light only.** Onboarding is locked to light appearance; dark tokens wait on D-01.
- **Scan progress.** The Figma frame draws five progress segments for six categories;
  the app draws one per category. Each category stays "In progress" for at least
  450 ms so the list is readable; the reads themselves are real.
- **Honest scan states.** Categories that are not fully read show "Partial",
  "Not supported" or "Unavailable" rather than "Complete". Network is always partial
  until the `getifaddrs` gate (§7.2) passes. The ready screen adds a one-line note
  when anything is unavailable (ONB-09); that line is not in Figma.
- **Memory tile.** Falls back to physical memory when "in use" cannot be read.
- **Device catalogue** is provisional (`0.1-provisional`): names from Xcode device
  types, chip names unverified. Needs D-11.
- **Premium.** No StoreKit yet (M6). Debug shows sample plans; Release shows
  "Plans aren't available". Purchase, restore and the legal links show a notice.
- **Back icon** is the SF Symbol `chevron.left`; Figma references a Material icon.
- **Tab bar** is the `SSTabBar` component in DesignSystem with the Figma icons.
  Home and Monitor use their filled icons when selected and every icon stays white,
  as designed. Device, Activity and Settings have no filled icon in the frames
  pulled so far, so when one of them is selected the others dim to 50%.
  Device and Activity are placeholders; Settings has "Replay onboarding".
- **Settings: storage.** Preferences are one versioned `UserSettings` document in
  UserDefaults (`AppPreferences.settings`). Reset preferences (SET-14) restores it and
  keeps the device name, onboarding state, first-registered date and all history.
- **Settings: what each preference does.**
  - **Monitoring (SET-03):** refresh on entry, auto-refresh every 15 s, the Trends
    section and the "Show on Monitor" tiles are applied by Monitor. Session summaries are
    the Activity "record sessions" switch. There is no background interval.
  - **Thresholds (SET-05):** battery (5–50%, step 5) and storage (5–30%) thresholds and
    the minimum thermal state feed the alert rules. Changes are a draft with Save;
    leaving with unsaved changes asks to save or discard.
  - **Notifications (SET-04):** alerts post a local notification only when the master
    switch, the category and iOS permission all allow it. When iOS denies permission,
    the screen says so and links to the app's page in iOS Settings.
  - **Reduce animations** disables animations app-wide.
- **Settings: stored but not applied yet.** Compact layout, metric descriptions and
  technical values are saved, but no screen reads them yet.
- **Settings: deviations.**
  - **Theme:** Light only. Dark and System are shown as "Soon" until D-01 settles the
    dark palette.
  - **Subscription:** no StoreKit entitlement exists (M6), so Settings always shows the
    free state, never "Active". Restore calls the existing premium service.
  - **Data & History:** sizes are measured by encoding the stored records. "Monitoring
    history" and "observations" from Figma are omitted because no observations are
    stored yet. Clear history (SET-13) covers activity, alerts and sessions, and never
    removes an active session.
  - **Export (SET-08):** CSV or JSON plus a plain-text device report; PDF is not built.
  - **Privacy (SET-10):** only Notifications and Motion & Fitness are listed. SystemScope
    never asks for camera or location, so those Figma rows are not shown.
  - **Links:** support, help, terms, privacy policy and website rows appear only when
    `AppEnvironment.settingsLinks` provides them. None exist yet, so no placeholder URLs
    ship. Diagnostics are copied or attached only on the user's action.
  - **Loading and save-failed states:** not built. Settings read synchronously from
    UserDefaults, which has no failure path.
  - **Replay onboarding** moved to the overview's More menu.
- **Activity: what is recorded.** iOS gives SystemScope no background readings, so
  activity is recorded only while the app is in the foreground: battery, storage,
  network and thermal every 30 seconds and on system notifications, memory warnings,
  completed speed tests and Monitor sessions. The first reading after launch is a
  baseline, never an event. Sample data (`-UseSampleDevice`) fills the Figma history.
- **Activity: alerts.** Battery at or below 20% while unplugged (information), free
  storage at or below 10% (attention), Serious or Critical thermal state (attention or
  critical). One open alert per condition. Read and resolution states are separate;
  opening never resolves (ACT-04, ACT-05). There is no `expired` state: no expiry
  policy exists. Figma's "your 50 GB threshold" is not user-configurable yet.
- **Activity: sessions** come from the Monitor tab's live session. Leaving the tab ends
  it as completed; leaving the app ends it as interrupted. Sessions left active by a
  previous launch are marked interrupted on the next launch. All sessions are
  "Performance monitoring": Network and Battery sessions need monitors that do not
  exist yet.
- **Activity: persistence** is one versioned JSON document in Application Support
  (`completeUntilFirstUserAuthentication`), not SwiftData as PRD §3 proposes. Retention
  (7, 30, 90 days or forever) runs on load and on change; open alerts are never pruned.
  Clear history removes events only and writes before updating the screen, so a
  failure leaves everything as it was (ACT-10, ACT-11).
- **Activity: swipe actions** are a custom gesture on the card rows (Figma's cards are
  not a List). Every swipe action is also in the long-press menu, VoiceOver actions and
  the detail screen (ACT-12).
- **Activity: omitted.** The "Custom" date range in Filters (no date picker designed),
  Figma's Wi-Fi network name (not recorded), and "Previous speed test" rows beyond the
  previous event of the same kind.
- **Activity sheets** are presented from the shell root (`activitySheets(model:)`), for
  the same reason as the Device sheets.
- **Device: catalogue specifications.** Screen size, pixel density, panel, chip
  process, transistors, GPU and Neural Engine cores, memory type, radio standards
  (Wi-Fi, 5G, Bluetooth, NFC, UWB, GNSS, satellite), port and charging have no public
  API. They come from `DeviceSpecifications` in the catalogue, which stays empty until
  the D-11 source is decided, so real devices show "Not in catalogue" (DEV-05, DEV-06).
  `-UseSampleDevice` fills them with the Figma values.
- **Device: live readings.** Display (resolution, scale, maximum refresh rate, EDR
  headroom for HDR, P3, brightness), cameras (megapixels, aperture, frame rate, HDR,
  zoom from the virtual device's switch-over factors), sensors, OS build (parsed from
  `operatingSystemVersionString`), locale and time zone are read on device. Cameras are
  enumerated without camera permission (DEV-14); Face ID is checked without a prompt.
- **Device: sensor tests** (DEV-11 to DEV-13) exist for the accelerometer, gyroscope,
  magnetometer and barometer, run for 5 seconds only after "Run Test", and pass when
  readings arrive. The barometer test triggers the Motion & Fitness prompt
  (`NSMotionUsageDescription` added). Other sensors show what iOS reports and say that
  this does not mean faulty. Ambient light is always "Unknown": no public API.
- **Device: omitted from Figma.** Device uptime (a required-reason API with no fitting
  reason), "Airplane Mode off" (not readable), battery "Historical observations" (no
  stored history yet), and every Settings button (Open About, Display & Brightness,
  Camera, Software Update, Battery Health): iOS has no public deep links, so the
  screens name the Settings path instead.
- **Device: rename** allows 40 characters (PRD §2.3); Figma's counter shows 32.
- **Device: identification.** "Identified" means the hardware identifier is in the
  provisional catalogue; the Device record row says "Catalogue match" rather than
  Figma's "Verified" until D-11 closes. Unknown identifiers show the information banner
  and "Unknown iPhone model" (DEV-04).
- **Device: first registered** is the first launch of SystemScope, stored locally.
- **Device: architecture** is the instruction set the app runs as (`arm64`), not
  Figma's `arm64e`, which only system binaries use.
- **Device: sheets** are presented from the shell root (`deviceSheets(model:)`), next
  to the speed-test sheet. Presented from inside the tab, they were dismissed whenever
  the root's sheet modifier updated.
- **Monitor: scope.** The overview (MON-01) and all seven metric screens (MON-02 to
  MON-08) are built; each tile opens its screen. Not built: the "inspect measurement"
  drag interaction, the alert detail, "View history" / "View all" destinations, and the
  redesigned speed-test consent and results sheets (the existing sheet is reused).
- **Monitor: live session.** While the Monitor tab is visible and the app is active,
  one session samples app CPU and device memory every second and re-reads everything
  every 15 s. It carries across Monitor screens and ends on leaving; nothing is stored.
  The Live charts show the last 60 s of that session. Every other range (5 min to
  30 days) shows what the session has covered, or "Not enough history yet".
- **Monitor: app CPU** (MON-02) is getrusage CPU-time delta over elapsed time, as a
  share of all active cores. "Low / Moderate / High" is under 20% / under 50% / above.
  Provisional: D-03 gate.
- **Monitor: memory** (MON-03) shows wired, active and compressed side by side and
  never sums them into free memory. Its status pill reads "This iPhone" (a scope
  label), not the design's "Normal", because there is no defined rule for "normal".
  The app bar compares SystemScope's footprint with physical RAM; the rest is labelled
  "not visible to apps" instead of the design's "Rest of iPhone · 4.9 GB".
- **Monitor: GPU** (MON-04) chips list only what Metal reports (ray tracing, unified
  memory, float filtering, BC textures). Mesh shaders, MetalFX, Dynamic Caching and
  the GPU core count are not detectable and are left out. MetricKit reports are not
  collected, so Performance reports is empty.
- **Monitor: no Settings deep links.** iOS has no public link to iPhone Storage or
  Battery settings, so "Manage Storage" is omitted and "Battery Health · Open in
  Settings" is plain text.
- **Monitor: battery** (MON-06) replaces "Plugged in 9:12 AM" with the reading time:
  iOS doesn't report when charging started.
- **Monitor: thermal** (MON-07) "Recent changes" lists changes observed this session.
- **Monitor: network** (MON-08) health is from the current connection, not the last
  speed test. The hourly traffic bars need history and are replaced by a note. The
  Wi-Fi name needs Apple's entitlement, not Location, so the note says that.
- **Monitor: recommendations** appear only when a reading triggers them (storage free
  at or below 30%, battery at or below 20% and unplugged, thermal above Nominal).
- **Monitor: Premium lock** ("Monitor is part of Premium") is not built. It conflicts
  with the PRD's proposed matrix (§11.2), where current Monitor values are free, and
  there is no entitlement service until M6.
- **Monitor: history sections.** Alerts, Trends and Recent activity need stored
  alerts, observations and sessions, which do not exist yet. With real data they show
  empty states; the designed content only appears with sample data.
- **Monitor: Processor tile.** Core count is `ProcessInfo.processorCount`. The
  performance/efficiency split needs a sysctl read behind the §7.2 gate, so it is
  only shown with sample data. The tile's sparkline is empty in Figma and is omitted.
- **Monitor: GPU tile** shows the Apple GPU family but not a GPU core count, which
  Metal does not report.
- **Monitor: Recommended.** Rules: free storage at or below 30% suggests a review;
  battery at or below 20% and not charging suggests Low Power Mode. The chevron is
  left off because there is nowhere to go yet.
- **Monitor: sampling.** Refreshes on entry, on pull or the refresh button, and every
  15 s while the tab is visible and the app is active. "Stale" tile states are not
  built. "Standard monitoring" is shown as designed; its meaning is not defined.
- **Shell: status bar.** A white backdrop sits behind the status bar so scrolled
  content does not show through it.
- **Home: Performance card.** iOS has no public device-wide CPU/GPU load (PRD §1.5),
  so with real data the card says so. The designed bars only appear with sample data.
- **Home: Memory.** Reads `host_statistics64` (active + wired + compressor pages).
  Provisional: not yet through the §7.2 physical-device gate.
- **Home: Network counters.** Read with `getifaddrs` (en0 = Wi-Fi, pdp_ip* =
  cellular), cumulative since the counters last reset, 32-bit. Provisional, same gate.
  The Wi-Fi name is not read (needs the Access Wi-Fi Information entitlement), so the
  card shows the interface type instead.
- **Home: Data usage chart** needs recorded history, which does not exist yet. Real
  data shows the since-restart total and "Not enough history yet". The 6 Months and
  1 Year ranges exceed the PRD's proposed retention options (§8.4).
- **Home: Network screen** follows the later Figma variant (Run Speed Test in the top
  bar, Network health at the bottom). "Network health" is derived from the path only.
- **Home: "Temperature" card** keeps the Figma title but shows only the iOS thermal
  state, never degrees.
- **Home: low-battery card colours** are matched by eye; that frame's values were
  not pulled from Figma.
- **Home: overall status** adds Attention, Critical and Partial states (HOME-06);
  Figma only draws Healthy. Tiles other than Network do not navigate yet.
- **Battery.** `BatteryMonitor` (DeviceInfo) reads UIDevice and updates from the
  battery change notifications, no polling. Home overlays its live reading on the
  scanned summary and re-reads when the app returns to the foreground. State is a
  typed enum rather than the dev note's `String` (PRD §8.2: no stringly-typed states).
- **GPU.** `GPUInformationProvider` reads the default Metal device's name, family and
  capabilities, and lists counter sets where supported. It is read during the scan's
  "Display & cameras" step (no separate row, to keep the designed six) and on Home
  refresh. `deviceWideUtilisation` is always nil. `GPUPerformanceMonitor` can time a
  real Metal command buffer, but SystemScope submits no GPU work, so nothing calls it
  and "SystemScope GPU Activity" never appears yet.
- **GPU screen** (tap the Performance card) has no Figma frame; it reuses Home
  components as a placeholder until one is designed.
- **Speed test: no production server.** `AppEnvironment.productionSpeedTestServers`
  is empty, so shipped builds say the speed test is unavailable. The backend
  (HTTPS, regions, rate limits) and the provider decision (D-06) are still needed.
  The endpoint contract is documented on `SpeedTestServerClient`.
- **Speed test: local dev server.** `python3 Tools/speedtest-dev-server.py 8787 8`
  serves the contract on loopback, throttled to 8 Mbps per connection; pair it with
  `-SpeedTestServer http://127.0.0.1:8787`. Development only.
- **Speed test: method.** Download counts bytes as received over 4 connections;
  upload counts only server-confirmed bytes over 3. Payloads double per request.
  Each phase stops at its time limit or data budget (Quick 15 MB, Standard 45 MB).
  The first 20% of the download window is left out as ramp-up. Latency is the median
  HTTP round trip from URLSessionTaskMetrics; jitter is the mean absolute difference
  of consecutive samples. Loaded latency is sampled during each transfer rather than
  as a separate phase.
- **Speed test: not built.** Packet loss (always "Unavailable"), the Advanced
  profile, history trends/comparison/filtering/export, and "Reconnecting" as a
  distinct connection state. History is a list with delete.
- **Speed test: result model** uses typed enums instead of the note's strings, and
  has no `status` field because only completed tests are stored. History is a JSON
  file in Application Support until the SwiftData Persistence module exists.
- **Speed test: shared sheet.** The sheet is attached at the tab shell so Home and
  Monitor both open it.
- **Speed test: screens.** Only the running state has a Figma frame. Ready, results,
  failure and history are built from existing components.
- **Not set up:** CI (D-12), lint/format tooling, app icon, signing team.
