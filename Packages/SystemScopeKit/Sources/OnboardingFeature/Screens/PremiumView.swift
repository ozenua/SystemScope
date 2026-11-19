import DesignSystem
import SwiftUI

/// Premium paywall (PRD §11.4). Prices come from the injected offering, never from
/// this view. Back returns to the ready screen, where the free path lives (ONB-10).
struct PremiumView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(
                onBack: model.goBack,
                trailingTitle: Strings.restore,
                onTrailing: { Task { await model.restorePurchases() } }
            ) {
                PremiumBadge(style: .gradient)
            }

            OnboardingScrollPage {
                VStack(spacing: 22) {
                    OnboardingHeading(title: Strings.premiumTitle, message: Strings.premiumBody, spacing: 8)
                    VStack(spacing: 8) {
                        benefits
                        plans
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            } footer: {
                footer
            }
        }
        .background(SSScreenBackground())
        .task { await model.loadPlans() }
    }

    private var benefits: some View {
        let columns = [GridItem(.flexible(), spacing: 12, alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(Strings.premiumBenefits, id: \.self) { benefit in
                HStack(spacing: 8) {
                    SSIconView(.tickCircle, size: 18, color: SSColor.positiveFill)
                    Text(benefit)
                        .ssText(.body14)
                        .foregroundStyle(SSColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        if model.plans.isEmpty {
            Text(Strings.plansUnavailable)
                .ssText(.body14)
                .foregroundStyle(SSColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous))
        } else {
            HStack(alignment: .top, spacing: 8) {
                ForEach(model.plans) { plan in
                    PlanCard(
                        plan: plan,
                        isSelected: plan.id == model.selectedPlanID,
                        savingsPercent: plan.period == .yearly ? model.yearlySavingsPercent : nil
                    ) {
                        model.selectedPlanID = plan.id
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(Strings.startPremium) {
                Task { await model.startPremium() }
            }
            .buttonStyle(.ssPrimary)
            .disabled(model.selectedPlan == nil || model.isPurchasing)

            Text(Strings.paymentTerms)
                .ssText(.caption12)
                .foregroundStyle(SSColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                legalLink(Strings.termsOfUse, action: model.openLegalLink)
                legalLink(Strings.privacyPolicy, action: model.openLegalLink)
                legalLink(Strings.restorePurchases) { Task { await model.restorePurchases() } }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func legalLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .ssText(.captionMedium12)
                .foregroundStyle(SSColor.textPrimary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }
}

private struct PlanCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let savingsPercent: Int?
    let select: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SSRadius.cardMedium, style: .continuous)
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(isSelected ? SSArtwork.radioSelected : SSArtwork.radio)
                    Text(plan.period == .monthly ? Strings.monthly : Strings.annual)
                        .ssText(.label15)
                        .foregroundStyle(isSelected ? SSColor.textPrimary : SSColor.textSecondary)
                }
                .fixedSize()
                Text(plan.displayPrice)
                    .ssText(.price24)
                    .foregroundStyle(SSColor.textPrimary)
                Text(caption)
                    .ssText(.caption13)
                    .foregroundStyle(SSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .background(SSColor.surface, in: shape)
            .overlay(alignment: .topTrailing) {
                if let savingsPercent {
                    Text(Strings.savePercent(savingsPercent))
                        .ssText(.badge11)
                        .foregroundStyle(SSColor.positive)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(SSColor.border, lineWidth: 1))
                        .padding(.top, 12)
                        .padding(.trailing, 10)
                }
            }
            .overlay {
                if isSelected {
                    shape.strokeBorder(SSColor.premiumGradient, lineWidth: 2)
                } else {
                    shape.strokeBorder(SSColor.borderStrong, lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var caption: String {
        switch plan.period {
        case .monthly: Strings.perMonth
        case .yearly: plan.monthlyEquivalentDisplayPrice.map(Strings.perYearWithMonthly) ?? Strings.perYear
        }
    }
}
