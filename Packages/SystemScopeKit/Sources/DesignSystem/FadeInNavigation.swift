import SwiftUI

public struct SSFadeInNavigationDestination: ViewModifier {
    @State private var isVisible = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear { isVisible = true }
            .animation(.smooth(duration: 0.24), value: isVisible)
    }
}

public extension View {
    func ssFadeInNavigationDestination() -> some View {
        modifier(SSFadeInNavigationDestination())
    }
}
