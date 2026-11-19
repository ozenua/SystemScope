# SystemScope --- Developer Product Requirements Document

  -----------------------------------------------------------------------
  Field                               Value
  ----------------------------------- -----------------------------------
  Product                             SystemScope

  Document                            Developer PRD

  Version                             1.2

  Status                              Implementation baseline --- subject
                                      to the release gates in this
                                      document

  Date                                16 November 2026

  Platform                            iPhone, portrait-first, native iOS

  Minimum OS                          iOS 17.0 proposed; confirm against
                                      the final device-support decision

  Design source                       Figma file
                                      `iD27dtBjMydBFMwol7QilV`; UI design
                                      and COMPONENTS pages

  Supersedes                          SystemScope-Dev-PRD.md v1.0

  Product model                       Paid subscription; local-first; no
                                      user account

  Audience                            iPhone users who want
                                      understandable device information
                                      and honest, limited-scope
                                      monitoring
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 0. How to use this document

This PRD is the implementation source of truth for SystemScope v1.2. It
translates the product and approved UI direction into requirements that
engineering, design, QA and product can estimate, build and verify.

**Requirement language** - **MUST**: required for v1 acceptance. -
**SHOULD**: expected unless an approved exception is recorded. -
**MAY**: optional or deferred. - **TBD / decision**: must be resolved by
the named gate before the affected feature is released.

Where this document and a Figma screen disagree: 1. Product truth and
iOS platform constraints in this PRD take precedence over a visual that
implies impossible access. 2. The approved Figma COMPONENTS page is the
visual source of truth after the visual-direction decision in §2.6 is
signed off. 3. Record all deviations in the decision log. Do not
silently improvise.

This is a complete product and engineering requirements document, not a
guarantee that every listed iOS API is available on every device or
accepted for every distribution configuration. Every restricted API
requires a physical-device feasibility check and App Review readiness
check before release.

## 1. Product overview

### 1.1 Product summary

SystemScope is a device-wide iPhone information and monitoring hub. Its
primary job is to inspect the iPhone and consolidate the hardware
specifications, operating-system information, resource statistics,
connectivity details, sensor capabilities and other diagnostic
information that iOS makes available to an ordinary third-party app.

Users should not have to navigate multiple iOS Settings screens or
individual technical menus to find supported device information.
SystemScope performs a foreground device scan, organises the results
into a single, understandable interface, refreshes dynamic readings
when the app is active, and keeps a local history where sampling is
supported.

The product distinguishes:
- **Device-wide readings:** aggregate iPhone-level values exposed through
  supported APIs, such as physical memory statistics and validated
  network-interface counters.
- **Device specifications:** hardware and software facts read directly
  or resolved through a maintained, confidence-labelled device catalogue.
- **App-only diagnostics:** resource usage attributable only to
  SystemScope, clearly separated from device-wide readings.
- **Unavailable information:** values Apple does not expose to
  third-party apps, or values that cannot be reliably identified on the
  current device/OS.

All personal readings and history are stored locally in v1. SystemScope
does not claim unrestricted access to iOS internals, other apps' private
data, or every value displayed in Apple's own Settings app.

SystemScope is **not** a system cleaner, memory booster, battery-health
diagnostic, unrestricted system monitor or device-tuning utility.

### 1.2 Product principles

1.  **Device-wide inspection first.** Prefer supported iPhone-level
    readings and specifications over app-only metrics. The central
    experience is one consolidated device scan.
2.  **Truth over completeness.** Never invent a metric or imply
    system-wide access when only app-level data is available.
3.  **Scope is always visible.** Label device-wide, app-only,
    catalogue-derived, estimated/derived and unavailable values.
3.  **Foreground-first monitoring.** Live sampling is active only while
    the relevant app screen is visible. Background checks are
    opportunistic, never guaranteed.
4.  **Local-first privacy.** No account and no server-side storage of
    personal monitoring history in v1.
5.  **Explain limitations.** An unavailable value is a product state,
    not a failure to be hidden.
6.  **Low overhead.** Monitoring must not materially increase the
    resource use it reports.
7.  **Accessible by default.** Dynamic Type, VoiceOver, contrast, Reduce
    Motion and clear language are part of acceptance.

### 1.3 Navigation

The app has five primary tabs:

  Tab        Purpose
  ---------- ----------------------------------------------------------
  Home       At-a-glance device overview and entry points
  Monitor    Current observable metrics and monitoring sessions
  Device     Static hardware, software and capability information
  Activity   Historical events, alerts and sessions
  Settings   Preferences, permissions, data, subscription and support

First-run onboarding and the Premium paywall are flows outside the tab
bar.

### 1.4 v1 goals

-   Deliver a useful and honest device overview.
-   Present the iPhone's identifiable specifications with
    source/confidence labels where appropriate.
-   Consolidate all supported device-wide specifications, system
    information, resource statistics and diagnostic capabilities in one
    place.
-   Show app-only diagnostics only as a clearly separate secondary
    category; never substitute them for device-wide readings.
-   Provide useful foreground monitoring and a local activity history.
-   Support configurable alert thresholds with honest notification
    limitations.
-   Offer user-initiated speed testing only after provider, privacy and
    data-use decisions are approved.
-   Support local export and an auto-renewable Premium subscription.
-   Deliver a coherent, accessible light and dark experience.

### 1.5 Non-goals

-   Reading other apps' private data or per-process metrics.
-   System-wide CPU/GPU utilisation where iOS exposes no supported
    public measurement API.
-   Per-app network traffic for other installed apps.
-   Accessing private iOS internals, private frameworks or protected
    system databases.
-   Clearing RAM, killing apps, cleaning storage, changing hidden system
    settings or boosting performance.
-   Battery temperature, battery health percentage or cycle count unless
    Apple exposes an approved public API in a future OS.
-   Continuous background monitoring or guaranteed background alerts.
-   User accounts, cloud sync, server-side personal history or
    third-party behavioural analytics.
-   iPad/Mac-specific layouts, widgets, Live Activities, Apple Watch,
    Shortcuts or App Intents in v1.
-   Advanced diagnostics that require private APIs or unsupported
    hardware access.

## 2. Decisions and product boundaries

### 2.1 Locked product decisions

-   Product name: SystemScope.
-   Platform: native iPhone app.
-   Product priority: monitoring first; advanced diagnostics later.
-   Information density: simple and accessible.
-   Data model: local-first, no account.
-   Monetisation: paid auto-renewable Premium subscription with a free
    preview/free tier as defined in §11.
-   System access: public APIs and approved entitlements only.
-   No hidden system tweaking or performance claims.

### 2.2 Monitoring versus device information

Keep these concepts separate in every screen and data record:

-   **Monitor:** time-sensitive readings and observations. Each reading
    has a timestamp, source and scope.
-   **Device:** hardware/software facts and catalogue-backed
    capabilities. These are not live performance readings.
-   **Activity:** events and completed/interrupted monitoring sessions
    over time.
-   **Home:** concise summary, not a second full Monitor screen.

### 2.3 Device naming

Third-party iOS apps must not assume they can read the user's chosen
device name. The app MUST use a local display name: - Default:
`My iPhone`. - User may edit it to a maximum of 40 characters. - Trim
leading/trailing whitespace. - Reject empty or whitespace-only values. -
Store locally and use consistently across Home, Device, Activity and
exports. - Never claim the local display name is the iOS Settings device
name.

### 2.4 Measurement scope labels

Every metric must have one of these scopes:
- `This iPhone`: aggregate/device-level value exposed by an API, such as
  host memory statistics or validated interface byte counters.
- `This app`: measured only for SystemScope's own process or requests.
- `Device specification`: a hardware/software fact read directly or
  resolved from a verified catalogue.
- `Estimated/derived`: calculated from explicitly identified inputs,
  with method and confidence disclosed.
- `Unavailable`: not exposed, not reliable, or not currently obtainable.

The Home dashboard, first-run scan and Device/Monitor sections MUST
prioritise `This iPhone` and `Device specification` information.
`This app` values belong in a clearly labelled app-diagnostics subsection
and must never be presented as the phone's overall resource usage.

### 2.5 Visual source of truth --- decision required

The earlier product direction used warm off-white backgrounds and pastel
metric cards. The v1.0 engineering document cites a 15 November Figma
surface revision that retires pastel surfaces in favour of white/clear
cards and outlined components.

**Release gate D-01:** Product Design must confirm the authoritative
visual direction and update Figma documentation before UI implementation
is considered visually approved. Until signed off, do not independently
combine the two systems. All screens, components, empty states, charts
and dark mode must follow one approved token set.

### 2.6 Platform truth table

| Area | Allowed v1 behaviour | Must not claim |
|---|---|---|
| CPU | Processor specifications and core topology from verified sources; SystemScope process CPU only if validated | Total iPhone CPU utilisation or per-process breakdown |
| Memory | Device-wide physical RAM and host VM statistics where `host_statistics64` is validated; app footprint separately | Exact RAM use by every individual app or an invented per-app breakdown |
| GPU | GPU name/family/capabilities through Metal | Live GPU utilisation, clock or per-app GPU load |
| Storage | Consistent device-volume capacity values exposed by Foundation | Full iOS Settings category-by-category storage breakdown or access to other app containers |
| Battery | Device battery level/state and Low Power Mode | Battery health, cycle count, temperature or remaining battery time unless a future public API supports them |
| Thermal | iOS thermal state | CPU/GPU/battery temperature in °C/°F |
| Network | Aggregate interface byte counters through `getifaddrs`/`if_data` only after validation; path/interface state through Network framework | Per-app traffic for other apps, exact carrier billing totals, or guaranteed uninterrupted historical coverage |
| Wi-Fi | Interface/path details; SSID only when Apple's entitlement and qualifying access conditions are satisfied | Guaranteed SSID access or signal strength in dBm |
| Sensors | Hardware/API capability, permission state and explicit supported test results | Failure diagnosis solely from unavailable access |
| Background | Opportunistic snapshots when iOS grants execution | Continuous sampling or guaranteed real-time background alerts |

