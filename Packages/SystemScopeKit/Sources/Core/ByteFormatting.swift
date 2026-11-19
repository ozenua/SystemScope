import Foundation

public enum ByteFormatting {
    /// Storage capacity in decimal gigabytes, e.g. "68.6 GB".
    public static func storage(_ bytes: Int64, fractionDigits: Int = 1) -> String {
        gigabytes(Double(bytes) / 1_000_000_000, fractionDigits: fractionDigits)
    }

    /// Memory in binary gigabytes, e.g. "8 GB".
    public static func memory(_ bytes: UInt64, fractionDigits: Int = 0) -> String {
        gigabytes(Double(bytes) / 1_073_741_824, fractionDigits: fractionDigits)
    }

    private static func gigabytes(_ value: Double, fractionDigits: Int) -> String {
        Measurement(value: value, unit: UnitInformationStorage.gigabytes)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0...fractionDigits))
            ))
    }
}
