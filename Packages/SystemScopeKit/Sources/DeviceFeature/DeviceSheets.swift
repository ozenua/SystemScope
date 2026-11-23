import Core
import DesignSystem
import DeviceInfo
import SwiftUI

// MARK: - Device actions

struct DeviceActionsSheet: View {
    let model: DeviceModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetChrome(horizontalPadding: 16) {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(L("Device actions"))
                        .ssText(.metric17)
                        .foregroundStyle(SSColor.textStrong)
                    Text([model.displayName, model.summary.modelName].compactMap { $0 }.joined(separator: " · "))
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textTertiary)
                }
                VStack(spacing: 0) {
                    row(.edit, L("Rename device")) { model.beginRename() }
                    divider
                    row(.copy, L("Copy all specifications")) { model.copyAllSpecifications() }
                    divider
                    row(.refresh, L("Refresh information")) {
                        model.sheet = nil
                        Task { await model.refresh() }
                    }
                }
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                Button(L("Cancel")) { dismiss() }
                    .buttonStyle(SheetCancelButtonStyle())
            }
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(360)])
    }

    private var divider: some View {
        Rectangle().fill(SSColor.border).frame(height: 1).padding(.horizontal, 14)
    }

    private func row(_ icon: SSIcon, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SSIconView(icon, size: 20, color: SSColor.textStrong)
                Text(title)
                    .ssText(.label15)
                    .foregroundStyle(SSColor.textStrong)
                Spacer()
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SheetCancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ssText(.metric17)
            .foregroundStyle(SSColor.textStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Rename (DEV-07, PRD §2.3)

struct RenameSheet: View {
    @Bindable var model: DeviceModel
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private var isEmpty: Bool { model.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        SheetChrome {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Rename your device"))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.66)
                        .foregroundStyle(SSColor.textStrong)
                    Text(L("Give your iPhone a name that’s easy to recognize."))
                        .ssText(.body14)
                        .foregroundStyle(SSColor.textTertiary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Device name"))
                        .ssText(.captionMedium13)
                        .foregroundStyle(SSColor.textTertiary)
                    HStack(spacing: 8) {
                        TextField(text: $model.renameDraft, prompt: Text(AppPreferences.defaultDeviceDisplayName).foregroundStyle(SSColor.textFaint)) {
                            Text(L("Device name"))
                        }
                        .ssText(.bodyMedium16)
                        .foregroundStyle(SSColor.textStrong)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { model.saveRename() }
                        if focused, !model.renameDraft.isEmpty {
                            Button { model.renameDraft = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(SSColor.textFaint)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(L("Clear")))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(model.renameError ? SSColor.errorText : (focused ? SSColor.textStrong : SSColor.border), lineWidth: focused || model.renameError ? 1.5 : 1)
                    )
                    HStack {
                        Group {
                            if model.renameError {
                                Text(L("Enter a name to continue.")).foregroundStyle(SSColor.errorText)
                            } else {
                                Text(L("Used only inside SystemScope.")).foregroundStyle(SSColor.textTertiary)
                            }
                        }
                        .ssText(.captionMedium12)
                        Spacer()
                        Text("\(model.renameDraft.count)/\(AppPreferences.deviceDisplayNameLimit)")
                            .ssText(.captionMedium12)
                            .foregroundStyle(SSColor.textFaint)
                            .accessibilityLabel(Text(L("\(model.renameDraft.count) of \(AppPreferences.deviceDisplayNameLimit) characters")))
                    }
                }
                VStack(spacing: 4) {
                    Button(L("Save changes")) { model.saveRename() }
                        .buttonStyle(.ssPrimary)
                        .opacity(isEmpty ? 0.35 : 1)
                    Button(L("Cancel")) { dismiss() }
                        .ssText(.metric17)
                        .foregroundStyle(SSColor.textStrong)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.bottom, 16)
        }
        .presentationDetents([.height(440)])
        .onAppear { focused = true }
    }
}

// MARK: - Specification sheet (DEV-13)

struct SpecificationSheet: View {
    let model: DeviceModel
    let content: SpecSheetContent
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetChrome {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(content.title)
                        .ssText(.metric17)
                        .foregroundStyle(SSColor.textStrong)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    CircleIconButton(icon: .close, label: L("Close"), size: 32, iconSize: 14) { dismiss() }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.value)
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-1.2)
                        .foregroundStyle(SSColor.textStrong)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(content.detail)
                        .ssText(.body14)
                        .foregroundStyle(Color.black.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SSColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(spacing: 0) {
                    ForEach(Array(content.rows.enumerated()), id: \.offset) { index, row in
                        HStack {
                            Text(row.label).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                            Spacer()
                            Text(row.value).ssText(.segment13).foregroundStyle(SSColor.textStrong)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        if index < content.rows.count - 1 {
                            Rectangle().fill(SSColor.border).frame(height: 1)
                        }
                    }
                }
                HStack(spacing: 6) {
                    SSIconView(.shieldTick, size: 14, color: SSColor.textTertiary)
                    Text(L("Source: \(content.source)"))
                        .ssText(.captionMedium12)
                        .foregroundStyle(SSColor.textTertiary)
                }
                Button {
                    model.copy("\(content.title): \(content.value)")
                    copied = true
                } label: {
                    HStack(spacing: 8) {
                        SSIconView(copied ? .tickCircle : .copy, size: 18, color: .white)
                        Text(copied ? L("Copied") : L("Copy"))
                    }
                }
                .buttonStyle(SSPrimaryButtonStyle(fill: copied ? SSColor.chargingGreen : nil))
            }
            .padding(.bottom, 16)
        }
        .presentationDetents([.height(CGFloat(390 + content.rows.count * 42))])
    }
}

/// Builders for the specification sheets opened from the Device screens.
@MainActor
enum SpecSheets {
    private static func source(_ model: DeviceModel) -> String {
        if let specs = model.specifications { return specs.source }
        return L("device catalogue \(model.details?.catalogueVersion ?? DeviceCatalogue.bundled.version), not yet verified")
    }

    static func chip(_ model: DeviceModel) -> SpecSheetContent {
        let summary = model.summary
        let specs = model.specifications
        var detail = L("The system on a chip that runs your iPhone.")
        if let cores = summary.processorCoreCount {
            detail = L("\(cores)-core CPU reported by iOS.") + " " + detail
        }
        return SpecSheetContent(
            title: L("Chip"),
            value: summary.processor ?? Fallback.notInCatalogue,
            detail: detail,
            rows: [
                .init(label: L("Process"), value: specs?.processNanometres.map { "\($0) nm" } ?? Fallback.notInCatalogue),
                .init(label: L("Transistors"), value: specs?.transistorsBillions.map { L("\($0) billion") } ?? Fallback.notInCatalogue),
                .init(label: L("Released"), value: specs?.releaseYear.map(String.init) ?? Fallback.notInCatalogue),
            ],
            source: source(model)
        )
    }

    static func storage(_ model: DeviceModel) -> SpecSheetContent {
        let summary = model.summary
        let free = summary.storageAvailableBytes.map { ByteFormatting.storage($0) }
        return SpecSheetContent(
            title: L("Storage"),
            value: DeviceFormat.storage(summary.storageTotalBytes) ?? Fallback.unavailable,
            detail: L("Capacity as iOS reports it for this iPhone's volume, rounded to the advertised size."),
            rows: [
                .init(label: L("Available"), value: free ?? Fallback.unavailable),
                .init(label: L("Volume size"), value: summary.storageTotalBytes.map { ByteFormatting.storage($0) } ?? Fallback.unavailable),
            ],
            source: L("FileManager volume capacity, read on device")
        )
    }
}

// MARK: - Sensor detail (DEV-11, DEV-12, DEV-13)

struct SensorSheet: View {
    let model: DeviceModel
    let sensor: SensorKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let info = SensorInfo(sensor)
        let availability = model.status(of: sensor)
        let state = model.sensorTests[sensor]
        SheetChrome {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    OutlinedIcon(icon: info.icon, size: 40, iconSize: 20, cornerRadius: 12)
                    Text(info.name)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.66)
                        .foregroundStyle(SSColor.textStrong)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    CircleIconButton(icon: .close, label: L("Close"), size: 32, iconSize: 14) { dismiss() }
                }
                SensorStatusPill(availability: availability, test: state)
                Text(info.description)
                    .ssText(.body16)
                    .foregroundStyle(SSColor.textStrong)
                VStack(spacing: 0) {
                    row(L("Framework"), info.framework)
                    Rectangle().fill(SSColor.border).frame(height: 1)
                    row(L("Measures"), info.measures)
                    Rectangle().fill(SSColor.border).frame(height: 1)
                    row(L("Permission"), info.permission)
                    Rectangle().fill(SSColor.border).frame(height: 1)
                    row(L("Test status"), testStatus(state))
                }
                if sensor.isTestable, availability == .available || availability == .permissionRequired {
                    VStack(spacing: 10) {
                        Button {
                            Task { await model.runTest(sensor) }
                        } label: {
                            if state == .running {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text(L("Testing…"))
                                }
                            } else {
                                Text(state == nil ? L("Run Test") : L("Run Again"))
                            }
                        }
                        .buttonStyle(.ssPrimary)
                        .disabled(state == .running)
                        Text(sensor == .barometer
                             ? L("Takes about 5 seconds. iOS may ask for Motion & Fitness access first.")
                             : L("Takes about 5 seconds. Keep your iPhone still."))
                            .ssText(.caption12)
                            .foregroundStyle(SSColor.textTertiary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    DeviceNote(text: L("SystemScope can't test this sensor. Its status shows what iOS reports; it doesn't mean the sensor is faulty."))
                }
            }
            .padding(.bottom, 16)
        }
        .presentationDetents([.height(500)])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).ssText(.body14).foregroundStyle(SSColor.textTertiary)
            Spacer()
            Text(value).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func testStatus(_ state: SensorTestState?) -> String {
        switch state {
        case nil: sensor.isTestable ? L("Not tested") : L("No test available")
        case .running: L("Testing…")
        case .finished(.passed(let samples)): L("Passed · \(samples) readings")
        case .finished(.noReadings): L("No readings received")
        case .finished(.permissionDenied): L("Permission denied")
        case .finished(.unavailable): L("Not available")
        }
    }
}

