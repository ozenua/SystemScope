import DesignSystem
import SwiftUI

/// Back button, centred content and a trailing text action. Every part is optional.
struct OnboardingTopBar<Center: View>: View {
    var onBack: (() -> Void)?
    var trailingTitle: String?
    var onTrailing: (() -> Void)?
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            center
            HStack {
                if let onBack {
                    // The 32 pt circle sits at the 16 pt margin; its 44 pt target overhangs by 6.
                    SSBackButton(label: Strings.back, action: onBack)
                        .padding(.leading, -6)
                }
                Spacer()
                if let trailingTitle, let onTrailing {
                    Button(action: onTrailing) {
                        Text(trailingTitle)
                            .ssText(.body16)
                            .foregroundStyle(SSColor.textPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }
}

extension OnboardingTopBar where Center == EmptyView {
    init(onBack: (() -> Void)? = nil, trailingTitle: String? = nil, onTrailing: (() -> Void)? = nil) {
        self.init(onBack: onBack, trailingTitle: trailingTitle, onTrailing: onTrailing) { EmptyView() }
    }
}

struct StepLabel: View {
    let current: Int

    var body: some View {
        Text(Strings.step(current))
            .ssText(.label14)
            .foregroundStyle(SSColor.textSecondary)
    }
}

/// Centred title and supporting text used at the top of each step.
struct OnboardingHeading: View {
    let title: String
    let message: String
    var spacing: CGFloat = 12
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: spacing) {
            // One line at standard text sizes, as designed (SF is wider than the Figma
            // face); wraps freely once the user picks a larger size.
            Text(title)
                .ssText(.title32)
                .lineLimit(dynamicTypeSize <= .large ? 1 : nil)
                .minimumScaleFactor(dynamicTypeSize <= .large ? 0.85 : 1)
                .foregroundStyle(SSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .ssText(.body16)
                .foregroundStyle(SSColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

struct PremiumBadge: View {
    enum Style {
        case onDark
        case gradient
    }

    let style: Style

    var body: some View {
        HStack(spacing: 6) {
            SSIconView(.crown, size: 14, color: style == .onDark ? SSColor.positiveFill : SSColor.ink)
            Text(Strings.premiumBadge)
                .ssText(.overline11)
                .foregroundStyle(style == .onDark ? Color.white : SSColor.ink)
        }
        .padding(.leading, style == .onDark ? 8 : 10)
        .padding(.trailing, style == .onDark ? 10 : 12)
        .padding(.vertical, style == .onDark ? 5 : 6)
        .background {
            switch style {
            case .onDark: Capsule().fill(Color.white.opacity(0.1))
            case .gradient: Capsule().fill(SSColor.premiumGradient)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Scrolling page body whose footer scrolls with the content. When the content is
/// shorter than the screen the footer rests at the bottom; when it is taller,
/// everything scrolls together and nothing is pinned or clipped.
struct OnboardingScrollPage<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    content
                    Spacer(minLength: 16)
                    footer
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
