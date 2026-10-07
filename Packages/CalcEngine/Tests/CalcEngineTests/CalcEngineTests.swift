import Foundation
import Testing
import BigDecimal
@testable import CalcEngine

/// Parent suite. `.serialized` because BigDecimal keeps global caches (π, factorials, Spouge constants)
/// that are not safe to touch from several threads at once.
@Suite(.serialized)
struct CalcEngineTests {}

// MARK: - Fixture loading

enum Fixtures {
    static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    enum FixtureError: Error { case missing(String) }
}

struct ExpressionCase: Decodable, CustomTestStringConvertible {
    var id: String
    var expr: String
    var angle: String
    var exact: Bool?
    var expected: String?
    var expected16: String?
    var error: String?
    var testDescription: String { "\(id): \(expr)" }
}

struct ExpressionFixture: Decodable {
    var workingDigits: Int
    var canonDigits: Int
    var cases: [ExpressionCase]
}

struct TranscendentalCase: Decodable, CustomTestStringConvertible {
    var id: String
    var fn: String
    var angle: String?
    var args: [String]
    var exact: Bool?
    var expected: String?
    var expected16: String?
    var minDigits: Int?
    var error: String?
    var testDescription: String { id }
}

struct TranscendentalFixture: Decodable {
    var workingDigits: Int
    var cases: [TranscendentalCase]
}

struct SequenceCase: Decodable, CustomTestStringConvertible {
    var id: String
    var keys: [String]
    var primary: String
    var expression: String?
    var testDescription: String { "\(id): \(keys.joined(separator: " "))" }
}

struct SequenceFixture: Decodable {
    var locale: String
    var profile: String
    var angle: String
    var cases: [SequenceCase]
}

struct FormattingCase: Decodable, CustomTestStringConvertible {
    var value: String
    var profile: String
    var locale: String
    var grouping: Bool
    var expected: String
    var testDescription: String { "\(value) [\(profile), \(locale), grouping=\(grouping)]" }
}

struct FormattingFixture: Decodable {
    var cases: [FormattingCase]
}

// MARK: - Numeric comparison helpers

enum Numeric {
    static func angle(_ name: String?) -> AngleMode {
        name == "deg" ? .degrees : .radians
    }

    /// `|actual − expected| ≤ |expected| · 10^-digits`; an expected zero demands an exact zero.
    static func agree(_ actual: CalcValue, _ expectedCanonical: String, digits: Int) -> Bool {
        let expected = BigDecimal(expectedCanonical)
        if expected.isZero { return actual.isZero }
        let value = actual.approx(Rounding(.toNearestOrEven, 70))
        let difference = (value - expected).abs
        let tolerance = expected.abs.multiply(BigDecimal(1, -digits), Rounding(.toNearestOrEven, 20))
        return difference <= tolerance
    }

    static func display16(_ value: CalcValue) -> String {
        value.canonicalString(digits: 16, mode: .toNearestOrAwayFromZero)
    }

    static func value(_ literal: String) -> CalcValue {
        CalcValue(literal: literal)!
    }
}
