import Foundation
import Network

public struct ConnectionSnapshot: Sendable, Equatable {
    public var isConnected: Bool
    public var interface: NetworkInterfaceKind?
    public var isExpensive: Bool
    public var isConstrained: Bool
    public var supportsIPv4: Bool
    public var supportsIPv6: Bool
    public var isCellularAvailable: Bool

    public init(
        isConnected: Bool,
        interface: NetworkInterfaceKind?,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        supportsIPv4: Bool = false,
        supportsIPv6: Bool = false,
        isCellularAvailable: Bool = false
    ) {
        self.isConnected = isConnected
        self.interface = interface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.isCellularAvailable = isCellularAvailable
    }
}

public protocol NetworkPathProviding: Sendable {
    func current() async -> ConnectionSnapshot?
    func changes() -> AsyncStream<ConnectionSnapshot>
}

/// Detects connection state and interface type without requiring permissions.
public struct NetworkPathMonitor: NetworkPathProviding {
    public init() {}

    public func changes() -> AsyncStream<ConnectionSnapshot> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.systemscope.network-path")
            monitor.pathUpdateHandler = { path in
                continuation.yield(Self.snapshot(for: path))
            }
            monitor.start(queue: queue)
            continuation.onTermination = { _ in monitor.cancel() }
        }
    }

    public func current() async -> ConnectionSnapshot? {
        await withTaskGroup(of: ConnectionSnapshot?.self) { group in
            group.addTask {
                for await snapshot in changes() { return snapshot }
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

    private static func snapshot(for path: NWPath) -> ConnectionSnapshot {
        let interface: NetworkInterfaceKind? =
            if path.status != .satisfied { nil }
            else if path.usesInterfaceType(.wifi) { .wifi }
            else if path.usesInterfaceType(.cellular) { .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { .wired }
            else { .other }
        return ConnectionSnapshot(
            isConnected: path.status == .satisfied,
            interface: interface,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            isCellularAvailable: path.availableInterfaces.contains { $0.type == .cellular }
        )
    }
}
