import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// DEV-01 · Device overview, its detail screens and sheets.
public struct DeviceView: View {
    @Bindable private var model: DeviceModel
    private let onOpenMonitor: (DeviceMonitorLink) -> Void

    public init(model: DeviceModel, onOpenMonitor: @escaping (DeviceMonitorLink) -> Void) {
        self.model = model
        self.onOpenMonitor = onOpenMonitor
    }

    public var body: some View {
        NavigationStack(path: $model.path) {
            DeviceOverview(model: model)
                .navigationDestination(for: DeviceRoute.self) { route in
                    destination(route)
                }
        }
        .backSwipe { model.goBack() }
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private func destination(_ route: DeviceRoute) -> some View {
        switch route {
        case .general: GeneralView(model: model)
        case .processor: ProcessorView(model: model) { onOpenMonitor(.cpu) }
        case .memory: MemoryView(model: model) { onOpenMonitor(.memory) }
        case .display: DisplayView(model: model)
        case .camera: CameraView(model: model)
        case .connectivity: ConnectivityView(model: model) { onOpenMonitor(.network) }
        case .sensors: SensorsView(model: model)
        case .battery: BatteryView(model: model) { onOpenMonitor(.battery) }
        case .operatingSystem: OperatingSystemView(model: model)
        case .graphics: GraphicsView(model: model) { onOpenMonitor(.gpu) }
        }
    }
}

public extension View {
    /// The Device sheets and toast. Applied by the shell at its root, next to the
    /// speed-test sheet: a sheet presented from inside a tab is dismissed whenever the
    /// root's own sheet modifier updates.
    func deviceSheets(model: DeviceModel) -> some View {
        modifier(DeviceSheetsModifier(model: model))
    }
}

private struct DeviceSheetsModifier: ViewModifier {
    @Bindable var model: DeviceModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.sheet) { sheet in
                switch sheet {
                case .actions: DeviceActionsSheet(model: model)
                case .rename: RenameSheet(model: model)
                case .spec(let content): SpecificationSheet(model: model, content: content)
                case .sensor(let kind): SensorSheet(model: model, sensor: kind)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    ToastView(message: toast)
                        .padding(.bottom, 116)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: model.toast)
    }
}

