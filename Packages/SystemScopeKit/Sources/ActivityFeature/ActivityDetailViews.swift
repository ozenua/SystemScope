import ActivityStore
import DesignSystem
import SwiftUI

// ACT-02 Event detail, ACT-03 Alerts, ACT-04 Alert detail, ACT-05 Sessions,
// ACT-06 Session detail, ACT-07 Search.

extension ActivityCategory {
    var monitorLink: ActivityMonitorLink? {
        switch self {
        case .performance: .cpu
        case .battery: .battery
        case .network: .network
        case .thermal: .thermal
        case .storage: .storage
        case .sessions: nil
        }
    }

    var monitorName: String {
        switch self {
        case .performance: L("CPU Monitor")
        case .battery: L("Battery Monitor")
        case .network: L("Network Monitor")
        case .thermal: L("Thermal Monitor")
        case .storage: L("Storage Monitor")
        case .sessions: L("Monitor")
        }
    }
}

/// Shown when a record was deleted while its screen was open.
struct MissingRecord: View {
    let onBack: () -> Void

    var body: some View {
        ActivityPage {
            ActivityDetailHeader(title: L("Activity"), subtitle: L("This item is no longer available"), onBack: onBack)
            EmptyStateCard(icon: .info, title: L("Item not found"), message: L("It may have been deleted or removed by your retention setting."))
        }
    }
}

// MARK: - Event detail (ACT-02)

struct EventDetailView: View {
    let model: ActivityModel
    let id: UUID
    let onOpenMonitor: (ActivityMonitorLink) -> Void

    var body: some View {
        if let event = model.event(id) {
            content(event)
        } else {
            MissingRecord(onBack: model.goBack)
        }
    }

    private func content(_ event: ActivityEvent) -> some View {
        let alert = event.relatedAlertID.flatMap(model.alert)
        let session = event.relatedSessionID.flatMap(model.session)
        let previous = model.log.events.first { $0.kind == event.kind && $0.timestamp < event.timestamp }
        let pair = beforeAfter(event)
        return ActivityPage {
            ActivityDetailHeader(title: L("Activity"), subtitle: L("Event details"), onBack: model.goBack)
            HStack {
                CategoryIcon(icon: event.category.icon)
                Spacer()
                if let alert {
                    StatusPill(title: alert.severity.label, dot: alert.severity.color)
                } else {
                    StatusPill(title: L("Recorded"))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.78)
                    .foregroundStyle(SSColor.textStrong)
                HStack(spacing: 6) {
                    SSIconView(.clock, size: 14, color: SSColor.textTertiary)
                    Text(ActivityFormat.dayAndTime(event.timestamp)).ssText(.captionMedium13).foregroundStyle(SSColor.textTertiary)
                }
                .accessibilityElement(children: .combine)
            }
            if let pair {
                HStack(spacing: 12) {
                    stateColumn(L("Before"), pair.before)
                    SSIconView(.arrowCircleRight, size: 20, color: SSColor.textTertiary)
                    stateColumn(L("After"), pair.after)
                }
                .padding(16)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            TitledCard(title: L("What happened")) {
                Text(event.explanation ?? event.detail)
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.75))
                    .padding(.bottom, 10)
            }
            if !event.measurements.isEmpty {
                TitledCard(title: L("Measurements")) {
                    MeasurementList(rows: event.measurements, onCopy: { model.copy($0) })
                }
            }
            TitledCard(title: L("Source")) {
                MeasurementList(rows: [
                    ActivityMeasurement(L("Category"), ActivityText.categoryName(event.category)),
                    ActivityMeasurement(L("Scope"), event.scope),
                    ActivityMeasurement(L("Recorded by"), event.source),
                ])
            }
            Text(L("Related")).ssText(.section18).foregroundStyle(SSColor.textStrong)
            ActivityCard {
                if let link = event.category.monitorLink {
                    relatedRow(icon: .activity, title: event.category.monitorName, detail: L("Live readings for this category")) { onOpenMonitor(link) }
                    divider
                }
                if let previous {
                    relatedRow(icon: .clock, title: L("Previous \(event.title.lowercased())"), detail: "\(ActivityFormat.dayAndTime(previous.timestamp)) · \(previous.detail)") {
                        model.open(.event(previous.id))
                    }
                    divider
                }
                relatedRow(icon: .info, title: L("Related alerts"), detail: alert.map(\.title) ?? L("None for this event")) {
                    if let alert { model.open(.alert(alert.id)) }
                }
                .disabled(alert == nil)
                if let session {
                    divider
                    relatedRow(icon: .timer, title: L("Monitoring session"), detail: L("\(ActivityText.sessionTitle(session.type)) · started \(ActivityFormat.time(session.startedAt))")) {
                        model.open(.session(session.id))
                    }
                }
            }
            if let link = event.category.monitorLink {
                Button { onOpenMonitor(link) } label: {
                    HStack(spacing: 8) {
                        Text(L("View in \(event.category.monitorName)"))
                        SSIconView(.arrowCircleRight, size: 18, color: .white)
                    }
                }
                .buttonStyle(.ssPrimary)
            }
            HStack(spacing: 10) {
                ActionPill(icon: .copy, title: L("Copy details")) { model.copy(model.detailsText(.event(event))) }
                ActionPill(icon: .close, title: L("Delete event"), destructive: true) { model.delete(.event(event)) }
            }
        }
    }

    private var divider: some View { Rectangle().fill(SSColor.border).frame(height: 1).padding(.leading, 64) }

    private func beforeAfter(_ event: ActivityEvent) -> (before: String, after: String)? {
        let labels = event.measurements.reduce(into: [String: String]()) { $0[$1.label] = $1.value }
        if let before = labels[L("Previous state")] ?? labels["Previous state"], let after = labels[L("New state")] ?? labels["New state"] {
            return (before, after)
        }
        if let before = labels[L("Before")] ?? labels["Before"], let after = labels[L("After")] ?? labels["After"] {
            return (before, after)
        }
        return nil
    }

    private func stateColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(SSColor.textStrong)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func relatedRow(icon: SSIcon, title: String, detail: String, action: @escaping () -> Void) -> some View {
        RelatedRow(icon: icon, title: title, detail: detail, action: action)
    }
}

