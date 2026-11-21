import Foundation
import Testing
@testable import Core

@MainActor
struct AppPreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsAreFirstRun() {
        let preferences = AppPreferences(defaults: makeDefaults())
        #expect(preferences.hasCompletedOnboarding == false)
        #expect(preferences.deviceDisplayName == "My iPhone")
    }

    @Test func onboardingCompletionPersists() {
        let defaults = makeDefaults()
        AppPreferences(defaults: defaults).hasCompletedOnboarding = true
        #expect(AppPreferences(defaults: defaults).hasCompletedOnboarding)
    }

    @Test func displayNameIsTrimmedAndCapped() {
        let preferences = AppPreferences(defaults: makeDefaults())
        #expect(preferences.setDeviceDisplayName("  Work phone \n"))
        #expect(preferences.deviceDisplayName == "Work phone")

        #expect(preferences.setDeviceDisplayName(String(repeating: "a", count: 60)))
        #expect(preferences.deviceDisplayName.count == 40)
    }

    @Test func detectedDeviceNameSeedsTheLocalDisplayName() {
        let preferences = AppPreferences(
            defaults: makeDefaults(),
            detectedDeviceName: "Ozen's iPhone"
        )
        #expect(preferences.deviceDisplayName == "Ozen's iPhone")
    }

    @Test func explicitNameSurvivesDetectedDeviceName() {
        let defaults = makeDefaults()
        let first = AppPreferences(defaults: defaults, detectedDeviceName: "Ozen's iPhone")
        #expect(first.setDeviceDisplayName("Work phone"))
        let second = AppPreferences(defaults: defaults, detectedDeviceName: "Ozen's iPhone")
        #expect(second.deviceDisplayName == "Work phone")
    }

    @Test func resetRestoresDetectedDeviceName() {
        let preferences = AppPreferences(
            defaults: makeDefaults(),
            detectedDeviceName: "Ozen's iPhone"
        )
        #expect(preferences.setDeviceDisplayName("Work phone"))
        preferences.resetDeviceProfile()
        #expect(preferences.deviceDisplayName == "Ozen's iPhone")
    }

    @Test func emptyDisplayNameIsRejected() {
        let preferences = AppPreferences(defaults: makeDefaults())
        #expect(preferences.setDeviceDisplayName("   ") == false)
        #expect(preferences.deviceDisplayName == "My iPhone")
    }

    @Test func themePreferencePersistsAndRestores() {
        let defaults = makeDefaults()
        let preferences = AppPreferences(defaults: defaults)
        preferences.settings.theme = .dark

        #expect(AppPreferences(defaults: defaults).settings.theme == .dark)

        preferences.resetPreferences()
        #expect(preferences.settings.theme == .light)
    }
}

@MainActor
@Test func firstRegisteredIsStoredOnce() {
    let defaults = UserDefaults(suiteName: "FirstRegistered-\(UUID().uuidString)")!
    let first = Date(timeIntervalSince1970: 1_000)
    #expect(AppPreferences(defaults: defaults, now: first).firstRegistered == first)
    #expect(AppPreferences(defaults: defaults, now: .now).firstRegistered == first)
}
