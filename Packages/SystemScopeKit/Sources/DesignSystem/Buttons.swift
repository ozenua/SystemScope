import SwiftUI

/// Filled full-width button. `.dark` is the standard primary; `.light` sits on dark cards.
public struct SSPrimaryButtonStyle: ButtonStyle {
    public enum Tone: Sendable {
        case dark
        case light
    }

    private let tone: Tone
    private let fill: Color?
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameter fill: replaces the tone's background, e.g. green for a "Copied" state.
    public init(tone: Tone = .dark, fill: Color? = nil) {
        self.tone = tone
        self.fill = fill
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ssText(.button18)
            .multilineTextAlignment(.center)
            .foregroundStyle(tone == .dark ? Color.white : Color(hex: 0x111111))
            .frame(maxWidth: .infinity)
            .padding(.vertical, tone == .dark ? 20 : 15)
            .padding(.horizontal, 20)
            .background(
                fill ?? (tone == .dark ? SSColor.ink : Color.white),
                in: RoundedRectangle(cornerRadius: SSRadius.button, style: .continuous)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

/// Text-only full-width button.
public struct SSSecondaryButtonStyle: ButtonStyle {
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ssText(.button18)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(hex: 0x121212))
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 15 : 20)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

public extension ButtonStyle where Self == SSPrimaryButtonStyle {
    static var ssPrimary: SSPrimaryButtonStyle { SSPrimaryButtonStyle() }
    static var ssPrimaryLight: SSPrimaryButtonStyle { SSPrimaryButtonStyle(tone: .light) }
}

public extension ButtonStyle where Self == SSSecondaryButtonStyle {
    static var ssSecondary: SSSecondaryButtonStyle { SSSecondaryButtonStyle() }
    static var ssSecondaryCompact: SSSecondaryButtonStyle { SSSecondaryButtonStyle(compact: true) }
}

/// 32 pt circular back button inside a 44 pt touch target.
public struct SSBackButton: View {
    private let label: String
    private let action: () -> Void

    public init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x1D1B20))
                .frame(width: 32, height: 32)
                .background(SSColor.hairline, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(label))
    }
}
