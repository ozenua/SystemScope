import Darwin
import Foundation

/// Path state, optional Wi-Fi/cellular details and cumulative byte counters.
///
/// Interface counters remain limited to en0 and pdp_ip*; tunnel, loopback and other
/// interfaces are never summed.
public struct SystemNetworkInspector: NetworkInspecting {
    public init() {}

    public func readNetwork() async -> NetworkSnapshot {
        guard let path = await NetworkPathMonitor().current() else { return NetworkSnapshot() }
        async let wifi = WiFiInformationProvider().read()
        async let cellular = CellularInformationProvider().read()
        let wifiInfo = await wifi
        let cellularInfo = await cellular
        var snapshot = NetworkSnapshot(
            isConnected: path.isConnected,
            interface: path.interface,
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            isCellularAvailable: path.isCellularAvailable,
            networkName: wifiInfo.ssid,
            wifiBSSID: wifiInfo.bssid,
            wifiSecurity: wifiInfo.security,
            cellularTechnology: cellularInfo.technology,
            carrierName: cellularInfo.carrierName
        )
        if let kind = snapshot.interface, let counters = Self.counters(for: kind) {
            snapshot.receivedBytes = counters.received
            snapshot.sentBytes = counters.sent
        }
        return snapshot
    }

    static func counters(for kind: NetworkInterfaceKind) -> (received: UInt64, sent: UInt64)? {
        let matches: (String) -> Bool
        switch kind {
        case .wifi: matches = { $0 == "en0" }
        case .cellular: matches = { $0.hasPrefix("pdp_ip") }
        case .wired, .other: return nil
        }

        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var found = false
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            // Only the AF_LINK row carries if_data; this also de-duplicates address families.
            guard let address = entry.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  let data = entry.ifa_data,
                  matches(String(cString: entry.ifa_name)) else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(stats.ifi_ibytes)
            sent += UInt64(stats.ifi_obytes)
            found = true
        }
        return found ? (received, sent) : nil
    }
}
