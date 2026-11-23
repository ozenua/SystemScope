import Foundation
import Photos

public enum PhotoAccessState: String, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

public enum PhotoMediaType: String, Sendable {
    case image
    case video
}

public struct PhotoMediaItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let mediaType: PhotoMediaType
    public let byteSize: Int64
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let duration: TimeInterval?
    public let creationDate: Date?

    public init(
        id: String,
        mediaType: PhotoMediaType,
        byteSize: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        duration: TimeInterval?,
        creationDate: Date?
    ) {
        self.id = id
        self.mediaType = mediaType
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.creationDate = creationDate
    }

    public var dimensions: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    public var date: Date? { creationDate }
}

public struct PhotoScanResult: Sendable {
    public let items: [PhotoMediaItem]
    public let unreadableAssetCount: Int

    public var largeItems: [PhotoMediaItem] {
        items.filter {
            switch $0.mediaType {
            case .image: $0.byteSize >= 20_000_000
            case .video: $0.byteSize >= 100_000_000
            }
        }
        .sorted { $0.byteSize > $1.byteSize }
    }

    public init(items: [PhotoMediaItem], unreadableAssetCount: Int) {
        self.items = items
        self.unreadableAssetCount = unreadableAssetCount
    }
}

public enum PhotoStorageError: Error, LocalizedError {
    case accessNotGranted
    case assetsChanged
    case assetDataUnavailable
    case deletionFailed

    public var errorDescription: String? {
        switch self {
        case .accessNotGranted: "Photos access is needed to scan or delete selected items."
        case .assetsChanged: "Some selected photos are no longer available. Scan again before deleting."
        case .assetDataUnavailable: "The selected Photos item has no locally available original data."
        case .deletionFailed: "Photos did not complete the deletion."
        }
    }
}

public struct PhotoStorageAnalyzer: Sendable {
    public init() {}

    @MainActor
    public func accessState() -> PhotoAccessState {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    @MainActor
    public func requestAccess() async -> PhotoAccessState {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return Self.map(current) }
        let result = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        return Self.map(result)
    }

    @MainActor
    public func scan(
        progress: @MainActor (Int, Int) -> Void
    ) async throws -> PhotoScanResult {
        guard accessState() == .authorized || accessState() == .limited else {
            throw PhotoStorageError.accessNotGranted
        }

        let fetchedAssets = PHAsset.fetchAssets(with: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchedAssets.count)
        fetchedAssets.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image || asset.mediaType == .video else { return }
            assets.append(asset)
        }

        var items: [PhotoMediaItem] = []
        items.reserveCapacity(assets.count)
        var unreadableCount = 0

        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()
            do {
                let size = try await resourceSize(for: asset)
                let mediaType: PhotoMediaType = asset.mediaType == .video ? .video : .image
                items.append(PhotoMediaItem(
                    id: asset.localIdentifier,
                    mediaType: mediaType,
                    byteSize: size,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: mediaType == .video ? asset.duration : nil,
                    creationDate: asset.creationDate
                ))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                unreadableCount += 1
            }
            progress(index + 1, assets.count)
        }

        return PhotoScanResult(items: items, unreadableAssetCount: unreadableCount)
    }

    @MainActor
    public func deleteAssets(with identifiers: [String]) async throws {
        guard accessState() == .authorized || accessState() == .limited else {
            throw PhotoStorageError.accessNotGranted
        }
        guard !identifiers.isEmpty else { return }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count == identifiers.count else {
            throw PhotoStorageError.assetsChanged
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoStorageError.deletionFailed)
                }
            }
        }
    }

    @MainActor
    private func resourceSize(for asset: PHAsset) async throws -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        let expectedType: PHAssetResourceType = asset.mediaType == .video ? .video : .photo
        guard let resource = resources.first(where: { $0.type == expectedType })
                ?? resources.first(where: {
                    $0.type == .fullSizeVideo || $0.type == .fullSizePhoto
                }) else {
            throw PhotoStorageError.assetsChanged
        }

        let counter = PhotoByteCounter()
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in counter.add(data.count) },
                completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        guard counter.value > 0 else {
                            continuation.resume(throwing: PhotoStorageError.assetDataUnavailable)
                            return
                        }
                        continuation.resume(returning: counter.value)
                    }
                }
            )
        }
    }

    @MainActor
    private static func map(_ status: PHAuthorizationStatus) -> PhotoAccessState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}

private final class PhotoByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int64 = 0

    var value: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func add(_ bytes: Int) {
        lock.lock()
        count += Int64(bytes)
        lock.unlock()
    }
}
