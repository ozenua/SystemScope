import Foundation

/// Loads and saves the activity document. Views never touch this directly; they go
/// through `ActivityLog` (PRD §4, repositories).
public protocol ActivityPersisting: Sendable {
    func load() async throws -> ActivitySnapshot
    func save(_ snapshot: ActivitySnapshot) async throws
}

public enum ActivityPersistenceError: Error, Equatable {
    case unsupportedVersion(Int)
    case unavailable
}

/// JSON document in Application Support, written atomically with file protection
/// that still allows writes after first unlock (PRD §8.1).
public actor FileActivityPersistence: ActivityPersisting {
    private let url: URL

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.url = base.appendingPathComponent("Activity", isDirectory: true).appendingPathComponent("activity.json")
        }
    }

    public func load() throws -> ActivitySnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return ActivitySnapshot() }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var snapshot = try decoder.decode(ActivitySnapshot.self, from: data)
        guard snapshot.version <= ActivitySnapshot.currentVersion else {
            throw ActivityPersistenceError.unsupportedVersion(snapshot.version)
        }
        snapshot.version = ActivitySnapshot.currentVersion
        return snapshot
    }

    public func save(_ snapshot: ActivitySnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// In-memory store for previews, tests and `-UseSampleDevice`. Can be told to fail.
public actor InMemoryActivityPersistence: ActivityPersisting {
    private var snapshot: ActivitySnapshot
    private var failLoads: Bool
    private var failSaves: Bool

    public init(snapshot: ActivitySnapshot = ActivitySnapshot(), failLoads: Bool = false, failSaves: Bool = false) {
        self.snapshot = snapshot
        self.failLoads = failLoads
        self.failSaves = failSaves
    }

    public func load() throws -> ActivitySnapshot {
        if failLoads { throw ActivityPersistenceError.unavailable }
        return snapshot
    }

    public func save(_ snapshot: ActivitySnapshot) throws {
        if failSaves { throw ActivityPersistenceError.unavailable }
        self.snapshot = snapshot
    }

    public func setFailures(loads: Bool, saves: Bool) {
        failLoads = loads
        failSaves = saves
    }

    public var stored: ActivitySnapshot { snapshot }
}