SystemScope MUST not hide a capability simply because it is not
available on every device. It should show a clear `Unavailable`,
`Permission needed`, `Not supported` or `Not verified` state as
appropriate, while preserving the rest of the device scan.

## 3. Technology stack

### 3.1 Recommended stack

  -----------------------------------------------------------------------
  Concern                 Technology              Requirement
  ----------------------- ----------------------- -----------------------
  Language                Swift 6                 Use strict concurrency
                                                  checks where practical;
                                                  isolate UI state to
                                                  MainActor

  UI                      SwiftUI                 UIKit bridging only for
                                                  a justified platform
                                                  gap

  State                   Observation framework   Feature state must be
                                                  explicit and testable

  Persistence             SwiftData               Local store; no
                                                  CloudKit in v1

  Preferences             UserDefaults /          Centralised defaults
                          AppStorage behind typed and migrations
                          preferences interface   

  Charts                  Swift Charts            Accessible descriptions
                                                  and truthful gaps

  System/device APIs      Foundation, UIKit,      Public APIs only;
                          ProcessInfo, Metal,     permissions requested
                          Network, CoreMotion,    contextually
                          AVFoundation,           
                          LocalAuthentication as  
                          needed                  

  Networking              URLSession + Network    Only for explicit speed
                          framework               test in v1

  Purchases               StoreKit 2              Verified transaction
                                                  and entitlement
                                                  handling

  Notifications           UserNotifications       Local notifications
                                                  only

  Background work         BackgroundTasks         Best-effort
                                                  maintenance/refresh
                                                  only

  Diagnostics             MetricKit               Optional,
                                                  privacy-reviewed; no
                                                  live system telemetry

  Logging                 os.Logger               Redact identifiers and
                                                  user data

  Export                  Foundation file APIs;   Local generation and
                          PDF rendering with      iOS share sheet
                          supported Apple APIs    

  Dependencies            Swift Package Manager   No third-party runtime
                                                  SDKs unless approved

  Tests                   Swift Testing,          Unit, integration, UI,
                          XCTest/XCUITest         accessibility and
                                                  physical-device
                                                  validation

  CI/CD                   Xcode Cloud preferred;  Choose one before M0
                          GitHub Actions +        
                          fastlane acceptable     

  Distribution            TestFlight and App      App Store policies and
                          Store                   privacy declarations
                                                  must be verified before
                                                  release
  -----------------------------------------------------------------------

### 3.2 Deployment target

-   Proposed minimum: **iOS 17.0**.
-   Product and engineering MUST confirm the minimum supported iOS
    version before M0.
-   Build using the current stable Xcode and SDK supported at submission
    time.
-   Test minimum supported OS, current OS and previous major OS where
    available.
-   Do not raise the minimum OS merely to simplify implementation
    without install-base and product approval.

### 3.3 Fonts and layout

-   Use system SF fonts; do not bundle Inter solely to imitate design
    references.
-   Use monospaced system typography for identifiers and technical
    values.
-   All text styles must support Dynamic Type. Avoid fixed-height text
    containers.
-   Minimum interactive target: 44 × 44 pt.
-   Layout must work on supported iPhone sizes in portrait; landscape
    behaviour must be defined rather than accidentally broken.

## 4. Application architecture

### 4.1 Architectural shape

Use a modular SwiftUI application with feature boundaries and
protocol-driven access to platform services.

``` text
SystemScopeApp
 ├─ AppShell
 │   ├─ TabNavigation
 │   ├─ RouteCoordinator
 │   └─ AppEnvironment
 ├─ DesignSystem
 ├─ Core
 ├─ DeviceInfo
 ├─ Metrics
 ├─ Monitoring
 ├─ Persistence
 ├─ Alerts
 ├─ Notifications
 ├─ SpeedTest
 ├─ Store
 ├─ Export
 └─ Features
     ├─ Onboarding
     ├─ Home
     ├─ Monitor
     ├─ Device
     ├─ Activity
     └─ Settings
```

### 4.2 Dependency rules

-   Feature modules depend on Core, DesignSystem and service protocols.
-   Feature modules MUST NOT directly depend on other feature modules.
-   Platform APIs are accessed through provider protocols.
-   Persistence is accessed through repositories; views must not query
    SwiftData directly.
-   UI views render state and send user intents. They do not own
    sampling, alert rules or subscription decisions.
-   Use dependency injection so previews and tests can use deterministic
    fake providers.
-   Avoid creating abstractions for hypothetical future features; keep
    boundaries useful and small.

### 4.3 Concurrency and lifecycle

-   UI-facing observable state is MainActor-isolated.
-   Long-running sampling, aggregation and persistence work must not
    block the main thread.
-   Use actors or equivalent isolation for mutable sampling/session
    services.
-   Sampling subscriptions must start when a relevant screen becomes
    visible and stop/cancel when it is no longer visible.
-   On app backgrounding, stop foreground live streams and close or
    interrupt active sessions according to §8.
-   Handle app termination without assuming `deinit` or a final callback
    will run.

### 4.4 Navigation

-   Root navigation: five tabs --- Home, Monitor, Device, Activity,
    Settings.
-   Each tab owns a navigation stack or equivalent state-preserving
    navigation context.
-   Preserve scroll position when navigating to a detail and back.
-   Use sheets for short tasks: filters, rename, information, speed-test
    consent/results and selection.
-   Use confirmation dialogs/modals for destructive actions.
-   Notification taps must route to the correct alert detail when the
    referenced record still exists; otherwise show a safe fallback to
    Activity.
-   Deep links are internal routing contracts. Define and test route
    identifiers before enabling external URL schemes.

## 5. Design system and UI implementation requirements

### 5.1 Design source

Figma file: `iD27dtBjMydBFMwol7QilV`. - `UI design`: screen layouts and
states. - `COMPONENTS`: reusable component definitions. - Any design
board referenced by the file must be checked for current status. -
Engineering must not invent missing screen designs. Raise a design task
and use the nearest approved component only as a temporary
implementation placeholder.

### 5.2 Design system components

Implement reusable equivalents for: - Tab bar and screen headers. -
Section headers and grouped settings cards. - Standard, navigation,
action, copyable and expandable rows. - Toggle, selection and slider
rows. - Permission rows. - Status badges and information banners. -
Device identity/profile card. - Subscription card. - Confirmation modal
and bottom sheet. - Export category row. - Activity timeline, alert and
session cards. - Summary cards and category/filter chips. - Search
field. - Empty, unavailable, unsupported, permission and error states. -
Time-range selector, timestamp and refresh control. - Recommendation
row. - Rename-device sheet.

Each component must have documented variants, accessible labels,
light/dark previews and at least one accessibility Dynamic Type preview.

### 5.3 Component behaviour

-   Status must never be communicated by colour alone.
-   Disabled controls must explain why they are unavailable where that
    explanation is useful.
-   Loading indicators must not imply progress percentages unless
    progress can be measured.
-   Empty, unavailable, unsupported, permission-required, stale and
    error are distinct states.
-   Destructive actions require confirmation and a clear scope
    statement.
-   Copy actions provide confirmation and copy only the value the user
    selected.
-   Haptics are optional, subtle and must respect system settings.

### 5.4 Accessibility

-   Dynamic Type through accessibility sizes; content reflows without
    clipping.
-   VoiceOver order follows visual hierarchy.
-   Announce metric name, value, unit, scope and freshness where
    meaningful.
-   Charts need accessible summaries and data alternatives.
-   Controls expose value, state and action.
-   Contrast target: WCAG AA-aligned (4.5:1 normal text, 3:1 large text
    and meaningful non-text UI).
-   Support Reduce Motion and the in-app Reduce Animations preference.
-   Do not rely on colour, animation, sound or haptics as the sole
    signal.

## 6. Functional requirements by feature

### 6.1 Onboarding

Screens: onboarding introduction, Meet Your Device, Set Up Monitoring,
Inspect Your Device, Your Device Is Ready, Premium.

Requirements: - ONB-01: Show first-run onboarding once; persist
completion locally. - ONB-02: Explain the product's actual monitoring
limits before asking for notification permission. - ONB-03: Do not
request a permission simply to display a static hardware
specification. - ONB-04: Ask for notification permission contextually,
with Skip. - ONB-05: Do not request location, camera, photos or motion
permissions during generic onboarding. Request only when the user starts
a feature that requires them. - ONB-06: Initial device inspection may
read supported static device information and take one foreground
snapshot of available metrics. - ONB-07: Display progress by category
only where work is actually measurable; otherwise use indeterminate
progress. - ONB-08: Unavailable information must be shown as
unavailable, never as zero or fabricated. - ONB-09: The ready screen
summarises what was identified and what iOS does not expose. - ONB-10:
Paywall can be dismissed using the approved free-preview/free-tier
action. - ONB-11: Replaying onboarding from Settings must not erase user
preferences or history.

Acceptance: - A user can complete onboarding without granting optional
permissions. - The first-run scan reads all supported device information
and clearly reports partial/unavailable categories. - The scan is an
information inventory, not a claim that every hardware component has
been stress-tested. - No unavailable metric is represented as a
successful measurement.

### 6.2 Home

