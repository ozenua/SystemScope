import ActivityStore
import DesignSystem
import SwiftUI

/// ACT-01 · Activity overview, the pushed screens, and their states.
public struct ActivityView: View {
    @Bindable private var model: ActivityModel
    private let onOpenMonitor: (ActivityMonitorLink) -> Void

    public init(model: ActivityModel, onOpenMonitor: @escaping (ActivityMonitorLink) -> Void) {
        self.model = model
        self.onOpenMonitor = onOpenMonitor
    }

    public var body: some View {
        NavigationStack(path: $model.path) {
            ActivityOverview(model: model, onOpenMonitor: onOpenMonitor)
                .navigationDestination(for: ActivityRoute.self) { route in
                    Group {
                        switch route {
                        case .event(let id): EventDetailView(model: model, id: id, onOpenMonitor: onOpenMonitor)
                        case .alerts: AlertsView(model: model)
                        case .alert(let id): AlertDetailView(model: model, id: id, onOpenMonitor: onOpenMonitor)
                        case .sessions: SessionsView(model: model)
                        case .session(let id): SessionDetailView(model: model, id: id, onOpenMonitor: onOpenMonitor)
                        case .search: SearchView(model: model)
                        }
                    }
                    .ssFadeInNavigationDestination()
                }
        }
        .backSwipe { model.goBack() }
        .task { await model.load() }
    }
}

public extension View {
    /// Filters and settings sheets, the clear-history dialog and the toast. Applied by
    /// the shell at its root: a sheet presented from inside a tab is dismissed
    /// whenever the root's own sheet modifier updates.
    func activitySheets(model: ActivityModel) -> some View {
        modifier(ActivitySheetsModifier(model: model))
    }
}

private struct ActivitySheetsModifier: ViewModifier {
    @Bindable var model: ActivityModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.sheet) { sheet in
                switch sheet {
                case .filters: FiltersSheet(model: model)
                case .settings: ActivitySettingsSheet(model: model)
                }
            }
            .overlay {
                if model.clearState != .idle {
                    ClearHistoryDialog(model: model)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    ActivityToast(message: toast)
                        .padding(.bottom, 116)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.clearState)
            .animation(.easeInOut(duration: 0.25), value: model.toast)
    }
}

