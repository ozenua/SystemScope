import DesignSystem
import SwiftUI

struct SplashView: View {
    let model: OnboardingModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1A1A), .black], startPoint: .top, endPoint: .bottom)

            AppLogo(size: 100)

            VStack {
                Spacer()
                Text(verbatim: "Scope")
                    // 125 pt in Figma's display face; SF is wider, so 112 pt gives the same span.
                    .font(.system(size: 112, weight: .bold))
                    .tracking(-4.5)
                    .foregroundStyle(Color(hex: 0x181818))
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 58)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            model.splashFinished()
        }
    }
}