struct DeviceOverview: View {
    let model: DeviceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if model.isRefreshing, model.hasLoaded {
                    RefreshingPill().frame(maxWidth: .infinity)
                }
                if model.refreshFailed {
                    RefreshErrorBanner(lastUpdated: model.lastUpdated) {
                        Task { await model.refresh() }
                    }
                }
                if model.hasLoaded {
                    loaded
                } else {
                    DeviceOverviewSkeleton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Device"))
                    .ssText(.pageTitle28)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(L("Your device information"))
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
            Spacer()
            CircleIconButton(icon: .more, label: L("More options")) { model.sheet = .actions }
        }
    }

    @ViewBuilder
    private var loaded: some View {
        if model.identification == .unknown {
            UnknownModelBanner(identifier: model.summary.modelIdentifier ?? model.details?.hardwareIdentifier)
        }
        DeviceIdentityCard(model: model)
        quickSpecs
        explore
        record
    }

    // MARK: Quick specs (DEV-02)

    private var quickSpecs: some View {
        let summary = model.summary
        let display = model.details?.display
        let displayValue: String? = display?.maximumFramesPerSecond.map { fps in
            fps > 60 ? L("\(fps) Hz ProMotion") : L("\(fps) Hz")
        }
        return VStack(alignment: .leading, spacing: 14) {
            DeviceSectionTitle(title: L("Quick specs"))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    QuickSpecCell(icon: .cpu, label: L("Processor"), value: DeviceFormat.shortChip(summary.processor), fallback: Fallback.unavailable) {
                        model.open(.processor)
                    }
                    Rectangle().fill(SSColor.border).frame(width: 1)
                    QuickSpecCell(icon: .cpuSetting, label: L("Memory"), value: DeviceFormat.memory(summary.physicalMemoryBytes)) {
                        model.open(.memory)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(SSColor.border).frame(height: 1)
                HStack(spacing: 0) {
                    QuickSpecCell(icon: .monitor, label: L("Display"), value: displayValue) {
                        model.open(.display)
                    }
                    Rectangle().fill(SSColor.border).frame(width: 1)
                    QuickSpecCell(icon: .storage, label: L("Storage"), value: DeviceFormat.storage(summary.storageTotalBytes)) {
                        model.sheet = .spec(SpecSheets.storage(model))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    // MARK: Explore device

    private var explore: some View {
        let summary = model.summary
        let details = model.details
        let specs = model.specifications
        let rows: [(DeviceRoute, SSIcon, String, String)] = [
            (.general, .mobile, L("General"), L("Name, model and identifiers")),
            (.processor, .cpu, L("Processor"), processorSubtitle(summary)),
            (.memory, .cpuSetting, L("Memory"), DeviceFormat.memory(summary.physicalMemoryBytes).map { L("\($0) of physical RAM") } ?? Fallback.unavailable),
            (.display, .monitor, L("Display"), displaySubtitle(details?.display, specs)),
            (.camera, .camera, L("Camera"), cameraSubtitle(details?.cameras ?? [])),
            (.connectivity, .wifi, L("Connectivity"), connectivitySubtitle(specs)),
            (.sensors, .radar, L("Sensors"), L("Motion, location and biometric sensors")),
            (.battery, .battery, L("Battery"), L("Charging and battery information")),
            (.operatingSystem, .monitorMobile, L("Operating System"), osSubtitle(details, summary)),
            (.graphics, .cube, L("Graphics"), graphicsSubtitle()),
        ]
        return VStack(alignment: .leading, spacing: 14) {
            DeviceSectionTitle(title: L("Explore device"))
            VStack(spacing: 2) {
                ForEach(rows, id: \.0) { route, icon, title, subtitle in
                    Button { model.open(route) } label: {
                        HStack(spacing: 12) {
                            OutlinedIcon(icon: icon, size: 40, iconSize: 20, cornerRadius: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .ssText(.rowTitle15)
                                    .foregroundStyle(SSColor.textStrong)
                                Text(subtitle)
                                    .ssText(.caption13)
                                    .foregroundStyle(SSColor.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            SSIconView(.chevronRight, size: 20, color: SSColor.textFaint)
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.vertical, 6)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func processorSubtitle(_ summary: DeviceSummary) -> String {
        let chip = summary.processor ?? Fallback.notInCatalogue
        guard let cores = summary.processorCoreCount else { return chip }
        return L("\(chip) · \(cores)-core CPU")
    }

    private func displaySubtitle(_ display: DisplayDetails?, _ specs: DeviceSpecifications?) -> String {
        if let name = specs?.displayName {
            return [DeviceFormat.diagonal(specs?.screenDiagonalInches), name].compactMap { $0 }.joined(separator: " ")
        }
        return DeviceFormat.pixels(display).map { L("\($0) pixels") } ?? Fallback.unavailable
    }

    private func cameraSubtitle(_ cameras: [CameraDetails]) -> String {
        if let main = cameras.first(where: { $0.kind == .wide })?.megapixels {
            return L("\(main) MP main camera system")
        }
        return cameras.isEmpty ? L("No cameras reported") : L("\(cameras.count) cameras")
    }

    private func connectivitySubtitle(_ specs: DeviceSpecifications?) -> String {
        let parts = [specs?.wifiStandard, specs?.cellular, specs?.bluetoothVersion.map { L("Bluetooth \($0)") }].compactMap { $0 }
        return parts.isEmpty ? L("Wi-Fi, cellular and Bluetooth") : parts.joined(separator: ", ")
    }

    private func osSubtitle(_ details: DeviceDetails?, _ summary: DeviceSummary) -> String {
        guard let version = details?.osVersion ?? summary.osVersion else { return Fallback.unavailable }
        if let build = details?.osBuild { return L("iOS \(version) (\(build))") }
        return L("iOS \(version)")
    }

    private func graphicsSubtitle() -> String {
        let metal3 = model.gpu?.supportedCapabilities.contains(.metal3) == true
        let cores = model.specifications?.gpuCoreCount.map { L("\($0)-core GPU") } ?? model.gpu?.name ?? L("GPU")
        return metal3 ? L("\(cores) · Metal 3") : cores
    }

    // MARK: Device record

    private var record: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeviceSectionTitle(title: L("Device record"))
            DeviceCard {
                SpecificationList(specs: [
                    Spec(label: L("First registered"), value: DeviceFormat.day(model.firstRegistered)),
                    Spec(label: L("Last updated"), value: model.lastUpdated.map(DeviceFormat.relative)),
                ])
                Rectangle().fill(SSColor.border).frame(height: 1)
                HStack {
                    Text(L("Identification"))
                        .ssText(.body14)
                        .foregroundStyle(SSColor.textTertiary)
                    Spacer()
                    IdentificationPill(status: model.identification, matchedTitle: L("Catalogue match"))
                }
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct QuickSpecCell: View {
    let icon: SSIcon
    let label: String
    let value: String?
    var fallback: String = Fallback.unavailable
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    OutlinedIcon(icon: icon, size: 36, iconSize: 18)
                    Spacer()
                    SSIconView(.chevronRight, size: 20, color: SSColor.textFaint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .ssText(.captionMedium13)
                        .foregroundStyle(SSColor.textSubtle)
                    Text(value ?? fallback)
                        .font(.system(size: value == nil ? 16 : 22, weight: .bold))
                        .tracking(-0.66)
                        .foregroundStyle(value == nil ? SSColor.textTertiary : SSColor.textStrong)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct IdentificationPill: View {
    let status: IdentificationStatus
    var matchedTitle: String = L("Identified")

    var body: some View {
        switch status {
        case .identified: StatusPill(title: matchedTitle)
        case .partial, .unknown: StatusPill(title: L("Partial"), dot: SSColor.statusAmber)
        }
    }
}

/// Device Identity Card: illustration stage, name with edit, model, iOS, status.
struct DeviceIdentityCard: View {
    let model: DeviceModel

    var body: some View {
        let summary = model.summary
        HStack(spacing: 16) {
            DeviceFrontIllustration(width: 70)
                .frame(width: 118, height: 184)
                .background(SSColor.stage, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.66)
                        .foregroundStyle(SSColor.textStrong)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CircleIconButton(icon: .edit, label: L("Rename device"), size: 30, iconSize: 15) {
                        model.beginRename()
                    }
                }
                Text(summary.modelName ?? L("Unknown iPhone model"))
                    .ssText(.label14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.75))
                if let version = model.details?.osVersion ?? summary.osVersion {
                    Text(L("iOS \(version)"))
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textTertiary)
                }
                Spacer().frame(height: 6)
                IdentificationPill(status: model.identification)
            }
        }
    }
}

/// Information Banner for a model that is not in the catalogue (DEV-04).
struct UnknownModelBanner: View {
    let identifier: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SSIconView(.info, size: 20, color: SSColor.textStrong)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("This iPhone isn’t in our catalogue yet"))
                    .ssText(.labelSemibold14)
                Text(L("Identifier \(identifier ?? Fallback.unavailable). Live values such as memory, storage and refresh rate still work; other specifications show as unavailable until the next update."))
                    .ssText(.caption13)
                    .opacity(0.75)
            }
            .foregroundStyle(SSColor.textStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Refresh Control pill shown while new readings load.
struct RefreshingPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text(L("Refreshing device information…"))
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textStrong)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(SSColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Error banner (DEV-10): the last readings stay, with when they were taken.
struct RefreshErrorBanner: View {
    let lastUpdated: Date?
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SSIconView(.warning, size: 18, color: SSColor.errorText)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.7), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Couldn’t refresh"))
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textStrong)
                Text(lastUpdated.map { L("Showing details from \(DeviceFormat.time($0)).") } ?? L("No device details could be read."))
                    .ssText(.caption12)
                    .foregroundStyle(Color(hex: 0x5C4040))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(action: onRetry) {
                Text(L("Retry"))
                    .ssText(.segment13)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Loading state: grey blocks in the shape of the overview.
struct DeviceOverviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SSColor.hairline).frame(width: 118, height: 184)
                VStack(alignment: .leading, spacing: 10) {
                    block(width: 150, height: 22)
                    block(width: 110, height: 14)
                    block(width: 70, height: 12)
                    block(width: 90, height: 22)
                }
            }
            block(width: 110, height: 18)
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SSColor.surface).frame(height: 260)
            block(width: 130, height: 18)
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SSColor.surface).frame(height: 320)
        }
        .redacted(reason: .placeholder)
        .accessibilityElement()
        .accessibilityLabel(Text(L("Loading device information")))
    }

    private func block(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SSColor.hairline).frame(width: width, height: height)
    }
}
