import Foundation
import Photos
import Vision

public enum PhotoMatchKind: String, Sendable {
    case duplicate
    case similar
}

public struct PhotoMatch: Identifiable, Sendable {
    public let first: PhotoMediaItem
    public let second: PhotoMediaItem
    public let kind: PhotoMatchKind
    public let visualDistance: Float

    public var id: String { "\(first.id)|\(second.id)" }
    public var potentialSpaceBytes: Int64 { min(first.byteSize, second.byteSize) }
}

public struct PhotoComparisonResult: Sendable {
    public let matches: [PhotoMatch]
    public let uncomparableImageCount: Int

    public init(matches: [PhotoMatch], uncomparableImageCount: Int) {
        self.matches = matches
        self.uncomparableImageCount = uncomparableImageCount
    }
}

@MainActor
public struct DuplicateMediaDetector {
    private let imageManager = PHImageManager.default()

    public init() {}

    public func findMatches(in items: [PhotoMediaItem]) async -> PhotoComparisonResult {
        let photos = items.filter { $0.mediaType == .image }
        let exactCandidates = Dictionary(grouping: photos) {
            "\($0.pixelWidth)x\($0.pixelHeight):\($0.byteSize)"
        }
        var featurePrints: [String: VNFeaturePrintObservation] = [:]
        var uncomparableIDs = Set<String>()
        var matches: [PhotoMatch] = []
        var matchedPairs = Set<String>()

        for group in exactCandidates.values where group.count > 1 {
            var representatives: [(PhotoMediaItem, VNFeaturePrintObservation)] = []
            for item in group {
                guard let print = await featurePrint(for: item.id) else {
                    uncomparableIDs.insert(item.id)
                    continue
                }
                featurePrints[item.id] = print
                var matchIndex: Int?
                var matchDistance: Float = .greatestFiniteMagnitude
                for (index, representative) in representatives.enumerated() {
                    guard let distance = distance(print, representative.1) else { continue }
                    if distance < matchDistance {
                        matchIndex = index
                        matchDistance = distance
                    }
                }
                if let matchIndex, matchDistance <= 0.025 {
                    let representative = representatives[matchIndex].0
                    matches.append(PhotoMatch(
                        first: representative,
                        second: item,
                        kind: .duplicate,
                        visualDistance: matchDistance
                    ))
                    matchedPairs.insert(pairKey(representative.id, item.id))
                } else {
                    representatives.append((item, print))
                }
            }
        }

        let byDimensions = Dictionary(grouping: photos) {
            "\($0.pixelWidth)x\($0.pixelHeight)"
        }
        for group in byDimensions.values {
            let dated = group.compactMap { item in
                item.creationDate.map { (item, $0) }
            }
            .sorted { $0.1 < $1.1 }
            for firstIndex in dated.indices {
                let first = dated[firstIndex].0
                let firstDate = dated[firstIndex].1
                var secondIndex = dated.index(after: firstIndex)
                while secondIndex < dated.endIndex,
                      dated[secondIndex].1.timeIntervalSince(firstDate) <= 5 * 60 {
                    let second = dated[secondIndex].0
                    let key = pairKey(first.id, second.id)
                    if !matchedPairs.contains(key) {
                        let firstPrint = await imagePrint(for: first.id, cache: &featurePrints)
                        let secondPrint = await imagePrint(for: second.id, cache: &featurePrints)
                        if let firstPrint, let secondPrint,
                           let distance = distance(firstPrint, secondPrint),
                           distance <= 0.18 {
                            matches.append(PhotoMatch(
                                first: first,
                                second: second,
                                kind: .similar,
                                visualDistance: distance
                            ))
                            matchedPairs.insert(key)
                        } else if firstPrint == nil || secondPrint == nil {
                            if firstPrint == nil { uncomparableIDs.insert(first.id) }
                            if secondPrint == nil { uncomparableIDs.insert(second.id) }
                        }
                    }
                    dated.formIndex(after: &secondIndex)
                }
            }
        }

        return PhotoComparisonResult(
            matches: matches.sorted { $0.potentialSpaceBytes > $1.potentialSpaceBytes },
            uncomparableImageCount: uncomparableIDs.count
        )
    }

    private func imagePrint(for identifier: String, cache: inout [String: VNFeaturePrintObservation])
        async -> VNFeaturePrintObservation? {
        if let cached = cache[identifier] { return cached }
        guard let print = await featurePrint(for: identifier) else { return nil }
        cache[identifier] = print
        return print
    }

    private func featurePrint(for identifier: String) async -> VNFeaturePrintObservation? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        let image: CGImage? = await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                continuation.resume(returning: image?.cgImage)
            }
        }
        guard let image else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private func distance(_ first: VNFeaturePrintObservation, _ second: VNFeaturePrintObservation) -> Float? {
        var value: Float = 0
        do {
            try first.computeDistance(&value, to: second)
            return value
        } catch {
            return nil
        }
    }

    private func pairKey(_ first: String, _ second: String) -> String {
        first < second ? "\(first)|\(second)" : "\(second)|\(first)"
    }
}
