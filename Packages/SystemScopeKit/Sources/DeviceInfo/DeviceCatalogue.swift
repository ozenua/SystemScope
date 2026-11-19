import Foundation

/// Versioned mapping from hardware identifier to marketing name and chip (DEV-04, DEV-15).
///
/// PROVISIONAL: model names come from Xcode's simulator device types; chip names are
/// not yet verified against the D-11 catalogue source, so callers must label them
/// `Confidence.derived` until that decision closes.
public struct DeviceCatalogue: Sendable {
    public struct Entry: Sendable, Equatable {
        public let modelName: String
        public let processor: String?
        /// Static specifications. Nil until the D-11 catalogue source is decided, so
        /// screens show these fields as not in the catalogue rather than guessing.
        public var specifications: DeviceSpecifications?

        public init(modelName: String, processor: String?, specifications: DeviceSpecifications? = nil) {
            self.modelName = modelName
            self.processor = processor
            self.specifications = specifications
        }
    }

    public let version: String
    private let entries: [String: Entry]

    public init(version: String, entries: [String: Entry]) {
        self.version = version
        self.entries = entries
    }

    public func entry(for identifier: String) -> Entry? {
        entries[identifier]
    }

    public static let bundled = DeviceCatalogue(
        version: "0.1-provisional",
        entries: [
            "iPhone14,4": Entry(modelName: "iPhone 13 mini", processor: "Apple A15 Bionic"),
            "iPhone14,5": Entry(modelName: "iPhone 13", processor: "Apple A15 Bionic"),
            "iPhone14,2": Entry(modelName: "iPhone 13 Pro", processor: "Apple A15 Bionic"),
            "iPhone14,3": Entry(modelName: "iPhone 13 Pro Max", processor: "Apple A15 Bionic"),
            "iPhone14,6": Entry(modelName: "iPhone SE (3rd generation)", processor: "Apple A15 Bionic"),
            "iPhone14,7": Entry(modelName: "iPhone 14", processor: "Apple A15 Bionic"),
            "iPhone14,8": Entry(modelName: "iPhone 14 Plus", processor: "Apple A15 Bionic"),
            "iPhone15,2": Entry(modelName: "iPhone 14 Pro", processor: "Apple A16 Bionic"),
            "iPhone15,3": Entry(modelName: "iPhone 14 Pro Max", processor: "Apple A16 Bionic"),
            "iPhone15,4": Entry(modelName: "iPhone 15", processor: "Apple A16 Bionic"),
            "iPhone15,5": Entry(modelName: "iPhone 15 Plus", processor: "Apple A16 Bionic"),
            "iPhone16,1": Entry(modelName: "iPhone 15 Pro", processor: "Apple A17 Pro"),
            "iPhone16,2": Entry(modelName: "iPhone 15 Pro Max", processor: "Apple A17 Pro"),
            "iPhone17,3": Entry(modelName: "iPhone 16", processor: "Apple A18"),
            "iPhone17,4": Entry(modelName: "iPhone 16 Plus", processor: "Apple A18"),
            "iPhone17,1": Entry(modelName: "iPhone 16 Pro", processor: "Apple A18 Pro"),
            "iPhone17,2": Entry(modelName: "iPhone 16 Pro Max", processor: "Apple A18 Pro"),
            "iPhone17,5": Entry(modelName: "iPhone 16e", processor: "Apple A18"),
            "iPhone18,3": Entry(modelName: "iPhone 17", processor: "Apple A19"),
            "iPhone18,1": Entry(modelName: "iPhone 17 Pro", processor: "Apple A19 Pro"),
            "iPhone18,2": Entry(modelName: "iPhone 17 Pro Max", processor: "Apple A19 Pro"),
            "iPhone18,4": Entry(modelName: "iPhone Air", processor: "Apple A19 Pro"),
            "iPhone18,5": Entry(modelName: "iPhone 17e", processor: nil),
        ]
    )
}
