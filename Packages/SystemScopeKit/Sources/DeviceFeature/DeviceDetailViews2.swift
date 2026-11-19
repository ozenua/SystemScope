import Core
import DesignSystem
import DeviceInfo
import SwiftUI

// DEV-07 Connectivity, DEV-08 Sensors, DEV-09 Battery, DEV-10 Operating System,
// DEV-11 Graphics.

// MARK: - Connectivity

struct ConnectivityView: View {
    let model: DeviceModel
    let onOpenMonitor: () -> Void

    var body: some View {
        let network = model.network
        let specs = model.specifications
        DevicePage {
            DeviceDetailHeader(title: L("Connectivity"), subtitle: L("Wireless and communication capabilities"), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(network == nil ? Fallback.unavailable : (network?.isConnected == true ? L("Connected") : L("Not connected")))
                            .font(.system(size: 26, weight: .bold))
                            .tracking(-0.78)
                            .foregroundStyle(SSColor.textStrong)
                        Text(statusLine(network))
                            .ssText(.caption13)
                            .foregroundStyle(SSColor.textTertiary)
                    }
                    Spacer()
                    SSIconView(network?.interface == .cellular ? .cellular : .wifi, size: 24, color: SSColor.textStrong)
                        .frame(width: 48, height: 48)
                        .background(SSColor.surface, in: Circle())
                }
                .accessibilityElement(children: .combine)
                if let network {
                    SSFlowLayout(spacing: 6) {
                        StatusPill(title: L("Wi-Fi"), dot: network.interface == .wifi ? SSColor.statusGreen : SSColor.textFaint)
                        StatusPill(title: L("Cellular"), dot: network.isCellularAvailable == true || network.interface == .cellular ? SSColor.statusGreen : SSColor.textFaint)
                        if network.isConstrained == true { StatusPill(title: L("Low Data Mode"), dot: SSColor.statusAmber) }
                        if network.isExpensive == true { StatusPill(title: L("Metered"), dot: SSColor.accent) }
                    }
                }
            }
            DeviceSectionTitle(title: L("Capabilities"))
            let cells: [(SSIcon, String, String?, String?)] = [
                (.wifi, L("Wi-Fi"), specs?.wifiStandard, network?.interface == .wifi ? L("Connected") : nil),
                (.cellular, L("Cellular"), specs?.cellular, network?.isCellularAvailable.map { $0 ? L("Available") : L("Not in use") }),
                (.signal, L("Bluetooth"), specs?.bluetoothVersion, nil),
                (.mobile, L("NFC"), specs?.nfc, nil),
                (.radar, L("Ultra Wideband"), specs?.ultraWideband, nil),
                (.radar, L("GPS / GNSS"), specs?.gnss, nil),
                (.signal, L("Satellite"), specs?.satellite, nil),
                (.bolt, L("Wired"), specs?.port, nil),
            ]
            let rows = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                            if column > 0 { Rectangle().fill(SSColor.border).frame(width: 1) }
                            VStack(alignment: .leading, spacing: 4) {
                                SSIconView(cell.0, size: 18, color: SSColor.textStrong).padding(.bottom, 14)
                                Text(cell.1).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                                Text(cell.2 ?? Fallback.notInCatalogue)
                                    .font(.system(size: cell.2 == nil ? 14 : 17, weight: .bold))
                                    .foregroundStyle(cell.2 == nil ? SSColor.textTertiary : SSColor.textStrong)
                                if let live = cell.3 {
                                    Text(live).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            DeviceNote(text: L("SystemScope only shows connection details iOS shares with apps. Some features depend on your region and carrier."))
            RelatedMonitorCard(
                title: L("Check your connection"),
                message: L("Connection status, speed tests and SystemScope’s data usage."),
                button: L("Open Network Monitor"),
                action: onOpenMonitor
            )
        }
    }