Requirements: - HOME-01: Show local device display name, model identity
confidence, iOS version and overall status. - HOME-02: Show concise
cards for device-wide Memory, Battery, Thermal, Storage and Network
information, plus processor/GPU specifications and device status where
available. - HOME-03: Each card labels its measurement scope
and last update when freshness matters. - HOME-04: A tile navigates to
its corresponding Monitor detail or Device information screen. -
HOME-05: Network summary shows aggregate device network usage when
the interface-counter feasibility gate passes. Keep SystemScope's own
traffic as a separate secondary value. - HOME-06: Overall status is derived
only from configured and currently available rules. If a critical input
is stale/unavailable, show `Status unavailable` or a clearly qualified
status rather than silently treating it as healthy. - HOME-07: Battery
card uses actual battery level/state. Battery notifications are not
assumed to arrive every five seconds. - HOME-08: Refresh on screen entry
and user-initiated pull-to-refresh. A visible refresh animation must
correspond to a real refresh. - HOME-09: Home must remain useful when
some metric categories are unsupported.

Overall status precedence: 1. Critical: a supported critical alert is
currently open. 2. Attention: a supported attention alert is currently
open. 3. Normal: all configured inputs are available and below
thresholds. 4. Unknown/Partial: one or more required inputs are stale or
unavailable and no reliable overall conclusion can be made.

### 6.3 Monitor overview and metric details

Screens: MON-01 Overview; MON-02 CPU; MON-03 Memory; MON-04 GPU; MON-05
Storage; MON-06 Battery; MON-07 Thermal; MON-08 Network.

Common requirements: - MON-01: Every metric displays title,
value/status, unit, scope, source/freshness explanation and timestamp as
applicable. - MON-02: Provide explicit refresh. - MON-03: Live sampling
runs only while the relevant screen is visible and app is
foreground-active. - MON-04: Historical charts read local observations.
Never interpolate across missing periods as if data existed. - MON-05:
Gaps are visually distinct and labelled as periods without readings. -
MON-06: Below the minimum observation count, show `Insufficient history`
rather than a misleading chart. - MON-07: Time ranges: Live session, 5m,
15m, 1h where supported; Today, 7 days and 30 days only when stored
history exists and entitlement allows it. - MON-08: Unsupported,
unavailable, stale, permission-required, loading and error states must
be designed and implemented distinctly. - MON-09: Do not store repeated
identical state-change events unless the event policy requires them. -
MON-10: Every chart exposes an accessible textual summary and data
range.

Metric-specific requirements:

**CPU** - Show SystemScope process CPU activity only if the selected
measurement method is validated on physical devices and accepted for App
Store distribution. - Label it `SystemScope app CPU`, not
`iPhone CPU`. - Calculate from CPU-time deltas over measured elapsed
time; document normalisation and units. - If feasibility or distribution
review fails, ship the CPU page as processor information plus a clear
limitation state. Do not ship a fabricated live percentage.

**Memory — device-wide first**
- Show total physical RAM using `ProcessInfo.processInfo.physicalMemory`
  and/or a verified model catalogue entry.
- Implement a device-wide memory sampler using Mach host VM statistics:
  `mach_host_self()`, `host_statistics64(..., HOST_VM_INFO64, ...)`,
  `vm_statistics64` / `vm_statistics64_data_t`, and `vm_page_size`.
- Where verified on supported physical devices, expose page-derived
  categories such as free, active, inactive, wired and compressor
  statistics. Confirm exact field semantics and accounting rules
  against the target SDK headers before assigning user-facing labels.
- Convert page counts to bytes using the runtime page size. Preserve raw
  page counts in diagnostic records to make calculations auditable.
- Do not assume `total - free` equals memory used by apps. Do not add
  overlapping VM categories together. Define a tested accounting model
  and disclose that iOS memory accounting is managed dynamically.
- Use a `DeviceMemorySnapshot` and label it `This iPhone`.
- Keep `task_info` / `TASK_VM_INFO` physical footprint and
  `os_proc_available_memory()` in a separate `SystemScope app` diagnostic
  section only. Never present either as device-wide memory.
- Capture an initial foreground snapshot, refresh on demand, and sample
  conservatively while Monitor is visible. Background history is
  best-effort only.
- If `host_statistics64` is unavailable, rejected, unstable or not
  suitable for App Store distribution on the target OS, show physical
  RAM plus a clear unavailable state for dynamic device memory. Do not
  silently fall back to app memory and label it as phone memory.

**GPU** - Show GPU name/family and capabilities where exposed. -
Explicitly state that live GPU utilisation is not available through the
supported public API surface. - No fabricated utilisation graph.

**Storage** - Define the primary capacity measure before implementation.
Prefer a clearly labelled available-capacity value and show the exact
source used. - Do not combine total capacity from one API with an
incompatible available-capacity definition without explaining the
calculation. - Clearly distinguish the app's storage estimate from the
iOS Settings storage breakdown. - Recalculate percentage and alert
threshold from the same consistent capacity basis.

**Battery** - Show battery percentage and
charging/full/unplugged/unknown state where available. - Show Low Power
Mode where available. - Battery-level change notifications are no more
frequent than once per minute; do not claim five-second battery
updates. - Do not estimate remaining battery time or drainage rate. -
Battery health, cycle count and temperature are unavailable in v1.

**Thermal** - Show iOS thermal state only: Nominal, Fair, Serious,
Critical, Unknown. - Do not show °C/°F temperature. - Recommendations
must be advisory and avoid promising performance improvement.

**Network — device-wide first**
- Show current path status and interface state using `NWPathMonitor`.
- Implement a device-wide aggregate traffic sampler using `getifaddrs()`
  and interface statistics in `struct if_data`, especially
  `ifi_ibytes` and `ifi_obytes`, subject to the release gate in §7.2.
- Display received/downloaded and sent/uploaded bytes, total observed
  traffic, last snapshot time, coverage start and any detected counter
  reset/gap.
- Classify interfaces as Wi-Fi, cellular, loopback, tunnel/VPN,
  bridge/other only after physical-device validation. Never sum
  overlapping virtual/tunnel interfaces or loopback into the user-facing
  device total. If classification is ambiguous, show `Other interface`
  or an unclassified total with a clear note rather than guessing.
- Persist interface counter snapshots and calculate deltas. Counters are
  cumulative and may reset after reboot, interface recreation or system
  changes. If a counter decreases, start a new counter epoch and
  re-baseline; never show negative usage.
- The aggregate is observed interface traffic, not a carrier billing
  statement. It may differ from carrier usage due to interface coverage,
  VPN/tunnel behaviour, counter resets and sampling gaps.
- Capture on app launch/foreground and while the Monitor screen is
  visible. Background snapshots are best-effort; do not promise
  continuous collection while the app is closed.
- Keep `URLSessionTaskMetrics` or equivalent SystemScope request
  accounting in a separate `SystemScope app traffic` subsection.
- SSID lookup is conditional.
  `NEHotspotNetwork.fetchCurrent()` requires the Access Wi-Fi
  Information entitlement and at least one of Apple's qualifying access
  conditions. Location authorization is one possible condition, not the
  only one. A nil result must not be interpreted as proof of permission
  denial.
- Do not display carrier name or cellular signal dBm without a supported
  API and separate feasibility approval. Speed test remains explicitly
  user initiated and follows §10.

### 6.4 Device information

Screens: DEV-01 Overview; DEV-02 General; DEV-03 Processor; DEV-04
Memory; DEV-05 Display; DEV-06 Camera; DEV-07 Connectivity; DEV-08
Sensors; DEV-09 Battery; DEV-10 Operating System; DEV-11 Graphics;
DEV-12 Rename; DEV-13 Specification sheet.

Requirements: - DEV-01: Show local display name, identified
model/marketing name, iOS version and identification status. - DEV-02:
Show quick specs for processor, physical RAM, display and storage where
verified. - DEV-03: Detail pages distinguish live API readings from
static catalogue specifications. - DEV-04: Use hardware identifier
mapping for marketing names; unknown identifiers fall back to
`Unknown iPhone model` with available raw identifier in technical
details. - DEV-05: Every catalogue field must have a source and
confidence classification: Verified on device, Verified catalogue,
Derived, Unknown. - DEV-06: Do not present Derived or Unknown values as
definitive. - DEV-07: Rename sheet follows §2.3 and stores only the
local display name. - DEV-08: Copy single value and Copy all are
available where designed; show a copied confirmation. - DEV-09: Refresh
dynamic fields only; static catalogue fields need not be re-fetched. -
DEV-10: Refresh failure retains last known value with stale timestamp
and an error explanation. - DEV-11: Sensor page distinguishes hardware
capability, API availability, permission state, test status and test
result. - DEV-12: Sensor tests run only after explicit user action and
contextual permission request. - DEV-13: A sensor is not marked faulty
solely because its API is unavailable or permission was denied. -
DEV-14: Camera enumeration and camera diagnostic testing are separate
actions. Do not request camera permission to list static camera
specifications. - DEV-15: Device catalogue must be versioned, reviewed
and updated as new iPhones launch.

### 6.5 Activity, alerts and sessions

Screens: ACT-01 Overview; ACT-02 Event detail; ACT-03 Alerts; ACT-04
Alert detail; ACT-05 Sessions; ACT-06 Session detail; ACT-07 Search;
ACT-08 Filters; ACT-09 Activity settings; ACT-10 Clear history.

Activity requirements: - ACT-01: Date-grouped feed with categories,
summary counts and pagination. - ACT-02: Event detail shows event time,
category, scope, source and relevant measurement snapshot. - ACT-03:
Alert list supports status and severity filters. - ACT-04: Opening an
alert marks it read but never resolves it. - ACT-05: Alert resolution is
an explicit user action. - ACT-06: Search includes title, detail,
category and date metadata. - ACT-07: Recent searches are local, capped
at 10 and clearable. - ACT-08: Filters include category, date range,
status and sort order. - ACT-09: Empty, filtered-empty, search-empty,
partial, loading and error states are distinct. - ACT-10: Deletion and
clear-history actions state exactly what will be deleted. - ACT-11:
Clear history must not delete device profile or preferences. - ACT-12:
Swipe actions must have visible alternatives and accessible actions.