struct SensorStatusPill: View {
    let availability: SensorAvailability
    let test: SensorTestState?

    var body: some View {
        switch test {
        case .finished(.passed): StatusPill(title: L("Test passed"))
        case .finished(.noReadings): StatusPill(title: L("No readings"), dot: SSColor.statusAmber)
        case .finished(.permissionDenied): StatusPill(title: L("Permission required"), dot: SSColor.statusAmber)
        case .running: StatusPill(title: L("Testing"), dot: SSColor.accent)
        default: StatusPill(title: availability.label, dot: availability.dot)
        }
    }
}

/// Static copy for each sensor.
struct SensorInfo {
    let name: String
    let summary: String
    let description: String
    let framework: String
    let measures: String
    let permission: String
    let icon: SSIcon

    init(_ kind: SensorKind) {
        switch kind {
        case .accelerometer:
            name = L("Accelerometer"); summary = L("Motion and orientation")
            description = L("Measures acceleration along three axes, used for orientation, step counting and motion.")
            framework = "Core Motion"; measures = L("Acceleration · 3 axes"); permission = L("Not required"); icon = .activity
        case .gyroscope:
            name = L("Gyroscope"); summary = L("Rotation rate")
            description = L("Measures how fast your iPhone rotates, used for games, AR and image stabilisation.")
            framework = "Core Motion"; measures = L("Rotation rate · 3 axes"); permission = L("Not required"); icon = .cube
        case .magnetometer:
            name = L("Magnetometer"); summary = L("Compass heading")
            description = L("Measures the magnetic field around your iPhone, used for the compass and heading.")
            framework = "Core Motion"; measures = L("Magnetic field · 3 axes"); permission = L("Not required"); icon = .radar
        case .barometer:
            name = L("Barometer"); summary = L("Air pressure and altitude changes")
            description = L("Measures air pressure to estimate changes in altitude, like climbing stairs or a hill.")
            framework = "Core Motion · CMAltimeter"; measures = L("Pressure · relative altitude"); permission = L("Motion & Fitness"); icon = .statusUp
        case .proximity:
            name = L("Proximity sensor"); summary = L("Turns the screen off during calls")
            description = L("Detects when something is close to the screen, such as your ear during a call.")
            framework = "UIKit"; measures = L("Near or far"); permission = L("Not required"); icon = .mobile
        case .ambientLight:
            name = L("Ambient light"); summary = L("Adjusts screen brightness")
            description = L("Measures surrounding light so iOS can adjust brightness and True Tone. iOS doesn't let apps read it.")
            framework = L("None public"); measures = L("Light level"); permission = L("Not applicable"); icon = .lamp
        case .location:
            name = L("GPS / GNSS"); summary = L("Satellite positioning")
            description = L("Finds your position from satellite signals. SystemScope only reads whether location access is allowed.")
            framework = "Core Location"; measures = L("Position"); permission = L("Location"); icon = .signal
        case .faceID:
            name = L("Face ID"); summary = L("TrueDepth facial recognition")
            description = L("Recognises your face with the TrueDepth camera. iOS reports whether it is present; SystemScope never asks you to authenticate.")
            framework = "LocalAuthentication"; measures = L("Biometric match"); permission = L("Not requested"); icon = .shieldTick
        case .lidar:
            name = L("LiDAR Scanner"); summary = L("Depth sensing for AR and photos")
            description = L("Measures depth with light pulses for AR, night portraits and faster autofocus.")
            framework = "AVFoundation"; measures = L("Depth"); permission = L("Not requested"); icon = .radar
        }
    }
}
