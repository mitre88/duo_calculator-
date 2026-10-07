import Foundation

/// Decimal / grouping symbols. Injected so the engine stays locale-agnostic and testable.
public struct LocaleSeparators: Sendable, Hashable {
    public var decimal: String
    public var grouping: String
    public var minus: String
    public var exponent: String

    public init(decimal: String = ".", grouping: String = ",", minus: String = "-", exponent: String = "e") {
        self.decimal = decimal
        self.grouping = grouping
        self.minus = minus
        self.exponent = exponent
    }

    public init(locale: Locale) {
        let decimal = locale.decimalSeparator ?? "."
        var grouping = locale.groupingSeparator ?? ","
        if grouping == decimal { grouping = decimal == "," ? "." : "," }
        self.init(decimal: decimal, grouping: grouping)
    }

    public static let enUS = LocaleSeparators()
    public static let deDE = LocaleSeparators(decimal: ",", grouping: ".")

    /// Separators for a locale identifier; the common ones are tabulated so tests do not depend on ICU data.
    public static func named(_ identifier: String) -> LocaleSeparators {
        switch identifier.replacingOccurrences(of: "-", with: "_") {
        case "en_US", "es_MX", "en", "es_US", "en_GB", "ja_JP", "zh_CN": return .enUS
        case "de_DE", "es_ES", "it_IT", "pt_BR", "nl_NL", "es_AR", "id_ID": return .deDE
        case "fr_FR", "ru_RU", "sv_SE", "pl_PL", "cs_CZ": return LocaleSeparators(decimal: ",", grouping: "\u{202F}")
        case "de_CH": return LocaleSeparators(decimal: ".", grouping: "’")
        default: return LocaleSeparators(locale: Locale(identifier: identifier))
        }
    }
}
