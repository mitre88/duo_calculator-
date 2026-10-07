import CalcEngine

/// Stable identity of every key. The same `KeyID` is used in every layout, so SwiftUI (and Liquid
/// Glass via `glassEffectID`) can morph a key from its basic position to its scientific one.
nonisolated enum KeyID: Hashable, Codable, CaseIterable {
    case digit(Int)
    case decimal
    case equals
    case add, subtract, multiply, divide
    case allClear
    case toggleSign
    case percent
    case openParen, closeParen
    case memoryClear, memoryAdd, memorySubtract, memoryRecall
    case second
    case square, cube, power
    case exponential      // eˣ  / yˣ
    case powerOfTen       // 10ˣ / 2ˣ
    case reciprocal
    case squareRoot, cubeRoot, nthRoot
    case naturalLog       // ln / logᵧ
    case log10            // log₁₀ / log₂
    case factorial
    case sine, cosine, tangent
    case eulerNumber
    case exponentEntry
    case angleMode
    case hyperbolicSine, hyperbolicCosine, hyperbolicTangent
    case pi
    case random

    static var allCases: [KeyID] {
        (0...9).map(KeyID.digit) + [
            .decimal, .equals, .add, .subtract, .multiply, .divide, .allClear, .toggleSign, .percent,
            .openParen, .closeParen, .memoryClear, .memoryAdd, .memorySubtract, .memoryRecall, .second,
            .square, .cube, .power, .exponential, .powerOfTen, .reciprocal, .squareRoot, .cubeRoot, .nthRoot,
            .naturalLog, .log10, .factorial, .sine, .cosine, .tangent, .eulerNumber, .exponentEntry, .angleMode,
            .hyperbolicSine, .hyperbolicCosine, .hyperbolicTangent, .pi, .random,
        ]
    }

    /// String form for `glassEffectID` / accessibility identifiers.
    var identifier: String {
        switch self {
        case .digit(let d): "digit.\(d)"
        default: "\(self)"
        }
    }
}
