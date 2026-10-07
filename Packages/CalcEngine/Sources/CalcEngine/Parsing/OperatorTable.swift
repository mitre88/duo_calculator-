/// Binding powers of the Pratt parser — the single source of truth for precedence.
/// Mirrors `BINARY_BP` & friends in `Tools/reference_model.py`.
///
/// | level | operators                               | L / R    | notes                                   |
/// |-------|-----------------------------------------|----------|-----------------------------------------|
/// | 1     | `+ −`                                   | 10 / 11  | left                                    |
/// | 2     | `× ÷` and implicit multiplication       | 20 / 21  | left; `6 ÷ 2(1+2) = 9`                  |
/// | 3     | prefix `−`                              | R 30     | `−2² = −4`, `−2 × 3 = (−2) × 3`         |
/// | 4     | function without parentheses (`sin 30`) | R 35     | `sin 30² = sin(900)`                    |
/// | 5     | `^`, `ʸ√x`, `logᵧ`                      | 50 / 49  | right: `2^3^2 = 512`                    |
/// | 6     | postfix `! % x² x³`                     | L 60     | `2^3! = 64`                             |
enum OperatorTable {
    static func binding(_ op: BinaryOperator) -> (left: Int, right: Int) {
        switch op {
        case .add, .subtract: (10, 11)
        case .multiply, .divide: (20, 21)
        case .power, .root, .logBase, .reversedPower: (50, 49)
        }
    }

    static let implicitMultiplication: (left: Int, right: Int) = (20, 21)
    static let prefixMinus = 30
    static let prefixFunction = 35
    static let postfix = 60

    static let maxDepth = 64
    static let maxTokens = 512
}
