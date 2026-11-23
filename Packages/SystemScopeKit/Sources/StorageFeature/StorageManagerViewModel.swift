import Core
import DeviceInfo
import Foundation
import Observation

@MainActor
@Observable
public final class StorageManagerViewModel {
    public private(set) var storage: StorageInformation?
    public private(set) var cacheUsage: CacheStorageUsage?
    public private(set) var photoAccess: PhotoAccessState
    public private(set) var largeMedia: [PhotoMediaItem] = []
    public private(set) var photoMatches: [PhotoMatch] = []
    public private(set) var photoUnreadableCount = 0
    public private(set) var photoUncomparableCount = 0
    public private(set) var photoScanProgress: (completed: Int, total: Int)?
    public private(set) var isScanningPhotos = false
    public private(set) var documentScan: DocumentScanResult?
    public private(set) var isScanningDocuments = false
    public private(set) var isRefreshingStorage = false
    public private(set) var storageRefreshFailed = false
    public private(set) var errorMessage: String?
    public private(set) var statusMessage: String?
    public var selectedPhotoIDs = Set<String>()
    public var selectedDocumentIDs = Set<String>()

    @ObservationIgnored private let cleanupCoordinator: StorageCleanupCoordinator
    @ObservationIgnored private let photoAnalyzer: PhotoStorageAnalyzer
    @ObservationIgnored private let duplicateDetector: DuplicateMediaDetector
    @ObservationIgnored private let documentAnalyzer: DocumentStorageAnalyzer

    public init(
        cleanupCoordinator: StorageCleanupCoordinator? = nil,
        photoAnalyzer: PhotoStorageAnalyzer = .init(),
        duplicateDetector: DuplicateMediaDetector = .init(),
        documentAnalyzer: DocumentStorageAnalyzer = .init()
    ) {
        self.photoAnalyzer = photoAnalyzer
        self.duplicateDetector = duplicateDetector
        self.documentAnalyzer = documentAnalyzer
        self.cleanupCoordinator = cleanupCoordinator ?? StorageCleanupCoordinator(
            photoAnalyzer: photoAnalyzer,
            documentAnalyzer: documentAnalyzer
        )
        self.photoAccess = photoAnalyzer.accessState()
    }

