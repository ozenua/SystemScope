import DesignSystem
import SwiftUI

// Decorative sample dashboards for the introduction pages. Sizes are fixed Figma
// values on purpose: this is artwork, labelled "Sample", and hidden from VoiceOver.

struct IntroIllustration: View {
    let page: Int

    var body: some View {
        ZStack(alignment: .top) {
            AppLogo(size: 50)
                .padding(.top, 101)

            PhoneMock {
                switch page {
                case 0: IndicatorsMock()
                case 1: OverviewMock()
                default: ResourceCardsMock()
                }
            }
            .padding(.top, 186)

            if page == 1 {
                ChangeSpottedCard()
                    .padding(.top, 464)
            }
        }
    }
}

// MARK: - Phone frame

private struct PhoneMock<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let outline = UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
            Capsule()
                .fill(.black)
                .frame(width: 80, height: 22)
                .offset(x: 87.5, y: 10)
            content
        }
        .frame(width: 255, height: 387, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .padding(.top, 10)
        .frame(width: 275, height: 397, alignment: .top)
        .clipShape(outline)
        .overlay(
            outline.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.5),
                        .init(color: .black.opacity(0), location: 0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 4
            )
        )
    }
}

private struct MockHeader: View {
    let overline: String
    let title: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(overline)
                    .font(.system(size: 10))
                    .foregroundStyle(SSColor.textSecondary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.45)
                    .foregroundStyle(SSColor.ink)
            }
            Text(Strings.mockSample)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SSColor.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(SSColor.surfaceMuted, in: Capsule())
        }
        .fixedSize()
        .offset(x: 18, y: 46)
    }
}

private struct MockIconTile: View {
    let icon: SSIcon
    var size: CGFloat = 28
    var iconSize: CGFloat = 16
    var radius: CGFloat = 9
    var fill: Color = SSColor.surfaceMuted

    var body: some View {
        SSIconView(icon, size: iconSize, color: Color(hex: 0x292D32))
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct MockBars: View {
    let heights: [CGFloat]
    var width: CGFloat = 3
    var spacing: CGFloat = 2
    var radius: CGFloat = 2
    var color: Color = SSColor.ink
    var highlightIndex: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: radius)
                    .fill(index == highlightIndex ? SSColor.positiveFill : color)
                    .frame(width: width, height: height)
            }
        }
    }
}

private struct MockSegments: View {
    let widths: [CGFloat]
    var height: CGFloat = 8
    var radius: CGFloat = 2
    var spacing: CGFloat = 2

    private let colors = [SSColor.ink, SSColor.textMuted, SSColor.borderStrong]

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                RoundedRectangle(cornerRadius: radius)
                    .fill(colors[index % colors.count])
                    .frame(width: width, height: height)
            }
        }
    }
}

// MARK: - Page 1

private struct IndicatorsMock: View {
    var body: some View {
        MockHeader(overline: Strings.mockOverview, title: Strings.mockMyIPhone)

        VStack(alignment: .leading, spacing: 10) {
            indicator(.cpu, Strings.mockCPU, fills: false) {
                MockBars(heights: [6, 11, 8, 13])
            }
            indicator(.battery, Strings.mockBattery, fills: true) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(SSColor.borderStrong)
                    .frame(width: 24, height: 10)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(SSColor.positiveFill)
                            .frame(width: 17, height: 10)
                    }
            }
            indicator(.storage, Strings.mockStorage, fills: true) {
                MockSegments(widths: [10, 7, 7])
            }
            indicator(.wifi, Strings.mockNetwork, fills: false) {
                MockBars(heights: [4, 8, 12], color: SSColor.positiveFill)
            }
        }
        .frame(width: 140, alignment: .leading)
        .offset(x: 18, y: 97)
    }

    private func indicator(
        _ icon: SSIcon,
        _ title: String,
        fills: Bool,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 8) {
            MockIconTile(icon: icon)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.26)
                .foregroundStyle(SSColor.ink)
                .fixedSize()
            trailing()
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: fills ? .infinity : nil, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
}

// MARK: - Page 2

