import ActivityStore
import DesignSystem
import SwiftUI

// ACT-08 Filters, ACT-09 Activity settings, ACT-10 Clear history.

/// Selectable option: outlined with a tick when selected, plain text otherwise.
struct FilterOption: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { SSIconView(.tickCircle, size: 16, color: SSColor.textStrong) }
                Text(label).ssText(.label15).foregroundStyle(SSColor.textStrong)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? SSColor.surface : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isSelected ? SSColor.border : .clear, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FiltersSheet: View {
    @Bindable var model: ActivityModel
    @State private var draft: ActivityFilters
    @Environment(\.dismiss) private var dismiss

    init(model: ActivityModel) {
        self.model = model
        _draft = State(initialValue: model.filters)
    }

    private var resultCount: Int {
        var preview = model.filteredItems
        // Count with the draft filters, not the applied ones.
        let base: [ActivityItem] = switch model.chip {
        case .alerts: model.log.alerts.map(ActivityItem.alert)
        default: model.log.events.map(ActivityItem.event).filter { model.chip.category == nil || $0.category == model.chip.category }
        }
        preview = model.apply(draft, to: base)
        return preview.count
    }

    var body: some View {
        SheetScaffold(title: L("Filter activity"), onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    group(L("Category")) {
                        FilterOption(label: L("All"), isSelected: draft.categories.isEmpty) { draft.categories = [] }
                        ForEach(ActivityCategory.allCases) { category in
                            FilterOption(label: ActivityText.categoryName(category), isSelected: draft.categories.contains(category)) {
                                if draft.categories.contains(category) { draft.categories.remove(category) } else { draft.categories.insert(category) }
                            }
                        }
                    }
                    group(L("Date")) {
                        ForEach(ActivityFilters.DateRange.allCases, id: \.self) { range in
                            FilterOption(label: Self.label(range), isSelected: draft.dateRange == range) { draft.dateRange = range }
                        }
                    }
                    group(L("Status")) {
                        ForEach(ActivityFilters.Status.allCases, id: \.self) { status in
                            FilterOption(label: Self.label(status), isSelected: draft.status == status) { draft.status = status }
                        }
                    }
                    group(L("Sort by")) {
                        ForEach(ActivityFilters.Sort.allCases, id: \.self) { sort in
                            FilterOption(label: Self.label(sort), isSelected: draft.sort == sort) { draft.sort = sort }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            HStack(spacing: 10) {
                Button(L("Reset")) { draft = ActivityFilters() }
                    .ssText(.value16)
                    .foregroundStyle(SSColor.textStrong)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                Button {
                    model.filters = draft
                    dismiss()
                } label: {
                    Text(L("Show \(resultCount) results"))
                        .ssText(.value16)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(SSColor.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .presentationDetents([.large])
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong).accessibilityAddTraits(.isHeader)
            SSFlowLayout(spacing: 4) { content() }
        }
    }

    static func label(_ range: ActivityFilters.DateRange) -> String {
        switch range {
        case .today: L("Today")
        case .sevenDays: L("Last 7 days")
        case .thirtyDays: L("Last 30 days")
        case .all: L("All dates")
        }
    }

    static func label(_ status: ActivityFilters.Status) -> String {
        switch status {
        case .all: L("All")
        case .unread: L("Unread")
        case .needsAttention: L("Needs attention")
        case .resolved: L("Resolved")
        }
    }

    static func label(_ sort: ActivityFilters.Sort) -> String {
        switch sort {
        case .newest: L("Newest first")
        case .oldest: L("Oldest first")
        case .severity: L("Severity")
        }
    }
}

struct ActivitySettingsSheet: View {
    let model: ActivityModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?

    var body: some View {
        let settings = model.log.settings
        SheetScaffold(title: L("Activity settings"), onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    overline(L("DISPLAY"))
                    toggleRow(L("Group by date"), L("Show Today, Yesterday and older headers"), settings.groupByDate) { value in
                        model.log.updateSettings { $0.groupByDate = value }
                    }
                    divider
                    toggleRow(L("Show resolved alerts"), L("Keep resolved items in the feed"), settings.showResolvedAlerts) { value in
                        model.log.updateSettings { $0.showResolvedAlerts = value }
                    }
                    divider
                    toggleRow(L("Compact rows"), L("Hide descriptions in the timeline"), settings.compactRows) { value in
                        model.log.updateSettings { $0.compactRows = value }
                    }
                    overline(L("DATA")).padding(.top, 12)
                    Menu {
                        ForEach(ActivityRetention.allCases, id: \.self) { retention in
                            Button(Self.label(retention)) { model.log.updateSettings { $0.retention = retention } }
                        }
                    } label: {
                        row(L("Keep activity for"), L("Older items are removed automatically")) {
                            Text("\(Self.label(settings.retention)) ›").ssText(.label14).foregroundStyle(SSColor.textSubtle)
                        }
                    }
                    .buttonStyle(.plain)
                    divider
                    toggleRow(L("Record monitoring sessions"), L("Save a summary when you leave a monitor"), settings.recordSessions) { value in
                        model.log.updateSettings { $0.recordSessions = value }
                    }
                    overline(L("HISTORY")).padding(.top, 12)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            row(L("Export activity"), L("Save as CSV to Files")) {
                                SSIconView(.arrowUp, size: 18, color: SSColor.textStrong)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    divider
                    Button { model.requestClearHistory() } label: {
                        row(L("Clear activity history"), L("Removes \(model.clearableCount) items from this iPhone"), titleColor: SSColor.thermalRed) {
                            SSIconView(.close, size: 18, color: SSColor.thermalRed)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.clearableCount == 0)
                    Text(L("Activity is stored only on this iPhone and is never sent anywhere."))
                        .ssText(.caption12)
                        .foregroundStyle(SSColor.textTertiary)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .presentationDetents([.large])
        .onAppear { exportURL = model.exportFileURL() }
    }

    private var divider: some View { Rectangle().fill(SSColor.border).frame(height: 1).padding(.leading, 14) }

    private func overline(_ text: String) -> some View {
        Text(text).ssText(.overline11).foregroundStyle(SSColor.textTertiary).accessibilityAddTraits(.isHeader)
    }

    private func row<Trailing: View>(_ title: String, _ detail: String, titleColor: Color = SSColor.textStrong, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).ssText(.label15).foregroundStyle(titleColor)
                Text(detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func toggleRow(_ title: String, _ detail: String, _ value: Bool, onChange: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { value }, set: onChange)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).ssText(.label15).foregroundStyle(SSColor.textStrong)
                Text(detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            }
        }
        .tint(SSColor.textStrong)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    static func label(_ retention: ActivityRetention) -> String {
        switch retention {
        case .sevenDays: L("7 days")
        case .thirtyDays: L("30 days")
        case .ninetyDays: L("90 days")
        case .indefinitely: L("Forever")
        }
    }
}

/// ACT-10: confirm, deleting, success and error, in one centred dialog.
struct ClearHistoryDialog: View {
    let model: ActivityModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { if model.clearState == .confirming { model.cancelClearHistory() } }
            VStack(spacing: 12) {
                icon
                    .frame(width: 56, height: 56)
                    .overlay(Circle().strokeBorder(SSColor.border, lineWidth: 1))
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(SSColor.textStrong).multilineTextAlignment(.center)
                Text(message).ssText(.body14).foregroundStyle(SSColor.textTertiary).multilineTextAlignment(.center)
                buttons.padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch model.clearState {
        case .deleting: ProgressView()
        case .succeeded: SSIconView(.tickCircle, size: 22, color: SSColor.positive)
        case .failed: SSIconView(.warning, size: 22, color: SSColor.errorText)
        default: SSIconView(.close, size: 22, color: SSColor.thermalRed)
        }
    }

    private var title: String {
        switch model.clearState {
        case .deleting: L("Clearing history…")
        case .succeeded: L("History cleared")
        case .failed: L("Couldn’t clear history")
        default: L("Clear activity history?")
        }
    }

    private var message: String {
        switch model.clearState {
        case .deleting: L("Removing activity records from this iPhone.")
        case .succeeded(let count): L("\(count) activity records were removed. Alerts, sessions, your device profile and settings were kept.")
        case .failed: L("Nothing was removed. Your history is unchanged. Try again.")
        default: L("This will permanently remove \(model.clearableCount) activity records from SystemScope. Alerts, sessions, your device profile and settings are kept.")
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch model.clearState {
        case .deleting:
            EmptyView()
        case .succeeded:
            Button(L("Done")) { model.finishClearHistory() }.buttonStyle(.ssPrimary)
        case .failed:
            VStack(spacing: 4) {
                Button(L("Try again")) { Task { await model.confirmClearHistory() } }.buttonStyle(.ssPrimary)
                cancel
            }
        default:
            VStack(spacing: 4) {
                Button(L("Clear history")) { Task { await model.confirmClearHistory() } }
                    .buttonStyle(SSPrimaryButtonStyle(fill: SSColor.thermalRed))
                cancel
            }
        }
    }

    private var cancel: some View {
        Button(L("Cancel")) { model.cancelClearHistory() }
            .ssText(.metric17)
            .foregroundStyle(SSColor.textStrong)
            .frame(maxWidth: .infinity, minHeight: 48)
    }
}
