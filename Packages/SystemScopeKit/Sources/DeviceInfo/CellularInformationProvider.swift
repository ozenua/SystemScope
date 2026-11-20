import CoreTelephony
import Foundation

public struct CellularInformation: Sendable, Equatable {
    public var technology: String?
    /// Carrier names are unavailable through a current non-deprecated public API.
    public var carrierName: String?

    public init(technology: String? = nil, carrierName: String? = nil) {
        self.technology = technology
        self.carrierName = carrierName
    }
}

public protocol CellularInformationProviding: Sendable {
    func read() async -> CellularInformation
}

public struct CellularInformationProvider: CellularInformationProviding {
    public init() {}

    public func read() async -> CellularInformation {
        let info = CTTelephonyNetworkInfo()
        let technologies = info.serviceCurrentRadioAccessTechnology?.values.compactMap(Self.label)
        return CellularInformation(technology: technologies?.sorted().first)
    }

    private static func label(_ technology: String) -> String? {
        switch technology {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA: "5G"
        case CTRadioAccessTechnologyLTE: "LTE"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA:
            "3G"
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB:
            "2G/3G"
        default: nil
        }
    }
}
