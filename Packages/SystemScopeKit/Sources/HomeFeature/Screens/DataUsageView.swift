import DesignSystem
import SwiftUI

/// Home / Network / Data Usage: observed traffic by time range.
struct DataUsageView: View {
    @Bindable var model: HomeModel

    var body: some View {
        VStack(spacing: 0) {
            HomeTopBar(onBack: model.goBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Strings.dataUsage)
                        .ssText(.section18)
                        .foregroundStyle(SSColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    TimeRangeSelector(selection: $model.selectedRange)

                    HomeCard {
                        VStack(alignment: .leading, spacing: 24) {
                            if let series = model.selectedUsage {
                                UsageHeading(label: model.selectedRange.title, total: Format.bytes(series.totalBytes))
                                UsageBars(
                                    series: series,
                                    height: 131,
                                    summary: Strings.usageSummary(Format.bytes(series.totalBytes), model.selectedRange.title)
                                )
                            } else {
                                Text(model.selectedRange.title)
                                    .ssText(.bodyMedium14)
                                    .foregroundStyle(SSColor.textSubtle)
                                InsufficientHistory()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(SSScreenBackground())
        .task { await model.loadUsage() }
    }
}

extension DataUsageRange {
    var title: String {
        switch self {
        case .today: Strings.today
        case .week: Strings.sevenDays
        case .month: Strings.thirtyDays
        case .sixMonths: Strings.sixMonths
        case .year: Strings.oneYear
        }
    }
}

/// Segmented time-range control (Figma "TimeRangeSelector").
private struct TimeRangeSelector: View {
    @Binding var selection: DataUsageRange

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DataUsageRange.allCases, id: \.self) { range in
                let isSelected = range == selection
                Button {
                    selection = range
                } label: {
                    Text(range.title)
                        .ssText(.segment13)
                        .foregroundStyle(isSelected ? SSColor.textPrimary : SSColor.textSubtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.08), radius: 1.5, y: 2)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(SSColor.hairline, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
