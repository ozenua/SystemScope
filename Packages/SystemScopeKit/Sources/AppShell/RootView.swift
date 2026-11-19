import Core
import OnboardingFeature
import SwiftUI

/// Chooses between first-run onboarding and the five-tab shell (PRD §1.3, ONB-01).
public struct RootView: View {
    private let environment: AppEnvironment
    @State private var onboarding: OnboardingModel?

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        Group {
            if environment.preferences.hasCompletedOnboarding {
                MainTabView(environment: environment)
            } else if let onboarding {
                OnboardingFlowView(model: onboarding)
            } else {
                Color.clear
            }
        }
        .task(id: environment.preferences.hasCompletedOnboarding) {
            guard !environment.preferences.hasCompletedOnboarding else {
                onboarding = nil
                return
            }
            let preferences = environment.preferences
            onboarding = OnboardingModel(
                inspector: environment.inspector,
                notifications: environment.notifications,
                premium: environment.premium,
                initialStep: environment.initialOnboardingStep,
                onFinish: { preferences.hasCompletedOnboarding = true }
            )
        }
    }
}
