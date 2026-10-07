import Foundation

/// Error kinds surfaced by the engine. Mirrors `CalcError` in `Tools/reference_model.py`.
public enum CalcError: Error, Hashable, Sendable, Codable, CustomStringConvertible {
    /// `1 ÷ 0`, `0⁻¹`, `0 ^ (negative)`.
    case divisionByZero
    /// Argument outside the function domain: `√(−1)`, `ln(0)`, `asin(2)`, `tan(90°)`, `(−1)!`.
    case domain
    /// Result magnitude beyond `CalcPrecision.overflowDecimalExponent` (or a NaN/∞ leaked from the math library).
    case overflow
    /// Malformed expression (text input): unbalanced parentheses, dangling operator, unknown token.
    case syntax
    /// Expression too deep or too long to evaluate safely.
    case tooComplex

    /// Stable identifier used by the JSON fixtures (`"error": "divisionByZero"`).
    public var fixtureName: String {
        switch self {
        case .divisionByZero: "divisionByZero"
        case .domain: "domain"
        case .overflow: "overflow"
        case .syntax: "syntax"
        case .tooComplex: "tooComplex"
        }
    }

    public init?(fixtureName: String) {
        guard let match = CalcError.allCases.first(where: { $0.fixtureName == fixtureName }) else { return nil }
        self = match
    }

    public static let allCases: [CalcError] = [.divisionByZero, .domain, .overflow, .syntax, .tooComplex]

    public var description: String { fixtureName }
}
