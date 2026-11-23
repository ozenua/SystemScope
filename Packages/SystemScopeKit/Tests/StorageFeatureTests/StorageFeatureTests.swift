import DeviceInfo
import Foundation
import StorageFeature
import Testing

struct StorageInformationTests {
    @Test func derivesUsedCapacityAndUtilization() {
        let storage = StorageInformation(totalBytes: 500, availableBytes: 125)
        #expect(storage.usedBytes == 375)
        #expect(storage.utilization == 0.75)
    }

    @Test func utilizationIsUnavailableWhenTotalIsZero() {
        let storage = StorageInformation(totalBytes: 0, availableBytes: 0)
        #expect(storage.utilization == nil)
    }
}

struct CacheManagerTests {
    @Test func clearRemovesOnlyDesignatedCacheFiles() throws {
        let fileManager = FileManager.default
        let testRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SystemScopeCacheTests-\(UUID().uuidString)", isDirectory: true)
        let cacheRoot = testRoot.appendingPathComponent("Caches", isDirectory: true)
        let temporaryRoot = testRoot.appendingPathComponent("Temporary", isDirectory: true)
        let unrelated = testRoot.appendingPathComponent("Documents", isDirectory: true)
        let cacheDirectory = cacheRoot.appendingPathComponent("SystemScope", isDirectory: true)
        let tempCacheDirectory = temporaryRoot.appendingPathComponent("SystemScopeCache", isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempCacheDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unrelated, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: testRoot) }

        let cacheFile = cacheDirectory.appendingPathComponent("image.cache")
        let tempFile = tempCacheDirectory.appendingPathComponent("download.tmp")
        let userFile = unrelated.appendingPathComponent("keep.txt")
        try Data(repeating: 1, count: 100).write(to: cacheFile)
        try Data(repeating: 2, count: 50).write(to: tempFile)
        try Data(repeating: 3, count: 25).write(to: userFile)

        let manager = SystemScopeCacheManager(
            fileManager: fileManager,
            cacheRoot: cacheRoot,
            temporaryRoot: temporaryRoot
        )
        let outcome = try manager.clear()

        #expect(outcome.usageBeforeCleanup.byteCount == 150)
        #expect(outcome.removedUsage.byteCount == 150)
        #expect(outcome.removedUsage.fileCount == 2)
        #expect(outcome.failures.isEmpty)
        #expect(!fileManager.fileExists(atPath: cacheFile.path))
        #expect(!fileManager.fileExists(atPath: tempFile.path))
        #expect(fileManager.fileExists(atPath: userFile.path))
    }
}

struct DocumentStorageAnalyzerTests {
    @Test func scansFolderSizesAndHashesThenDeletesOnlySelectedFile() throws {
        let fileManager = FileManager.default
        let testRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SystemScopeDocumentTests-\(UUID().uuidString)", isDirectory: true)
        let selectedFolder = testRoot.appendingPathComponent("Selected", isDirectory: true)
        let unrelatedFolder = testRoot.appendingPathComponent("Unrelated", isDirectory: true)
        try fileManager.createDirectory(at: selectedFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unrelatedFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: testRoot) }

        let first = selectedFolder.appendingPathComponent("first.txt")
        let duplicate = selectedFolder.appendingPathComponent("duplicate.txt")
        let unrelated = unrelatedFolder.appendingPathComponent("keep.txt")
        let contents = Data("same file contents".utf8)
        try contents.write(to: first)
        try contents.write(to: duplicate)
        try Data("keep".utf8).write(to: unrelated)

        let analyzer = DocumentStorageAnalyzer(fileManager: fileManager)
        let result = try analyzer.scan(urls: [selectedFolder])

        #expect(result.selectedLocations.count == 1)
        #expect(result.selectedLocations.first?.byteSize == Int64(contents.count * 2))
        #expect(result.selectedLocations.first?.fileCount == 2)
        #expect(result.duplicateGroups.count == 1)
        #expect(result.duplicateGroups.first?.potentialSpaceBytes == Int64(contents.count))
        #expect(result.files.count == 2)

        var folderDeletionRejected = false
        do {
            _ = try analyzer.delete(result.selectedLocations)
        } catch DocumentStorageError.folderDeletionNotSupported {
            folderDeletionRejected = true
        }
        #expect(folderDeletionRejected)
        #expect(fileManager.fileExists(atPath: first.path))
        #expect(fileManager.fileExists(atPath: duplicate.path))

        let deletion = try analyzer.delete([result.files[0]])
        #expect(deletion.deletedItemCount == 1)
        #expect(deletion.failures.isEmpty)
        #expect(!fileManager.fileExists(atPath: result.files[0].url.path))
        #expect(fileManager.fileExists(atPath: unrelated.path))
    }
}

struct PhotoStorageThresholdTests {
    @Test func identifiesLargePhotosAndVideosWithDifferentThresholds() {
        let smallPhoto = PhotoMediaItem(
            id: "small",
            mediaType: .image,
            byteSize: 19_999_999,
            pixelWidth: 1000,
            pixelHeight: 1000,
            duration: nil,
            creationDate: nil
        )
        let largePhoto = PhotoMediaItem(
            id: "large-photo",
            mediaType: .image,
            byteSize: 20_000_000,
            pixelWidth: 4000,
            pixelHeight: 3000,
            duration: nil,
            creationDate: nil
        )
        let largeVideo = PhotoMediaItem(
            id: "large-video",
            mediaType: .video,
            byteSize: 100_000_000,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 10,
            creationDate: nil
        )

        #expect(PhotoScanResult(items: [smallPhoto, largePhoto, largeVideo], unreadableAssetCount: 0)
            .largeItems.map(\.id) == ["large-video", "large-photo"])
    }
}
