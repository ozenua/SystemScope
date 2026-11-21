import Core
import DeviceInfo
import Foundation
import Testing
@testable import OnboardingFeature

/// Reports every category as partial with no values, like a device that shares little.
private struct SparseInspector: DeviceInspecting {
    func readSnapshot(of category: ScanCategory) async -> DeviceDataResult<DeviceSummary> {
        DeviceDataResult(value: DeviceSummary(), scope: .unavailable, source: "test", status: .partial)
    }
}

@MainActor
struct OnboardingModelTests {
    private final class Finished {
        var value = false
    }

    private func makeModel(
        inspector: any DeviceInspecting = SampleDeviceInspector(),
        notifications: any NotificationAuthorizing = SampleNotificationAuthorizer(result: .denied),
        finished: Finished = Finished(),
        initialStep: OnboardingModel.Step = .splash
    ) -> OnboardingModel {
        OnboardingModel(
            inspector: inspector,
            notifications: notifications,
            premium: SamplePremiumOffering(),
            initialStep: initialStep,
            minimumStageDuration: .zero,
            onFinish: { finished.value = true }
        )
    }

    /// PRD §6.1 acceptance: onboarding completes without granting optional permissions.
    @Test func completesWithoutGrantingPermissions() async {
        let finished = Finished()
        let model = makeModel(finished: finished)

        model.splashFinished()
        #expect(model.step == .intro)
        model.advanceIntro()
        model.advanceIntro()
        model.advanceIntro()
        #expect(model.step == .meetDevice)

        await model.identifyDevice()
        #expect(model.summary.modelName == "iPhone 15 Pro")

        model.goForward()
        #expect(model.step == .monitoring)
        #expect(model.notificationPermission == .notDetermined)

        model.goForward()
        #expect(model.step == .inspect)
        await model.runScan()
        #expect(model.isScanComplete)
        #expect(model.step == .ready)

        model.finish()
        #expect(finished.value)
    }

    @Test func introPagesAdvanceAndRetreat() {
        let model = makeModel()
        model.splashFinished()
        model.advanceIntro()
        #expect(model.introPage == 1)
        model.retreatIntro()
        model.retreatIntro()
        #expect(model.introPage == 0)
        #expect(model.step == .intro)
    }

    @Test func deniedNotificationsDoNotBlockTheFlow() async {
        let model = makeModel()
        await model.enableNotifications()
        #expect(model.notificationPermission == .denied)
    }

    /// ONB-08: categories that were not fully read are never reported as complete.
    @Test func partialCategoriesAreNotReportedAsComplete() async {
        let model = makeModel(inspector: SparseInspector())
        await model.runScan()
        #expect(model.isScanComplete)
        #expect(model.hasUnavailableInformation)
        #expect(model.categoryStates[.sensors] == .finished(.partial))
        #expect(model.summary.batteryLevel == nil)
    }

    @Test func yearlyPlanIsPreselectedWithCalculatedSaving() async {
        let model = makeModel()
        await model.loadPlans()
        #expect(model.selectedPlan?.period == .yearly)
        #expect(model.yearlySavingsPercent == 33)
        #expect(model.selectedPlan?.monthlyEquivalentDisplayPrice?.contains("3.33") == true)
    }

    @Test func unavailablePurchaseShowsNoticeAndDoesNotFinish() async {
        let finished = Finished()
        let model = makeModel(finished: finished)
        await model.loadPlans()
        await model.startPremium()
        #expect(model.notice == .purchasesUnavailable)
        #expect(finished.value == false)
    }

    @Test func readyScreenOpensFullAppWithoutPremiumStep() {
        let finished = Finished()
        let model = makeModel(finished: finished, initialStep: .ready)
        model.goForward()
        #expect(finished.value)
    }
}
