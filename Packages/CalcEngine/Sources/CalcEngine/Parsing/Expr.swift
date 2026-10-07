/// Abstract syntax tree produced by `PrattParser`.
public indirect enum Expr: Sendable, Hashable {
    case number(CalcValue)
    case constant(Constant)
    case group(Expr)
    case negate(Expr)
    case function(UnaryFunction, Expr)
    case postfix(PostfixOperator, Expr)
    case binary(BinaryOperator, Expr, Expr)
}