Alert lifecycle: - Read state and resolution state are independent. -
Read state: `unread`, `read`. - Resolution state: `open`, `resolved`,
`dismissed`, `expired`. - Deletion is a separate record operation and
must not be confused with dismissal. - Opening changes `unread` to
`read`; it does not change `open`. - Resolve action changes `open` to
`resolved` and records `resolvedAt`. - Dismiss action changes `open` to
`dismissed` and records `dismissedAt`. - Expiry is system-defined only
where a specific expiry policy exists; otherwise do not create an
`expired` state. - Resolved and dismissed alerts remain visible when the
user's filters include them.

Monitoring session lifecycle: - A session represents one continuous
foreground monitoring period, not an individual chart page view. -
Session starts when the user explicitly starts monitoring or enters a
feature that the approved UX defines as auto-start. Product Design must
make that entry behaviour explicit. - Navigating between Monitor detail
screens does not create duplicate sessions. - Leaving Monitor or
backgrounding the app pauses/stops live sampling. Record the
interruption reason. - A session that cannot continue after
backgrounding is `interrupted`, not completed. - A user may start a new
session; do not imply an interrupted session resumed in the
background. - Session states: `active`, `paused`, `completed`,
`interrupted`, `failed`. - Store start/end times, status, interruption
reason, metrics included, sample count and summary. - Session summary
must indicate missing periods and metrics that were unavailable.

### 6.6 Settings

Screens: SET-01 Overview; SET-02 My Device; SET-03 Monitoring; SET-04
Notifications; SET-05 Thresholds; SET-06 Appearance; SET-07 Data &
History; SET-08 Export; SET-09 Subscription; SET-10 Privacy &
Permissions; SET-11 Support; SET-12 About; SET-13 Clear history; SET-14
Reset preferences.

Requirements: - SET-01: Overview with device profile, subscription
state, grouped settings and version/legal footer. - SET-02: Device
display name, device overview, specs, refresh and reset local profile
action. - SET-03: Monitoring preferences for refresh on entry,
foreground auto-refresh, history visibility and session summaries. No
background interval control. - SET-04: Notification master control and
category preferences; show actual system authorization status and Open
Settings when permission is denied. - SET-05: Thresholds: low battery
default 20% (range 5--50, step 5); low storage default 10% (range 5--30,
step 5); thermal minimum severity default Serious. Provide
reset-to-default and save/discard behaviour. - SET-06:
Light/Dark/System; compact layout; metric descriptions; technical
values; reduce animations. - SET-07: Local data overview, retention
policy, history controls and clear actions. Only show storage size if it
is actually measured. - SET-08: Export selected categories and date
range in approved formats. - SET-09: Subscription status, benefits,
purchase/restore/manage actions and legal disclosures. - SET-10: Privacy
and permission status with explanations; do not show irrelevant
permission rows. - SET-11: Support links and user-reviewed diagnostic
attachment. No diagnostics are sent without explicit user approval. -
SET-12: App version/build and legal/product links. - SET-13:
Clear-history flow with category selection, confirmation, deleting,
success and failure. - SET-14: Reset preferences confirmation. Reset
preferences only; preserve device profile, subscription and history.

### 6.7 Recommendations

-   Recommendations must be deterministic, explainable and based only on
    supported readings or user preferences.
-   Each recommendation has a trigger, severity, title, explanation,
    suggested action and dismissal behaviour.
-   Never recommend actions that imply SystemScope can alter iOS system
    internals.
-   Examples: "Consider enabling Low Power Mode" when the user has low
    battery and is not charging; "Review available storage in iPhone
    Settings" when supported available storage crosses the configured
    threshold.
-   Do not generate recommendations from stale or unavailable readings.
-   AI-generated recommendations are not part of v1 unless a separate
    privacy, cost, accuracy and product approval is recorded. No user
    data is sent to an AI service in the v1 local-first model.

## 6.8 Unified device inspection and scan

SystemScope is a read-only inspection and presentation layer over
information iOS makes available to the app. The scan is a core product
workflow, not merely an onboarding animation.

### Scan behaviour
- `DeviceScanCoordinator` MUST orchestrate independent category
  providers for identity, operating system, processor, memory, storage,
  battery, thermal state, graphics, display, cameras, connectivity,
  network counters and sensor capabilities.
- Run the initial scan in the foreground on first launch. Users MUST
  also be able to run `Refresh all device information` from Home/Device.
- Each category returns independently with `available`, `partial`,
  `permissionRequired`, `unsupported`, `notVerified`, `stale` or
  `failed` status. A failure in one provider MUST NOT block other
  categories.
- The scan MUST not request all permissions up front. Read public
  information that requires no permission first; request optional
  permissions only when the user opens the corresponding feature or
  starts a test.
- Show scan progress only when a provider can report meaningful
  progress. Otherwise use indeterminate progress and do not invent
  percentages.
- Every value stores source API/catalogue, scope, observed timestamp,
  freshness policy, confidence and any permission/availability state.
- A refresh updates dynamic values and revalidates static/catalogue
  values when appropriate. Do not repeatedly run intrusive sensor tests
  as part of a passive scan.
- Device specifications and current readings must be browsable without
  requiring users to understand which iOS Settings screen normally
  contains the information.
- Export MUST preserve scope, source, timestamp, confidence and
  unavailable status so exported reports do not imply false precision.

### Provider contract
Each provider MUST implement a common asynchronous contract equivalent
to:
`func readSnapshot() async -> DeviceDataResult<Value>`

`DeviceDataResult` MUST include:
`value`, `scope`, `source`, `observedAt`, `status`, `confidence`,
`permissionState`, `limitations` and `errorCode` (nullable).

Provider implementations MUST be isolated behind protocols and injected
into the scan coordinator. UI code MUST NOT call low-level system APIs
directly.

## 7. Platform APIs, permissions and capability rules

### 7.1 Data-source register

  ---------------------------------------------------------------------------------------
  Data                    Candidate source                      Scope and restrictions
  ----------------------- ------------------------------------- -------------------------
  Model identifier        `uname()` / `utsname.machine`         Hardware identifier; map
                                                                through maintained
                                                                catalogue

  iOS version             `UIDevice.current.systemVersion`      Device-level OS version

  Physical RAM            `ProcessInfo.processInfo.physicalMemory` Device-wide physical
                          + verified model catalogue             capacity/specification

  Device VM statistics    `mach_host_self()` +                   Device-wide VM page
                          `host_statistics64(...,                statistics; validate
                          HOST_VM_INFO64, ...)` +                 fields and distribution
                          `vm_statistics64` + `vm_page_size`     suitability before use

  App memory footprint    `task_info` with `TASK_VM_INFO`         SystemScope process only;
                                                                never substitute for
                                                                device memory

  App-available memory    `os_proc_available_memory()`            Advisory app allocation
                                                                headroom only; not
                                                                device free RAM

  App CPU                 Mach task/thread information only     SystemScope process only;
                          after feasibility review              fallback to limitation
                                                                state

  GPU capabilities        Metal device discovery                Capabilities only; no
                                                                live utilisation

  Storage                 Foundation URL resource values        Exact capacity property
                                                                must be selected and
                                                                documented

  Battery                 `UIDevice` battery monitoring         Battery level/state;
                                                                notification cadence is
                                                                limited

  Low Power Mode          `ProcessInfo.isLowPowerModeEnabled`   Device-level state

  Thermal                 `ProcessInfo.thermalState`            State only; no
                                                                temperature

  Network path            `NWPathMonitor`                       Path and interface
                                                                properties

  Wi-Fi SSID              `NEHotspotNetwork.fetchCurrent()`     Entitlement plus
                                                                qualifying Apple access
                                                                condition; may return nil

  Camera capability       AVFoundation discovery                Enumeration separate from
                                                                camera use

  Motion capability       CoreMotion availability checks        Permission and test
                                                                requirements vary by API

  Biometry type           LocalAuthentication capability        Capability only; do not
                          evaluation                            authenticate without user
                                                                intent

  Display                 UIKit screen properties               Use only properties
                                                                supported on target
                                                                OS/device

  Device network usage    `getifaddrs()` + `struct if_data`       Aggregate per-interface
                          (`ifi_ibytes`, `ifi_obytes`)             counters; classify and
                                                                de-duplicate interfaces;
                                                                reset/gap caveats apply

  App network usage       `URLSessionTaskMetrics` for SystemScope  SystemScope's own
                          requests                                requests only; separate
                                                                from device aggregate

  Uptime                  ProcessInfo.systemUptime              Optional; verify
                                                                required-reason
                                                                API/privacy manifest
                                                                treatment

  Aggregated app          MetricKit                             Not live monitoring;
  diagnostics                                                   include in support only
                                                                with consent
  ---------------------------------------------------------------------------------------

### 7.1.1 Device-wide memory API implementation

Preferred proof-of-concept API surface:
- `import Darwin` and the Mach headers available in the iOS SDK.
- `mach_host_self()`
- `host_statistics64(_:_:_:_:)`
- `HOST_VM_INFO64`
- `vm_statistics64` / `vm_statistics64_data_t`
- `vm_page_size`

Implementation notes:
1. Allocate and initialise the expected `vm_statistics64` output buffer
   and pass the correct `mach_msg_type_number_t` count for the selected
   SDK definition.
