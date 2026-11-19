import Foundation

/// Local history of completed tests, newest first. Uploaded payloads are never stored.
public protocol SpeedTestHistoryStoring: Sendable {
    func all() async -> [InternetSpeedTestResult]
    func save(_ result: InternetSpeedTestResult) async throws
    func delete(id: InternetSpeedTestResult.ID) async throws
}

/// History kept in memory only. For tests and previews.
public actor InMemorySpeedTestRepository: SpeedTestHistoryStoring {
    private var results: [InternetSpeedTestResult]

    public init(results: [InternetSpeedTestResult] = []) {
        self.results = results.sorted { $0.timestamp > $1.timestamp }
    }

    public func all() -> [InternetSpeedTestResult] { results }

    public func save(_ result: InternetSpeedTestResult) {
        results.insert(result, at: 0)
    }

    public func delete(id: InternetSpeedTestResult.ID) {
        results.removeAll { $0.id == id }
    }
}

/// History as one versioned JSON file in Application Support, on device only.
///
/// A stand-in until the shared Persistence module (SwiftData, PRD §3.1) exists; the
/// protocol above is the seam for swapping it.
public actor FileSpeedTestRepository: SpeedTestHistoryStoring {
    private struct Document: Codable {
        var schemaVersion = 1
        var results: [InternetSpeedTestResult]
    }

    public static let maximumResults = 200

    private let fileURL: URL
    private var cache: [InternetSpeedTestResult]?

    public init(fileURL: URL = FileSpeedTestRepository.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "SpeedTest/history.json")
    }

    public func all() -> [InternetSpeedTestResult] {
        if let cache { return cache }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? decoder.decode(Document.self, from: $0) }?
            .results ?? []
        cache = loaded
        return loaded
    }

    public func save(_ result: InternetSpeedTestResult) throws {
        var results = all()
        results.insert(result, at: 0)
        try write(Array(results.prefix(Self.maximumResults)))
    }

    public func delete(id: InternetSpeedTestResult.ID) throws {
        try write(all().filter { $0.id != id })
    }

    private func write(_ results: [InternetSpeedTestResult]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Document(results: results))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache = results
    }
}