private struct OverviewMock: View {
    var body: some View {
        MockHeader(overline: Strings.mockDeviceHealth, title: Strings.mockOverview)

        VStack(spacing: 6) {
            row(.battery, Strings.mockBattery) { statusPill(Strings.mockGood) }
            row(.thermometer, Strings.mockThermal) { statusPill(Strings.mockNormal) }
            row(.storage, Strings.mockStorage) {
                MockSegments(widths: [30, 14, 18], radius: 3)
            }
            row(.activity, Strings.mockActivity) {
                Image(SSArtwork.mockSparkline)
            }
        }
        .frame(width: 227)
        .offset(x: 14, y: 90)

        LinearGradient(
            colors: [Color(hex: 0xF1F1F1, opacity: 0), Color(hex: 0xF1F1F1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 255, height: 157)
        .offset(y: 230)
    }

    private func row(_ icon: SSIcon, _ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 8) {
            MockIconTile(icon: icon, size: 26, radius: 8, fill: .white)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .tracking(-0.24)
                .foregroundStyle(SSColor.ink)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0xF6F6F6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(SSColor.positive)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
    }
}

private struct ChangeSpottedCard: View {
    var body: some View {
        HStack(spacing: 8) {
            SSIconView(.statusUp, size: 16, color: SSColor.positive)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(Strings.mockChangeSpotted)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.24)
                    .foregroundStyle(SSColor.ink)
                Text(Strings.mockStorageWentUp)
                    .font(.system(size: 10))
                    .tracking(-0.1)
                    .foregroundStyle(SSColor.textSecondary)
            }
        }
        .fixedSize()
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
}

// MARK: - Page 3

private struct ResourceCardsMock: View {
    var body: some View {
        MockHeader(overline: Strings.mockOverview, title: Strings.mockMyIPhone)

        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(hex: 0xF7F7F7))
            .frame(width: 219, height: 46)
            .offset(x: 18, y: 260)

        VStack(alignment: .leading, spacing: 3.2) {
            HStack(spacing: 5.6) {
                card(.cpu, Strings.mockPerformance, Strings.mockCPUAndMemory) {
                    MockBars(
                        heights: [9.5, 15.9, 11.9, 20.7, 14.3, 23.8, 17.5],
                        width: 11.1,
                        spacing: 3.2,
                        radius: 2.4,
                        color: SSColor.ink.opacity(0.85),
                        highlightIndex: 5
                    )
                    .frame(height: 23.8, alignment: .bottom)
                }
                card(.storage, Strings.mockStorage, Strings.mockUsedAndAvailable) {
                    VStack(alignment: .leading, spacing: 4.8) {
                        MockSegments(widths: [46.1, 20.7, 25.4], height: 7.9, radius: 3.2, spacing: 2.4)
                        HStack(spacing: 7.9) {
                            legend(SSColor.ink, Strings.mockUsed)
                            legend(SSColor.borderStrong, Strings.mockFree)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4.8) {
                card(.battery, Strings.mockBattery, Strings.mockLevelAndCharging) {
                    HStack(spacing: 2.4) {
                        RoundedRectangle(cornerRadius: 3.2)
                            .fill(SSColor.positiveFill)
                            .frame(width: 60.4, height: 12.7)
                            .padding(2.4)
                            .frame(width: 90.6, alignment: .leading)
                            .background(SSColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 5.6))
                        RoundedRectangle(cornerRadius: 1.6)
                            .fill(Color(hex: 0xCCCCCC))
                            .frame(width: 2.4, height: 6.4)
                    }
                }
                card(.wifi, Strings.mockNetwork, Strings.mockConnectivityAndData) {
                    Image(SSArtwork.mockActivityLine)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 244, alignment: .leading)
        .offset(x: 6, y: 90)
    }

    private func card(
        _ icon: SSIcon,
        _ title: String,
        _ subtitle: String,
        @ViewBuilder visual: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 7.9) {
            HStack(spacing: 6.4) {
                MockIconTile(icon: icon, size: 22.3, iconSize: 12.7, radius: 7.2)
                VStack(alignment: .leading, spacing: 0.8) {
                    Text(title)
                        .font(.system(size: 10.3, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(SSColor.ink)
                    Text(subtitle)
                        .font(.system(size: 7.9))
                        .foregroundStyle(SSColor.textSecondary)
                }
                .lineLimit(1)
                .fixedSize()
            }
            visual()
        }
        .padding(11.1)
        .frame(width: 119.2, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 15.9, style: .continuous))
        .clipped()
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3.2) {
            RoundedRectangle(cornerRadius: 2.4)
                .fill(color)
                .frame(width: 4.8, height: 4.8)
            Text(text)
                .font(.system(size: 7.9))
                .foregroundStyle(SSColor.textSecondary)
        }
    }
}
