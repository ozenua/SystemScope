import DeviceInfo
import Foundation
import Network

public struct ConnectionSnapshot: Sendable, Equatable {
    public var isConnected: Bool
    public var interface: NetworkInterfaceKind?
    /// Cellular or personal hotspot: the test will use paid data.
    public var isExpensive: Bool
    /// Low Data Mode.
    public var isConstrained: Bool

    public init(isConnected: Bool, interface: NetworkInterfaceKind?, isExpensive: Bool = false, isConstrained: Bool = false) {
        self.isConnected = isConnected
        self.interface = interface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

public protocol NetworkPathProviding: Sendable {
    /// nil when no path update arrives in time.
    func current() async -> ConnectionSnapshot?
    /// Every path update, starting with the current one.
    func changes() -> AsyncStream<ConnectionSnapshot>
}

/// Connection type from NWPathMonitor. Needs no permission; a satisfied path is not
/// proof of internet access, which only a test-server request confirms.
public struct NetworkPathMonitor: NetworkPathProviding {
    public init() {}

    public func changes() -> AsyncStream<ConnectionSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                for await path in NWPathMonitor() {
                    let interface: NetworkInterfaceKind? =
                        if path.status != .satisfied { nil }
                        else if path.usesInterfaceType(.wifi) { .wifi }
                        else if path.usesInterfaceType(.cellular) { .cellular }
                        else if path.usesInterfaceType(.wiredEthernet) { .wired }
                        else { .other }
                    continuation.yield(ConnectionSnapshot(
                        isConnected: path.status == .satisfied,
                        interface: interface,
                        isExpensive: path.isExpensive,
                        isConstrained: path.isConstrained
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
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
}
