@testable import ActivityFeature
import ActivityStore
import Foundation
import Testing

@MainActor
private func makeModel(_ snapshot: ActivitySnapshot = SampleActivity.snapshot(), failSaves: Bool = false) async -> ActivityModel {
    let log = ActivityLog(persistence: InMemoryActivityPersistence(snapshot: snapshot, failSaves: failSaves))
    let model = ActivityModel(log: log, copy: { _ in })
    await model.load()
    return model
}

@MainActor
struct ActivityModelTests {
    @Test func summaryCountsMatchTheRecords() async {
        let model = await makeModel()
        #expect(model.todayCount == 5)
        #expect(model.openAlertCount == 2)
        #expect(model.sessionsToday == 2)
    }

    @Test func feedGroupsByDateAndPaginates() async {
        let model = await makeModel()
        let sections = model.feedSections
        #expect(sections.first?.id == "today")
        #expect(sections.first?.items.count == 5)
        #expect(sections.dropFirst().first?.id == "yesterday")
        #expect(model.canLoadMore)
        let before = sections.flatMap(\.items).count
        model.loadMore()
        #expect(model.feedSections.flatMap(\.items).count > before)
    }

    @Test func chipsAndFiltersNarrowTheFeed() async {
        let model = await makeModel()
        model.chip = .battery
        let allBattery = model.filteredItems.allSatisfy { $0.category == .battery }
        #expect(allBattery)
        model.chip = .alerts
        model.filters.status = .needsAttention
        #expect(model.filteredItems.count == 2)
        model.filters.status = .resolved
        let allResolved = model.filteredItems.allSatisfy(\.isResolved)
        #expect(allResolved)
        model.filters.sort = .severity
        #expect(model.feedSections.count == 1)
    }

    @Test func emptyAndFilteredEmptyAreDistinct() async {
        let empty = await makeModel(ActivitySnapshot())
        #expect(!empty.hasAnyHistory)
        let model = await makeModel()
        model.filters.categories = [.storage]
        model.filters.dateRange = .today
        model.chip = .network
        #expect(model.hasAnyHistory)
        #expect(model.feedSections.isEmpty)
    }

    @Test func openingAnEventMarksItAndItsAlertRead() async {
        let model = await makeModel()
        let event = model.log.events.first { $0.relatedAlertID != nil }!
        model.open(.event(event.id))
        #expect(model.event(event.id)?.readState == .read)
        let alert = model.alert(event.relatedAlertID!)!
        #expect(alert.readState == .read)
        #expect(alert.resolutionState == .open)
    }

    @Test func searchMatchesTitleDetailAndCategory() async {
        let model = await makeModel()
        model.searchQuery = "battery"
        #expect(!model.searchResults.isEmpty)
        model.searchQuery = "Thermal"
        let hasThermal = model.searchResults.contains { $0.category == .thermal }
        #expect(hasThermal)
        model.searchScope = .sessions
        model.searchQuery = "network"
        let onlySessions = model.searchResults.allSatisfy { if case .session = $0 { true } else { false } }
        #expect(onlySessions)
        model.searchQuery = "zzzz"
        #expect(model.searchResults.isEmpty)
    }

    @Test func clearHistoryStatesExactCountAndKeepsAlerts() async {
        let model = await makeModel()
        let count = model.clearableCount
        let alerts = model.log.alerts.count
        model.requestClearHistory()
        #expect(model.clearState == .confirming)
        await model.confirmClearHistory()
        #expect(model.clearState == .succeeded(count))
        #expect(model.log.alerts.count == alerts)
        #expect(!model.log.sessions.isEmpty)
    }

    @Test func clearHistoryFailureIsShown() async {
        let model = await makeModel(failSaves: true)
        model.requestClearHistory()
        await model.confirmClearHistory()
        #expect(model.clearState == .failed)
        #expect(model.clearableCount > 0)
    }

    @Test func deletingTheOpenItemPopsItsScreen() async {
        let model = await makeModel()
        let event = model.log.events[0]
        model.open(.event(event.id))
        model.delete(.event(event))
        #expect(model.path.isEmpty)
        #expect(model.event(event.id) == nil)
        #expect(model.toast != nil)
    }

    @Test func exportIncludesEveryRecordType() async {
        let model = await makeModel()
        let csv = model.exportCSV()
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 1 + model.log.events.count + model.log.alerts.count + model.log.sessions.count)
        #expect(csv.hasPrefix("type,timestamp"))
    }
}
