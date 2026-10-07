/// Evaluates an `Expr` with the engine's semantics (two numeric lanes, iOS percent rules).
public struct Evaluator: Sendable {
    public var angleMode: AngleMode

    public init(angleMode: AngleMode = .degrees) {
        self.angleMode = angleMode
    }

    public func evaluate(_ expression: Expr) throws -> CalcValue {
        try MathKernel.checkOverflow(eval(expression))
    }

    /// Tokenize → parse (strict) → evaluate. Convenience for tests, the CLI and pasted text.
    public static func evaluate(text: String, angleMode: AngleMode = .degrees) throws -> CalcValue {
        let tokens = try ExpressionTokenizer.tokenize(text)
        let tree = try PrattParser.parse(tokens, options: .strict)
        return try Evaluator(angleMode: angleMode).evaluate(tree)
    }

    private func eval(_ expression: Expr) throws -> CalcValue {
        switch expression {
        case .number(let value):
            return value
        case .constant(let constant):
            return constant == .pi ? MathKernel.pi() : MathKernel.e()
        case .group(let inner):
            return try eval(inner)
        case .negate(let inner):
            return try eval(inner).negated
        case .function(let fn, let inner):
            return try MathKernel.apply(fn, to: eval(inner), angle: angleMode)
        case .postfix(let op, let inner):
            let x = try eval(inner)
            switch op {
            case .percent: return MathKernel.percent(x)
            case .factorial: return try MathKernel.factorial(x)
            case .square: return try MathKernel.power(x, CalcValue(2))
            case .cube: return try MathKernel.power(x, CalcValue(3))
            }
        case .binary(let op, let lhs, let rhs):
            let a = try eval(lhs)
            let b = try rightOperand(op, lhs: a, rhs: rhs)
            return try apply(op, a, b)
        }
    }

    /// The right operand of `op` as it is actually applied (what `=` repeats): `200 + 10%` → `20`.
    public func resolvedOperand(_ op: BinaryOperator, lhs: CalcValue, rhs: Expr) throws -> CalcValue {
        try rightOperand(op, lhs: lhs, rhs: rhs)
    }

    /// iOS percent semantics: `a ± b%` → `a ± a·b/100`; `a ×÷^ b%` → `a op (b/100)`.
    private func rightOperand(_ op: BinaryOperator, lhs a: CalcValue, rhs: Expr) throws -> CalcValue {
        if case .postfix(.percent, let inner) = rhs {
            let x = try eval(inner)
            switch op {
            case .add, .subtract: return try MathKernel.multiply(a, MathKernel.percent(x))
            default: return MathKernel.percent(x)
            }
        }
        return try eval(rhs)
    }

    private func apply(_ op: BinaryOperator, _ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        try Evaluator.applyBinary(op, a, b)
    }

    /// Applies a binary operator to two values (shared with the engine's repeat-equals).
    public static func applyBinary(_ op: BinaryOperator, _ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        switch op {
        case .add: try MathKernel.add(a, b)
        case .subtract: try MathKernel.subtract(a, b)
        case .multiply: try MathKernel.multiply(a, b)
        case .divide: try MathKernel.divide(a, b)
        case .power: try MathKernel.power(a, b)
        case .root: try MathKernel.root(a, b)
        case .logBase: try MathKernel.logBase(a, base: b)
        case .reversedPower: try MathKernel.power(b, a)
        }
    }
}
