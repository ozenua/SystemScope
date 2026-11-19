import Core
import DesignSystem
import DeviceInfo
import SwiftUI

// DEV-02 General, DEV-03 Processor, DEV-04 Memory, DEV-05 Display, DEV-06 Camera.
// Live API readings fall back to "Unavailable"; catalogue specifications fall back
// to "Not in catalogue" (DEV-03, DEV-05).

// MARK: - General

struct GeneralView: View {
    let model: DeviceModel

    var body: some View {
        let summary = model.summary
        let details = model.details
        let identifier = summary.modelIdentifier ?? details?.hardwareIdentifier
        DevicePage {
            DeviceDetailHeader(
                title: L("General"),
                subtitle: L("Identity and configuration of your iPhone"),
                onBack: model.goBack,
                trailingIcon: .more,
                trailingLabel: L("More options"),
                trailingAction: { model.sheet = .actions }
            )
            identity(summary: summary, identifier: identifier)
            DeviceSectionTitle(title: L("Device information"))
            SpecificationCard(specs: [
                Spec(label: L("Device name"), value: model.displayName, kind: .action { model.beginRename() }),
                Spec(label: L("Model"), value: summary.modelName, fallback: L("Unknown iPhone model")),
                Spec(label: L("Model identifier"), value: identifier, kind: .copyable),
                Spec(label: L("Device family"), value: details?.deviceFamily),
                Spec(label: L("First registered"), value: DeviceFormat.day(model.firstRegistered)),
            ], onCopy: { model.copy($0) })
            DeviceSectionTitle(title: L("System configuration"))
            SpecificationCard(specs: [
                Spec(label: L("iOS version"), value: details?.osVersion ?? summary.osVersion, kind: .action { model.open(.operatingSystem) }),
                Spec(label: L("Build number"), value: details?.osBuild, kind: .copyable),
                Spec(label: L("Architecture"), value: details?.architecture),
                Spec(label: L("Physical memory"), value: DeviceFormat.memory(summary.physicalMemoryBytes)),
                Spec(label: L("Display scale"), value: DeviceFormat.scale(details?.display)),
                Spec(label: L("Screen dimensions"), value: DeviceFormat.points(details?.display)),
            ], onCopy: { model.copy($0) })
            ExpandableSection(title: L("Additional information"), subtitle: L("Locale, region and time zone")) {
                SpecificationList(specs: [
                    Spec(label: L("Language"), value: details?.localeName),
                    Spec(label: L("Region"), value: details?.regionName),
                    Spec(label: L("Time zone"), value: details?.timeZone),
                ])
            }
            OutlineButton(icon: .copy, title: L("Copy specifications")) { model.copyAllSpecifications() }
        }
    }

