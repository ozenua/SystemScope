import SwiftUI

/// Shared surface and grabber for app-presented bottom sheets.
public struct SSBottomSheetChrome<Content: View>: View {
    @ViewBuilder private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(SSColor.track)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SSColor.surface)
        .presentationBackground(SSColor.surface)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
    }
}

/// Consistent sheet title and close control.
public struct SSBottomSheetTitleRow: View {
    private let title: String
    private let closeLabel: String
    private let onClose: () -> Void

    public init(title: String, closeLabel: String = "Close", onClose: @escaping () -> Void) {
        self.title = title
        self.closeLabel = closeLabel
        self.onClose = onClose
    }

    public var body: some View {
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
            .accessibilityLabel(Text(closeLabel))
        }
        .padding(.horizontal, 20)
    }
}
