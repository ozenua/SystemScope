import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// Inspect Your Device: the first-run foreground scan. Progress counts real category
/// reads (ONB-07) and anything not fully read is labelled, never shown as complete (ONB-08).
struct InspectDeviceView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar {
                StepLabel(current: 6)
            }

            ScrollView {
                VStack(spacing: 22) {
                    ScanVisual(isActive: !model.isScanComplete)
                    VStack(spacing: 24) {
                        OnboardingHeading(title: Strings.inspectTitle, message: Strings.inspectBody)
                        statusCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(SSScreenBackground())
        .task { await model.runScan() }
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 18) {
                ForEach(ScanCategory.allCases, id: \.self) { category in
                    CategoryRow(category: category, state: model.categoryStates[category] ?? .upNext)
                }
            }
            .padding(20)

            VStack(spacing: 10) {
                HStack {
                    Text(stageTitle)
                        .foregroundStyle(SSColor.textPrimary)
                    Spacer(minLength: 8)
                    Text(Strings.progressCount(progressPosition, ScanCategory.allCases.count))
                        .foregroundStyle(SSColor.textSecondary)
                }
                .ssText(.label14)
                .accessibilityElement(children: .combine)

                // One segment per category (the Figma frame draws five for six categories).
                SSSegmentedProgress(
                    total: ScanCategory.allCases.count,
                    completed: model.completedCategoryCount,
                    hasCurrent: model.currentCategory != nil
                )
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal, 15)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous))
    }

    private var progressPosition: Int {
        min(model.completedCategoryCount + (model.currentCategory == nil ? 0 : 1), ScanCategory.allCases.count)
    }

    private var stageTitle: String {
        guard let category = model.currentCategory else {
            return model.isScanComplete ? Strings.stageDone : Strings.stageWaiting
        }
        return switch category {
        case .deviceAndSystem: Strings.stageDevice
        case .memoryAndStorage: Strings.stageMemory
        case .batteryAndThermal: Strings.stageBattery
        case .networkAndConnectivity: Strings.stageNetwork
        case .displayAndCameras: Strings.stageDisplay
        case .sensors: Strings.stageSensors
        }
    }
}

private struct CategoryRow: View {
    let category: ScanCategory
    let state: OnboardingModel.CategoryState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 10) {
            SSIconView(icon, size: 20, color: state == .upNext ? SSColor.textMuted : Color(hex: 0x292D32))
            Text(title)
                .ssText(.body16)
                .lineLimit(dynamicTypeSize <= .large ? 1 : nil)
                .minimumScaleFactor(dynamicTypeSize <= .large ? 0.85 : 1)
                .foregroundStyle(state == .upNext ? SSColor.textSecondary : SSColor.textPrimary)
            Spacer(minLength: 8)
            status
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .upNext:
            Text(Strings.statusUpNext)
                .ssText(.label14)
                .foregroundStyle(SSColor.textMuted)
        case .inProgress:
            HStack(spacing: 6) {
                Spinner()
                Text(Strings.statusInProgress)
                    .ssText(.label14)
                    .foregroundStyle(SSColor.ink)
            }
        case .finished(.available):
            HStack(spacing: 6) {
                SSIconView(.tickCircle, size: 18, color: SSColor.positiveFill)
                Text(Strings.statusComplete)
                    .ssText(.label14)
                    .foregroundStyle(SSColor.positive)
            }
        case let .finished(other):
            Text(Self.label(for: other))
                .ssText(.label14)
                .foregroundStyle(SSColor.textSecondary)
        }
    }

    private static func label(for status: DataStatus) -> String {
        switch status {
        case .available: Strings.statusComplete
        case .partial, .stale: Strings.statusPartial
        case .permissionRequired: Strings.statusPermissionNeeded
        case .unsupported: Strings.statusNotSupported
        case .notVerified: Strings.statusNotVerified
        case .failed: Strings.unavailable
        }
    }

    private var title: String {
        switch category {
        case .deviceAndSystem: Strings.categoryDevice
        case .memoryAndStorage: Strings.categoryMemory
        case .batteryAndThermal: Strings.categoryBattery
        case .networkAndConnectivity: Strings.categoryNetwork
        case .displayAndCameras: Strings.categoryDisplay
        case .sensors: Strings.categorySensors
        }
    }

    private var icon: SSIcon {
        switch category {
        case .deviceAndSystem: .mobile
        case .memoryAndStorage: .storage
        case .batteryAndThermal: .battery
        case .networkAndConnectivity: .wifi
        case .displayAndCameras: .mobileAlt
        case .sensors: .activity
        }
    }
}

private struct Spinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        SSIconView(.spinner, size: 14)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

/// The radar-style scan artwork. The arc, head and sweep rotate while a scan runs.
private struct ScanVisual: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    var body: some View {
        ZStack {
            Image(SSArtwork.scanRingOuter)
            Image(SSArtwork.scanRingInner)

            ZStack(alignment: .topLeading) {
                Color.clear
                Image(SSArtwork.scanSweep)
                    .resizable()
                    .frame(width: 94, height: 94)
                    .offset(x: 48, y: 48)
                Image(SSArtwork.scanArc)
                    .offset(x: 49.74, y: 18)
                Image(SSArtwork.scanHead)
                    .offset(x: 45, y: 152)
            }
            .frame(width: 190, height: 190, alignment: .topLeading)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(
                rotating ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default,
                value: rotating
            )

            AppLogo(size: 32)
        }
        .frame(width: 190, height: 190)
        .accessibilityHidden(true)
        .onAppear { rotating = isActive && !reduceMotion }
        .onChange(of: isActive) { _, active in
            rotating = active && !reduceMotion
        }
    }
}
