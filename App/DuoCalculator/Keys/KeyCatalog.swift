import CalcEngine

/// Every key defined exactly once (with its 2nd face). Layouts only reference `KeyID`s.
enum KeyCatalog {
    static let all: [KeyID: KeyDefinition] = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

    static func definition(_ id: KeyID) -> KeyDefinition {
        guard let definition = all[id] else { fatalError("KeyCatalog is missing \(id)") }
        return definition
    }

    static let definitions: [KeyDefinition] = digits + basics + scientific

    private static let digits: [KeyDefinition] = (0...9).map { d in
        KeyDefinition(.digit(d), face: .text(String(d)), category: .digit, action: .event(.digit(d)), accessibilityKey: "key.digit.\(d)")
    }

    private static let basics: [KeyDefinition] = [
        KeyDefinition(.decimal, face: .text("."), category: .decimal, action: .event(.decimalSeparator), accessibilityKey: "key.decimal"),
        KeyDefinition(.equals, face: .symbol("equal"), category: .equals, action: .event(.equals), accessibilityKey: "key.equals"),
        KeyDefinition(.add, face: .symbol("plus"), category: .binaryOperator, action: .event(.binary(.add)), accessibilityKey: "key.add"),
        KeyDefinition(.subtract, face: .symbol("minus"), category: .binaryOperator, action: .event(.binary(.subtract)), accessibilityKey: "key.subtract"),
        KeyDefinition(.multiply, face: .symbol("multiply"), category: .binaryOperator, action: .event(.binary(.multiply)), accessibilityKey: "key.multiply"),
        KeyDefinition(.divide, face: .symbol("divide"), category: .binaryOperator, action: .event(.binary(.divide)), accessibilityKey: "key.divide"),
        KeyDefinition(.allClear, face: .text("AC"), category: .utility, action: .event(.clear), accessibilityKey: "key.allClear"),
        KeyDefinition(.toggleSign, face: .symbol("plus.forwardslash.minus"), category: .utility, action: .event(.toggleSign), accessibilityKey: "key.toggleSign"),
        KeyDefinition(.percent, face: .symbol("percent"), category: .utility, action: .event(.percent), accessibilityKey: "key.percent"),
    ]