2. Check the returned `kern_return_t`; publish a snapshot only when the
   call succeeds and the returned structure length is valid.
3. Convert page counts to bytes with `UInt64(vm_page_size)`, guarding
   against integer overflow.
4. Persist raw page counts and derived byte values together.
5. Validate which fields are stable and semantically appropriate on each
   supported iOS version. Do not assume macOS examples or old blog posts
   describe current iOS behaviour.
6. Test low-memory and high-memory iPhones, minimum supported iOS and
   current iOS.
7. Verify that use is accepted for App Store distribution. If not, use
   the specified fallback and do not ship a private or undocumented
   substitute.

Potential user-facing values, only after validation:
`Physical RAM`, `Free`, `Active`, `Inactive`, `Wired`, and
`Compressed`. The UI must define whether values are current page counts,
derived byte estimates or system accounting categories. Do not imply
that `Active + Inactive + Wired + Free + Compressed` is an exact,
non-overlapping partition of physical RAM unless SDK semantics and
device tests prove that accounting model.

### 7.1.2 Device-wide network counter API implementation

Preferred proof-of-concept API surface:
- `getifaddrs(_:)` and `freeifaddrs(_:)`
- `struct ifaddrs`
- `struct if_data`
- `ifi_ibytes` (received bytes)
- `ifi_obytes` (transmitted bytes)
- `if_nametoindex(_:)` / interface name and index where useful
- `NWPathMonitor` for current path and interface context

Implementation notes:
1. Call `getifaddrs`, walk the linked list safely, and always release it
   with `freeifaddrs` using `defer`.
2. Read interface statistics only from entries whose address family
   and `ifa_data` make the `if_data` structure valid; guard all pointers.
3. Record interface name, index, flags, byte counters, sample time and
   classification confidence.
4. Build and maintain a tested interface classification table for
   physical Wi-Fi/cellular interfaces and known virtual/tunnel/loopback
   interfaces. Do not hard-code one device's interface list as universal.
5. Do not sum duplicate address-family rows for the same interface.
   De-duplicate by interface identity before aggregation.
6. Treat VPN/tunnel interfaces carefully: they can expose traffic that
   overlaps with the underlying physical interface. Exclude them from
   physical aggregate totals unless testing proves a non-overlapping
   accounting method. If VPN is active and attribution is ambiguous,
   mark the aggregate as `VPN may affect totals`.
7. Store a baseline per interface. Compute deltas only between
   consecutive valid snapshots in the same counter epoch. A decrease,
   interface disappearance/reappearance or reboot starts a new epoch.
8. Do not infer monthly carrier billing usage from counters that have
   unknown baseline or missed intervals. Show observed coverage dates
   and label totals `Observed device traffic`.
9. Verify behaviour across Wi-Fi/cellular handoff, dual SIM, Personal
   Hotspot, VPN, IPv4/IPv6, Wi-Fi calling and reboot.
10. Confirm App Store distribution suitability on current iOS versions.

### 7.1.3 Supporting Apple frameworks and APIs

Use these public SDK surfaces where applicable:
- **UIKit / `UIDevice`:** device name/model where available, OS version,
  battery level/state, orientation and proximity state.
- **Foundation / `ProcessInfo`:** physical memory capacity, OS runtime
  information, Low Power Mode and thermal state.
- **Darwin / `sysctl` / `uname`:** hardware identifier and explicitly
  verified read-only system properties. Each sysctl key requires
  availability and App Review validation; never assume every key is
  public or stable.
- **Mach:** device VM statistics (`host_statistics64`) and
  SystemScope-process-only CPU/memory diagnostics.
- **Network:** `NWPathMonitor` path/interface state and
  `URLSessionTaskMetrics` for SystemScope's own network requests.
- **NetworkExtension:** `NEHotspotNetwork.fetchCurrent()` for
  conditional Wi-Fi SSID access; entitlement and qualifying access
  conditions apply.
- **CoreTelephony:** supported radio-technology information where
  available; do not promise carrier identity or signal strength.
- **Metal:** GPU device identity and supported capabilities only.
- **AVFoundation:** camera hardware discovery and permission-gated
  camera tests.
- **CoreMotion / CoreLocation / ARKit:** sensor availability and
  permission-gated user-initiated tests; availability does not prove
  sensor calibration or accuracy.
- **LocalAuthentication:** biometric capability type, not biometric
  templates or authentication secrets.
- **StoreKit 2:** subscription products, purchase state and entitlement.
- **UserNotifications / BackgroundTasks:** local alerts and
  opportunistic refresh only.
- **MetricKit:** delayed diagnostics for SystemScope itself, not a live
  device-wide telemetry API.

Do not add third-party device-information SDKs that rely on private APIs,
jailbreak detection tricks, protected databases or undocumented
entitlements.

### 7.2 API feasibility gate

Before committing any restricted or low-level metric: 1. Create a small
isolated proof of concept. 2. Test on at least two physical iPhone
generations, including the oldest supported device. 3. Verify API
availability, accuracy, update behaviour and failure states. 4. Confirm
public API and entitlement requirements against current Apple
documentation. 5. Confirm App Store distribution suitability. 6. Record
results and the fallback UI. 7. Do not implement the feature as a
guaranteed metric until the gate passes.

CPU process measurement, Wi-Fi SSID access, sensor enumeration and any
sysctl usage require this gate.

### 7.3 Permissions

  ----------------------------------------------------------------------------------
  Permission /          Purpose           Request moment        Fallback
  entitlement                                                   
  --------------------- ----------------- --------------------- --------------------
  Notifications         Local alerts      When user enables     Alerts remain in
                                          alerts or in approved Activity; explain
                                          onboarding step       notifications are
                                                                off

  Location When In Use  One possible      Only when user        SSID
                        qualifying        explicitly asks to    hidden/unavailable
                        condition for     reveal network name   
                        Wi-Fi SSID access and the selected      
                                          access path requires  
                                          it                    

  Access Wi-Fi          Conditional Wi-Fi Provisioning/review   Hide SSID if
  Information           details           requirement, not a    entitlement
  entitlement                             user permission       unavailable
                                          prompt                

  Motion & Fitness      Specific motion   On starting that test Not tested /
                        tests only if                           permission required
                        required by                             
                        selected API                            

  Camera                Camera diagnostic On starting camera    Camera specs remain
                        test only         test                  viewable; test
                                                                unavailable

  Photos                Not used in v1    Never request         Remove/hide
                                                                onboarding
                                                                permission row

  LocalAuthentication   Capability        Only at point of use  Capability
                        display or                              unavailable
                        user-initiated                          
                        authentication if                       
                        added                                   
  ----------------------------------------------------------------------------------

Do not ask for a permission merely to improve onboarding completion.
Explain the feature, why access is needed and what happens if the user
declines.

### 7.4 Background execution

-   No continuous background sampling.
-   `BGAppRefreshTask` may be used for small, opportunistic refresh or
    maintenance only.
-   iOS determines if and when the task runs; execution is not
    guaranteed.
-   Background refresh MUST NOT be represented as a fixed schedule or
    real-time monitoring.
-   Any background observation is stored with its actual timestamp and
    source.
-   On app foregrounding, refresh supported values and mark old values
    stale until refreshed.
-   Notifications may only be generated from a condition actually
    observed. The app must not imply it detected a threshold crossing at
    the moment it happened if it only observed it later.
-   The user-facing explanation must state that background checks are
    best-effort and may be delayed or skipped.

### 7.5 Sampling policy

  -----------------------------------------------------------------------
  Context                             Target behaviour
  ----------------------------------- -----------------------------------
  CPU/app memory detail visible       Up to 1-second sampling only if
                                      feasible and within overhead budget

  Home overview                       Refresh on entry and user action;
                                      optional visible refresh for
                                      eligible metrics

  Battery                             Event-driven / explicit refresh;
                                      respect OS notification cadence

  Thermal                             Event-driven and foreground
                                      snapshot

  Device memory snapshot              On screen entry; user refresh;
                                      conservative foreground cadence
  Device network counters             On launch/foreground and while
                                      Monitor is visible; no promise
                                      while app is closed
  Network path                        Event-driven path changes

  Storage                             Explicit refresh and conservative
                                      periodic sampling while visible

  Background                          No live streams; optional
                                      opportunistic snapshot only
  -----------------------------------------------------------------------

These are maximum sampling targets, not promises that every API emits a
new value at each interval. Persist observations at a conservative
cadence; do not write duplicate records unnecessarily.

### 7.6 Freshness and unavailable-state rules

Every reading has a `recordedAt` timestamp and a freshness
classification: - `fresh`: within metric-specific expected freshness
window. - `stale`: older than expected; show last updated time. -
`unavailable`: API returned no usable value or value is not exposed. -
`unsupported`: feature cannot be provided on this device/OS. -
`permissionRequired`: a permission is genuinely required and not
granted. - `error`: a read was attempted and failed. - `loading`: read
in progress. - `notMeasured`: no observation exists yet.

Never convert nil, error, stale or unsupported into numeric zero.

## 8. Data model and persistence

### 8.1 Persistence principles

-   Store all personal device profile, observations, activity, alerts,
    sessions and preferences locally.
-   No CloudKit or account sync in v1.
-   Use migrations for schema changes.
-   Use transactions for multi-record destructive operations.
-   Do not persist transient loading states.
-   Keep raw samples only as long as needed for the selected history
    policy; aggregate older observations without inventing readings.
-   Protect local files using an appropriate iOS data-protection class.
    Validate the chosen protection class against background writes and
    user expectations.

### 8.2 Logical entities