    private func statusLine(_ network: NetworkSnapshot?) -> String {
        guard let network else { return L("Connection status couldn't be read") }
        var parts: [String] = []
        switch network.interface {
        case .wifi: parts.append(L("Wi-Fi in use"))
        case .cellular: parts.append(L("Cellular in use"))
        case .wired: parts.append(L("Wired connection in use"))
        case .other, nil: break
        }
        if network.isCellularAvailable == true, network.interface != .cellular { parts.append(L("Cellular available")) }
        return parts.isEmpty ? L("No active connection") : parts.joined(separator: " · ")
    }
}

// MARK: - Sensors

struct SensorsView: View {
    let model: DeviceModel

    var body: some View {
        let sensors = model.details?.sensors ?? []
        let available = sensors.filter { $0.availability == .available || $0.availability == .supported }.count
        let needsPermission = sensors.filter { $0.availability == .permissionRequired }.count
        DevicePage {
            DeviceDetailHeader(title: L("Sensors"), subtitle: L("Hardware sensors in your iPhone"), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Your device can sense more than you think."))
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.66)
                    .foregroundStyle(SSColor.textStrong)
                Text(L("Explore the sensors and detection technologies built into your iPhone."))
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textSubtle)
                SSFlowLayout(spacing: 6) {
                    HeroChip(text: L("\(sensors.count) sensors"))
                    HeroChip(text: L("\(available) available"))
                    if needsPermission > 0 { HeroChip(text: L("\(needsPermission) need permission")) }
                }
            }
            DeviceSectionTitle(title: L("Sensor inventory"))
            if sensors.isEmpty {
                DeviceNote(text: L("Sensor information couldn't be read."))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                        if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1).padding(.horizontal, 12) }
                        let info = SensorInfo(sensor.kind)
                        Button { model.sheet = .sensor(sensor.kind) } label: {
                            HStack(spacing: 12) {
                                OutlinedIcon(icon: info.icon, size: 40, iconSize: 20, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.name).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                                    Text(info.summary).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                SensorStatusPill(availability: sensor.availability, test: model.sensorTests[sensor.kind])
                                SSIconView(.chevronRight, size: 18, color: SSColor.textFaint)
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.vertical, 4)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            DeviceNote(text: L("Status shows what SystemScope can verify. A sensor can be built in even if iOS doesn’t let apps read it directly."))
        }
    }
}

// MARK: - Battery

struct BatteryView: View {
    let model: DeviceModel
    let onOpenMonitor: () -> Void

    var body: some View {
        let battery = model.batterySnapshot
        let specs = model.specifications
        DevicePage {
            DeviceDetailHeader(title: L("Battery"), subtitle: L("Battery hardware and charging capabilities"), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 12) {
                BatteryGraphic(level: battery.level, charging: battery.state == .charging)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(battery.level.map { "\($0)%" } ?? Fallback.unavailable)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1.02)
                        .foregroundStyle(SSColor.textStrong)
                    if let state = battery.state {
                        Text(stateLabel(state)).ssText(.labelSemibold14).foregroundStyle(SSColor.textSubtle)
                    }
                }
                .accessibilityElement(children: .combine)
                Text(L("Battery level and charging state reported by iOS."))
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textTertiary)
            }
            DeviceSectionTitle(title: L("Battery specifications"))
            SpecificationCard(specs: [
                Spec(label: L("Battery state"), value: battery.state.map(stateLabel)),
                Spec(label: L("Battery level"), value: battery.level.map { "\($0)%" }),
                Spec(label: L("Charging port"), value: specs?.port, fallback: Fallback.notInCatalogue),
                Spec(label: L("Fast charging"), value: specs?.fastCharging, fallback: Fallback.notInCatalogue),
                Spec(label: L("Wireless charging"), value: specs?.wirelessCharging, fallback: Fallback.notInCatalogue),
            ])
            VStack(spacing: 8) {
                SSIconView(.info, size: 20, color: SSColor.textStrong)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
                Text(L("Battery health isn’t available here"))
                    .ssText(.rowTitle15)
                    .foregroundStyle(SSColor.textStrong)
                Text(L("iOS shows maximum capacity and cycle count in Settings › Battery, not to apps."))
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityElement(children: .combine)
            DeviceSectionTitle(title: L("Related information"))
            SpecificationCard(specs: [
                Spec(label: L("Low Power Mode"), value: battery.isLowPowerModeEnabled ? L("On") : L("Off")),
                Spec(label: L("Last reading"), value: DeviceFormat.relative(battery.observedAt)),
            ])
            RelatedMonitorCard(
                title: L("Watch your battery over time"),
                message: L("Charging sessions and battery level history."),
                button: L("Open Battery Monitor"),
                action: onOpenMonitor
            )
        }
    }

    private func stateLabel(_ state: BatteryChargeState) -> String {
        switch state {
        case .charging: L("Charging")
        case .full: L("Full")
        case .unplugged: L("Not charging")
        }
    }
}

