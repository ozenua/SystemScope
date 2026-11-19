import ActivityStore
import Core
import DesignSystem
import SwiftUI

// MARK: - Rename (SET-02)

struct RenameDeviceSheet: View {
    @Bindable var model: SettingsModel
    @FocusState private var focused: Bool

    var body: some View {
        SettingsSheetScaffold(title: L("Rename your device"), onClose: { model.sheet = nil }) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("Give your iPhone a name that’s easy to recognize."))
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textTertiary)
                TextField(text: $model.renameDraft, prompt: Text(AppPreferences.defaultDeviceDisplayName)) { Text(L("Device name")) }
                    .ssText(.bodyMedium16)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { model.saveRename() }
                    .onChange(of: model.renameDraft) { _, value in
                        if value.count > AppPreferences.deviceDisplayNameLimit {
                            model.renameDraft = String(value.prefix(AppPreferences.deviceDisplayNameLimit))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(model.renameError ? SSColor.errorText : SSColor.textStrong, lineWidth: 1.5)
                    )
                HStack {
                    Text(model.renameError ? L("Enter a name to continue.") : L("Used only inside SystemScope."))
                        .foregroundStyle(model.renameError ? SSColor.errorText : SSColor.textTertiary)
                    Spacer()
                    Text("\(model.renameDraft.count)/\(AppPreferences.deviceDisplayNameLimit)").foregroundStyle(SSColor.textFaint)
                }
                .ssText(.captionMedium12)
                Button(L("Save changes")) { model.saveRename() }
                    .buttonStyle(SSPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(340)])
        .onAppear { focused = true }
    }
}

// MARK: - Clear history (SET-13)

struct ClearHistorySheet: View {
    let model: SettingsModel

    var body: some View {
        SettingsSheetScaffold(title: title, onClose: { model.finishClear() }) {
            VStack(alignment: .leading, spacing: 14) {
                switch model.clearState {
                case .choosing: choosing
                case .confirming: confirming
                case .deleting: status(icon: nil, title: L("Clearing history…"), message: L("Removing records from this iPhone."))
                case .succeeded(let count):
                    status(icon: .tickCircle, title: L("History cleared"), message: L("\(count) records were removed. Your device profile and preferences were kept."))
                    Button(L("Done")) { model.finishClear() }.buttonStyle(SSPrimaryButtonStyle())
                case .failed:
                    status(icon: .warning, title: L("Couldn’t clear history"), message: L("Nothing was removed. Your history is unchanged."))
                    Button(L("Try Again")) { Task { await model.performClear() } }.buttonStyle(SSPrimaryButtonStyle())
                    Button(L("Cancel")) { model.finishClear() }
                        .ssText(.metric17).foregroundStyle(SSColor.textStrong).frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(470)])
        .interactiveDismissDisabled(model.clearState == .deleting)
    }

    private var title: String {
        switch model.clearState {
        case .confirming: L("Are you sure?")
        default: L("Clear history")
        }
    }

    private var choosing: some View {
        let sizes = model.measuredSizes
        return VStack(alignment: .leading, spacing: 14) {
            Text(L("Choose what to delete. This can’t be undone.")).ssText(.body14).foregroundStyle(SSColor.textTertiary)
            ForEach(HistoryKind.allCases) { kind in
                let selected = model.clearSelection.contains(kind)
                Button { model.toggleClear(kind) } label: {
                    HStack(spacing: 12) {
                        SSIconView(kind.icon, size: 20, color: SSColor.textStrong)
                            .frame(width: 40, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).ssText(.label15).foregroundStyle(SSColor.textStrong)
                            Text("\(kind.countLabel(model.count(of: kind))) · \(SettingsFormat.bytes(sizes[kind] ?? 0))")
                                .ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(selected ? SSColor.textStrong : SSColor.textFaint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.count(of: kind) == 0)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Text(L("Your device profile, preferences and exported files are kept."))
                .ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            Button(model.clearSelection.count == 1 ? L("Clear 1 category") : L("Clear \(model.clearSelection.count) categories")) { model.confirmClear() }
                .buttonStyle(SSPrimaryButtonStyle(fill: SSColor.errorText))
                .disabled(model.clearSelection.isEmpty || model.clearCount == 0)
        }
    }

    private var confirming: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ACT-10: state exactly what will be deleted.
            Text(L("This permanently removes \(model.clearCount) records from SystemScope:"))
                .ssText(.body14).foregroundStyle(SSColor.textStrong)
            ForEach(HistoryKind.allCases.filter { model.clearSelection.contains($0) }) { kind in
                TickLine(text: "\(kind.title) · \(kind.countLabel(model.count(of: kind)))", boxed: true)
            }
            Button(L("Clear History")) { Task { await model.performClear() } }
                .buttonStyle(SSPrimaryButtonStyle(fill: SSColor.errorText))
            Button(L("Back")) { model.backToChoosing() }
                .ssText(.metric17).foregroundStyle(SSColor.textStrong).frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    private func status(icon: SSIcon?, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Group {
                if let icon { SSIconView(icon, size: 24, color: icon == .warning ? SSColor.errorText : SSColor.positive) } else { ProgressView() }
            }
            .frame(width: 56, height: 56)
            .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(SSColor.textStrong)
            Text(message).ssText(.body14).foregroundStyle(SSColor.textTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Information sheets

struct InfoSheet: View {
    let title: String
    let paragraphs: [String]
    let onClose: () -> Void

    var body: some View {
        SettingsSheetScaffold(title: title, onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph).ssText(.body16).foregroundStyle(SSColor.textStrong.opacity(0.85))
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum InfoText {
    static var monitoring: [String] {
        [
            L("SystemScope reads your iPhone’s state through public iOS APIs while the app is open."),
            L("A monitoring session starts when you open the Monitor tab and ends when you leave it. Leaving the app ends it as interrupted."),
            L("iOS doesn’t let apps measure in the background, so there are no readings while SystemScope is closed. Gaps are shown as gaps, never filled in."),
            L("Some values, such as device-wide CPU and GPU load, aren’t available to apps at all. SystemScope shows them as unavailable rather than guessing."),
        ]
    }

    static var whatsNew: [String] {
        [
            L("Device: specifications, cameras, sensors and sensor tests."),
            L("Activity: a timeline of events, alerts and monitoring sessions, with search and filters."),
            L("Settings: thresholds, notifications, history controls and data export."),
        ]
    }

    static var licenses: [String] {
        [L("SystemScope doesn’t include third-party libraries. It is built only with Apple’s frameworks.")]
    }

    static var collects: [String] {
        [
            L("Device details such as model, iOS version, memory, storage, battery, thermal state and network type, read from iOS while the app is open."),
            L("Activity events, alerts and monitoring session summaries that you can review, export or delete."),
            L("Your settings and the device name you choose."),
            L("Everything stays on this iPhone. SystemScope has no account and doesn’t send your data anywhere. A speed test only contacts the test server you start it against."),
        ]
    }
}
