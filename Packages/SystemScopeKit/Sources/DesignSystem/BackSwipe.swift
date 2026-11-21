import SwiftUI

private struct BackSwipeModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let horizontalDistance = value.translation.width
                    let verticalDistance = abs(value.translation.height)
                    guard value.startLocation.x <= 44,
                          horizontalDistance >= 80,
                          horizontalDistance > verticalDistance * 1.25 else {
                        return
                    }
                    action()
                }
        )
    }
}

public extension View {
    /// Enables an edge swipe that mirrors the custom back buttons used by the app.
    func backSwipe(action: @escaping () -> Void) -> some View {
        modifier(BackSwipeModifier(action: action))
    }
}