struct BatteryGraphic: View {
    let level: Int?
    let charging: Bool

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(SSColor.textStrong, lineWidth: 2.5)
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(fill)
                        .frame(width: max(0, (proxy.size.width) * CGFloat(level ?? 0) / 100))
                }
                .padding(6)
                if charging {
                    SSIconView(.lightning, size: 22, color: SSColor.textStrong)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 104, height: 46)
            RoundedRectangle(cornerRadius: 2).fill(SSColor.textStrong).frame(width: 4, height: 16)
        }
        .accessibilityHidden(true)
    }

    private var fill: Color {
        guard let level else { return SSColor.track }
        if level <= 20 { return SSColor.coral.opacity(0.6) }
        return SSColor.pastelGreen
    }
}

// MARK: - Operating System

struct OperatingSystemView: View {
    let model: DeviceModel

    var body: some View {
        let details = model.details
        let version = details?.osVersion ?? model.summary.osVersion
        let build = details?.osBuild
        let recorded = details?.observedAt ?? model.lastUpdated
        DevicePage {
            DeviceDetailHeader(title: L("Operating System"), subtitle: L("Installed software on your iPhone"), onBack: model.goBack)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(details?.osName ?? "iOS")
                        .ssText(.labelSemibold14)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SSColor.ink, in: Capsule())
                    Spacer()
                    Text(L("Installed version")).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                }
                Text(version ?? Fallback.unavailable)
                    .font(.system(size: version == nil ? 32 : 72, weight: .bold))
                    .tracking(-2.88)
                    .foregroundStyle(SSColor.textStrong)
                HStack(spacing: 10) {
                    Text(L("Build")).ssText(.body14).foregroundStyle(SSColor.textSubtle)
                    Text(build ?? Fallback.unavailable)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(SSColor.textStrong)
                }
                if let recorded {
                    HStack(spacing: 6) {
                        SSIconView(.clock, size: 14, color: SSColor.textFaint)
                        Text(L("Recorded \(DeviceFormat.relative(recorded).lowercasedFirst)"))
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                    }
                    .padding(.leading, 20)
                }
            }
            HStack(spacing: 0) {
                copyHalf(L("Copy version"), value: version.map { "iOS \($0)" })
                Rectangle().fill(SSColor.border).frame(width: 1, height: 44)
                copyHalf(L("Copy build"), value: build)
            }
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            DeviceSectionTitle(title: L("Software information"))
            SpecificationCard(specs: [
                Spec(label: L("Operating system"), value: version.map { "iOS \($0)" }, kind: .copyable),
                Spec(label: L("Build number"), value: build, kind: .copyable),
                Spec(label: L("System architecture"), value: details?.architecture),
                Spec(label: L("Device compatibility"), value: model.summary.modelName.map { L("Running on \($0)") }),
            ], onCopy: { model.copy($0) })
            DeviceSectionTitle(title: L("Updates"))
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SSIconView(.refresh, size: 20, color: SSColor.textStrong)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Check for updates in Settings")).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                        Text(L("SystemScope can’t confirm whether a newer iOS version is available. Go to Settings › General › Software Update."))
                            .ssText(.caption13)
                            .foregroundStyle(SSColor.textTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func copyHalf(_ title: String, value: String?) -> some View {
        Button { if let value { model.copy(value) } } label: {
            HStack(spacing: 8) {
                SSIconView(.copy, size: 18, color: SSColor.textStrong)
                Text(title).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(value == nil)
    }
}

extension String {
    /// "Today, 9:41 AM" → "today, 9:41 AM"
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}

// MARK: - Graphics

struct GraphicsView: View {
    let model: DeviceModel
    let onOpenMonitor: () -> Void

    var body: some View {
        let gpu = model.gpu
        let specs = model.specifications
        let capabilities = gpu?.supportedCapabilities ?? []
        let family = DeviceFormat.highestFamily(gpu)
        DevicePage {
            DeviceDetailHeader(
                title: L("Graphics"),
                subtitle: L("GPU and rendering capabilities"),
                onBack: model.goBack,
                trailingIcon: .copy,
                trailingLabel: L("Copy graphics details"),
                trailingAction: { model.copy([gpu?.name, family, capabilities.contains(.metal3) ? "Metal 3" : nil].compactMap { $0 }.joined(separator: " · ")) }
            )
            VStack(alignment: .leading, spacing: 14) {
                GPUCoreGraphic(cores: specs?.gpuCoreCount ?? 6)
                Text(gpu?.name ?? Fallback.unavailable)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(SSColor.textStrong)
                Text([specs?.gpuCoreCount.map { L("\($0)-core") }, family.map { L("\($0) GPU family") }].compactMap { $0 }.joined(separator: " · "))
                    .ssText(.label14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.65))
                SSFlowLayout(spacing: 6) {
                    if capabilities.contains(.metal3) { HeroChip(text: "Metal 3") }
                    if capabilities.contains(.rayTracing) { HeroChip(text: L("Hardware ray tracing")) }
                    if capabilities.contains(.unifiedMemory) { HeroChip(text: L("Unified memory")) }
                }
            }
            DeviceSectionTitle(title: L("Graphics specifications"))
            SpecificationCard(specs: [
                Spec(label: L("Metal feature set"), value: gpu.map { _ in capabilities.contains(.metal3) ? "Metal 3" : (gpu?.metalAvailable == true ? "Metal" : L("Not available")) }, kind: .copyable),
                Spec(label: L("GPU families"), value: gpu.map { $0.families.filter { !$0.hasPrefix("Metal") }.joined(separator: " · ") }.flatMap { $0.isEmpty ? nil : $0 }),
                Spec(label: L("Ray tracing"), value: gpu.map { _ in capabilities.contains(.rayTracing) ? L("Supported") : L("Not supported") }),
                Spec(label: L("Max threads per group"), value: gpu?.maxThreadsPerThreadgroup.map(String.init)),
                Spec(label: L("Recommended working set"), value: gpu?.recommendedMaxWorkingSetBytes.map { ByteFormatting.memory($0, fractionDigits: 1) }),
                Spec(label: L("Hardware generation"), value: family.map { name in specs?.releaseYear.map { "\(name) (\($0))" } ?? name }),
            ], onCopy: { model.copy($0) })
            RelatedMonitorCard(
                title: L("See graphics performance reports"),
                message: L("SystemScope’s own GPU time and Metal capability details."),
                button: L("Open GPU Monitor"),
                action: onOpenMonitor
            )
        }
    }
}

/// GPU cores drawn as tiles, three to a row, the first filled.
struct GPUCoreGraphic: View {
    let cores: Int

    var body: some View {
        let count = min(max(cores, 1), 12)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 3), alignment: .leading, spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(index == 0 ? SSColor.textStrong : Color.white.opacity(0.7))
                    .frame(width: 34, height: 34)
            }
        }
        .frame(width: 110, alignment: .leading)
        .accessibilityHidden(true)
    }
}
