import DesignSystem
import DeviceInfo
import SwiftUI

// Building blocks for the Device screens, named after the Figma components.

/// Scrolling page shell shared by every Device detail screen.
struct DevicePage<Content: View>: View {
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

/// Header / Detail: back, an optional trailing action, then title and subtitle.
struct DeviceDetailHeader: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    var trailingIcon: SSIcon?
    var trailingLabel: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SSBackButton(label: L("Back"), action: onBack)
                    .padding(.leading, -6)
                Spacer()
                if let trailingIcon, let trailingAction {
                    CircleIconButton(icon: trailingIcon, label: trailingLabel ?? "", action: trailingAction)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .ssText(.screenTitle24)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
        }
    }
}

/// 40 pt grey circle with an icon (More options, Copy).
struct CircleIconButton: View {
    let icon: SSIcon
    let label: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SSIconView(icon, size: iconSize, color: SSColor.textStrong)
                .frame(width: size, height: size)
                .background(SSColor.hairline, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

struct DeviceSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .ssText(.section18)
            .foregroundStyle(SSColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// White rounded card.
struct DeviceCard<Content: View>: View {
    var radius: CGFloat = 24
    var padding: EdgeInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// SpecificationRow: Default, Copyable or Expandable (tappable).
struct Spec: Identifiable {
    enum Kind {
        case plain
        case copyable
        case action(() -> Void)
    }

    let id = UUID()
    let label: String
    let value: String?
    var fallback: String = Fallback.unavailable
    var kind: Kind = .plain
}

struct SpecificationList: View {
    let specs: [Spec]
    var onCopy: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(specs.enumerated()), id: \.element.id) { index, spec in
                SpecificationRow(spec: spec, onCopy: onCopy)
                if index < specs.count - 1 {
                    Rectangle().fill(SSColor.border).frame(height: 1)
                }
            }
        }
    }
}

struct SpecificationCard: View {
    let specs: [Spec]
    var onCopy: ((String) -> Void)?

    var body: some View {
        DeviceCard { SpecificationList(specs: specs, onCopy: onCopy) }
    }
}

struct SpecificationRow: View {
    let spec: Spec
    var onCopy: ((String) -> Void)?

