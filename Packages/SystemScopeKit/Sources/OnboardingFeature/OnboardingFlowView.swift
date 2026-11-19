import DesignSystem
import SwiftUI

/// Root of the first-run flow. Lives outside the tab bar (PRD §1.3).
public struct OnboardingFlowView: View {
    @Bindable private var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: OnboardingModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            switch model.step {
            case .splash: SplashView(model: model)
            case .intro: IntroView(model: model)
            case .meetDevice: MeetDeviceView(model: model)
            case .monitoring: MonitoringSetupView(model: model)
            case .inspect: InspectDeviceView(model: model)
            case .ready: DeviceReadyView(model: model)
            case .premium: PremiumView(model: model)
            }
        }
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.step)
        // Onboarding is designed in light only; dark values wait on gate D-01.
        .preferredColorScheme(model.step == .splash ? .dark : .light)
        .alert(item: $model.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(Strings.ok))
            )
        }
    }
}

private extension OnboardingModel.Notice {
    var title: String {
        switch self {
        case .purchasesUnavailable: Strings.noticePurchasesTitle
        case .nothingToRestore: Strings.noticeNothingToRestoreTitle
        case .legalLinksUnavailable: Strings.noticeLegalTitle
        }
    }

    var message: String {
        switch self {
        case .purchasesUnavailable: Strings.noticePurchasesBody
        case .nothingToRestore: Strings.noticeNothingToRestoreBody
        case .legalLinksUnavailable: Strings.noticeLegalBody
        }
    }
}
