import Darwin
import Foundation
import Network

/// Path state from NWPathMonitor and cumulative byte counters from getifaddrs.
///
/// PROVISIONAL (PRD §7.1.2, §7.2): the interface classification below (en0 = Wi-Fi,
/// pdp_ip* = cellular) and the 32-bit `if_data` counters have not been through the
/// physical-device feasibility gate. Tunnel, loopback and other interfaces are never
/// summed. The Wi-Fi name is not read: it needs the Access Wi-Fi Information entitlement.
public struct SystemNetworkInspector: NetworkInspecting {
    public init() {}

    public func readNetwork() async -> NetworkSnapshot {
        guard let path = await Self.currentPath() else { return NetworkSnapshot() }
        var snapshot = NetworkSnapshot(
            isConnected: path.isSatisfied,
            interface: path.isSatisfied ? path.kind : nil,
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            isCellularAvailable: path.isCellularAvailable
        )
        if let kind = snapshot.interface, let counters = Self.counters(for: kind) {
            snapshot.receivedBytes = counters.received
            snapshot.sentBytes = counters.sent
        }
        return snapshot
    }

    struct PathInfo: Sendable {
        var isSatisfied: Bool
        var kind: NetworkInterfaceKind
        var isConstrained: Bool
        var isExpensive: Bool
        var supportsIPv4: Bool
        var supportsIPv6: Bool
        var isCellularAvailable: Bool
    }

    /// nil when no path update arrived in time.
    static func currentPath() async -> PathInfo? {
        await withTaskGroup(of: PathInfo?.self) { group in
            group.addTask {
                for await path in NWPathMonitor() {
                    let kind: NetworkInterfaceKind =
                        if path.usesInterfaceType(.wifi) { .wifi }
                        else if path.usesInterfaceType(.cellular) { .cellular }
                        else if path.usesInterfaceType(.wiredEthernet) { .wired }
                        else { .other }
                    return PathInfo(
                        isSatisfied: path.status == .satisfied,
                        kind: kind,
                        isConstrained: path.isConstrained,
                        isExpensive: path.isExpensive,
                        supportsIPv4: path.supportsIPv4,
                        supportsIPv6: path.supportsIPv6,
                        isCellularAvailable: path.availableInterfaces.contains { $0.type == .cellular }
                    )
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
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