struct ActivityOverview: View {
    @Bindable var model: ActivityModel
    let onOpenMonitor: (ActivityMonitorLink) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if model.isLoading {
                    ActivitySkeleton()
                } else if model.loadFailed {
                    summary
                    EmptyStateCard(
                        icon: .warning,
                        title: L("Couldn’t load activity"),
                        message: L("Your history is still on this iPhone. Try again in a moment."),
                        button: L("Try again"),
                        action: { Task { await model.retry() } }
                    )
                } else {
                    summary
                    ChipRow(options: ActivityChip.allCases, label: Self.chipLabel, selection: $model.chip)
                    feed
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .refreshable { await model.retry() }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    static func chipLabel(_ chip: ActivityChip) -> String {
        switch chip {
        case .all: L("All")
        case .alerts: L("Alerts")
        case .performance: L("Performance")
        case .battery: L("Battery")
        case .network: L("Network")
        case .thermal: L("Thermal")
        case .storage: L("Storage")
        case .sessions: L("Sessions")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Activity"))
                    .ssText(.pageTitle28)
                    .foregroundStyle(SSColor.textStrong)
                    .accessibilityAddTraits(.isHeader)
                Text(L("Your device history and events"))
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
            Spacer()
            HStack(spacing: 0) {
                CircleButton(icon: .search, label: L("Search activity")) { model.open(.search) }
                ZStack(alignment: .topTrailing) {
                    CircleButton(icon: .filter, label: L("Filter activity")) { model.sheet = .filters }
                    if !model.filters.isDefault {
                        Circle().fill(SSColor.accent).frame(width: 9, height: 9).offset(x: -6, y: 6)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityValue(Text(model.filters.isDefault ? "" : L("Filters on")))
                CircleButton(icon: .more, label: L("Activity settings")) { model.sheet = .settings }
            }
        }
    }

    private var summary: some View {
        SummaryCard(
            cells: [
                .init(label: L("Today"), value: "\(model.todayCount)", caption: L("Recorded events")),
                .init(label: L("Alerts"), value: "\(model.openAlertCount)", caption: L("Need attention")) { model.open(.alerts) },
                .init(label: L("Sessions"), value: "\(model.sessionsToday)", caption: L("Monitored today")) { model.open(.sessions) },
            ],
            timestamp: model.lastActivity.map { L("Last activity \(ActivityFormat.time($0))") } ?? L("No activity recorded yet")
        )
    }

    @ViewBuilder
    private var feed: some View {
        let sections = model.feedSections
        if !model.hasAnyHistory || (model.isUnfiltered && model.log.events.isEmpty && model.chip != .alerts) {
            // ACT-09: empty (no history) is distinct from filtered-empty.
            EmptyStateCard(
                icon: .activity,
                title: L("No activity yet"),
                message: L("Events appear here as SystemScope monitors your iPhone."),
                button: L("Open Monitor"),
                action: { onOpenMonitor(.cpu) }
            )
        } else if sections.isEmpty {
            EmptyStateCard(
                icon: .filter,
                title: L("No matching activity"),
                message: L("Nothing matches these filters. Try another category or clear the filters."),
                button: L("Clear filters"),
                action: {
                    model.filters = ActivityFilters()
                    model.chip = .all
                }
            )
        } else {
            ForEach(sections) { section in
                ActivitySectionView(model: model, section: section)
            }
            if model.canLoadMore {
                Button { model.loadMore() } label: {
                    Text(L("Load older activity"))
                        .ssText(.rowTitle15)
                        .foregroundStyle(SSColor.textStrong)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A date header and its card of rows, collapsible.
struct ActivitySectionView: View {
    let model: ActivityModel
    let section: ActivitySection
    var collapsible = true

    var body: some View {
        let collapsed = collapsible && model.isCollapsed(section)
        VStack(alignment: .leading, spacing: 12) {
            DateHeader(title: section.title, count: section.items.count, isCollapsed: collapsed) {
                withAnimation(.easeInOut(duration: 0.2)) { model.toggleSection(section.id) }
            }
            if !collapsed {
                ActivityCard {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                        ActivityItemRow(model: model, item: item, showDate: section.id == "older" || section.id.hasPrefix("search"))
                    }
                }
            }
        }
    }
}

/// A tappable row with swipe, context-menu and accessibility actions.
struct ActivityItemRow: View {
    let model: ActivityModel
    let item: ActivityItem
    var showDate = false

    var body: some View {
        let canToggle: Bool = if case .session = item { false } else { true }
        SwipeActionRow(
            isUnread: item.isUnread,
            canToggleRead: canToggle,
            onToggleRead: { model.toggleRead(item) },
            onDelete: { model.delete(item) }
        ) {
            Button { model.open(item.route) } label: {
                ActivityRow(item: item, compact: model.log.settings.compactRows, timeText: ActivityFormat.rowTime(item.date, showDate: showDate))
            }
            .buttonStyle(.plain)
        }
    }
}

enum ActivityFormat {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func rowTime(_ date: Date, showDate: Bool) -> String {
        guard showDate, !Calendar.current.isDateInToday(date) else { return time(date) }
        if Calendar.current.isDateInYesterday(date) { return L("Yesterday") }
        if let days = Calendar.current.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "Today", "Yesterday", "Mon" within a week, else "9 Nov".
    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L("Today") }
        if calendar.isDateInYesterday(date) { return L("Yesterday") }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func dayAndTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L("Today, \(time(date))") }
        if calendar.isDateInYesterday(date) { return L("Yesterday, \(time(date))") }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    static func hours(_ interval: TimeInterval) -> String {
        let hours = interval / 3600
        if hours < 1 { return L("\(ActivityText.minutes(interval))m") }
        return "\(hours.formatted(.number.precision(.fractionLength(0...1))))h"
    }
}

/// Loading state: grey blocks in the shape of the overview.
struct ActivitySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SSColor.surface).frame(height: 132)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in Capsule().fill(SSColor.hairline).frame(width: 80, height: 38) }
            }
            RoundedRectangle(cornerRadius: 6).fill(SSColor.hairline).frame(width: 90, height: 20)
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 14).fill(SSColor.hairline).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(SSColor.hairline).frame(width: 170, height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(SSColor.hairline).frame(width: 120, height: 12)
                        }
                        Spacer()
                    }
                    .padding(14)
                }
            }
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .accessibilityElement()
        .accessibilityLabel(Text(L("Loading activity")))
    }
}
