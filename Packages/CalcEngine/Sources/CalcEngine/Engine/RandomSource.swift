/// Source of the `Rand` key values: a 16-digit decimal in `[0, 1)`.
public protocol RandomSource: Sendable {
    mutating func nextUnitValue() -> CalcValue
}

public struct SystemRandomSource: RandomSource {
    public init() {}

    public mutating func nextUnitValue() -> CalcValue {
        let n = UInt64.random(in: 0..<10_000_000_000_000_000)
        return RandomSupport.unitValue(from: n)
    }
}

/// Deterministic SplitMix64 generator for tests and fixtures.
public struct SeededRandomSource: RandomSource {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func nextUnitValue() -> CalcValue {
        RandomSupport.unitValue(from: next() % 10_000_000_000_000_000)
    }
}

enum RandomSupport {
    static func unitValue(from n: UInt64) -> CalcValue {
        let digits = String(n)
        let padded = String(repeating: "0", count: max(0, 16 - digits.count)) + digits
        return CalcValue(literal: "0." + padded) ?? .zero
    }
}