    private func identity(summary: DeviceSummary, identifier: String?) -> some View {
        HStack(spacing: 16) {
            DeviceBackIllustration()
                .frame(width: 108, height: 160)
                .background(SSColor.pastelBlue, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(SSColor.textStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CircleIconButton(icon: .edit, label: L("Rename device"), size: 30, iconSize: 15) { model.beginRename() }
                }
                Text(summary.modelName ?? L("Unknown iPhone model"))
                    .ssText(.label14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.75))
                if let identifier {
                    Button { model.copy(identifier) } label: {
                        HStack(spacing: 6) {
                            Text(identifier)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(SSColor.textStrong)
                            SSIconView(.copy, size: 14, color: SSColor.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SSColor.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L("Copy model identifier \(identifier)")))
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - Processor

struct ProcessorView: View {
    let model: DeviceModel
    let onOpenMonitor: () -> Void

    var body: some View {
        let summary = model.summary
        let specs = model.specifications
        let architecture = model.details?.architecture
        DevicePage {
            DeviceDetailHeader(
                title: L("Processor"),
                subtitle: L("Your iPhone’s chip and CPU configuration"),
                onBack: model.goBack,
                trailingIcon: .copy,
                trailingLabel: L("Copy processor"),
                trailingAction: { model.copy(summary.processor ?? Fallback.notInCatalogue) }
            )
            Button { model.sheet = .spec(SpecSheets.chip(model)) } label: {
                VStack(alignment: .leading, spacing: 18) {
                    SiliconGraphic()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.processor ?? Fallback.notInCatalogue)
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-1.2)
                            .foregroundStyle(SSColor.textStrong)
                        Text(chipLine(specs))
                            .ssText(.label14)
                            .foregroundStyle(SSColor.textStrong.opacity(0.65))
                    }
                    SSFlowLayout(spacing: 6) {
                        if let cores = summary.processorCoreCount { HeroChip(text: L("\(cores)-core CPU")) }
                        if let gpu = specs?.gpuCoreCount { HeroChip(text: L("\(gpu)-core GPU")) }
                        if let neural = specs?.neuralEngineCoreCount { HeroChip(text: L("\(neural)-core Neural Engine")) }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(L("Shows chip details")))
            CompactSpecGrid(cells: [
                .init(label: L("CPU architecture"), value: architecture),
                .init(label: L("Total cores"), value: summary.processorCoreCount.map(String.init)),
                .init(label: L("Performance cores"), value: summary.performanceCoreCount.map(String.init), fallback: Fallback.notInCatalogue),
                .init(label: L("Efficiency cores"), value: summary.efficiencyCoreCount.map(String.init), fallback: Fallback.notInCatalogue),
            ])
            DeviceSectionTitle(title: L("Processor information"))
            ExpandableSection(title: L("CPU Architecture"), subtitle: L("Architecture and core configuration"), isExpanded: true) {
                SpecificationList(specs: [
                    Spec(label: L("Architecture"), value: architecture.map { L("64-bit ARM (\($0))") }),
                    Spec(label: L("Core configuration"), value: DeviceFormat.coreSplit(summary), fallback: Fallback.notInCatalogue),
                    Spec(label: L("Active cores"), value: summary.activeCoreCount.map(String.init)),
                    Spec(label: L("Instruction capabilities"), value: specs?.instructionCapabilities, fallback: Fallback.notInCatalogue),
                ])
            }
            ExpandableSection(title: L("Neural Processing"), subtitle: L("Neural Engine and machine learning")) {
                SpecificationList(specs: [
                    Spec(label: L("Neural Engine"), value: specs?.neuralEngineCoreCount.map { L("\($0) cores") }, fallback: Fallback.notInCatalogue),
                ])
            }
            ExpandableSection(title: L("Chip Details"), subtitle: L("Generation, family and graphics")) {
                SpecificationList(specs: [
                    Spec(label: L("Chip"), value: summary.processor, fallback: Fallback.notInCatalogue),
                    Spec(label: L("Family"), value: specs?.chipFamily, fallback: Fallback.notInCatalogue),
                    Spec(label: L("Process"), value: specs?.processNanometres.map { "\($0) nm" }, fallback: Fallback.notInCatalogue),
                    Spec(label: L("Released"), value: specs?.releaseYear.map(String.init), fallback: Fallback.notInCatalogue),
                    Spec(label: L("Graphics"), value: model.gpu?.name),
                ])
            }
            RelatedMonitorCard(
                title: L("See how SystemScope uses the CPU"),
                message: L("Live app activity, session history and processor details."),
                button: L("Explore CPU Monitor"),
                action: onOpenMonitor
            )
        }
    }

    private func chipLine(_ specs: DeviceSpecifications?) -> String {
        let parts = [specs?.chipFamily, specs?.processNanometres.map { L("\($0) nm process") }, specs?.releaseYear.map(String.init)].compactMap { $0 }
        return parts.isEmpty ? L("Chip details aren't in the catalogue yet") : parts.joined(separator: " · ")
    }
}

/// Silicon graphic: package, die, two performance cores, four efficiency cores and the Neural Engine.
struct SiliconGraphic: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.75)).frame(width: 96, height: 96)
            ForEach(0..<4) { index in
                let x = CGFloat(30 + index * 12)
                Rectangle().fill(SSColor.textStrong.opacity(0.35)).frame(width: 4, height: 6).offset(x: x, y: 4)
                Rectangle().fill(SSColor.textStrong.opacity(0.35)).frame(width: 4, height: 6).offset(x: x, y: 86)
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SSColor.textStrong).frame(width: 64, height: 64).offset(x: 16, y: 16)
            ForEach(0..<2) { index in
                RoundedRectangle(cornerRadius: 3).strokeBorder(SSColor.border, lineWidth: 1)
                    .frame(width: 24, height: 24).offset(x: CGFloat(22 + index * 28), y: 22)
            }
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 3).fill(SSColor.pastelBlue)
                    .frame(width: 11, height: 10).offset(x: CGFloat(22 + index * 13), y: 50)
            }
            RoundedRectangle(cornerRadius: 3).fill(SSColor.pastelGreen).frame(width: 50, height: 8).offset(x: 22, y: 64)
        }
        .frame(width: 96, height: 96, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - Memory

struct MemoryView: View {
    let model: DeviceModel
    let onOpenMonitor: () -> Void

    var body: some View {
        let summary = model.summary
        let specs = model.specifications
        let gigabytes = DeviceFormat.gigabytes(summary.physicalMemoryBytes)
        let unified = model.gpu?.supportedCapabilities.contains(.unifiedMemory)
        DevicePage {
            DeviceDetailHeader(
                title: L("Memory"),
                subtitle: L("Physical memory built into your iPhone"),
                onBack: model.goBack,
                trailingIcon: .copy,
                trailingLabel: L("Copy memory"),
                trailingAction: { model.copy(DeviceFormat.memory(summary.physicalMemoryBytes) ?? Fallback.unavailable) }
            )
            VStack(alignment: .leading, spacing: 12) {
                if let gigabytes {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(gigabytes)").font(.system(size: 72, weight: .bold)).tracking(-2.88)
                        Text("GB").ssText(.unit28)
                    }
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityElement(children: .combine)
                } else {
                    Text(Fallback.unavailable).ssText(.metric32).foregroundStyle(SSColor.textTertiary)
                }
                Text(L("Physical device memory"))
                    .ssText(.label14)
                    .foregroundStyle(SSColor.textSubtle)
                if let gigabytes, gigabytes > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<min(gigabytes, 16), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SSColor.surface).frame(height: 24)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(gigabytes <= 16 ? L("Each block represents 1 GB") : L("Showing the first 16 GB"))
                        .ssText(.caption12)
                        .foregroundStyle(SSColor.textTertiary)
                }
            }
            DeviceSectionTitle(title: L("Memory information"))
            SpecificationCard(specs: [
                Spec(label: L("Total physical memory"), value: DeviceFormat.memory(summary.physicalMemoryBytes), kind: .copyable),
                Spec(label: L("Memory architecture"), value: unified == true ? L("Unified memory") : nil),
                Spec(label: L("Memory type"), value: specs?.memoryType, fallback: Fallback.notInCatalogue),
                Spec(label: L("Classification"), value: gigabytes.map { L("\($0) GB tier") }),
                Spec(label: L("Hardware generation"), value: generation(summary, specs), fallback: Fallback.notInCatalogue),
            ], onCopy: { model.copy($0) })
            DeviceNote(text: L("This is the memory built into your iPhone. iOS doesn’t let apps see how much memory other apps are using."))
            RelatedMonitorCard(
                title: L("Monitor memory usage"),
                message: L("See how much memory SystemScope uses during active monitoring sessions."),
                button: L("Open Memory Monitor"),
                action: onOpenMonitor
            )
        }
    }

    private func generation(_ summary: DeviceSummary, _ specs: DeviceSpecifications?) -> String? {
        guard let chip = DeviceFormat.shortChip(summary.processor) else { return nil }
        return specs?.releaseYear.map { "\(chip) (\($0))" } ?? chip
    }
}

