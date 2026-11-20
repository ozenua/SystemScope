import Foundation

public enum NetworkInterfaceKind: String, Sendable, Codable {
    case wifi
    case cellular
    case wired
    case other
}

/// Current network path plus cumulative interface byte counters.
/// nil fields are unavailable and must be shown as such.
public struct NetworkSnapshot: Sendable, Equatable {
    /// nil when the path could not be read.
    public var isConnected: Bool?
    public var interface: NetworkInterfaceKind?
    /// Low Data Mode or similar.
    public var isConstrained: Bool
    /// Cellular or Personal Hotspot.
    public var isExpensive: Bool
    public var supportsIPv4: Bool?
    public var supportsIPv6: Bool?
    /// Whether a cellular interface is available, used or not. nil when unknown.
    public var isCellularAvailable: Bool?
    /// Wi-Fi network name. Only with Apple's entitlement and a qualifying access condition.
    public var networkName: String?
    public var wifiBSSID: String?
    public var wifiSecurity: String?
    public var cellularTechnology: String?
    /// Carrier names are not exposed by a current non-deprecated public API on iOS.
    public var carrierName: String?
    /// Bytes since the interface counters last reset (usually the last restart).
    public var receivedBytes: UInt64?
    public var sentBytes: UInt64?

    public init(
        isConnected: Bool? = nil,
        interface: NetworkInterfaceKind? = nil,
        isConstrained: Bool = false,
        isExpensive: Bool = false,
        supportsIPv4: Bool? = nil,
        supportsIPv6: Bool? = nil,
        isCellularAvailable: Bool? = nil,
        networkName: String? = nil,
        wifiBSSID: String? = nil,
        wifiSecurity: String? = nil,
        cellularTechnology: String? = nil,
        carrierName: String? = nil,
        receivedBytes: UInt64? = nil,
        sentBytes: UInt64? = nil
    ) {
        self.isConnected = isConnected
        self.interface = interface
        self.isConstrained = isConstrained
        self.isExpensive = isExpensive
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.isCellularAvailable = isCellularAvailable
        self.networkName = networkName
        self.wifiBSSID = wifiBSSID
        self.wifiSecurity = wifiSecurity
        self.cellularTechnology = cellularTechnology
        self.carrierName = carrierName
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

public protocol NetworkInspecting: Sendable {
    func readNetwork() async -> NetworkSnapshot
}

/// Sample values matching the Figma Home screens. Debug and previews only.
public struct SampleNetworkInspector: NetworkInspecting {
    public init() {}

    public func readNetwork() async -> NetworkSnapshot {
        NetworkSnapshot(
            isConnected: true,
            interface: .wifi,
            supportsIPv4: true,
            supportsIPv6: true,
            isCellularAvailable: true,
            networkName: "MyHome_5G",
            wifiBSSID: "02:00:00:00:00:00",
            wifiSecurity: "Secured",
            cellularTechnology: "5G",
            receivedBytes: 24_600_000,
            sentBytes: 4_800_000
        )
    }
}