    var body: some View {
        switch spec.kind {
        case .plain:
            content(trailing: nil)
                .accessibilityElement(children: .combine)
        case .copyable:
            if let value = spec.value, let onCopy {
                Button { onCopy(value) } label: { content(trailing: .copy) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(Text(L("Copies the value")))
            } else {
                content(trailing: nil)
            }
        case .action(let action):
            Button(action: action) { content(trailing: .chevronDown) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
        }
    }

    private func content(trailing: SSIcon?) -> some View {
        HStack(spacing: 12) {
            Text(spec.label)
                .ssText(.body14)
                .foregroundStyle(SSColor.textTertiary)
            Spacer(minLength: 8)
            Text(spec.value ?? spec.fallback)
                .ssText(.labelSemibold14)
                .foregroundStyle(spec.value == nil ? SSColor.textTertiary : SSColor.textStrong)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
            if let trailing {
                SSIconView(trailing, size: trailing == .copy ? 16 : 18, color: SSColor.textTertiary)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// Expandable card: title, subtitle and a chevron; rows appear when open.
struct ExpandableSection<Content: View>: View {
    let title: String
    let subtitle: String
    @State var isExpanded: Bool
    var leading: AnyView?
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, subtitle: String, isExpanded: Bool = false, leading: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        _isExpanded = State(initialValue: isExpanded)
        self.leading = leading
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    if let leading { leading }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .ssText(.rowTitle15)
                            .foregroundStyle(SSColor.textStrong)
                        Text(subtitle)
                            .ssText(.caption13)
                            .foregroundStyle(SSColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SSIconView(.chevronDown, size: 20, color: SSColor.textStrong)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? L("Expanded") : L("Collapsed")))
            if isExpanded {
                Spacer().frame(height: 8)
                content
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, isExpanded ? 6 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Quick specifications: a 2-column grid of label/value cells split by hairlines.
struct CompactSpecGrid: View {
    struct Cell: Identifiable {
        let id = UUID()
        let label: String
        let value: String?
        var fallback: String = Fallback.unavailable
    }

    let cells: [Cell]

    var body: some View {
        let rows = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, cell in
                        if column > 0 { Rectangle().fill(SSColor.border).frame(width: 1) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(cell.label)
                                .ssText(.caption12)
                                .foregroundStyle(SSColor.textTertiary)
                            Text(cell.value ?? cell.fallback)
                                .font(.system(size: cell.value == nil ? 14 : 18, weight: .bold))
                                .tracking(-0.54)
                                .foregroundStyle(cell.value == nil ? SSColor.textTertiary : SSColor.textStrong)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .combine)
                    }
                    if row.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Small white pill (hero chips such as "6-core CPU").
struct HeroChip: View {
    let text: String
    var background: Color = Color.white.opacity(0.7)

    var body: some View {
        Text(text)
            .ssText(.chip12)
            .foregroundStyle(SSColor.textStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }
}

/// Outlined pill with a coloured dot. The text carries the meaning.
struct StatusPill: View {
    let title: String
    var dot: Color = SSColor.statusGreen

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(title)
                .ssText(.chip12)
                .foregroundStyle(SSColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(SSColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Outlined circle or rounded square holding an icon.
struct OutlinedIcon: View {
    let icon: SSIcon
    var size: CGFloat = 40
    var iconSize: CGFloat = 20
    var cornerRadius: CGFloat?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius ?? size / 2, style: .continuous)
        SSIconView(icon, size: iconSize, color: Color(hex: 0x292D32))
            .frame(width: size, height: size)
            .overlay(shape.strokeBorder(SSColor.border, lineWidth: 1))
    }
}

/// Platform note: grey info line explaining what iOS does not share.
struct DeviceNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SSIconView(.info, size: 16, color: SSColor.textFaint)
            Text(text)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Related / Explore Monitor: icon, title, body and a dark button.
struct RelatedMonitorCard: View {
    let title: String
    let message: String
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SSIconView(.activity, size: 20, color: SSColor.textStrong)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.7), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ssText(.rowTitle15)
                        .foregroundStyle(SSColor.textStrong)
                    Text(message)
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textStrong.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(button)
                    SSIconView(.arrowCircleRight, size: 18, color: .white)
                }
            }
            .buttonStyle(.ssPrimary)
        }
        .padding(18)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Bordered white button with an icon (Copy specifications).
struct OutlineButton: View {
    let icon: SSIcon
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SSIconView(icon, size: 18, color: SSColor.textStrong)
                Text(title)
                    .ssText(.value16)
                    .foregroundStyle(SSColor.textStrong)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Device front drawn with shapes: dark frame, gradient screen, Dynamic Island, clock.
struct DeviceFrontIllustration: View {
    var width: CGFloat = 70

    var body: some View {
        let scale = width / 96
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .fill(Color(hex: 0x2C2C2E))
                .overlay(
                    RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                        .strokeBorder(Color(hex: 0x9A958E), lineWidth: 1.5 * scale)
                )
            RoundedRectangle(cornerRadius: 19 * scale, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xDCE9FF), Color(hex: 0xE5DCFF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(4 * scale)
            Capsule()
                .fill(Color.black)
                .frame(width: 28 * scale, height: 8 * scale)
                .padding(.top, 11 * scale)
            VStack(spacing: 1) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day()))
                    .font(.system(size: 7 * scale, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                Text(Date.now.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .padding(.top, 30 * scale)
        }
        .frame(width: width, height: width * 196 / 96)
        .accessibilityHidden(true)
    }
}

/// The Figma device-back artwork.
struct DeviceBackIllustration: View {
    var width: CGFloat = 61.44

    var body: some View {
        Image(SSArtwork.deviceBack)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

/// Toast: dark capsule with a tick, shown after copy, rename and similar actions.
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            SSIconView(.tickCircleBold, size: 18, color: SSColor.statusGreen)
            Text(message)
                .ssText(.labelSemibold14)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SSColor.ink, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Grabber and white rounded background for the custom sheets.
struct SheetChrome<Content: View>: View {
    var horizontalPadding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(SSColor.track).frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, horizontalPadding)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(SSColor.surface)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
    }
}

extension SensorAvailability {
    var label: String {
        switch self {
        case .available: L("Available")
        case .supported: L("Supported")
        case .permissionRequired: L("Permission required")
        case .notPresent: L("Not detected")
        case .unknown: L("Unknown")
        }
    }

    var dot: Color {
        switch self {
        case .available: SSColor.statusGreen
        case .supported: SSColor.accent
        case .permissionRequired: SSColor.statusAmber
        case .notPresent, .unknown: SSColor.textFaint
        }
    }
}
