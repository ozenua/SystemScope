import DesignSystem
import SwiftUI

/// Introduction 1–3: a sample-dashboard illustration above the pitch and a single action.
struct IntroView: View {
    let model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The illustration is drawn on the Figma canvas (402 pt wide, measured from the top
    // of the screen) and scaled to fit. Its last 49 pt tuck under the text panel.
    private let canvas = CGSize(width: 402, height: 583)
    private let overlap: CGFloat = 49

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / canvas.width, (proxy.size.height + overlap) / canvas.height)
                IntroIllustration(page: model.introPage)
                    .frame(width: canvas.width, height: canvas.height, alignment: .top)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .id(model.introPage)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            }
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.introIllustration))

            panel
        }
        .background(SSScreenBackground())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.introPage)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 { model.advanceIntro() } else { model.retreatIntro() }
            }
        )
    }

    private var panel: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(title)
                    .ssText(.display36)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .ssText(.body16)
                    .foregroundStyle(SSColor.textSecondary)
                    .frame(maxWidth: model.introPage == 0 ? 275 : .infinity)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 318)
            .id(model.introPage)
            .transition(.opacity)

            SSPageDots(count: OnboardingModel.introPageCount, current: model.introPage)

            Button(isLastPage ? Strings.identifyMyDevice : Strings.continueAction) {
                model.advanceIntro()
            }
            .buttonStyle(.ssPrimary)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
    }

    private var isLastPage: Bool {
        model.introPage == OnboardingModel.introPageCount - 1
    }

    private var title: String {
        switch model.introPage {
        case 0: Strings.intro1Title
        case 1: Strings.intro2Title
        default: Strings.intro3Title
        }
    }

    private var message: String {
        switch model.introPage {
        case 0: Strings.intro1Body
        case 1: Strings.intro2Body
        default: Strings.intro3Body
        }
    }
}
