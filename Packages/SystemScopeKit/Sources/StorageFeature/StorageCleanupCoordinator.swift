import DeviceInfo
import Foundation

public struct StorageCleanupResult: Sendable {
    public let storageAfterCleanup: StorageInformation?
    public let storageRefreshError: String?
    public let deletedItemCount: Int
    public let operationFailures: [String]

    public init(
        storageAfterCleanup: StorageInformation?,
        storageRefreshError: String?,
        deletedItemCount: Int = 0,
        operationFailures: [String] = []
    ) {
        self.storageAfterCleanup = storageAfterCleanup
        self.storageRefreshError = storageRefreshError
        self.deletedItemCount = deletedItemCount
        self.operationFailures = operationFailures
    }
}

public struct CacheCleanupResult: Sendable {
    public let usageBeforeCleanup: CacheStorageUsage
    public let removedUsage: CacheStorageUsage
    public let operationFailures: [String]
    public let storageAfterCleanup: StorageInformation?
    public let storageRefreshError: String?

    public init(
        usageBeforeCleanup: CacheStorageUsage,
        removedUsage: CacheStorageUsage,
        operationFailures: [String],
        storageAfterCleanup: StorageInformation?,
        storageRefreshError: String?
    ) {
        self.usageBeforeCleanup = usageBeforeCleanup
        self.removedUsage = removedUsage
        self.operationFailures = operationFailures
        self.storageAfterCleanup = storageAfterCleanup
        self.storageRefreshError = storageRefreshError
    }
}

public struct StorageCleanupCoordinator: Sendable {
    private let storageProvider: StorageInformationProvider
    private let photoAnalyzer: PhotoStorageAnalyzer
    private let documentAnalyzer: DocumentStorageAnalyzer
    private let cacheManager: SystemScopeCacheManager

    public init(
        storageProvider: StorageInformationProvider = .init(),
        photoAnalyzer: PhotoStorageAnalyzer = .init(),
        documentAnalyzer: DocumentStorageAnalyzer = .init(),
        cacheManager: SystemScopeCacheManager = .init()
    ) {
        self.storageProvider = storageProvider
        self.photoAnalyzer = photoAnalyzer
        self.documentAnalyzer = documentAnalyzer
        self.cacheManager = cacheManager
    }

    public func refreshStorage() throws -> StorageInformation {
        try storageProvider.read()
    }

    @MainActor
    public func deletePhotos(with identifiers: [String]) async throws -> StorageCleanupResult {
        try await photoAnalyzer.deleteAssets(with: identifiers)
        return refreshAfterCleanup(deletedItemCount: identifiers.count)
    }

    public func deleteDocuments(_ items: [DocumentStorageItem]) throws -> StorageCleanupResult {
        let deletion = try documentAnalyzer.delete(items)
        return refreshAfterCleanup(
            deletedItemCount: deletion.deletedItemCount,
            operationFailures: deletion.failures
        )
    }

    public func clearSystemScopeCache() throws -> CacheCleanupResult {
        let outcome = try cacheManager.clear()
        let refreshed = refreshAfterCleanup()
        return CacheCleanupResult(
            usageBeforeCleanup: outcome.usageBeforeCleanup,
            removedUsage: outcome.removedUsage,
            operationFailures: outcome.failures,
            storageAfterCleanup: refreshed.storageAfterCleanup,
            storageRefreshError: refreshed.storageRefreshError
        )
    }

    public func cacheUsage() throws -> CacheStorageUsage {
        try cacheManager.usage()
    }

    private func refreshAfterCleanup(
        deletedItemCount: Int = 0,
        operationFailures: [String] = []
    ) -> StorageCleanupResult {
        do {
            return StorageCleanupResult(
                storageAfterCleanup: try storageProvider.read(),
                storageRefreshError: nil,
                deletedItemCount: deletedItemCount,
                operationFailures: operationFailures
            )
        } catch {
            return StorageCleanupResult(
                storageAfterCleanup: nil,
                storageRefreshError: error.localizedDescription,
                deletedItemCount: deletedItemCount,
                operationFailures: operationFailures
            )
        }
    }
}
