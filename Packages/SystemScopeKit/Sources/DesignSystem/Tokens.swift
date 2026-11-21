import SwiftUI

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Colour tokens taken from the Figma onboarding section.
public enum SSColor {
    public static let ink = Color(hex: 0x17191C)
    public static let textPrimary = Color.adaptive(light: .black, dark: .white)
    public static let textSecondary = Color.adaptive(light: Color(hex: 0x5C6570), dark: Color(hex: 0xB7C0CA))
    public static let textTertiary = Color.adaptive(light: Color(hex: 0x858585), dark: Color(hex: 0xA1A1A6))
    public static let textMuted = Color.adaptive(light: Color(hex: 0x999999), dark: Color(hex: 0x7D7D84))

    public static let surface = Color.adaptive(light: .white, dark: Color(hex: 0x1C1C1E))
    public static let surfaceSubtle = Color.adaptive(light: Color(hex: 0xF9F9F9), dark: Color(hex: 0x242426))
    public static let surfaceMuted = Color.adaptive(light: Color(hex: 0xF5F5F5), dark: Color(hex: 0x2C2C2E))
    public static let hairline = Color.adaptive(light: Color(hex: 0xF1F1F1), dark: Color(hex: 0x38383A))
    public static let border = Color.adaptive(light: Color(hex: 0xE8E7E2), dark: Color(hex: 0x48484A))
    public static let borderStrong = Color.adaptive(light: Color(hex: 0xE6E6E6), dark: Color(hex: 0x636366))
    public static let track = Color.adaptive(light: Color(hex: 0xD9D9D9), dark: Color(hex: 0x48484A))

    public static let positive = Color(hex: 0x1F8547)
    public static let positiveFill = Color(hex: 0x39B96B)

    public static let accent = Color(hex: 0x01A9FD)
    public static let meterBlue = Color(hex: 0x0A84FF)
    public static let chartGreen = Color(hex: 0x22A04B)
    public static let chargingGreen = Color(hex: 0x1F8A3B)
    public static let statusAmber = Color(hex: 0xF5A623)
    public static let thermalOrange = Color(hex: 0xF07A2B)
    public static let thermalRed = Color(hex: 0xE5432F)
    public static let footprintPurple = Color(hex: 0x8B5CF6)
    public static let infoBlue = Color(hex: 0x0B5D86)
    public static let warmBrown = Color(hex: 0x5C4300)
    public static let coral = Color(hex: 0xFE6A53)
    public static let lilac = Color(hex: 0xE2CEFD)
    public static let textSubtle = Color.adaptive(light: Color(hex: 0x737373), dark: Color(hex: 0xA1A1A6))
    public static let textLabel = Color.adaptive(light: Color(hex: 0x676767), dark: Color(hex: 0xB8B8BE))
    public static let textFaint = Color.adaptive(light: Color(hex: 0xA3A3A3), dark: Color(hex: 0x8E8E93))
    public static let statusGreen = Color(hex: 0x45CD33)
    public static let statusGreenSurface = Color(hex: 0xE3F8D7)
    public static let chipGreen = Color(hex: 0x00F314, opacity: 0.2)
    public static let iconChip = Color.adaptive(light: Color(hex: 0x121212, opacity: 0.04), dark: Color.white.opacity(0.08))
    /// The frame behind the content area and tab bar.
    public static let shell = Color.adaptive(light: Color(hex: 0x121212), dark: Color.black)
    public static let sheet = Color.adaptive(light: Color(hex: 0xFAFAFA), dark: Color(hex: 0x1C1C1E))
    /// Device illustration stages and chips.
    public static let pastelBlue = Color(hex: 0xDCE9FF)
    public static let pastelGreen = Color(hex: 0xD8F7B8)
    public static let stage = Color(hex: 0xEEEDE8)
    public static let chipBackground = Color.adaptive(light: Color(hex: 0xF5F4EF), dark: Color(hex: 0x2C2C2E))
    public static let errorText = Color.adaptive(light: Color(hex: 0xC0341F), dark: Color(hex: 0xFF6961))
    public static let textStrong = Color.adaptive(light: Color(hex: 0x111111), dark: Color(hex: 0xF2F2F7))

    public static let backgroundTop = Color.adaptive(light: .white, dark: Color(hex: 0x111113))
    public static let backgroundBottom = Color.adaptive(light: Color(hex: 0xE5E5E5), dark: Color(hex: 0x111113))

    public static let premiumGradient = LinearGradient(
        colors: [Color(hex: 0xFE6A53), Color(hex: 0xFFA489), Color(hex: 0xFDF1D1)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

public enum SSRadius {
    public static let button: CGFloat = 16
    public static let tile: CGFloat = 12
    public static let cardSmall: CGFloat = 22
    public static let cardMedium: CGFloat = 24
    public static let card: CGFloat = 32
}