// MARK: - Display

struct DisplayView: View {
    let model: DeviceModel

    var body: some View {
        let display = model.details?.display
        let specs = model.specifications
        DevicePage {
            DeviceDetailHeader(
                title: L("Display"),
                subtitle: L("Screen technology and capabilities"),
                onBack: model.goBack,
                trailingIcon: .copy,
                trailingLabel: L("Copy display details"),
                trailingAction: { model.copy(copyText(display, specs)) }
            )
            HStack(spacing: 16) {
                DeviceFrontIllustration(width: 54)
                    .frame(width: 78, height: 110)
                    .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(specs?.displayName ?? L("Built-in display"))
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(SSColor.textStrong)
                    Text(summaryLine(display, specs))
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textStrong.opacity(0.7))
                }
            }
            CompactSpecGrid(cells: [
                .init(label: L("Resolution"), value: DeviceFormat.pixels(display)),
                .init(label: L("Screen size"), value: DeviceFormat.diagonal(specs?.screenDiagonalInches).map { L("\($0) diagonal") }, fallback: Fallback.notInCatalogue),
                .init(label: L("Pixel density"), value: specs?.pixelDensity.map { "\($0) ppi" }, fallback: Fallback.notInCatalogue),
                .init(label: L("Display scale"), value: DeviceFormat.scale(display)),
            ])
            DeviceSectionTitle(title: L("Display capabilities"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                CapabilityTile(title: L("Refresh rate"), detail: display?.maximumFramesPerSecond.map { L("Up to \($0) Hz") }, supported: display?.maximumFramesPerSecond != nil)
                CapabilityTile(
                    title: L("ProMotion"),
                    detail: display?.isProMotion.map { pro in
                        guard pro, let max = display?.maximumFramesPerSecond else { return L("Not supported") }
                        return specs?.minimumRefreshHz.map { L("Adaptive \($0)–\(max) Hz") } ?? L("Adaptive up to \(max) Hz")
                    },
                    supported: display?.isProMotion
                )
                CapabilityTile(
                    title: L("HDR"),
                    detail: display?.isHDR.map { hdr in
                        guard hdr else { return L("Not supported") }
                        return specs?.peakBrightnessNits.map { L("Up to \($0.formatted()) nits") } ?? L("Supported")
                    },
                    supported: display?.isHDR
                )
                CapabilityTile(title: L("Wide color"), detail: display?.supportsWideColor.map { $0 ? L("Display P3") : L("sRGB") }, supported: display?.supportsWideColor)
                CapabilityTile(title: L("Always-On"), detail: specs?.alwaysOn.map { $0 ? L("Supported") : L("Not supported") } ?? Fallback.notInCatalogue, supported: specs?.alwaysOn)
            }
            DeviceSectionTitle(title: L("Current configuration"))
            SpecificationCard(specs: [
                Spec(label: L("Orientation"), value: display?.orientation.map { $0 == .portrait ? L("Portrait") : L("Landscape") }),
                Spec(label: L("Brightness"), value: display?.brightness.map { $0.formatted(.percent.precision(.fractionLength(0))) }),
                Spec(label: L("Appearance"), value: display?.appearance.map { $0 == .light ? L("Light") : L("Dark") }),
            ])
            DeviceNote(text: L("Change brightness and appearance in Settings › Display & Brightness."))
        }
    }

    private func summaryLine(_ display: DisplayDetails?, _ specs: DeviceSpecifications?) -> String {
        var parts: [String] = []
        if let size = DeviceFormat.diagonal(specs?.screenDiagonalInches) { parts.append(size) }
        if let panel = specs?.panelTechnology { parts.append(panel) }
        var features: [String] = []
        if display?.isProMotion == true { features.append(L("ProMotion")) }
        if specs?.alwaysOn == true { features.append(L("Always-On")) }
        let base = parts.isEmpty ? (DeviceFormat.pixels(display).map { L("\($0) pixels") } ?? Fallback.unavailable) : parts.joined(separator: " ")
        return features.isEmpty ? base : L("\(base) with \(features.formatted(.list(type: .and)))")
    }

    private func copyText(_ display: DisplayDetails?, _ specs: DeviceSpecifications?) -> String {
        [specs?.displayName, DeviceFormat.pixels(display), display?.maximumFramesPerSecond.map { "\($0) Hz" }]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

/// Capability tile: tick (or dash) icon, title and detail.
struct CapabilityTile: View {
    let title: String
    let detail: String?
    let supported: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SSIconView(supported == true ? .tickCircle : .info, size: 16, color: SSColor.textStrong.opacity(supported == true ? 1 : 0.4))
                Text(title)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textStrong)
            }
            Text(detail ?? Fallback.unavailable)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Camera (DEV-14: enumeration only, no permission)

