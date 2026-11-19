import Foundation

// Service protocols the onboarding feature needs. Live implementations are injected
// by AppShell; previews and tests use the samples below (PRD §4.2).

public enum NotificationPermission: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
}

public protocol NotificationAuthorizing: Sendable {
    func currentPermission() async -> NotificationPermission
    /// Shows the system prompt when the permission is not yet determined.
    func requestPermission() async -> NotificationPermission
}

public struct PremiumPlan: Identifiable, Sendable, Equatable {
    public enum Period: Sendable {
        case monthly
        case yearly
    }

    public let id: String
    public let period: Period
    public let price: Decimal
    /// Localised price string as supplied by the store. Never hard-coded in views (PRD §11.1).
    public let displayPrice: String
    public let currencyCode: String

    public init(id: String, period: Period, price: Decimal, displayPrice: String, currencyCode: String) {
        self.id = id
        self.period = period
        self.price = price
        self.displayPrice = displayPrice
        self.currencyCode = currencyCode
    }

    /// Whole-percent saving of the yearly plan against twelve monthly payments.
    public static func yearlySavingsPercent(monthly: PremiumPlan, yearly: PremiumPlan) -> Int? {
        let fullYear = monthly.price * 12
        guard fullYear > 0, yearly.price < fullYear, monthly.currencyCode == yearly.currencyCode else { return nil }
        let fraction = NSDecimalNumber(decimal: (fullYear - yearly.price) / fullYear).doubleValue
        let percent = Int((fraction * 100).rounded())
        return percent > 0 ? percent : nil
    }

    /// The yearly price expressed per month, e.g. "$3.33".
    public var monthlyEquivalentDisplayPrice: String? {
        guard period == .yearly else { return nil }
        return (price / 12).formatted(.currency(code: currencyCode).presentation(.narrow))
    }
}

public enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    case cancelled
    case nothingToRestore
    /// The store is not wired up in this build.
    case unavailable
}

public protocol PremiumOffering: Sendable {
    func loadPlans() async -> [PremiumPlan]
    func purchase(_ plan: PremiumPlan) async -> PurchaseOutcome
    func restorePurchases() async -> PurchaseOutcome
}

// MARK: - Samples

public struct SampleNotificationAuthorizer: NotificationAuthorizing {
    private let result: NotificationPermission

    public init(result: NotificationPermission = .granted) {
        self.result = result
    }

    public func currentPermission() async -> NotificationPermission { .notDetermined }
    public func requestPermission() async -> NotificationPermission { result }
}

/// Sample plans matching the Figma paywall. Purchases report `.unavailable`.
public struct SamplePremiumOffering: PremiumOffering {
    public init() {}

    public func loadPlans() async -> [PremiumPlan] {
        [
            PremiumPlan(
                id: "com.systemscope.premium.monthly",
                period: .monthly,
                price: Decimal(string: "4.99")!,
                displayPrice: "$4.99",
                currencyCode: "USD"
            ),
            PremiumPlan(
                id: "com.systemscope.premium.yearly",
                period: .yearly,
                price: Decimal(string: "39.99")!,
                displayPrice: "$39.99",
                currencyCode: "USD"
            ),
        ]
    }

    public func purchase(_ plan: PremiumPlan) async -> PurchaseOutcome { .unavailable }
    public func restorePurchases() async -> PurchaseOutcome { .unavailable }
}

/// No plans and no purchases: what Release uses until StoreKit lands in M6.
public struct UnavailablePremiumOffering: PremiumOffering {
    public init() {}

    public func loadPlans() async -> [PremiumPlan] { [] }
    public func purchase(_ plan: PremiumPlan) async -> PurchaseOutcome { .unavailable }
    public func restorePurchases() async -> PurchaseOutcome { .unavailable }
}
