import Core
import DeviceInfo
import Foundation
import Observation

/// State and intents for the first-run flow (PRD §6.1). Views render this and send
/// intents; they own no sampling, permission or purchase logic.
@MainActor
@Observable
public final class OnboardingModel {
    public enum Step: String, CaseIterable, Sendable {
        case splash
        case intro
        case meetDevice
        case monitoring
        case inspect
        case ready
        case premium
    }

    public enum CategoryState: Equatable, Sendable {
        case upNext
        case inProgress
        case finished(DataStatus)
    }

    public enum Notice: String, Identifiable, Sendable {
        case purchasesUnavailable
        case nothingToRestore
        case legalLinksUnavailable

        public var id: String { rawValue }
    }

    public nonisolated static let introPageCount = 3
    public nonisolated static let totalSteps = 7

    public private(set) var step: Step
    public private(set) var introPage = 0
    public private(set) var summary = DeviceSummary()
    public private(set) var isIdentifying = false
    public private(set) var categoryStates: [ScanCategory: CategoryState] = [:]
    public private(set) var notificationPermission: NotificationPermission = .notDetermined
    public private(set) var plans: [PremiumPlan] = []
    public private(set) var isPurchasing = false
    public var selectedPlanID: PremiumPlan.ID?
    public var notice: Notice?

    @ObservationIgnored private let inspector: any DeviceInspecting
    @ObservationIgnored private let notifications: any NotificationAuthorizing
    @ObservationIgnored private let premium: any PremiumOffering
    @ObservationIgnored private let minimumStageDuration: Duration
    @ObservationIgnored private let onFinish: @MainActor () -> Void

    /// - Parameter minimumStageDuration: how long each scan category stays visibly
    ///   "in progress" so the list is readable. Reads themselves are near-instant.
    public init(
        inspector: any DeviceInspecting,
        notifications: any NotificationAuthorizing,
        premium: any PremiumOffering,
        initialStep: Step = .splash,
        minimumStageDuration: Duration = .milliseconds(450),
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.inspector = inspector
        self.notifications = notifications
        self.premium = premium
        self.step = initialStep
        self.minimumStageDuration = minimumStageDuration
        self.onFinish = onFinish
        resetScan()
    }

    // MARK: - Derived state

    public var completedCategoryCount: Int {
        categoryStates.values.count { if case .finished = $0 { true } else { false } }
    }

    public var currentCategory: ScanCategory? {
        ScanCategory.allCases.first { categoryStates[$0] == .inProgress }
    }

    public var isScanComplete: Bool {
        completedCategoryCount == ScanCategory.allCases.count
    }

    /// True when any scanned category came back less than fully available (ONB-09).
    public var hasUnavailableInformation: Bool {
        categoryStates.values.contains { state in
            if case let .finished(status) = state { status != .available } else { false }
        }
    }

    public var selectedPlan: PremiumPlan? {
        plans.first { $0.id == selectedPlanID }
    }

    public var yearlySavingsPercent: Int? {
        guard let monthly = plans.first(where: { $0.period == .monthly }),
              let yearly = plans.first(where: { $0.period == .yearly }) else { return nil }
        return PremiumPlan.yearlySavingsPercent(monthly: monthly, yearly: yearly)
    }

    // MARK: - Navigation intents

    public func splashFinished() {
        guard step == .splash else { return }
        step = .intro
    }

    public func advanceIntro() {
        if introPage < Self.introPageCount - 1 {
            introPage += 1
        } else {
            step = .meetDevice
        }
    }

    public func retreatIntro() {
        if introPage > 0 { introPage -= 1 }
    }

    public func goBack() {
        switch step {
        case .meetDevice: step = .intro
        case .monitoring: step = .meetDevice
        case .premium: step = .ready
        case .splash, .intro, .inspect, .ready: break
        }
    }

    /// Continue, Skip and Maybe later all move forward: no step is mandatory.
    public func goForward() {
        switch step {
        case .splash: step = .intro
        case .intro: advanceIntro()
        case .meetDevice: step = .monitoring
        case .monitoring:
            resetScan()
            step = .inspect
        case .inspect: step = .ready
        case .ready: finish()
        case .premium: finish()
        }
    }

    public func finish() {
        onFinish()
    }

    // MARK: - Meet your device

    public func identifyDevice() async {
        isIdentifying = true
        defer { isIdentifying = false }
        for category in [ScanCategory.deviceAndSystem, .memoryAndStorage] {
            let result = await inspector.readSnapshot(of: category)
            if let value = result.value { summary.merge(value) }
        }
    }

    // MARK: - Set up monitoring

    public func refreshNotificationPermission() async {
        notificationPermission = await notifications.currentPermission()
    }

    public func enableNotifications() async {
        notificationPermission = await notifications.requestPermission()
    }

    // MARK: - Inspect your device

    public func runScan() async {
        resetScan()
        for category in ScanCategory.allCases {
            categoryStates[category] = .inProgress
            async let reading = inspector.readSnapshot(of: category)
            try? await Task.sleep(for: minimumStageDuration)
            let result = await reading
            if Task.isCancelled { return }
            if let value = result.value { summary.merge(value) }
            categoryStates[category] = .finished(result.status)
        }
        try? await Task.sleep(for: minimumStageDuration)
        if !Task.isCancelled, step == .inspect { step = .ready }
    }

    private func resetScan() {
        categoryStates = Dictionary(uniqueKeysWithValues: ScanCategory.allCases.map { ($0, .upNext) })
    }

    // MARK: - Premium

    public func loadPlans() async {
        guard plans.isEmpty else { return }
        plans = await premium.loadPlans()
        if selectedPlanID == nil {
            selectedPlanID = (plans.first { $0.period == .yearly } ?? plans.first)?.id
        }
    }

    public func startPremium() async {
        guard let plan = selectedPlan, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        handle(await premium.purchase(plan))
    }

    public func restorePurchases() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        handle(await premium.restorePurchases())
    }

    public func openLegalLink() {
        // Terms and Privacy URLs are open decision D-13.
        notice = .legalLinksUnavailable
    }

    private func handle(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .purchased: finish()
        case .cancelled: break
        case .nothingToRestore: notice = .nothingToRestore
        case .unavailable: notice = .purchasesUnavailable
        }
    }
}