**DeviceProfile** - `id` - `displayName` - `modelIdentifier` -
`catalogueVersion` - `identificationStatus` - `firstRegisteredAt` -
`lastUpdatedAt`

**DeviceSpecification** - `id` - `fieldKey` - `value` - `unit` -
`source` - `confidence` - `lastVerifiedAt` - `catalogueVersion`

**Observation** - `id` - `metric` - `numericValue` or typed value -
`unit` - `scope` - `source` - `measurementKind` (`measured`, `derived`,
`catalogue`) - `availabilityState` - `recordedAt` - `sessionID`
optional - `metadata` optional, versioned and Codable

Do not force enum/string states into a `Double` value. Use typed value
representation or a well-defined tagged payload.

**ActivityEvent** - `id` - `kind` - `category` - `title` - `detail` -
`payload` optional, versioned - `timestamp` - `readState` -
`relatedAlertID` optional - `relatedSessionID` optional

**Alert** - `id` - `category` - `severity` - `title` - `detail` -
`createdAt` - `readState` (`unread`, `read`) - `resolutionState`
(`open`, `resolved`, `dismissed`) - `resolvedAt` optional -
`dismissedAt` optional - `thresholdSnapshot` - `observationID`
optional - `lastNotifiedAt` optional - `deduplicationKey`

**MonitoringSession** - `id` - `type` - `startedAt` - `endedAt`
optional - `status` (`active`, `paused`, `completed`, `interrupted`,
`failed`) - `interruptionReason` optional - `metricsIncluded` -
`observationCount` - `summary` optional, versioned

**SpeedTestResult** - `id` - `timestamp` - `endpointIdentifier` -
`interface` - `downloadMbps` - `uploadMbps` - `latencyMs` - `jitterMs` -
`packetLossPercent` optional only if the provider truly measures it -
`bytesDownloaded` - `bytesUploaded` - `durationSeconds` -
`measurementMethodVersion`

**RecentSearch** - `query` - `createdAt` - Maximum 10 entries; local
only.

### 8.3 Data integrity

-   Store metric values with explicit units; do not rely on implicit
    display conventions.
-   Store timestamps in absolute time and format for the user's locale.
-   Version all structured payloads and export schemas.
-   Preserve the measurement scope and source when creating chart
    aggregates.
-   Never aggregate incompatible sources or units into one series.
-   If a sample is missing, preserve a gap.
-   If a metric's definition changes in a future release, do not
    silently combine old and new observations.

### 8.4 Retention and aggregation

Proposed defaults: - History retention: 30 days. - Options: 7 days, 30
days, 90 days, Keep indefinitely. - Retention applies to observations,
activity and sessions according to user-selected category preferences. -
Run cleanup on launch and during opportunistic maintenance. - Aggregate
old samples only where the aggregation preserves meaning
(e.g. min/mean/max for numeric metrics). - Do not downsample categorical
states into numeric averages. - Do not promise a fixed database size;
monitor actual store growth and provide a measured local-data size only
if reliable. - Clear history is transactional and must not delete
DeviceProfile or user preferences. - Reset preferences must not delete
history, device identity or subscription state.

### 8.5 Alert evaluation and deduplication

-   Evaluate thresholds only when a supported observation is obtained.
-   Battery low alert: battery level at or below configured threshold
    AND device is not charging; default threshold 20%.
-   Storage low alert: available capacity percentage at or below
    configured threshold; default 10%.
-   Thermal alert: configured minimum state reached or exceeded.
-   Network path changes are Activity events, not alerts by default.
-   Create at most one open alert per deduplication key and category.
-   Re-arm only after the metric returns beyond a documented hysteresis
    boundary.
-   Store the threshold value used when the alert was created.
-   Notification delivery is separate from alert creation; an alert may
    exist without notification permission.
-   Do not generate an alert from stale data.

## 9. Monitoring session rules

### 9.1 Session definition

A monitoring session is a user-visible foreground period in which one or
more supported metrics are being observed. It is not a promise of
continuous device monitoring.

### 9.2 Session transitions

  -----------------------------------------------------------------------
  Current state           Trigger                 Next state
  ----------------------- ----------------------- -----------------------
  None                    User starts monitoring  Active

  Active                  User pauses             Paused

  Paused                  User resumes while      Active
                          foreground              

  Active/Paused           User ends normally      Completed

  Active/Paused           App backgrounds or      Interrupted
                          process is interrupted  

  Active                  Sampling/persistence    Failed
                          cannot continue safely  
  -----------------------------------------------------------------------

-   A navigation change between Monitor metrics does not create another
    session.
-   The product must decide whether opening Monitor auto-starts a
    session or requires an explicit Start action. This is a
    design/product gate before session implementation.
-   On backgrounding, stop active sampling and record interruption. Do
    not keep a session labelled Active while the app is not sampling.
-   A new foreground visit starts a new session unless the user
    explicitly resumes a paused session and the product UX supports it.
-   Interrupted sessions remain in history with a reason where known.

## 10. Speed test

### 10.1 Release gate

Speed test must not ship until Product and Engineering select and
approve: - Endpoint/provider. - Licence permitting the intended app
use. - Data retention and logging terms. - Privacy disclosure and App
Store privacy answers. - Geographic performance and availability. -
Maximum test duration and data usage.

### 10.2 User experience

1.  User explicitly taps Start Speed Test.
2.  Consent sheet explains that data will be transferred and gives a
    maximum expected data amount.
3.  Show active interface and whether it is expensive/constrained.
4.  Require an additional confirmation before cellular use.
5.  User starts test; progress and Cancel are visible.
6.  Results show endpoint, timestamp, interface, download/upload,
    latency and jitter.
7.  Packet loss is shown only if the selected provider measures it with
    a defensible method.
8.  User can save, export or delete the result.

### 10.3 Measurement requirements

-   Results describe performance to the selected endpoint at that time,
    not universal network quality.
-   Define whether upload/download are sequential or simultaneous.
-   Define latency sample count, timeout, jitter formula and handling of
    failed probes.
-   Do not label failed HTTPS requests as network packet loss unless the
    method actually measures packet loss.
-   Set a conservative maximum data budget and enforce it in code.
-   Show actual bytes transferred after the test.
-   Cancel stops further transfers; partial results are discarded unless
    Product explicitly approves a partial-result state.
-   Speed test is not run automatically or in the background.

## 11. Monetisation and entitlement rules

### 11.1 Product model

-   Auto-renewable subscription using StoreKit 2.
-   Proposed product identifiers:
    -   `com.systemscope.premium.monthly`
    -   `com.systemscope.premium.yearly`
-   Subscription group: `premium`.
-   Prices, billing periods, trials and offers come from App Store
    Connect product metadata; never hard-code prices.
-   StoreKit local configuration is required for development/testing.
-   Family Sharing support must be explicitly configured and tested; do
    not assume it is enabled.

### 11.2 Proposed feature matrix --- product approval required

  Feature                        Free                              Premium
  ------------------------------ --------------------------------- ------------------
  Home overview                  Yes                               Yes
  Basic Monitor current values   Yes                               Yes
  Device information             Yes                               Yes
  Basic Activity feed            Last 7 days                       Extended history
  Default threshold alerts       Yes                               Yes
  Custom alert thresholds        No                                Yes
  Historical trends              Limited/current snapshot          7/30-day trends
  Advanced charts                No                                Yes
  Monitoring session history     No or limited preview             Yes
  Speed test                     Product decision; proposed free   Yes
  Current snapshot export        CSV                               CSV
  Full history export            No                                CSV/JSON
  PDF reports                    No                                Yes
  Advanced diagnostics           Not in v1                         Not in v1

**Decision gate:** Product must approve the final matrix before paywall
implementation. Do not use "No subscription" empty states for features
that should remain available to free users.

### 11.3 Entitlement logic

-   Use `Transaction.currentEntitlements` and transaction updates.
-   Verify transactions before granting access.
-   `subscribed` and `inGracePeriod` states are entitled according to
    StoreKit.
-   `inBillingRetryPeriod`, `expired` and `revoked` do not independently
    grant entitlement; check whether another valid entitlement exists.
-   Pending purchase is not active access.
-   If entitlement cannot be refreshed, preserve the last verified state
    where safe and show an explicit verification issue; do not invent a
    new entitlement.
-   Restore Purchases invokes StoreKit sync and reports the result.
-   Manage Subscription opens Apple's subscription management UI.
-   Centralise access in an entitlement service and feature flags; do
    not scatter product-ID checks through views.
-   Test expiry, cancellation, grace period, billing retry,
    refund/revocation, pending purchase, offline launch and restore.

### 11.4 Paywall requirements

-   Display product name, localised price, billing period, renewal
    terms, trial terms if applicable, Terms of Use, Privacy Policy and
    Restore Purchases.
-   Make close/dismiss behaviour clear.
-   Do not use misleading countdowns, false scarcity or preselected
    hidden consent.
-   Clearly identify what remains available without Premium.

## 12. Notifications

-   Local notifications only in v1.
-   Request authorization only after explaining the benefit.
-   Category preferences are separate from iOS authorization.
-   If permission is denied, show the actual system state and Open
    Settings action.
-   Alert creation must not depend on notification permission.
-   Notification content must identify the metric and threshold context
    without implying guaranteed detection time.
-   Tapping a notification opens the corresponding alert if it exists.
-   Deduplicate notifications; define cooldown per alert category.
-   Never send notifications from stale/unverified values.
-   Background refresh delays and skipped executions must be explained
    in the app.

## 13. Export

### 13.1 Formats

-   CSV: one file per category; UTF-8; header row; ISO-8601 timestamps;
    explicit units in column names.
-   JSON: one versioned structured document containing export metadata,
    device profile, selected observations, events, sessions and
    speed-test results.
