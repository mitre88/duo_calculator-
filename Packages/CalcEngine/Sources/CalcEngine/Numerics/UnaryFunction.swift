/// One-argument functions available on the keypad (and in text expressions).
/// Raw values are the names used by the text grammar, the `calc` CLI and the fixtures.
public enum UnaryFunction: String, Sendable, Codable, Hashable, CaseIterable {
    case sin, cos, tan
    case asin, acos, atan
    case sinh, cosh, tanh
    case asinh, acosh, atanh
    case ln, log10, log2
    case exp, pow10, pow2
    case sqrt, cbrt
    case reciprocal = "inv"
    case square = "sq"
    case cube
    case abs

    /// Functions whose result depends on the angle mode.
    public var usesAngleMode: Bool {
        switch self {
        case .sin, .cos, .tan, .asin, .acos, .atan: true
        default: false
        }
    }

    /// Display name used by `ExpressionRenderer` (`sin⁻¹`, `√`, `x²`…).
    public var displayName: String {
        switch self {
        case .asin: "sin⁻¹"
        case .acos: "cos⁻¹"
        case .atan: "tan⁻¹"
        case .asinh: "sinh⁻¹"
        case .acosh: "cosh⁻¹"
        case .atanh: "tanh⁻¹"
        case .ln: "ln"
        case .log10: "log₁₀"
        case .log2: "log₂"
        case .exp: "e^"
        case .pow10: "10^"
        case .pow2: "2^"
        case .sqrt: "√"
        case .cbrt: "∛"
        case .reciprocal: "1/"
        case .square: "²"
        case .cube: "³"
        case .abs: "abs"
        default: rawValue
        }
    }

    /// Functions rendered as a postfix mark (`x²`, `x³`) rather than `f(x)`.
    public var isPostfixStyle: Bool { self == .square || self == .cube }
}
