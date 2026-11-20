import Foundation
#if WIFI_INFORMATION_ENABLED
import NetworkExtension
#endif

public struct WiFiInformation: Sendable, Equatable {
    public var ssid: String?
    public var bssid: String?
    public var security: String?

    public init(ssid: String? = nil, bssid: String? = nil, security: String? = nil) {
        self.ssid = ssid
        self.bssid = bssid
        self.security = security
    }
}

public protocol WiFiInformationProviding: Sendable {
    func read() async -> WiFiInformation
}

/// Returns Wi-Fi details only for builds that are signed with the required
/// Access Wi-Fi Information entitlement.
public struct WiFiInformationProvider: WiFiInformationProviding {
    public init() {}

    public func read() async -> WiFiInformation {
#if WIFI_INFORMATION_ENABLED
        guard #available(iOS 14.0, *) else { return WiFiInformation() }
        return await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                guard let network else {
                    continuation.resume(returning: WiFiInformation())
                    return
                }
                continuation.resume(returning: WiFiInformation(
                    ssid: network.ssid.isEmpty ? nil : network.ssid,
                    bssid: network.bssid.isEmpty ? nil : network.bssid,
                    security: network.isSecure ? "Secured" : "Open"
                ))
            }
        }
#else
        return WiFiInformation()
#endif
    }
}
