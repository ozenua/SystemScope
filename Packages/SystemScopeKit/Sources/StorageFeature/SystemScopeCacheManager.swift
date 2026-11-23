import Foundation

public struct CacheStorageUsage: Sendable, Equatable {
    public let byteCount: Int64
    public let fileCount: Int

    public init(byteCount: Int64, fileCount: Int) {
        self.byteCount = byteCount
        self.fileCount = fileCount
    }
}

public struct CacheClearOutcome: Sendable {
    public let usageBeforeCleanup: CacheStorageUsage
    public let removedUsage: CacheStorageUsage
    public let failures: [String]

    public init(
        usageBeforeCleanup: CacheStorageUsage,
        removedUsage: CacheStorageUsage,
        failures: [String]
    ) {
        self.usageBeforeCleanup = usageBeforeCleanup
        self.removedUsage = removedUsage
        self.failures = failures
    }
}

public struct SystemScopeCacheManager: @unchecked Sendable {
    private let fileManager: FileManager
    private let cacheRoot: URL?
    private let temporaryRoot: URL?

    public init(
        fileManager: FileManager = .default,
        cacheRoot: URL? = nil,
        temporaryRoot: URL? = nil
    ) {
        self.fileManager = fileManager
        self.cacheRoot = cacheRoot
        self.temporaryRoot = temporaryRoot
    }

    public func usage() throws -> CacheStorageUsage {
        try usage(in: cacheDirectories())
    }

    @discardableResult
    public func clear() throws -> CacheClearOutcome {
        let directories = try cacheDirectories()
        let measuredUsage = try usage(in: directories)
        var removedBytes: Int64 = 0
        var removedFiles = 0
        var failures: [String] = []
        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            let rootValues = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
                failures.append("\(directory.lastPathComponent): unsafe cache directory.")
                continue
            }
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                failures.append("\(directory.lastPathComponent): \(error.localizedDescription)")
                continue
            }
            for url in contents {
                do {
                    let entryUsage = try measure(url)
                    try fileManager.removeItem(at: url)
                    removedBytes += entryUsage.bytes
                    removedFiles += entryUsage.files
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        return CacheClearOutcome(
            usageBeforeCleanup: measuredUsage,
            removedUsage: CacheStorageUsage(byteCount: removedBytes, fileCount: removedFiles),
            failures: failures
        )
    }

    private func cacheDirectories() throws -> [URL] {
        guard let cachesRoot = cacheRoot
                ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            throw CacheStorageError.cacheDirectoryUnavailable
        }
        return [
            cachesRoot.appendingPathComponent("SystemScope", isDirectory: true),
            (temporaryRoot ?? fileManager.temporaryDirectory)
                .appendingPathComponent("SystemScopeCache", isDirectory: true),
        ]
    }

    private func measure(_ directory: URL) throws -> (bytes: Int64, files: Int) {
        guard fileManager.fileExists(atPath: directory.path) else { return (0, 0) }
        let entryValues = try directory.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
        ])
        guard entryValues.isSymbolicLink != true else { return (0, 0) }
        if entryValues.isRegularFile == true, let size = entryValues.fileSize {
            return (Int64(size), 1)
        }
        guard entryValues.isDirectory == true else { return (0, 0) }
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: []
        ) else {
            throw CacheStorageError.cacheDirectoryUnreadable
        }

        var byteCount: Int64 = 0
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ])
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize
            else { continue }
            byteCount += Int64(size)
            fileCount += 1
        }
        return (byteCount, fileCount)
    }

    private func usage(in directories: [URL]) throws -> CacheStorageUsage {
        let totals = try directories.reduce(into: (bytes: Int64(0), files: 0)) { totals, directory in
            guard fileManager.fileExists(atPath: directory.path) else { return }
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw CacheStorageError.unsafeCacheDirectory
            }
            let directoryTotals = try measure(directory)
            totals.bytes += directoryTotals.bytes
            totals.files += directoryTotals.files
        }
        return CacheStorageUsage(byteCount: totals.bytes, fileCount: totals.files)
    }
}

public enum CacheStorageError: Error, LocalizedError {
    case cacheDirectoryUnavailable
    case cacheDirectoryUnreadable
    case unsafeCacheDirectory

    public var errorDescription: String? {
        switch self {
        case .cacheDirectoryUnavailable: "SystemScope's cache directory is unavailable."
        case .cacheDirectoryUnreadable: "SystemScope's cache directory could not be read."
        case .unsafeCacheDirectory: "A SystemScope cache path is not a regular cache directory."
        }
    }
}
