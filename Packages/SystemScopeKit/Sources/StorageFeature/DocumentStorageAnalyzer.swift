import CryptoKit
import Foundation
import UniformTypeIdentifiers

public struct DocumentStorageItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let securityScopedRoot: URL
    public let isDirectory: Bool
    public let byteSize: Int64
    public let fileCount: Int
    public let typeDescription: String
    public let modificationDate: Date?
    public let contentHash: String

    public init(
        url: URL,
        securityScopedRoot: URL,
        isDirectory: Bool,
        byteSize: Int64,
        fileCount: Int,
        typeDescription: String,
        modificationDate: Date?,
        contentHash: String = ""
    ) {
        self.id = url.standardizedFileURL.absoluteString
        self.url = url
        self.securityScopedRoot = securityScopedRoot
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.fileCount = fileCount
        self.typeDescription = typeDescription
        self.modificationDate = modificationDate
        self.contentHash = contentHash
    }

    public var filename: String { url.lastPathComponent }
    public var isLarge: Bool { !isDirectory && byteSize >= 100_000_000 }
}

public struct DocumentDuplicateGroup: Identifiable, Sendable {
    public let files: [DocumentStorageItem]
    public var id: String { files.map(\.id).sorted().joined(separator: "|") }
    public var potentialSpaceBytes: Int64 {
        max(0, files.reduce(0) { $0 + $1.byteSize } - (files.map(\.byteSize).max() ?? 0))
    }

    public init(files: [DocumentStorageItem]) {
        self.files = files
    }
}

public struct DocumentScanResult: Sendable {
    public let selectedLocations: [DocumentStorageItem]
    public let files: [DocumentStorageItem]
    public let duplicateGroups: [DocumentDuplicateGroup]
    public let unreadableFileCount: Int

    public init(
        selectedLocations: [DocumentStorageItem],
        files: [DocumentStorageItem],
        duplicateGroups: [DocumentDuplicateGroup],
        unreadableFileCount: Int
    ) {
        self.selectedLocations = selectedLocations
        self.files = files
        self.duplicateGroups = duplicateGroups
        self.unreadableFileCount = unreadableFileCount
    }
}

public struct DocumentDeletionResult: Sendable {
    public let deletedItemCount: Int
    public let failures: [String]

    public init(deletedItemCount: Int, failures: [String]) {
        self.deletedItemCount = deletedItemCount
        self.failures = failures
    }
}

public struct DocumentStorageAnalyzer: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(urls: [URL]) throws -> DocumentScanResult {
        var locations: [DocumentStorageItem] = []
        var files: [DocumentStorageItem] = []
        var unreadableCount = 0
        var scannedRoots = Set<String>()

        for selectedURL in urls {
            guard scannedRoots.insert(selectedURL.standardizedFileURL.absoluteString).inserted else { continue }
            let root = selectedURL
            let standardizedRoot = root.standardizedFileURL
            let hasSecurityAccess = root.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess { root.stopAccessingSecurityScopedResource() }
            }