-   PDF: optional Premium report with device identity, selected date
    range, metric summaries, charts and alerts/sessions where available.

### 13.2 Export requirements

-   User selects categories and date range.
-   Export includes only selected data.
-   Include scope, source and units in machine-readable formats.
-   Include gaps/unavailable values explicitly where meaningful; do not
    convert them to zero.
-   Display generating, ready and failed states.
-   Use the iOS share sheet.
-   Temporary export files must be cleaned up after sharing or a safe
    expiry interval.
-   No export is transmitted automatically.
-   Test large exports, empty ranges, partial history and interrupted
    generation.

## 14. Privacy, security and compliance

### 14.1 Data handling

-   No account, cloud sync, advertising or third-party behavioural
    analytics in v1.
-   No personal monitoring data leaves the device except when the user
    explicitly exports/shares or initiates the speed test.
-   Speed-test endpoint may receive network metadata such as IP address
    as part of the request. Provider retention and privacy terms must be
    reviewed before release.
-   Support diagnostics are off by default and require user review and
    explicit confirmation before sharing.
-   Do not log SSIDs, device display names, exported content or raw user
    data.
-   Use privacy-redacted logging.

### 14.2 Privacy manifest and App Store disclosures

-   Include `PrivacyInfo.xcprivacy`.
-   Audit every required-reason API actually used by the app and
    included SDKs.
-   Declare only applicable API categories and approved reason codes.
    Likely categories to assess include UserDefaults, Disk Space, System
    Boot Time and File Timestamp; do not add them merely because they
    appear in this PRD.
-   App Store privacy answers must reflect actual shipped behaviour,
    including the selected speed-test provider and any data processing.
-   Do not assume "Data Not Collected" until the endpoint, logs and
    third-party handling have been reviewed against Apple's current
    definitions.
-   No ATT prompt unless a future approved feature genuinely requires
    tracking.

### 14.3 Security

-   Use iOS data protection for local database and exported temporary
    files.
-   Keep purchase verification and entitlement state consistent with
    StoreKit.
-   No embedded server secrets or private API credentials.
-   Validate imported or decoded payloads and version them.
-   Avoid retaining unnecessary diagnostic data.
-   Clear sensitive temporary files when no longer needed.

### 14.4 App Store claims

Prohibited claims: - "Boost your iPhone." - "Clean RAM." - "Speed up
your processor." - "Show all apps using CPU." - "See your battery
temperature/health" unless public API support changes and is verified. -
"Monitor everything in real time." - "Get instant alerts while the app
is closed."

Use accurate descriptions such as: - "Monitor SystemScope's own app
activity." - "See iOS thermal state." - "View supported device
specifications." - "Track readings while SystemScope is open." -
"Background checks may be delayed or skipped by iOS."

## 15. Non-functional requirements

### 15.1 Performance targets

Targets are provisional and must be measured on the oldest supported
physical device.

  -----------------------------------------------------------------------
  Area                                Target
  ----------------------------------- -----------------------------------
  Cold launch to interactive Home     ≤ 1.5 seconds p90

  Tab transition                      ≤ 150 ms perceived response

  Activity scrolling                  Smooth at device refresh rate with
                                      1,000+ records

  Typical app memory                  Target \< 100 MB; investigate
                                      sustained growth

  Sampling overhead                   Target \< 1% average app CPU at
                                      approved 1-second sampling

  CSV export (30 days)                Target \< 5 seconds on reference
                                      device

  Clear history (10,000 records)      Target \< 3 seconds; atomic outcome

  Crash-free sessions                 ≥ 99.8% after meaningful beta
                                      volume
  -----------------------------------------------------------------------

Do not compromise correctness or battery impact to meet a sampling
target. If the target cannot be met, reduce sampling frequency or remove
the metric.

### 15.2 Reliability

-   All provider failures map to explicit UI states.
-   Persistence errors must not silently discard records.
-   Destructive operations must have a recoverable/atomic outcome where
    feasible.
-   App termination and backgrounding must not leave phantom active
    sessions.
-   Subscription state must recover safely after offline launch.
-   Unknown device models must degrade gracefully.

### 15.3 Localisation

-   v1 language: English, using UK spelling as in approved designs.
-   All user-facing strings in String Catalogs.
-   Dates, numbers, units and file sizes use locale-aware formatters.
-   Layout tolerates at least 40% string expansion.
-   Do not concatenate translated sentence fragments.

## 16. Analytics and product measurement

No third-party analytics SDK or server-side event collection in v1.

Product quality may be assessed through: - Opt-in beta feedback. - Crash
and performance diagnostics reviewed under user consent. - Local QA test
reports. - App Store aggregate metrics available through Apple's
platform.

If future product analytics are proposed, create a separate privacy
review and product decision. Do not add analytics silently.

## 17. Testing and quality plan

### 17.1 Unit tests

Required coverage: - Threshold evaluation and hysteresis. - Alert
deduplication and lifecycle transitions. - Session lifecycle and
interruption. - Observation units, scope and aggregation. - Freshness
classification. - Retention and cleanup. - Export encoding and schema
versioning. - Entitlement feature gating. - Preference defaults and
reset behaviour. - Device catalogue matching and unknown model fallback.

### 17.2 Integration tests

-   Persistence create/read/update/delete and migrations.
-   Atomic clear-history behaviour.
-   Session and event relationship integrity.
-   Notification scheduling and deep-link routing.
-   StoreKit test configuration for all entitlement states.
-   Export generation from mixed/partial history.
-   Offline and provider-failure behaviour.

### 17.3 UI tests

Critical journeys: 1. Onboarding completed without optional permissions.
2. Home → Battery → Monitor detail. 3. Home → Network → conditional SSID
unavailable state. 4. Monitor session start → navigate between metrics →
end session → Activity detail. 5. App background during session →
interrupted session recorded. 6. Threshold crossed during foreground
observation → alert created. 7. Alert opened → read, but remains
unresolved. 8. Alert explicitly resolved. 9. Activity search/filter → no
results → clear filters. 10. Settings threshold changed → save/discard.
11. Settings export CSV → share sheet. 12. Clear history → confirmation
→ empty feed; device profile retained. 13. Reset preferences →
preferences restored; history retained. 14. Purchase → entitlement
active → cancellation/expiry states. 15. Grace period versus billing
retry entitlement. 16. Light/Dark/System appearance and Reduce Motion.

### 17.4 Accessibility tests

-   VoiceOver critical journeys.
-   Dynamic Type at default and largest supported sizes.
-   Contrast in light and dark.
-   Touch target audit.
-   Chart alternatives.
-   Reduce Motion and in-app animation preference.
-   No status conveyed by colour alone.

### 17.5 Physical-device validation

At minimum: - Oldest supported iPhone/OS. - Current non-Pro iPhone. -
Current ProMotion iPhone. - Device without LiDAR. - Wi-Fi only and
cellular scenarios. - Low storage scenario. - Low battery and charging
scenarios. - Thermal state transitions where safely reproducible. -
Permission denied and permission revoked scenarios.

Simulator results are not sufficient evidence for hardware metrics,
battery behaviour, thermal state, network interfaces or sensor
availability.

## 18. CI/CD and release workflow

### 18.1 Branch and review

-   Trunk-based development with short-lived branches.
-   Pull request requires at least one review.
-   CI must pass before merge.
-   Product/Design review required for user-visible behaviour changes.
-   Platform-sensitive API changes require an API feasibility note.

### 18.2 CI checks

On pull request: - Build Debug. - Run formatting/lint. - Run unit and
integration tests. - Run relevant snapshot tests. - Validate privacy
manifest presence and structure. - Validate localisation catalogues.

On main: - Run full test suite. - Run UI tests on supported
simulators. - Build Release archive. - Upload to internal TestFlight
only after required checks pass.

### 18.3 Environments

-   Debug: deterministic fake providers and StoreKit configuration.
-   TestFlight: real public APIs, sandbox purchases and test data
    clearly labelled.
-   Release: no debug menus, fake metrics or test endpoints.

## 19. Delivery plan

Estimates assume two iOS engineers, part-time QA and design support.
Re-estimate after API feasibility spikes.

  -----------------------------------------------------------------------
  Milestone               Scope                   Exit criteria
  ----------------------- ----------------------- -----------------------
  M0 --- Decisions and    Confirm visual source,  D-01 and platform gates
  foundation              minimum OS,             recorded; app shell
                          architecture, CI, API   builds
                          feasibility spikes      

  M1 --- Design system    Tokens, components,     Approved
  and app shell           navigation, local       screens/components
                          preferences             implemented with
                                                  accessibility previews

  M2 --- Device and Home  Device catalogue,       Device facts verified
                          identity, rename, Home  on physical devices;
                          overview                unknown model fallback
                                                  works

  M3 --- Monitor core     Supported samplers,     No unsupported
                          Monitor screens,        system-wide claims;
                          freshness states and    sampling overhead
                          charts                  acceptable

  M4 --- Activity and     Persistence, sessions,  Lifecycle tests pass;
  alerts                  alert lifecycle,        background limitations
                          notifications, history  reflected accurately

  M5 --- Settings and     Preferences, data       Export formats
  export                  management, export and  validated; destructive
                          privacy UI              flows preserve
                                                  unrelated data

  M6 --- Premium and      StoreKit, paywall,      All entitlement states
  speed test              feature gating; speed   pass; speed-test
                          test only after         privacy/licence
                          provider gate           approved

  M7 --- Onboarding and   Onboarding, dark theme, Release gates complete
  hardening               accessibility,          
                          performance and App     
                          Store review            

  Beta                    TestFlight external     No P0/P1 defects;
                                                  crash-free target
                                                  reached with sufficient
                                                  sample
  -----------------------------------------------------------------------

