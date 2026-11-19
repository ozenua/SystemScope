import Foundation
import Observation
import UIKit

/// One battery reading. `level` is a whole percentage, or nil when iOS does not
/// report one; it is never substituted with zero.
public struct BatterySnapshot: Sendable, Equatable {
    public let level: Int?
    /// nil when iOS reports the state as unknown.
    public let state: BatteryChargeState?
    public let isLowPowerModeEnabled: Bool
    public let observedAt: Date

    public var isAvailable: Bool { level != nil }

    public init(level: Int?, state: BatteryChargeState?, isLowPowerModeEnabled: Bool = false, observedAt: Date = .now) {
        self.level = level
        self.state = state
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.observedAt = observedAt
    }

    /// Maps raw UIDevice values. A negative level means "unknown".
    public init(rawLevel: Float, rawState: UIDevice.BatteryState, isLowPowerModeEnabled: Bool = false, observedAt: Date = .now) {
        let state: BatteryChargeState? = switch rawState {
        case .unplugged: .unplugged
        case .charging: .charging
        case .full: .full
        case .unknown: nil
        @unknown default: nil
        }
        self.init(
            level: rawLevel >= 0 ? Int((rawLevel * 100).rounded()) : nil,
            state: state,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            observedAt: observedAt
        )
    }
}

@MainActor
public protocol BatteryMonitoring: AnyObject {
    var snapshot: BatterySnapshot { get }
    /// Begins observing changes. Safe to call repeatedly.
    func start()
    func stop()
}

/// Battery level and charging state from UIDevice (scope: this iPhone). Updates arrive
/// through UIKit's change notifications rather than polling; iOS posts level changes
/// no more than about once a minute. Needs no permission or entitlement.
@MainActor
@Observable
public final class BatteryMonitor: BatteryMonitoring {
    public private(set) var snapshot: BatterySnapshot
    @ObservationIgnored private var observation: Task<Void, Never>?

    public init() {
        snapshot = Self.readCurrent()
    }

    deinit {
        observation?.cancel()
    }

    public func start() {
        guard observation == nil else { return }
        snapshot = Self.readCurrent()
        observation = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                let names = [
                    UIDevice.batteryLevelDidChangeNotification,
                    UIDevice.batteryStateDidChangeNotification,
                    Notification.Name.NSProcessInfoPowerStateDidChange,
                ]
                for name in names {
                    group.addTask {
                        for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
                            await self?.refresh()
                        }
                    }
                }
            }
        }
    }

    /// Cancels the notification observers.
    public func stop() {
        observation?.cancel()
        observation = nil
    }

    private func refresh() {
        snapshot = Self.readCurrent()
    }

    /// Enables battery monitoring and reads the current values once.
    public static func readCurrent() -> BatterySnapshot {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return BatterySnapshot(
            rawLevel: device.batteryLevel,
            rawState: device.batteryState,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}

/// Fixed sample reading matching the Figma screens. Debug, previews and tests only.
@MainActor
public final class SampleBatteryMonitor: BatteryMonitoring {
    public let snapshot: BatterySnapshot

    public init(level: Int? = 82, state: BatteryChargeState? = .unplugged) {
        snapshot = BatterySnapshot(level: level, state: state)
    }

    public func start() {}
    public func stop() {}
}
