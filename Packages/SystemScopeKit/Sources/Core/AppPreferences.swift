import Foundation
import Observation

/// Typed interface over UserDefaults (PRD §3.1). Views never touch UserDefaults directly.
@MainActor
@Observable
public final class AppPreferences {
    private enum Key {
        static let hasCompletedOnboarding = "onboarding.completed"
        static let deviceDisplayName = "device.displayName"
        static let firstRegistered = "device.firstRegistered"
        static let settings = "settings.v1"
    }

    public static let defaultDeviceDisplayName = "My iPhone"
    public static let deviceDisplayNameLimit = 40

    @ObservationIgnored private let defaults: UserDefaults

    /// ONB-01: first-run onboarding is shown once.
    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// PRD §2.3: a local display name, initially seeded from the iOS device name.
    public private(set) var deviceDisplayName: String

    /// Settings from the Settings tab. Saved whenever they change.
    public var settings: UserSettings {
        didSet { saveSettings() }
    }

    /// When SystemScope first recorded this device: its first launch. Stored locally only.
    public let firstRegistered: Date

    private let detectedDeviceDisplayName: String

    public init(
        defaults: UserDefaults = .standard,
        now: Date = .now,
        detectedDeviceName: String? = nil
    ) {
        self.defaults = defaults
        let detectedName = detectedDeviceName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        detectedDeviceDisplayName = detectedName.flatMap { name in
            name.isEmpty ? nil : String(name.prefix(Self.deviceDisplayNameLimit))
        } ?? Self.defaultDeviceDisplayName
        if let stored = defaults.object(forKey: Key.firstRegistered) as? Date {
            firstRegistered = stored
        } else {
            firstRegistered = now
            defaults.set(now, forKey: Key.firstRegistered)
        }
        settings = defaults.data(forKey: Key.settings)
            .flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) } ?? UserSettings()
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        deviceDisplayName = defaults.string(forKey: Key.deviceDisplayName) ?? detectedDeviceDisplayName
    }

    /// Returns false (and changes nothing) when the name is empty after trimming.
    @discardableResult
    public func setDeviceDisplayName(_ proposed: String) -> Bool {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        deviceDisplayName = String(trimmed.prefix(Self.deviceDisplayNameLimit))
        defaults.set(deviceDisplayName, forKey: Key.deviceDisplayName)
        return true
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Key.settings)
        }
    }

    /// SET-14: preferences only. Keeps the device name, onboarding state and history.
    public func resetPreferences() {
        settings = UserSettings()
    }

    /// Restores the detected iPhone name (SET-02 "Reset local device profile").
    public func resetDeviceProfile() {
        deviceDisplayName = detectedDeviceDisplayName
        defaults.removeObject(forKey: Key.deviceDisplayName)
    }
}