    private static let scientific: [KeyDefinition] = [
        KeyDefinition(.openParen, face: .text("("), category: .parenthesis, action: .event(.openParen), accessibilityKey: "key.openParen"),
        KeyDefinition(.closeParen, face: .text(")"), category: .parenthesis, action: .event(.closeParen), accessibilityKey: "key.closeParen"),
        KeyDefinition(.memoryClear, face: .text("mc"), category: .memory, action: .event(.memory(.clear)), accessibilityKey: "key.memoryClear"),
        KeyDefinition(.memoryAdd, face: .text("m+"), category: .memory, action: .event(.memory(.add)), accessibilityKey: "key.memoryAdd"),
        KeyDefinition(.memorySubtract, face: .text("m−"), category: .memory, action: .event(.memory(.subtract)), accessibilityKey: "key.memorySubtract"),
        KeyDefinition(.memoryRecall, face: .text("mr"), category: .memory, action: .event(.memory(.recall)), accessibilityKey: "key.memoryRecall"),
        KeyDefinition(.second, face: .math(base: "2", superscript: "nd"), category: .modeToggle, action: .toggleSecond, accessibilityKey: "key.second"),
        KeyDefinition(.square, face: .math(base: "x", superscript: "2"), category: .function, action: .event(.postfix(.square)), accessibilityKey: "key.square"),
        KeyDefinition(.cube, face: .math(base: "x", superscript: "3"), category: .function, action: .event(.postfix(.cube)), accessibilityKey: "key.cube"),
        KeyDefinition(.power, face: .math(base: "x", superscript: "y"), category: .function, action: .event(.binary(.power)), accessibilityKey: "key.power"),
        KeyDefinition(.exponential, face: .math(base: "e", superscript: "x"), secondFace: .math(base: "y", superscript: "x"),
                      category: .function, action: .event(.function(.exp)), secondAction: .event(.binary(.reversedPower)),
                      accessibilityKey: "key.exponential", secondAccessibilityKey: "key.reversedPower"),
        KeyDefinition(.powerOfTen, face: .math(base: "10", superscript: "x"), secondFace: .math(base: "2", superscript: "x"),
                      category: .function, action: .event(.function(.pow10)), secondAction: .event(.function(.pow2)),
                      accessibilityKey: "key.powerOfTen", secondAccessibilityKey: "key.powerOfTwo"),
        KeyDefinition(.reciprocal, face: .math(base: "1/x"), category: .function, action: .event(.function(.reciprocal)), accessibilityKey: "key.reciprocal"),
        KeyDefinition(.squareRoot, face: .math(base: "√x", prefixSuperscript: "2"), category: .function, action: .event(.function(.sqrt)), accessibilityKey: "key.squareRoot"),
        KeyDefinition(.cubeRoot, face: .math(base: "√x", prefixSuperscript: "3"), category: .function, action: .event(.function(.cbrt)), accessibilityKey: "key.cubeRoot"),
        KeyDefinition(.nthRoot, face: .math(base: "√x", prefixSuperscript: "y"), category: .function, action: .event(.binary(.root)), accessibilityKey: "key.nthRoot"),
        KeyDefinition(.naturalLog, face: .text("ln"), secondFace: .math(base: "log", subscriptText: "y"),
                      category: .function, action: .event(.function(.ln)), secondAction: .event(.binary(.logBase)),
                      accessibilityKey: "key.naturalLog", secondAccessibilityKey: "key.logBase"),
        KeyDefinition(.log10, face: .math(base: "log", subscriptText: "10"), secondFace: .math(base: "log", subscriptText: "2"),
                      category: .function, action: .event(.function(.log10)), secondAction: .event(.function(.log2)),
                      accessibilityKey: "key.log10", secondAccessibilityKey: "key.log2"),
        KeyDefinition(.factorial, face: .text("x!"), category: .function, action: .event(.postfix(.factorial)), accessibilityKey: "key.factorial"),
        KeyDefinition(.sine, face: .text("sin"), secondFace: .math(base: "sin", superscript: "-1"),
                      category: .function, action: .event(.function(.sin)), secondAction: .event(.function(.asin)),
                      accessibilityKey: "key.sine", secondAccessibilityKey: "key.arcsine"),
        KeyDefinition(.cosine, face: .text("cos"), secondFace: .math(base: "cos", superscript: "-1"),
                      category: .function, action: .event(.function(.cos)), secondAction: .event(.function(.acos)),
                      accessibilityKey: "key.cosine", secondAccessibilityKey: "key.arccosine"),
        KeyDefinition(.tangent, face: .text("tan"), secondFace: .math(base: "tan", superscript: "-1"),
                      category: .function, action: .event(.function(.tan)), secondAction: .event(.function(.atan)),
                      accessibilityKey: "key.tangent", secondAccessibilityKey: "key.arctangent"),
        KeyDefinition(.eulerNumber, face: .text("e"), category: .constant, action: .event(.constant(.e)), accessibilityKey: "key.euler"),
        KeyDefinition(.exponentEntry, face: .text("EE"), category: .function, action: .event(.exponentEntry), accessibilityKey: "key.exponentEntry"),
        KeyDefinition(.angleMode, face: .text("Rad"), secondFace: nil, category: .modeToggle, action: .toggleAngle, accessibilityKey: "key.angleMode"),
        KeyDefinition(.hyperbolicSine, face: .text("sinh"), secondFace: .math(base: "sinh", superscript: "-1"),
                      category: .function, action: .event(.function(.sinh)), secondAction: .event(.function(.asinh)),
                      accessibilityKey: "key.sinh", secondAccessibilityKey: "key.asinh"),
        KeyDefinition(.hyperbolicCosine, face: .text("cosh"), secondFace: .math(base: "cosh", superscript: "-1"),
                      category: .function, action: .event(.function(.cosh)), secondAction: .event(.function(.acosh)),
                      accessibilityKey: "key.cosh", secondAccessibilityKey: "key.acosh"),
        KeyDefinition(.hyperbolicTangent, face: .text("tanh"), secondFace: .math(base: "tanh", superscript: "-1"),
                      category: .function, action: .event(.function(.tanh)), secondAction: .event(.function(.atanh)),
                      accessibilityKey: "key.tanh", secondAccessibilityKey: "key.atanh"),
        KeyDefinition(.pi, face: .text("π"), category: .constant, action: .event(.constant(.pi)), accessibilityKey: "key.pi"),
        KeyDefinition(.random, face: .text("Rand"), category: .function, action: .event(.random), accessibilityKey: "key.random"),
    ]
}
