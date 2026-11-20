import Darwin
import Foundation

public struct CPUInformation: Sendable, Equatable {
    public var hardwareIdentifier: String?
    public var architecture: String?
    public var physicalCores: Int?
    public var logicalCores: Int?
    public var performanceCores: Int?
    public var efficiencyCores: Int?
    public var l1DataCacheBytes: Int?
    public var l1InstructionCacheBytes: Int?
    public var l2CacheBytes: Int?
    public var l3CacheBytes: Int?

    public init(
        hardwareIdentifier: String? = nil,
        architecture: String? = nil,
        physicalCores: Int? = nil,
        logicalCores: Int? = nil,
        performanceCores: Int? = nil,
        efficiencyCores: Int? = nil,
        l1DataCacheBytes: Int? = nil,
        l1InstructionCacheBytes: Int? = nil,
        l2CacheBytes: Int? = nil,
        l3CacheBytes: Int? = nil
    ) {
        self.hardwareIdentifier = hardwareIdentifier
        self.architecture = architecture
        self.physicalCores = physicalCores
        self.logicalCores = logicalCores
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
        self.l1DataCacheBytes = l1DataCacheBytes
        self.l1InstructionCacheBytes = l1InstructionCacheBytes
        self.l2CacheBytes = l2CacheBytes
        self.l3CacheBytes = l3CacheBytes
    }
}

public struct CPUInformationProvider: Sendable {
    public init() {}

    public func read() -> CPUInformation {
        let clusters = discoveredClusters()
        return CPUInformation(
            hardwareIdentifier: readString("hw.machine"),
            architecture: architecture(),
            physicalCores: readPositiveInt("hw.physicalcpu"),
            logicalCores: readPositiveInt("hw.logicalcpu"),
            performanceCores: clusters.first(where: { $0.kind == .performance })?.count,
            efficiencyCores: clusters.first(where: { $0.kind == .efficiency })?.count,
            l1DataCacheBytes: readPositiveInt("hw.l1dcachesize"),
            l1InstructionCacheBytes: readPositiveInt("hw.l1icachesize"),
            l2CacheBytes: readPositiveInt("hw.l2cachesize"),
            l3CacheBytes: readPositiveInt("hw.l3cachesize")
        )
    }

    private enum ClusterKind {
        case performance
        case efficiency
        case unknown
    }

    private struct Cluster {
        let kind: ClusterKind
        let count: Int
    }

    private func discoveredClusters() -> [Cluster] {
        (0..<32).compactMap { level in
            guard let count = readPositiveInt("hw.perflevel\(level).physicalcpu") else { return nil }
            let name = readString("hw.perflevel\(level).name")?.lowercased()
            let kind: ClusterKind
            if name?.contains("performance") == true {
                kind = .performance
            } else if name?.contains("efficiency") == true {
                kind = .efficiency
            } else {
                kind = .unknown
            }
            return Cluster(kind: kind, count: count)
        }
    }

    private func readPositiveInt(_ key: String) -> Int? {
        var value = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(key, &value, &size, nil, 0) == 0, value > 0 else { return nil }
        return value
    }

    private func readString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.map { UInt8(bitPattern: $0) }
        let value = String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func architecture() -> String? {
        var info = utsname()
        guard uname(&info) == 0 else { return nil }
        let machine = info.machine
        return withUnsafeBytes(of: machine) { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