## 20. Definition of Done

A feature is complete only when: - Requirements and edge cases are
implemented. - Approved Figma screens and all required states are
represented. - Loading, empty, stale, unavailable, unsupported,
permission and error states are handled where relevant. - Scope, source,
unit and timestamp are accurate. - Accessibility checks pass. -
Unit/integration/UI tests are added at the appropriate level. -
Physical-device validation is completed for hardware-dependent
behaviour. - Privacy and permission behaviour is reviewed. - No debug
data, fake values or unapproved API use remains. - Product and Design
approve the user-visible behaviour.

## 21. Release blockers

Do not submit v1 if any of these remain unresolved: 1. Visual direction
conflict between Figma revisions. 2. Minimum supported iOS version not
approved. 3. CPU measurement not feasibility-verified but still
displayed as a live metric. 4. Wi-Fi SSID UI implies guaranteed access.
5. Background notifications imply continuous or guaranteed monitoring.
6. Speed-test endpoint/provider, licence and privacy handling are
unresolved while speed test is included. 7. Alert/session state model
does not match UI. 8. StoreKit grace-period and billing-retry
entitlement handling is incorrect. 9. Privacy manifest or App Store
privacy answers are incomplete. 10. Any unsupported metric is presented
as measured.

## 22. Decision log

  ---------------------------------------------------------------------------------------------
  ID             Decision             Owner                       Required by    Status
  -------------- -------------------- --------------------------- -------------- --------------
  D-01           Confirm              Product Design              M0             Open
                 authoritative visual                                            
                 system (pastel                                                  
                 surfaces vs 15 Nov                                              
                 outlined/neutral                                                
                 surfaces)                                                       

  D-02           Confirm minimum iOS  Product + Engineering       M0             Open
                 version (proposed                                               
                 iOS 17)                                                         

  D-03           Approve CPU process  Engineering                 M0/M3          Open
                 metric after                                                    
                 physical-device and                                             
                 distribution                                                    
                 feasibility test                                                

  D-04           Select storage       Engineering + Design        M3             Open
                 capacity definition                                             
                 and displayed labels                                            

  D-05           Confirm Wi-Fi SSID   Engineering + Product       M0/M3          Open
                 feature and                                                     
                 entitlement/access                                              
                 strategy                                                        

  D-06           Choose speed-test    Product + Engineering +     Before M6      Open
                 endpoint/provider    Legal                                      
                 and licence                                                     

  D-07           Approve speed-test   Product + Design            Before M6      Open
                 data budget and                                                 
                 cellular                                                        
                 confirmation                                                    

  D-08           Approve free/Premium Product                     Before M6      Open
                 feature matrix and                                              
                 prices/trials                                                   

  D-09           Decide whether       Product + Design            Before M4      Open
                 Monitor auto-starts                                             
                 sessions or requires                                            
                 Start                                                           

  D-10           Confirm sensor tests Product + Engineering       Before M2      Open
                 included in v1                                                  

  D-11           Confirm device       Engineering                 M2             Open
                 catalogue source and                                            
                 update owner                                                    

  D-12           Confirm CI platform  Engineering                 M0             Open

  D-13           Finalise Terms,      Product/Legal               Before         Open
                 Privacy Policy,                                  submission     
                 support and website                                             
                 URLs                                                            

  D-14           Validate App Store   Product/Legal/Engineering   Before         Open
                 privacy disclosures                              submission     
                 after all                                                       
                 network/provider                                                
                 decisions                                                       
  ---------------------------------------------------------------------------------------------

## 23. Glossary

  -----------------------------------------------------------------------
  Term                                Definition
  ----------------------------------- -----------------------------------
  Observation                         A timestamped metric value with
                                      scope, source and unit

  Scope                               Whether a value describes
                                      SystemScope, the iPhone, or a
                                      catalogue specification

  Stale                               A previously obtained value older
                                      than its expected freshness window

  Unavailable                         A value cannot currently be
                                      obtained or is not exposed

  Unsupported                         The feature is not supported on the
                                      current device/OS

  Alert                               A user-visible event created when a
                                      supported observation crosses a
                                      configured rule

  Session                             A foreground monitoring period with
                                      a defined lifecycle

  Thermal state                       iOS state: Nominal, Fair, Serious
                                      or Critical; not a temperature

  Device network usage                Aggregate observed traffic from
                                      validated device interface counters

  App CPU                             CPU consumed by SystemScope itself

  Device memory statistics            Aggregate host VM memory readings
                                      obtained from supported Mach APIs

  App memory footprint                Memory footprint of SystemScope's
                                      own process

  Retention                           How long local
                                      observations/events/sessions are
                                      kept

  Device catalogue                    Versioned mapping from hardware
                                      identifiers to verified
                                      specifications

  Device scan                          Coordinated read of all supported
                                      device information providers
  -----------------------------------------------------------------------

## Appendix A --- Screen inventory

**Onboarding:** Introduction 1--3; Meet Your Device; Set Up Monitoring;
Inspect Your Device; Your Device Is Ready; Premium.

**Home:** HOME; HOME / Network pop-up; loading, partial, stale, error
and no-data states.

**Monitor:** MON-01 Overview; MON-02 CPU; MON-03 Memory; MON-04 GPU;
MON-05 Storage; MON-06 Battery; MON-07 Thermal; MON-08 Network; metric
information sheets; refresh states; insufficient-history states;
speed-test consent/running/results (only if approved).

**Device:** DEV-01 Overview; DEV-02 General; DEV-03 Processor; DEV-04
Memory; DEV-05 Display; DEV-06 Camera; DEV-07 Connectivity; DEV-08
Sensors and sensor detail; DEV-09 Battery; DEV-10 Operating System;
DEV-11 Graphics; DEV-12 Rename; DEV-13 Specification sheet.

**Activity:** ACT-01 Overview; ACT-02 Event detail; ACT-03 Alerts;
ACT-04 Alert detail; ACT-05 Sessions; ACT-06 Session detail; ACT-07
Search; ACT-08 Filters; ACT-09 Activity settings; ACT-10 Clear history.

**Settings:** SET-01 Overview; SET-02 My Device; SET-03 Monitoring;
SET-04 Notifications; SET-05 Thresholds; SET-06 Appearance; SET-07 Data
& History; SET-08 Export; SET-09 Subscription; SET-10 Privacy &
Permissions; SET-11 Support; SET-12 About; SET-13 Clear history; SET-14
Reset preferences.

## Appendix B --- Required developer handover artefacts

Before implementation begins, the team must have: 1. Approved Figma file
and signed-off visual source of truth. 2. Screen/state inventory mapped
to this PRD. 3. Device catalogue data source and verification
spreadsheet. 4. API feasibility notes for CPU, Wi-Fi, sensors and
storage. 5. Approved subscription feature matrix. 6. Approved speed-test
provider decision or explicit removal from v1. 7. Privacy policy and
data-flow summary. 8. Test-device matrix. 9. Open-decision owners and
dates. 10. Release checklist mapped to Definition of Done.

## Appendix C --- Apple documentation to verify during implementation

Always re-check the current Apple documentation and SDK availability
when implementing platform-sensitive behaviour. The following references
informed this PRD:

-   [NEHotspotNetwork.fetchCurrent()](https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent(completionhandler:))
-   [UIDevice battery level change
    notification](https://developer.apple.com/documentation/uikit/uidevice/batteryleveldidchangenotification)
-   [BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)
-   [Using background tasks to update your
    app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)
-   [StoreKit
    RenewalState](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalstate)
-   [Transaction.currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
-   [os_proc_available_memory()](https://developer.apple.com/documentation/os/os_proc_available_memory)
-   [Apple: host_statistics64](https://developer.apple.com/documentation/kernel/1502863-host_statistics64)
-   [Apple: if_data](https://developer.apple.com/documentation/kernel/if_data)
-   [Apple Developer Relations: system-wide network usage via getifaddrs; no per-app usage API](https://developer.apple.com/forums/thread/81833)
-   [Apple: UIDevice](https://developer.apple.com/documentation/uikit/uidevice)
-   [URLResourceValues](https://developer.apple.com/documentation/foundation/urlresourcevalues)
-   [Adding required reason API entries to your privacy
    manifest](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

These links are implementation references, not a substitute for device
testing, entitlement approval or App Review.


## Appendix D — v1.2 product and engineering clarification

Version 1.2 makes unified device inspection the central product purpose.
It supersedes any earlier statement that SystemScope is limited to
SystemScope-process memory or that total device network counters are
categorically unavailable.

The implementation target is:
1. Read and organise all supported device-wide information available
   through approved iOS SDK APIs.
2. Use device-wide Mach VM statistics for memory only after the API and
   accounting model pass the release gate.
3. Use `getifaddrs` interface counters for observed aggregate network
   traffic only after interface de-duplication, VPN handling, reset
   detection and App Store suitability pass the release gate.
4. Keep app-process CPU, app memory footprint and SystemScope request
   traffic separate and clearly labelled.
5. Never claim access to every iOS internal, every installed app's
   private process data, or exact carrier billing records.

### v1.2 implementation release blockers
- Physical-device proof of concept for `host_statistics64` memory
  readings and correct VM page accounting.
- Physical-device proof of concept for `getifaddrs` byte counters and
  interface classification/de-duplication.
- VPN, interface reset, reboot and Wi-Fi/cellular handoff test results.
- Written App Store distribution review for both low-level API paths.
- Updated UI showing device-wide readings as primary and SystemScope
  app-only diagnostics as secondary.
- Export schema includes metric scope, source, freshness, confidence,
   coverage and limitations.