struct CameraView: View {
    let model: DeviceModel

    var body: some View {
        let cameras = model.details?.cameras ?? []
        // Main camera first, then the others by zoom, as in Figma.
        let rear = cameras.filter { $0.position == .back }.sorted { lhs, rhs in
            if (lhs.kind == .wide) != (rhs.kind == .wide) { return lhs.kind == .wide }
            return (lhs.relativeZoom ?? 1) < (rhs.relativeZoom ?? 1)
        }
        let front = cameras.filter { $0.position == .front }
        let hasFaceID = model.status(of: .faceID) == .supported
        let hasLiDAR = model.status(of: .lidar) == .supported
        DevicePage {
            DeviceDetailHeader(
                title: L("Camera"),
                subtitle: L("Camera system and supported features"),
                onBack: model.goBack,
                trailingIcon: .copy,
                trailingLabel: L("Copy camera details"),
                trailingAction: { model.copy(cameras.map { "\(DeviceFormat.cameraName($0, hasFaceID: hasFaceID)): \(DeviceFormat.cameraSummary($0))" }.joined(separator: "\n")) }
            )
            HStack(spacing: 16) {
                DeviceBackIllustration(width: 48)
                    .frame(width: 78, height: 110)
                    .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(rear.count >= 3 ? L("Pro camera system") : L("Camera system"))
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(SSColor.textStrong)
                    Text(systemLine(rear: rear.count, front: front.count, lidar: hasLiDAR))
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textStrong.opacity(0.7))
                    SSFlowLayout(spacing: 6) {
                        if let main = rear.first(where: { $0.kind == .wide })?.megapixels { HeroChip(text: "\(main) MP", background: SSColor.surface) }
                        if let tele = rear.first(where: { $0.kind == .telephoto })?.relativeZoom { HeroChip(text: L("\(DeviceFormat.zoom(tele)) optical"), background: SSColor.surface) }
                    }
                }
            }
            if cameras.isEmpty {
                DeviceNote(text: L("iOS didn't report any cameras on this device."))
            }
            if !rear.isEmpty {
                DeviceSectionTitle(title: L("Rear cameras"))
                ForEach(Array(rear.enumerated()), id: \.element.id) { index, camera in
                    cameraSection(camera, hasFaceID: hasFaceID, expanded: camera.kind == .wide || (index == 0 && !rear.contains { $0.kind == .wide }))
                }
            }
            if !front.isEmpty {
                DeviceSectionTitle(title: L("Front camera"))
                ForEach(front) { camera in
                    cameraSection(camera, hasFaceID: hasFaceID, expanded: false, extra: hasFaceID ? L("Face ID") : nil)
                }
            }
            if !cameras.isEmpty {
                DeviceSectionTitle(title: L("Camera capabilities"))
                SpecificationCard(specs: [
                    Spec(label: L("Frame rates"), value: cameras.compactMap(\.maxFrameRate).max().map { L("Up to \($0) fps") }),
                    Spec(label: L("HDR video"), value: cameras.contains { $0.supportsHDRVideo == true } ? L("Supported") : L("Not reported")),
                    Spec(label: L("Optical zoom"), value: opticalRange(rear)),
                    Spec(label: L("Digital zoom"), value: rear.compactMap(\.maxVideoZoomFactor).max().map { L("Up to \(DeviceFormat.zoom($0))") }),
                ])
            }
            DeviceNote(text: L("SystemScope lists cameras without asking for camera access. Video formats such as ProRes are set in Settings › Camera."))
        }
    }

    private func cameraSection(_ camera: CameraDetails, hasFaceID: Bool, expanded: Bool, extra: String? = nil) -> some View {
        let subtitle = [DeviceFormat.cameraSummary(camera), extra].compactMap { $0 }.joined(separator: " · ")
        let zoom = camera.relativeZoom.map(DeviceFormat.zoom) ?? "–"
        return ExpandableSection(
            title: DeviceFormat.cameraName(camera, hasFaceID: hasFaceID),
            subtitle: subtitle,
            isExpanded: expanded,
            leading: AnyView(
                Text(zoom)
                    .ssText(.segment13)
                    .foregroundStyle(SSColor.textStrong)
                    .frame(width: 40, height: 40)
                    .background(camera.kind == .telephoto ? SSColor.pastelBlue : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(camera.kind == .telephoto ? .clear : SSColor.border, lineWidth: 1))
            )
        ) {
            SpecificationList(specs: [
                Spec(label: L("Resolution"), value: camera.megapixels.map { "\($0) MP" }, kind: .copyable),
                Spec(label: L("Aperture"), value: camera.aperture.map { "ƒ/\(DeviceFormat.number($0, digits: 2))" }),
                Spec(label: L("Recording"), value: camera.maxFrameRate.map { L("Up to \($0) fps") }),
                Spec(label: L("HDR video"), value: camera.supportsHDRVideo.map { $0 ? L("Supported") : L("Not supported") }),
            ], onCopy: { model.copy($0) })
        }
    }

    private func systemLine(rear: Int, front: Int, lidar: Bool) -> String {
        var line = L("\(rear) rear and \(front) front cameras")
        if lidar { line += L(", plus a LiDAR Scanner") }
        return line
    }

    private func opticalRange(_ rear: [CameraDetails]) -> String? {
        let zooms = rear.compactMap(\.relativeZoom).sorted()
        return zooms.isEmpty ? nil : zooms.map(DeviceFormat.zoom).joined(separator: " · ")
    }
}
