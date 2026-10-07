import Foundation
import CalcEngine

/// Makes display strings friendlier for VoiceOver (`1.5e16` → "1.5 × 10^16").
enum SpokenNumber {
    static func spoken(_ text: String) -> String {
        var s = text
        if let range = s.range(of: "e"), s.first?.isNumber == true || s.hasPrefix("-") {
            let mantissa = s[..<range.lowerBound]
            let exponent = s[range.upperBound...]
            if !exponent.isEmpty, exponent.allSatisfy({ $0.isNumber || $0 == "-" }) {
                s = "\(mantissa) × 10^\(exponent)"
            }
        }
        return s
            .replacingOccurrences(of: "×", with: " × ")
            .replacingOccurrences(of: "÷", with: " ÷ ")
            .replacingOccurrences(of: "−", with: " − ")
            .replacingOccurrences(of: "√", with: " √ ")
            .replacingOccurrences(of: "π", with: " pi ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    static func errorDescription(_ error: CalcError?) -> String {
        switch error {
        case .divisionByZero: String(localized: "error.divisionByZero", bundle: .main)
        case .domain: String(localized: "error.domain", bundle: .main)
        case .overflow: String(localized: "error.overflow", bundle: .main)
        case .syntax: String(localized: "error.syntax", bundle: .main)
        case .tooComplex: String(localized: "error.tooComplex", bundle: .main)
        case nil: String(localized: "display.error", bundle: .main)
        }
    }
}