struct RelatedRow: View {
    let icon: SSIcon
    let title: String
    let detail: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SSIconView(icon, size: 18, color: SSColor.textStrong)
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                    Text(detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isEnabled { SSIconView(.chevronRight, size: 18, color: SSColor.textFaint) }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Alerts (ACT-03)

struct AlertsView: View {
    @Bindable var model: ActivityModel

    var body: some View {
        ActivityPage {
            ActivityDetailHeader(
                title: L("Alerts"),
                subtitle: L("Conditions worth your attention"),
                onBack: model.goBack
            )
            SummaryCard(cells: [
                .init(label: L("Total"), value: "\(model.alertsThisMonth)", caption: L("This month")),
                .init(label: L("Unresolved"), value: "\(model.openAlertCount)", caption: L("Need attention")),
                .init(label: L("Resolved"), value: "\(model.resolvedAlertCount)", caption: L("Marked by you")),
            ])
            ChipRow(options: ActivityModel.AlertChip.allCases, label: Self.label, selection: $model.alertChip)
            let sections = model.alertSections
            if model.log.alerts.isEmpty {
                EmptyStateCard(icon: .shieldTick, title: L("No alerts"), message: L("Alerts appear when a reading crosses a threshold while SystemScope is open."))
            } else if sections.isEmpty {
                EmptyStateCard(icon: .filter, title: L("No matching alerts"), message: L("Try another status or severity."))
            } else {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        DateHeader(title: section.title, count: section.items.count, isCollapsed: model.isCollapsed(section)) {
                            withAnimation(.easeInOut(duration: 0.2)) { model.toggleSection(section.id) }
                        }
                        if !model.isCollapsed(section) {
                            ActivityCard {
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                                    if case .alert(let alert) = item {
                                        AlertRow(model: model, alert: alert)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func label(_ chip: ActivityModel.AlertChip) -> String {
        switch chip {
        case .all: L("All")
        case .unresolved: L("Unresolved")
        case .resolved: L("Resolved")
        case .critical: L("Critical")
        case .attention: L("Attention")
        case .information: L("Information")
        }
    }
}

struct AlertRow: View {
    let model: ActivityModel
    let alert: ActivityAlert

    var body: some View {
        SwipeActionRow(
            isUnread: alert.readState == .unread,
            canToggleRead: true,
            onToggleRead: { model.toggleRead(.alert(alert)) },
            onDelete: { model.delete(.alert(alert)) }
        ) {
            Button { model.open(.alert(alert.id)) } label: {
                HStack(alignment: .top, spacing: 12) {
                    SSIconView(.warning, size: 20, color: alert.severity.color)
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            StatusPill(title: alert.severity.label, dot: alert.severity.color)
                            Spacer()
                            Text(ActivityFormat.time(alert.createdAt)).ssText(.captionMedium12).foregroundStyle(SSColor.textTertiary)
                            SSIconView(.chevronRight, size: 18, color: SSColor.textFaint)
                        }
                        Text(alert.title).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                        Text(alert.detail).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                        AlertStatePill(alert: alert)
                    }
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }
}

/// New (unread and open), Read, Resolved or Dismissed.
struct AlertStatePill: View {
    let alert: ActivityAlert

    var body: some View {
        switch alert.resolutionState {
        case .resolved: StatusPill(title: L("Resolved"))
        case .dismissed: StatusPill(title: L("Dismissed"), dot: SSColor.textFaint)
        case .open:
            if alert.readState == .unread {
                StatusPill(title: L("New"), dot: SSColor.coral, dark: true)
            } else {
                StatusPill(title: L("Read"), dot: SSColor.textFaint)
            }
        }
    }
}

// MARK: - Alert detail (ACT-04)

struct AlertDetailView: View {
    let model: ActivityModel
    let id: UUID
    let onOpenMonitor: (ActivityMonitorLink) -> Void

    var body: some View {
        if let alert = model.alert(id) {
            content(alert)
        } else {
            MissingRecord(onBack: model.goBack)
        }
    }

    private func content(_ alert: ActivityAlert) -> some View {
        ActivityPage {
            ActivityDetailHeader(
                title: L("Alert details"),
                subtitle: L("\(ActivityText.categoryName(alert.category)) alert"),
                onBack: model.goBack
            )
            HStack {
                StatusPill(title: alert.severity.label, dot: alert.severity.color)
                Spacer()
                AlertStatePill(alert: alert)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(alert.title)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.78)
                    .foregroundStyle(SSColor.textStrong)
                HStack(spacing: 6) {
                    SSIconView(.clock, size: 14, color: SSColor.textTertiary)
                    Text("\(ActivityFormat.dayAndTime(alert.createdAt)) · \(stateText(alert))")
                        .ssText(.captionMedium13)
                        .foregroundStyle(SSColor.textTertiary)
                }
                .accessibilityElement(children: .combine)
            }
            TitledCard(title: L("What happened?")) {
                Text(alert.explanation ?? alert.detail)
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textStrong.opacity(0.75))
                    .padding(.bottom, 10)
            }
            if !alert.thresholdSnapshot.isEmpty {
                TitledCard(title: L("Observed information")) {
                    MeasurementList(rows: alert.thresholdSnapshot)
                }
            }
            if let recommendation = alert.recommendation {
                Text(L("Recommended action")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                HStack(alignment: .top, spacing: 12) {
                    SSIconView(.lamp, size: 20, color: SSColor.textStrong)
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                        Text(recommendation.detail).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            if let link = alert.category.monitorLink {
                Button { onOpenMonitor(link) } label: {
                    HStack(spacing: 8) {
                        Text(L("View \(ActivityText.categoryName(alert.category))"))
                        SSIconView(.arrowCircleRight, size: 18, color: .white)
                    }
                }
                .buttonStyle(.ssPrimary)
            }
            Text(L("Alert actions")).ssText(.section18).foregroundStyle(SSColor.textStrong)
            ActivityCard {
                if alert.resolutionState == .open {
                    actionRow(.tickCircle, L("Mark as resolved"), color: SSColor.positive) {
                        model.log.resolve(alert: alert.id)
                        model.showToast(L("Alert resolved"))
                    }
                    divider
                    actionRow(.close, L("Dismiss")) {
                        model.log.dismiss(alert: alert.id)
                        model.showToast(L("Alert dismissed"))
                    }
                } else {
                    actionRow(.refresh, L("Reopen alert")) { model.log.reopen(alert: alert.id) }
                }
                divider
                actionRow(.notification, alert.readState == .unread ? L("Mark as read") : L("Mark as unread")) {
                    model.toggleRead(.alert(alert))
                }
                divider
                actionRow(.copy, L("Copy details")) { model.copy(model.detailsText(.alert(alert))) }
                divider
                actionRow(.close, L("Delete alert"), color: SSColor.thermalRed) { model.delete(.alert(alert)) }
            }
            HStack(alignment: .top, spacing: 8) {
                SSIconView(.info, size: 16, color: SSColor.textFaint)
                Text(L("Opening an alert doesn’t resolve it. You decide when it’s resolved."))
                    .ssText(.captionMedium12)
                    .foregroundStyle(SSColor.textFaint)
            }
            .padding(.horizontal, 4)
        }
    }

    private func stateText(_ alert: ActivityAlert) -> String {
        switch alert.resolutionState {
        case .open: L("Unresolved")
        case .resolved: alert.resolvedAt.map { L("Resolved \(ActivityFormat.dayAndTime($0))") } ?? L("Resolved")
        case .dismissed: L("Dismissed")
        }
    }

    private var divider: some View { Rectangle().fill(SSColor.border).frame(height: 1).padding(.horizontal, 16) }

    private func actionRow(_ icon: SSIcon, _ title: String, color: Color = SSColor.textStrong, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SSIconView(icon, size: 20, color: color)
                Text(title).ssText(.label15).foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sessions (ACT-05)

struct SessionsView: View {
    @Bindable var model: ActivityModel

    var body: some View {
        ActivityPage {
            ActivityDetailHeader(
                title: L("Sessions"),
                subtitle: L("Your monitoring history"),
                onBack: model.goBack,
                trailingIcon: .search,
                trailingLabel: L("Search activity"),
                trailingAction: {
                    model.searchScope = .sessions
                    model.open(.search)
                }
            )
            let latest = model.log.sessions.max { $0.startedAt < $1.startedAt }
            SummaryCard(cells: [
                .init(label: L("Sessions"), value: "\(model.sessionsThisMonth)", caption: L("This month")),
                .init(label: L("Time"), value: ActivityFormat.hours(model.monitoredTotal), caption: L("Monitored total")),
                .init(label: L("Latest"), value: latest.map { ActivityFormat.time($0.startedAt) } ?? "–", caption: latest.map { ActivityFormat.day($0.startedAt) } ?? L("None yet")),
            ])
            ChipRow(options: ActivityModel.SessionRange.allCases, label: Self.label, selection: $model.sessionRange)
            let sections = model.sessionSections
            if model.log.sessions.isEmpty {
                EmptyStateCard(
                    icon: .timer,
                    title: L("No sessions yet"),
                    message: model.log.settings.recordSessions
                        ? L("A session is saved each time you leave the Monitor tab.")
                        : L("Session recording is off in Activity settings.")
                )
            } else if sections.isEmpty {
                EmptyStateCard(icon: .filter, title: L("No sessions in this range"), message: L("Try a longer range."))
            } else {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        DateHeader(title: section.title, count: section.items.count, isCollapsed: false) {}
                            .allowsHitTesting(false)
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                                if case .session(let session) = item {
                                    SessionCard(session: session) { model.open(.session(session.id)) }
                                }
                            }
                        }
                        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
            }
        }
    }

    static func label(_ range: ActivityModel.SessionRange) -> String {
        switch range {
        case .all: L("All")
        case .today: L("Today")
        case .week: L("This week")
        case .month: L("This month")
        }
    }
}

struct SessionCard: View {
    let session: MonitoringSessionRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    CategoryIcon(icon: session.type.icon, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ActivityText.sessionTitle(session.type)).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                        Text(subtitle).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    StatusPill(title: session.status.label, dot: session.status.dot)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    let minutes = ActivityText.minutes(session.duration ?? Date.now.timeIntervalSince(session.startedAt))
                    Text("\(minutes)").font(.system(size: 26, weight: .bold)).foregroundStyle(SSColor.textStrong)
                    Text(session.endedAt == nil ? L("min so far") : L("minutes")).ssText(.labelSemibold14).foregroundStyle(SSColor.textSubtle)
                }
                SSFlowLayout(spacing: 6) {
                    ForEach(session.metricsIncluded, id: \.self) { metric in
                        Text(metric)
                            .ssText(.chip12)
                            .foregroundStyle(SSColor.textStrong)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SSColor.chipBackground, in: Capsule())
                    }
                }
                if let reason = session.interruptionReason {
                    Text(reason).ssText(.caption12).foregroundStyle(SSColor.warmBrown)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let day = ActivityFormat.day(session.startedAt)
        return session.endedAt == nil
            ? L("\(day) · started \(ActivityFormat.time(session.startedAt))")
            : "\(day) · \(ActivityFormat.time(session.startedAt))"
    }
}

// MARK: - Session detail (ACT-06)

struct SessionDetailView: View {
    let model: ActivityModel
    let id: UUID
    let onOpenMonitor: (ActivityMonitorLink) -> Void

    var body: some View {
        if let session = model.session(id) {
            content(session)
        } else {
            MissingRecord(onBack: model.goBack)
        }
    }

    private func content(_ session: MonitoringSessionRecord) -> some View {
        let minutes = ActivityText.minutes(session.duration ?? Date.now.timeIntervalSince(session.startedAt))
        return ActivityPage {
            ActivityDetailHeader(title: L("Session details"), subtitle: ActivityText.sessionTitle(session.type), onBack: model.goBack)
            HStack(spacing: 12) {
                CategoryIcon(icon: session.type.icon, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ActivityText.sessionTitle(session.type)).ssText(.rowTitle15).foregroundStyle(SSColor.textStrong)
                    Text(range(session)).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StatusPill(title: session.status.label, dot: session.status.dot)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(minutes)").font(.system(size: 44, weight: .bold)).tracking(-1.76).foregroundStyle(SSColor.textStrong)
                Text(L("minutes")).ssText(.unit20).foregroundStyle(SSColor.textSubtle)
            }
            .accessibilityElement(children: .combine)
            HStack {
                stat(L("Started"), ActivityFormat.time(session.startedAt))
                stat(L("Ended"), session.endedAt.map(ActivityFormat.time) ?? L("In progress"))
                stat(L("Observations"), "\(session.observationCount)")
            }
            if let reason = session.interruptionReason {
                Text(reason).ssText(.caption13).foregroundStyle(SSColor.warmBrown)
            }
            Text(L("Metrics collected")).ssText(.section18).foregroundStyle(SSColor.textStrong)
            SSFlowLayout(spacing: 8) {
                ForEach(session.metricsIncluded, id: \.self) { metric in
                    metricChip(metric, available: true)
                }
                ForEach(session.metricsUnavailable, id: \.self) { metric in
                    metricChip(metric, available: false)
                }
            }
            if !session.summary.isEmpty {
                Text(L("Observations")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                let cells = session.summary + [ActivityMeasurement(L("Alerts generated"), "\(session.alertsGenerated)")]
                let rows = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                if column > 0 { Rectangle().fill(SSColor.border).frame(width: 1) }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(cell.label).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                                    Text(cell.value).font(.system(size: 22, weight: .bold)).foregroundStyle(SSColor.textStrong)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                            if row.count == 1 { Spacer().frame(maxWidth: .infinity) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(L("Calculated from \(session.observationCount) observations recorded in this session."))
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textFaint)
            }
            Text(L("Session timeline")).ssText(.section18).foregroundStyle(SSColor.textStrong)
            SessionTimeline(session: session)
            if let link = monitorLink(session.type) {
                Button { onOpenMonitor(link) } label: {
                    HStack(spacing: 8) {
                        Text(L("View \(monitorName(session.type))"))
                        SSIconView(.arrowCircleRight, size: 18, color: .white)
                    }
                }
                .buttonStyle(.ssPrimary)
            }
            HStack(spacing: 10) {
                ActionPill(icon: .copy, title: L("Copy")) { model.copy(model.detailsText(.session(session))) }
                ShareLink(item: model.detailsText(.session(session))) {
                    HStack(spacing: 8) {
                        SSIconView(.arrowUp, size: 16, color: SSColor.textStrong)
                        Text(L("Export")).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                ActionPill(icon: .close, title: L("Delete"), destructive: true) { model.delete(.session(session)) }
            }
        }
    }

    private func monitorLink(_ type: SessionType) -> ActivityMonitorLink? {
        switch type {
        case .performance: .cpu
        case .network: .network
        case .battery: .battery
        }
    }

    private func monitorName(_ type: SessionType) -> String {
        switch type {
        case .performance: L("CPU Monitor")
        case .network: L("Network Monitor")
        case .battery: L("Battery Monitor")
        }
    }

    private func range(_ session: MonitoringSessionRecord) -> String {
        let day = ActivityFormat.day(session.startedAt)
        let start = ActivityFormat.time(session.startedAt)
        guard let end = session.endedAt else { return L("\(day), \(start) – now") }
        return "\(day), \(start) – \(ActivityFormat.time(end))"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
            Text(value).ssText(.value16).foregroundStyle(SSColor.textStrong)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func metricChip(_ metric: String, available: Bool) -> some View {
        HStack(spacing: 6) {
            SSIconView(available ? .tickCircle : .info, size: 14, color: available ? SSColor.positive : SSColor.textFaint)
            Text(available ? metric : L("\(metric) unavailable")).ssText(.chip12).foregroundStyle(SSColor.textStrong)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SSColor.surface, in: Capsule())
    }
}

/// Session timeline: start, recorded highlights, end.
struct SessionTimeline: View {
    let session: MonitoringSessionRecord

    var body: some View {
        let entries = [SessionTimelineEntry(date: session.startedAt, title: L("Session started"), detail: ActivityText.sessionTitle(session.type))]
            + session.timeline
            + (session.endedAt.map {
                [SessionTimelineEntry(
                    date: $0,
                    title: session.status == .interrupted ? L("Session interrupted") : L("Session ended"),
                    detail: session.interruptionReason ?? L("You left the Monitor")
                )]
            } ?? [])
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(dot(index, of: entries.count)).frame(width: 8, height: 8).padding(.top, 5)
                        if index < entries.count - 1 {
                            Rectangle().fill(SSColor.border).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                        Text(entry.detail).ssText(.caption12).foregroundStyle(SSColor.textTertiary)
                    }
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(ActivityFormat.time(entry.date)).ssText(.captionMedium12).foregroundStyle(SSColor.textTertiary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func dot(_ index: Int, of count: Int) -> Color {
        if index == 0 || index == count - 1 { return SSColor.textStrong }
        return [SSColor.statusGreen, SSColor.footprintPurple, SSColor.accent][(index - 1) % 3]
    }
}

// MARK: - Search (ACT-07)

struct SearchView: View {
    @Bindable var model: ActivityModel
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SSIconView(.search, size: 18, color: SSColor.textTertiary)
                        TextField(text: $model.searchQuery, prompt: Text(L("Search activity"))) { Text(L("Search activity")) }
                            .ssText(.bodyMedium16)
                            .focused($focused)
                            .submitLabel(.search)
                            .onSubmit { model.commitSearch() }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !model.searchQuery.isEmpty {
                            Button { model.searchQuery = "" } label: {
                                Image(systemName: "xmark.circle").foregroundStyle(SSColor.textFaint)
                                    .frame(minWidth: 32, minHeight: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(L("Clear search")))
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SSColor.border, lineWidth: 1))
                    Button(L("Cancel")) {
                        model.searchQuery = ""
                        model.searchScope = .all
                        model.goBack()
                    }
                    .ssText(.metric17)
                    .foregroundStyle(SSColor.textStrong)
                }
                let query = model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isEmpty {
                    recent
                } else {
                    let results = model.searchResults
                    HStack {
                        Text(L("\(results.count) results for “\(query)”")).ssText(.labelSemibold14).foregroundStyle(SSColor.textStrong)
                        Spacer()
                        Text(L("All dates")).ssText(.caption13).foregroundStyle(SSColor.textTertiary)
                    }
                    ChipRow(options: ActivityModel.SearchScope.allCases, label: Self.label, selection: $model.searchScope)
                    if results.isEmpty {
                        EmptyStateCard(
                            icon: .search,
                            title: L("No results"),
                            message: L("Nothing matches “\(query)”. Search covers titles, details, categories and dates.")
                        )
                    } else {
                        ForEach(model.searchSections) { section in
                            ActivitySectionView(model: model, section: section, collapsible: false)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focused = true }
        .onDisappear { if !model.searchQuery.isEmpty { model.commitSearch() } }
    }

    @ViewBuilder
    private var recent: some View {
        if model.log.recentSearches.isEmpty {
            EmptyStateCard(icon: .search, title: L("Search your activity"), message: L("Find events, alerts and sessions by name, category or date."))
        } else {
            HStack {
                Text(L("Recent searches")).ssText(.section18).foregroundStyle(SSColor.textStrong)
                Spacer()
                Button(L("Clear")) { model.log.clearRecentSearches() }
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.accent)
                    .frame(minHeight: 44)
            }
            ActivityCard {
                ForEach(Array(model.log.recentSearches.enumerated()), id: \.offset) { index, query in
                    if index > 0 { Rectangle().fill(SSColor.border).frame(height: 1) }
                    Button { model.searchQuery = query } label: {
                        HStack(spacing: 12) {
                            SSIconView(.clock, size: 18, color: SSColor.textTertiary)
                            Text(query).ssText(.label15).foregroundStyle(SSColor.textStrong)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(L("Recent searches stay on this iPhone. Up to 10 are kept."))
                .ssText(.caption12)
                .foregroundStyle(SSColor.textFaint)
        }
    }

    static func label(_ scope: ActivityModel.SearchScope) -> String {
        switch scope {
        case .all: L("All")
        case .alerts: L("Alerts")
        case .events: L("Events")
        case .sessions: L("Sessions")
        }
    }
}
