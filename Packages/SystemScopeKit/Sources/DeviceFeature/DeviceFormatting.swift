import Core
import DeviceInfo
import Foundation

/// Device copy from the String Catalog (PRD §15.3).
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

enum Fallback {
    /// A live API value SystemScope could not read.
    static var unavailable: String { L("Unavailable") }
    /// A static specification the catalogue does not have yet (DEV-05).
    static var notInCatalogue: String { L("Not in catalogue") }
}

enum DeviceFormat {
    static func memory(_ bytes: UInt64?) -> String? {
        bytes.map { ByteFormatting.memory($0) }
    }

    static func gigabytes(_ bytes: UInt64?) -> Int? {
        bytes.map { Int((Double($0) / 1_073_741_824).rounded()) }
    }

    static func storage(_ bytes: Int64?) -> String? {
        guard let bytes else { return nil }
        // Marketing capacity: the nearest standard size above the formatted volume.
        let gb = Double(bytes) / 1_000_000_000
        let tiers: [Double] = [64, 128, 256, 512, 1_024, 2_048]
        if let tier = tiers.first(where: { gb <= $0 }) {
            return tier >= 1_024 ? "\(Int(tier / 1_024)) TB" : "\(Int(tier)) GB"
        }
        return ByteFormatting.storage(bytes)
    }

    /// "Apple A17 Pro" → "A17 Pro"
    static func shortChip(_ name: String?) -> String? {
        name.map { $0.hasPrefix("Apple ") ? String($0.dropFirst(6)) : $0 }
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Today, 9:41 AM" or "14 Nov 2026, 9:41 AM"
    static func relative(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return L("Today, \(time(date))")
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }

    static func zoom(_ value: Double) -> String {
        "\(number(value))×"
    }

    static func pixels(_ display: DisplayDetails?) -> String? {
        guard let width = display?.nativeWidthPixels, let height = display?.nativeHeightPixels else { return nil }
        return "\(height) × \(width)"
    }

    static func points(_ display: DisplayDetails?) -> String? {
        guard let width = display?.pointWidth, let height = display?.pointHeight else { return nil }
        return "\(Int(width)) × \(Int(height)) pt"
    }

    static func scale(_ display: DisplayDetails?) -> String? {
        display?.scale.map { "@\(Int($0))x" }
    }

    static func diagonal(_ inches: Double?) -> String? {
        inches.map { "\(number($0))″" }
    }

    static func coreSplit(_ summary: DeviceSummary) -> String? {
        guard let performance = summary.performanceCoreCount, let efficiency = summary.efficiencyCoreCount else { return nil }
        return L("\(performance) performance + \(efficiency) efficiency")
    }

    static func cameraName(_ camera: CameraDetails, hasFaceID: Bool) -> String {
        switch camera.kind {
        case .wide: L("Main")
        case .ultraWide: L("Ultra Wide")
        case .telephoto: L("Telephoto")
        case .trueDepth: hasFaceID ? L("TrueDepth") : L("Front")
        }
    }

    static func cameraSummary(_ camera: CameraDetails) -> String {
        var parts: [String] = []
        if let megapixels = camera.megapixels { parts.append("\(megapixels) MP") }
        if let aperture = camera.aperture { parts.append("ƒ/\(number(aperture, digits: 2))") }
        return parts.isEmpty ? Fallback.unavailable : parts.joined(separator: " · ")
    }

    static func highestFamily(_ gpu: GPUInformation?) -> String? {
        gpu?.families.first { $0.hasPrefix("Apple") }
    }
}

/// Plain-text report for "Copy all specifications" (DEV-08). Every value carries the
/// same fallback wording as the screens.
@MainActor
enum DeviceReport {
    static func text(for model: DeviceModel) -> String {
        let summary = model.summary
        let details = model.details
        let specs = model.specifications
        func line(_ label: String, _ value: String?, fallback: String = Fallback.unavailable) -> String {
            "\(label): \(value ?? fallback)"
        }
        var lines = [
            "SystemScope — \(model.displayName)",
            line(L("Model"), summary.modelName ?? L("Unknown iPhone model")),
            line(L("Model identifier"), summary.modelIdentifier ?? details?.hardwareIdentifier),
            line(L("iOS version"), details?.osVersion ?? summary.osVersion),
            line(L("Build number"), details?.osBuild),
            line(L("Processor"), summary.processor, fallback: Fallback.notInCatalogue),
            line(L("CPU cores"), summary.processorCoreCount.map(String.init)),
            line(L("Physical memory"), DeviceFormat.memory(summary.physicalMemoryBytes)),
            line(L("Storage"), DeviceFormat.storage(summary.storageTotalBytes)),
            line(L("Resolution"), DeviceFormat.pixels(details?.display)),
            line(L("Maximum refresh rate"), details?.display?.maximumFramesPerSecond.map { "\($0) Hz" }),
            line(L("Screen size"), DeviceFormat.diagonal(specs?.screenDiagonalInches), fallback: Fallback.notInCatalogue),
            line(L("GPU"), model.gpu?.name),
            line(L("Cameras"), details.map { "\($0.cameras.count)" }),
        ]
        if let updated = model.lastUpdated {
            lines.append(line(L("Recorded"), updated.formatted(date: .abbreviated, time: .shortened)))
        }
        lines.append(L("Catalogue version \(details?.catalogueVersion ?? DeviceCatalogue.bundled.version)"))
        return lines.joined(separator: "\n")
    }
}