    public var selectedPhotoItems: [PhotoMediaItem] {
        let allItems = Dictionary(
            (largeMedia + photoMatches.flatMap { [$0.first, $0.second] }).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return selectedPhotoIDs.compactMap { allItems[$0] }.sorted { $0.byteSize > $1.byteSize }
    }

    public var documentItems: [DocumentStorageItem] {
        guard let documentScan else { return [] }
        let allItems = Dictionary(
            (documentScan.selectedLocations + documentScan.files).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return selectedDocumentIDs.compactMap { allItems[$0] }.sorted { $0.byteSize > $1.byteSize }
    }

    public func load() {
        refreshStorage()
        refreshCacheUsage()
        photoAccess = photoAnalyzer.accessState()
    }

    public func refreshStorage() {
        isRefreshingStorage = true
        defer { isRefreshingStorage = false }
        do {
            storage = try cleanupCoordinator.refreshStorage()
            storageRefreshFailed = false
        } catch {
            storageRefreshFailed = true
            errorMessage = error.localizedDescription
        }
    }

    public func scanPhotos() async {
        errorMessage = nil
        statusMessage = nil
        photoAccess = await photoAnalyzer.requestAccess()
        guard photoAccess == .authorized || photoAccess == .limited else { return }

        isScanningPhotos = true
        photoScanProgress = nil
        defer {
            isScanningPhotos = false
            photoScanProgress = nil
        }

        do {
            let result = try await photoAnalyzer.scan { [weak self] completed, total in
                self?.photoScanProgress = (completed, total)
            }
            largeMedia = result.largeItems
            photoUnreadableCount = result.unreadableAssetCount
            let comparison = await duplicateDetector.findMatches(in: result.items)
            photoMatches = comparison.matches
            photoUncomparableCount = comparison.uncomparableImageCount
            selectedPhotoIDs = []
            if result.unreadableAssetCount > 0 || comparison.uncomparableImageCount > 0 {
                statusMessage = "Some media could not be measured. Results may be incomplete."
            } else {
                statusMessage = "Photo scan complete."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func togglePhotoSelection(_ item: PhotoMediaItem) {
        if selectedPhotoIDs.contains(item.id) {
            selectedPhotoIDs.remove(item.id)
        } else {
            selectedPhotoIDs.insert(item.id)
        }
    }

    public func deleteSelectedPhotos() async {
        let items = selectedPhotoItems
        guard !items.isEmpty else { return }
        errorMessage = nil
        do {
            let result = try await cleanupCoordinator.deletePhotos(with: items.map(\.id))
            applyStorageResult(result)
            let deletedIDs = Set(items.map(\.id))
            largeMedia.removeAll { deletedIDs.contains($0.id) }
            photoMatches.removeAll {
                deletedIDs.contains($0.first.id) || deletedIDs.contains($0.second.id)
            }
            selectedPhotoIDs = []
            statusMessage = "Selected items were deleted from Photos. iOS may keep them in Recently Deleted, so available space may not increase yet."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func analyzeDocuments(at urls: [URL]) async {
        guard !urls.isEmpty else { return }
        errorMessage = nil
        statusMessage = nil
        isScanningDocuments = true
        defer { isScanningDocuments = false }
        do {
            let analyzer = documentAnalyzer
            documentScan = try await Task.detached(priority: .userInitiated) {
                try analyzer.scan(urls: urls)
            }.value
            selectedDocumentIDs = []
            if let count = documentScan?.unreadableFileCount, count > 0 {
                statusMessage = "Some files could not be read. Results may be incomplete."
            } else {
                statusMessage = "File scan complete."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleDocumentSelection(_ item: DocumentStorageItem) {
        if selectedDocumentIDs.contains(item.id) {
            selectedDocumentIDs.remove(item.id)
        } else {
            selectedDocumentIDs.insert(item.id)
        }
    }

    public func deleteSelectedDocuments() async {
        let items = documentItems
        guard !items.isEmpty else { return }
        errorMessage = nil
        do {
            let coordinator = cleanupCoordinator
            let result = try await Task.detached(priority: .userInitiated) {
                try coordinator.deleteDocuments(items)
            }.value
            applyStorageResult(result)
            documentScan = nil
            selectedDocumentIDs = []
            var failures = result.operationFailures
            if let storageError = result.storageRefreshError {
                failures.append("Storage could not be refreshed: \(storageError)")
            }
            if result.operationFailures.isEmpty {
                statusMessage = "Deleted \(result.deletedItemCount) selected item(s)."
            } else {
                statusMessage = "Deleted \(result.deletedItemCount) item(s); \(result.operationFailures.count) could not be deleted."
            }
            if !failures.isEmpty {
                errorMessage = failures.joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshCacheUsage() {
        do {
            cacheUsage = try cleanupCoordinator.cacheUsage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func clearCache() {
        errorMessage = nil
        do {
            let result = try cleanupCoordinator.clearSystemScopeCache()
            storage = result.storageAfterCleanup ?? storage
            storageRefreshFailed = result.storageRefreshError != nil
            statusMessage = "Removed \(ByteFormatting.storage(result.removedUsage.byteCount)) of SystemScope cache."
            var failures = result.operationFailures
            do {
                cacheUsage = try cleanupCoordinator.cacheUsage()
            } catch {
                failures.append("Remaining cache size could not be refreshed: \(error.localizedDescription)")
            }
            if let refreshError = result.storageRefreshError {
                failures.append("Storage could not be refreshed: \(refreshError)")
            }
            if !failures.isEmpty {
                errorMessage = failures.joined(separator: "\n")
            }
        } catch {
            let cleanupError = error.localizedDescription
            refreshStorage()
            refreshCacheUsage()
            errorMessage = cleanupError
        }
    }

    private func applyStorageResult(_ result: StorageCleanupResult) {
        if let updatedStorage = result.storageAfterCleanup {
            storage = updatedStorage
            storageRefreshFailed = false
        } else {
            storageRefreshFailed = true
            if let message = result.storageRefreshError {
                errorMessage = "The selected items were processed, but storage could not be refreshed: \(message)"
            }
        }
    }
}
