import SwiftUI

/// Text styles from the Figma file, mapped onto system SF fonts (PRD §3.3: Inter and
/// Neue Montreal are not bundled). Sizes scale with Dynamic Type.
public struct SSTextStyle: Sendable {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    let relativeTo: Font.TextStyle

    public static let pageTitle28 = SSTextStyle(size: 28, weight: .semibold, tracking: -0.84, relativeTo: .largeTitle)
    public static let metric36 = SSTextStyle(size: 36, weight: .semibold, tracking: -1.44, relativeTo: .largeTitle)
    public static let metric28 = SSTextStyle(size: 28, weight: .semibold, tracking: -1.12, relativeTo: .title)
    public static let unit20 = SSTextStyle(size: 20, weight: .semibold, tracking: -0.4, relativeTo: .title3)
    public static let unit18 = SSTextStyle(size: 18, weight: .semibold, tracking: -0.36, relativeTo: .headline)
    public static let rowTitle15 = SSTextStyle(size: 15, weight: .semibold, tracking: -0.3, relativeTo: .subheadline)
    public static let bodyMedium13 = SSTextStyle(size: 13, weight: .medium, tracking: -0.26, relativeTo: .footnote)
    public static let metric56 = SSTextStyle(size: 56, weight: .semibold, tracking: -2.24, relativeTo: .largeTitle)
    public static let metric52 = SSTextStyle(size: 52, weight: .semibold, tracking: -2.08, relativeTo: .largeTitle)
    public static let unit28 = SSTextStyle(size: 28, weight: .semibold, tracking: -0.56, relativeTo: .title)
    public static let unit26 = SSTextStyle(size: 26, weight: .semibold, tracking: -0.52, relativeTo: .title)
    public static let stat16 = SSTextStyle(size: 16, weight: .semibold, tracking: -0.48, relativeTo: .body)
    public static let lane11 = SSTextStyle(size: 11, weight: .medium, tracking: -0.22, relativeTo: .caption2)
    public static let metric48 = SSTextStyle(size: 48, weight: .semibold, tracking: -1.44, relativeTo: .largeTitle)
    public static let metric40 = SSTextStyle(size: 40, weight: .semibold, tracking: -0.8, relativeTo: .largeTitle)
    public static let metric32 = SSTextStyle(size: 32, weight: .semibold, tracking: -0.96, relativeTo: .largeTitle)
    public static let unit24 = SSTextStyle(size: 24, weight: .semibold, tracking: -0.48, relativeTo: .title)
    public static let unitMedium24 = SSTextStyle(size: 24, weight: .medium, tracking: -0.48, relativeTo: .title)
    public static let screenTitle24 = SSTextStyle(size: 24, weight: .semibold, tracking: -0.48, relativeTo: .title)
    public static let title20 = SSTextStyle(size: 20, weight: .semibold, tracking: -0.4, relativeTo: .title3)
    public static let section18 = SSTextStyle(size: 18, weight: .semibold, tracking: -0.54, relativeTo: .headline)
    public static let value16 = SSTextStyle(size: 16, weight: .semibold, tracking: -0.32, relativeTo: .body)
    public static let unit16 = SSTextStyle(size: 16, weight: .semibold, tracking: -0.32, relativeTo: .body)
    public static let bodyMedium14 = SSTextStyle(size: 14, weight: .medium, tracking: -0.42, relativeTo: .subheadline)
    public static let labelSemibold14 = SSTextStyle(size: 14, weight: .semibold, tracking: -0.28, relativeTo: .subheadline)
    public static let segment13 = SSTextStyle(size: 13, weight: .semibold, tracking: -0.26, relativeTo: .footnote)
    public static let chip12 = SSTextStyle(size: 12, weight: .semibold, tracking: -0.24, relativeTo: .caption)
    public static let axis12 = SSTextStyle(size: 12, weight: .medium, tracking: -0.24, relativeTo: .caption)
    public static let micro10 = SSTextStyle(size: 10, weight: .semibold, tracking: -0.2, relativeTo: .caption2)
    public static let display36 = SSTextStyle(size: 36, weight: .bold, tracking: -0.72, relativeTo: .largeTitle)
    public static let title32 = SSTextStyle(size: 32, weight: .bold, tracking: -0.64, relativeTo: .largeTitle)
    public static let heading24 = SSTextStyle(size: 24, weight: .bold, tracking: -0.48, relativeTo: .title)
    public static let price24 = SSTextStyle(size: 24, weight: .bold, tracking: -0.72, relativeTo: .title)
    public static let button18 = SSTextStyle(size: 18, weight: .semibold, tracking: -0.36, relativeTo: .headline)
    public static let cardTitle18 = SSTextStyle(size: 18, weight: .medium, tracking: -0.36, relativeTo: .headline)
    public static let rowTitle17 = SSTextStyle(size: 17, weight: .medium, tracking: -0.34, relativeTo: .headline)
    public static let metric17 = SSTextStyle(size: 17, weight: .semibold, tracking: -0.51, relativeTo: .headline)
    public static let body16 = SSTextStyle(size: 16, weight: .regular, tracking: -0.4, relativeTo: .body)
    public static let bodyMedium16 = SSTextStyle(size: 16, weight: .medium, tracking: -0.4, relativeTo: .body)
    public static let label15 = SSTextStyle(size: 15, weight: .medium, tracking: -0.3, relativeTo: .subheadline)
    public static let body14 = SSTextStyle(size: 14, weight: .regular, tracking: -0.28, relativeTo: .subheadline)
    public static let label14 = SSTextStyle(size: 14, weight: .medium, tracking: -0.28, relativeTo: .subheadline)
    public static let caption13 = SSTextStyle(size: 13, weight: .regular, tracking: -0.26, relativeTo: .footnote)
    public static let captionMedium13 = SSTextStyle(size: 13, weight: .medium, tracking: -0.13, relativeTo: .footnote)
    public static let overline13 = SSTextStyle(size: 13, weight: .semibold, tracking: 0.52, relativeTo: .footnote)
    public static let caption12 = SSTextStyle(size: 12, weight: .regular, tracking: -0.12, relativeTo: .caption)
    public static let captionMedium12 = SSTextStyle(size: 12, weight: .medium, tracking: -0.12, relativeTo: .caption)
    public static let badge11 = SSTextStyle(size: 11, weight: .semibold, tracking: 0, relativeTo: .caption2)
    public static let overline11 = SSTextStyle(size: 11, weight: .semibold, tracking: 0.88, relativeTo: .caption2)
}

private struct SSTextModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let style: SSTextStyle

    init(_ style: SSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: style.weight))
            .tracking(style.tracking * size / style.size)
    }
}

public extension View {
    func ssText(_ style: SSTextStyle) -> some View {
        modifier(SSTextModifier(style))
    }
}
