import Core
import DesignSystem
import DeviceInfo
import SwiftUI

/// Home / Performance / GPU: what Metal reports about the graphics hardware, kept
/// apart from utilisation, which iOS does not expose device-wide.
///
/// There is no Figma frame for this screen yet; it reuses the Home components.
struct GPUView: View {
    let model: HomeModel

    var body: some View {
        VStack(spacing: 0) {
            HomeTopBar(onBack: model.goBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Strings.gpuTitle)
                            .ssText(.screenTitle24)
                            .foregroundStyle(SSColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(Strings.gpuSubtitle)
                            .ssText(.bodyMedium14)
                            .foregroundStyle(SSColor.textSubtle)
                    }

                    section(Strings.gpuHardware, scope: Strings.scopeSpecification) {
                        row(Strings.gpuName, model.gpu?.name)
                        row(Strings.architecture, model.gpu?.architecture)
                        row(Strings.metal, model.gpu.map { $0.metalAvailable ? Strings.available : Strings.notAvailable })
                        row(Strings.gpuFamilies, families)
                        row(Strings.unifiedMemory, unifiedMemory)
                        row(Strings.threadgroupMemory, threadgroupMemory)
                        row(Strings.maxThreads, model.gpu?.maxThreadsPerThreadgroup.map(String.init))
                        row(Strings.workingSet, workingSet)
                        row(Strings.capabilities, capabilities)
                        row(Strings.counterSets, counterSets, fallback: Strings.countersUnsupported)
                    }

                    section(Strings.gpuUtilisation, scope: Strings.scopeThisIPhone) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Strings.unavailable)
                                .ssText(.title20)
                                .foregroundStyle(SSColor.textSubtle)
                            Text(Strings.gpuUtilisationUnavailable)
                                .ssText(.bodyMedium14)
                                .foregroundStyle(SSColor.textSubtle)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Only when SystemScope has timed real Metal work of its own.
                    if let milliseconds = model.gpu?.appGPUExecutionTimeMs {
                        section(Strings.appGPUActivity, scope: Strings.scopeThisApp) {
                            row(Strings.lastExecutionTime, Format.milliseconds(milliseconds))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
    }

    private var capabilities: String? {
        guard let gpu = model.gpu, gpu.metalAvailable else { return nil }
        let names = gpu.supportedCapabilities
            .filter {
                if case .appleFamily = $0 { return false }
                return $0 != .unifiedMemory
            }
            .map(\.title)
        return names.isEmpty ? Strings.noCapabilities : names.joined(separator: "\n")
    }

    private var families: String? {
        guard let families = model.gpu?.families, !families.isEmpty else { return nil }
        return families.joined(separator: "\n")
    }

    private var unifiedMemory: String? {
        model.gpu?.hasUnifiedMemory.map { $0 ? Strings.available : Strings.notAvailable }
    }

    private var threadgroupMemory: String? {
        guard let bytes = model.gpu?.maxThreadgroupMemoryBytes, bytes > 0 else { return nil }
        return ByteFormatting.memory(UInt64(bytes), fractionDigits: 0)
    }

    private var workingSet: String? {
        guard let bytes = model.gpu?.recommendedMaxWorkingSetBytes, bytes > 0 else { return nil }
        return ByteFormatting.memory(bytes, fractionDigits: 1)
    }

    private var counterSets: String? {
        guard let sets = model.gpu?.counterSets, !sets.isEmpty else { return nil }
        return sets.joined(separator: "\n")
    }

    private func section(_ title: String, scope: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .ssText(.section18)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(scope)
                    .ssText(.chip12)
                    .foregroundStyle(SSColor.textSubtle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SSColor.hairline, in: Capsule())
            }
            HomeCard {
                VStack(alignment: .leading, spacing: 16) { content() }
            }
        }
    }

    private func row(_ label: String, _ value: String?, fallback: String = Strings.unavailable) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .ssText(.bodyMedium14)
                .foregroundStyle(SSColor.textSubtle)
            Spacer(minLength: 8)
            Text(value ?? fallback)
                .ssText(.labelSemibold14)
                .foregroundStyle(value == nil ? SSColor.textSubtle : SSColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension GPUCapability {
    var title: String {
        switch self {
        case let .appleFamily(number): Strings.capabilityAppleFamily(number)
        case .metal3: Strings.capabilityMetal3
        case .unifiedMemory: Strings.capabilityUnifiedMemory
        case .float32Filtering: Strings.capabilityFloatFiltering
        case .rayTracing: Strings.capabilityRayTracing
        case .bcTextureCompression: Strings.capabilityBCCompression
        }
    }
}
