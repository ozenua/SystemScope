import DesignSystem
import SwiftUI

// Building blocks named after the Figma Settings components.

/// Page shell for pushed Settings screens.
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 24)
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Settings Header / Back: back button, title and subtitle, optional trailing view.
struct SettingsHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SSBackButton(label: L("Back"), action: onBack).padding(.leading, -6)
                Spacer()
                trailing
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .ssText(.screenTitle24)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
                if !subtitle.isEmpty {
                    Text(subtitle).ssText(.bodyMedium14).foregroundStyle(SSColor.textTertiary)
                }
            }
        }
    }
}

extension SettingsHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, onBack: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}

/// Group: a section title over a white card of rows split by inset hairlines.
struct SettingsGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .ssText(.section18)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                _VariadicView.Tree(DividedLayout()) { content }
            }
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if let footer {
                Text(footer).ssText(.caption12).foregroundStyle(SSColor.textTertiary).padding(.horizontal, 4)
            }
        }
    }
}

/// Puts an inset hairline between children.
private struct DividedLayout: _VariadicView_MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        ForEach(children) { child in
            child
            if child.id != last {
                Rectangle().fill(SSColor.border).frame(height: 1).padding(.leading, 16)
            }
        }
    }
}

/// Settings Row: icon chip, title, optional subtitle and value, chevron.
struct SettingsRow: View {
    var icon: SSIcon?
    let title: String
    var subtitle: String?
    var value: String?
    var destructive = false
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowContent(icon: icon, title: title, subtitle: subtitle, destructive: destructive) {
                if let value {
                    Text(value).ssText(.body14).foregroundStyle(SSColor.textTertiary).lineLimit(1)
                }
                if showsChevron {
                    SSIconView(.chevronRight, size: 20, color: SSColor.textFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Row layout shared by buttons, toggles and links.
struct RowContent<Trailing: View>: View {
    var icon: SSIcon?
    let title: String
    var subtitle: String?
    var destructive = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                SSIconView(icon, size: 20, color: destructive ? SSColor.thermalRed : SSColor.textStrong)
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).ssText(.label15).foregroundStyle(destructive ? SSColor.thermalRed : SSColor.textStrong)
                if let subtitle {
                    Text(subtitle).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Toggle row.
struct ToggleRow: View {
    var icon: SSIcon?
    let title: String
    var subtitle: String?
    let isOn: Bool
    var isEnabled = true
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
            HStack(spacing: 12) {
                if let icon {
                    SSIconView(icon, size: 20, color: SSColor.textStrong)
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).ssText(.label15).foregroundStyle(SSColor.textStrong)
                    if let subtitle {
                        Text(subtitle).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                    }
                }
            }
        }
        .tint(SSColor.textStrong)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
    }
}

/// Radio row: title, subtitle, radio on the right.
struct RadioRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowContent(title: title, subtitle: subtitle) {
                Image(isSelected ? SSArtwork.radioSelected : SSArtwork.radio)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Information Banner: icon, title and body on white.
struct InfoBanner: View {
    var icon: SSIcon = .info
    let title: String
    let message: String
    var tint: Color = SSColor.textStrong

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SSIconView(icon, size: 20, color: tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                Text(message).ssText(.caption13).foregroundStyle(SSColor.textStrong.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Outlined status pill with a coloured dot.
struct StatusPill: View {
    let title: String
    var dot: Color = SSColor.statusGreen
    var onDark = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(title).ssText(.chip12).foregroundStyle(onDark ? Color.white : SSColor.textStrong)
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().strokeBorder(onDark ? SSColor.border : .clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Permission pill: Allowed, Not allowed, Not requested.
struct PermissionPill: View {
    let permission: SettingsPermission

    var body: some View {
        let (title, color, fill): (String, Color, Color) = switch permission {
        case .granted: (L("Allowed"), SSColor.positive, SSColor.surface)
        case .denied, .restricted: (L("Not allowed"), SSColor.errorText, SSColor.surface)
        case .notDetermined: (L("Not requested"), SSColor.textTertiary, SSColor.chipBackground)
        }
        Text(title)
            .ssText(.chip12)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(fill == SSColor.surface ? color.opacity(0.4) : .clear, lineWidth: 1))
    }
}

struct SettingsToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            SSIconView(.tickCircleBold, size: 18, color: SSColor.statusGreen)
            Text(message).ssText(.labelSemibold14).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SSColor.ink, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Sheet chrome: grabber, title with a close button.
struct SettingsSheetScaffold<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(SSColor.track).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.66)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    SSIconView(.close, size: 14, color: SSColor.textStrong)
                        .frame(width: 32, height: 32)
                        .background(SSColor.hairline, in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Close")))
            }
            .padding(.horizontal, 20)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SSColor.surface)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
    }
}

/// Centred confirmation dialog: icon, title, message, extra content and buttons.
struct ConfirmDialog<Extra: View>: View {
    let icon: SSIcon
    let iconColor: Color
    let title: String
    let message: String
    let confirmTitle: String
    var destructive = true
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ViewBuilder var extra: Extra

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(spacing: 12) {
                SSIconView(icon, size: 22, color: iconColor)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(SSColor.textStrong).multilineTextAlignment(.center)
                Text(message).ssText(.body14).foregroundStyle(SSColor.textTertiary).multilineTextAlignment(.center)
                extra
                VStack(spacing: 4) {
                    Button(confirmTitle, action: onConfirm)
                        .buttonStyle(SSPrimaryButtonStyle(fill: destructive ? SSColor.errorText : nil))
                    Button(L("Cancel"), action: onCancel)
                        .ssText(.metric17)
                        .foregroundStyle(SSColor.textStrong)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .accessibilityAddTraits(.isModal)
        }
    }
}

/// Tick bullet line.
struct TickLine: View {
    let text: String
    var boxed = false

    var body: some View {
        HStack(spacing: 8) {
            SSIconView(.tickCircle, size: 18, color: boxed ? SSColor.textStrong : SSColor.positive)
            Text(text).ssText(.label14).foregroundStyle(SSColor.textStrong)
            Spacer(minLength: 0)
        }
        .padding(boxed ? 10 : 0)
        .overlay {
            if boxed { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1) }
        }
    }
}

enum SettingsFormat {
    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    static func relative(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return L("today, \(date.formatted(date: .omitted, time: .shortened))") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