            let rootValues = try root.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
            ])
            guard rootValues.isSymbolicLink != true else { continue }

            if rootValues.isDirectory == true {
                var locationBytes: Int64 = 0
                var locationFileCount = 0
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                    ],
                    options: []
                ) else {
                    unreadableCount += 1
                    continue
                }

                for case let fileURL as URL in enumerator {
                    let url = fileURL.standardizedFileURL
                    guard isContained(url, in: standardizedRoot) else {
                        enumerator.skipDescendants()
                        continue
                    }
                    do {
                        let values = try url.resourceValues(forKeys: [
                            .isRegularFileKey,
                            .isSymbolicLinkKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                        ])
                        guard values.isSymbolicLink != true else {
                            enumerator.skipDescendants()
                            continue
                        }
                        guard values.isRegularFile == true, let fileSize = values.fileSize else { continue }

                        let item = try makeFileItem(
                            url: url,
                            securityRoot: root,
                            byteSize: Int64(fileSize),
                            modificationDate: values.contentModificationDate
                        )
                        files.append(item)
                        locationBytes += item.byteSize
                        locationFileCount += 1
                    } catch {
                        unreadableCount += 1
                    }
                }

                locations.append(DocumentStorageItem(
                    url: root,
                    securityScopedRoot: root,
                    isDirectory: true,
                    byteSize: locationBytes,
                    fileCount: locationFileCount,
                    typeDescription: "Folder",
                    modificationDate: rootValues.contentModificationDate
                ))
            } else if rootValues.isRegularFile == true, let fileSize = rootValues.fileSize {
                let item = try makeFileItem(
                    url: root,
                    securityRoot: root,
                    byteSize: Int64(fileSize),
                    modificationDate: rootValues.contentModificationDate
                )
                locations.append(item)
                files.append(item)
            }
        }

        let uniqueFiles = Dictionary(grouping: files, by: \.id).values.compactMap(\.first)
        let duplicates = Dictionary(grouping: uniqueFiles.filter { !$0.isDirectory }, by: \.contentHash)
            .values
            .filter { $0.count > 1 }
            .map(DocumentDuplicateGroup.init(files:))

        return DocumentScanResult(
            selectedLocations: locations,
            files: uniqueFiles.sorted { $0.byteSize > $1.byteSize },
            duplicateGroups: duplicates.sorted { $0.potentialSpaceBytes > $1.potentialSpaceBytes },
            unreadableFileCount: unreadableCount
        )
    }

    public func delete(_ items: [DocumentStorageItem]) throws -> DocumentDeletionResult {
        guard !items.contains(where: \.isDirectory) else {
            throw DocumentStorageError.folderDeletionNotSupported
        }
        let targets = Dictionary(grouping: items, by: \.id).values.compactMap(\.first)

        for item in targets {
            let securityRoot = item.securityScopedRoot.standardizedFileURL
            guard isContained(item.url.standardizedFileURL, in: securityRoot)
                    || item.url.standardizedFileURL == securityRoot
            else {
                throw DocumentStorageError.invalidSelection
            }
            let values = try item.url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw DocumentStorageError.invalidSelection
            }
        }

        var deletedCount = 0
        var failures: [String] = []
        for item in targets {
            let securityRoot = item.securityScopedRoot
            let hasSecurityAccess = securityRoot.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess { securityRoot.stopAccessingSecurityScopedResource() }
            }
            do {
                try fileManager.removeItem(at: item.url)
                deletedCount += 1
            } catch {
                failures.append("\(item.filename): \(error.localizedDescription)")
            }
        }
        return DocumentDeletionResult(deletedItemCount: deletedCount, failures: failures)
    }

    private func makeFileItem(
        url: URL,
        securityRoot: URL,
        byteSize: Int64,
        modificationDate: Date?
    ) throws -> DocumentStorageItem {
        let currentValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard currentValues.isRegularFile == true, currentValues.isSymbolicLink != true else {
            throw DocumentStorageError.invalidSelection
        }
        let digest = try contentHash(of: url)
        let fileType = UTType(filenameExtension: url.pathExtension)?.localizedDescription
            ?? url.pathExtension.uppercased()
        return DocumentStorageItem(
            url: url,
            securityScopedRoot: securityRoot,
            isDirectory: false,
            byteSize: byteSize,
            fileCount: 1,
            typeDescription: fileType.isEmpty ? "File" : fileType,
            modificationDate: modificationDate,
            contentHash: digest
        )
    }

    private func contentHash(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func isContained(_ url: URL, in root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }
}

public enum DocumentStorageError: Error, LocalizedError {
    case invalidSelection
    case folderDeletionNotSupported

    public var errorDescription: String? {
        switch self {
        case .invalidSelection: "The selected file is outside the authorized location."
        case .folderDeletionNotSupported: "SystemScope only deletes individual files, not folders."
        }
    }
}
