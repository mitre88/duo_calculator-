import Foundation

/// Text → tokens. Used by tests, the `calc` CLI and paste; the keypad never goes through text.
///
/// Grammar: decimal numbers (`2`, `1.5`, `2e3`, `.25`), `+ - * / ^` (also `× ÷ − –`), `( )`, `,`,
/// postfix `!` and `%`, constants `pi` `e`, functions `sin(…)` / `sin …`, `root(x, n)`, `logb(x, b)`.
public enum ExpressionTokenizer {
    public static func tokenize(_ text: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(text)
        var i = 0
        let n = chars.count

        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

        while i < n {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }

            if isDigit(c) || (c == "." && i + 1 < n && isDigit(chars[i + 1])) {
                var j = i
                while j < n, isDigit(chars[j]) || chars[j] == "." { j += 1 }
                // exponent only when followed by digits, so "2e" is 2·e and "2e3" is 2000
                if j < n, chars[j] == "e" || chars[j] == "E" {
                    var k = j + 1
                    if k < n, chars[k] == "+" || chars[k] == "-" { k += 1 }
                    if k < n, isDigit(chars[k]) {
                        while k < n, isDigit(chars[k]) { k += 1 }
                        j = k
                    }
                }
                let literalText = String(chars[i..<j])
                guard literalText.filter({ $0 == "." }).count <= 1,
                      let literal = NumberLiteral(parsing: literalText) else { throw CalcError.syntax }
                tokens.append(.number(literal))
                i = j
                continue
            }

            switch c {
            case "π": tokens.append(.constant(.pi)); i += 1; continue
            case "√": tokens.append(.function(.sqrt)); i += 1; continue
            case "∛": tokens.append(.function(.cbrt)); i += 1; continue
            default: break
            }

            if c.isLetter {
                var j = i
                while j < n, chars[j].isLetter || chars[j].isNumber { j += 1 }
                let word = String(chars[i..<j]).lowercased()
                if let constant = Constant(rawValue: word) {
                    tokens.append(.constant(constant))
                } else if let fn = UnaryFunction(rawValue: word) {
                    tokens.append(.function(fn))
                } else if word == "root" {
                    tokens.append(.namedBinary(.root))
                } else if word == "logb" {
                    tokens.append(.namedBinary(.logBase))
                } else if word == "rpow" {
                    tokens.append(.namedBinary(.reversedPower))
                } else {
                    throw CalcError.syntax
                }
                i = j
                continue
            }

            switch c {
            case "+": tokens.append(.binary(.add))
            case "-", "−", "–": tokens.append(.binary(.subtract))
            case "*", "×", "·": tokens.append(.binary(.multiply))
            case "/", "÷": tokens.append(.binary(.divide))
            case "^": tokens.append(.binary(.power))
            case "(": tokens.append(.openParen)
            case ")": tokens.append(.closeParen)
            case ",": tokens.append(.comma)
            case "!": tokens.append(.postfix(.factorial))
            case "%": tokens.append(.postfix(.percent))
            case "²": tokens.append(.postfix(.square))
            case "³": tokens.append(.postfix(.cube))
            default: throw CalcError.syntax
            }
            i += 1
        }
        return tokens
    }
}
