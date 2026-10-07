import BigInt

/// Closed-form trigonometric values for the "nice" angles, in degrees.
/// Only rational results are tabulated; irrational ones (√2/2, √3/2, √3…) take the approx path.
enum ExactAngleTable {
    static func sine(degrees d: Int) -> BFraction? {
        switch d {
        case 0, 180: BFraction(0, 1)
        case 30, 150: BFraction(1, 2)
        case 90: BFraction(1, 1)
        case 210, 330: BFraction(-1, 2)
        case 270: BFraction(-1, 1)
        default: nil
        }
    }

    static func cosine(degrees d: Int) -> BFraction? {
        sine(degrees: (d + 90) % 360)
    }

    /// Returns `.some(nil)` for a tabulated-but-irrational angle, `nil`… — simplified: rational value or nil.
    /// Throws `.domain` at the poles (90°, 270°).
    static func tangent(degrees d: Int) throws -> BFraction? {
        switch d {
        case 90, 270: throw CalcError.domain
        case 0, 180: return BFraction(0, 1)
        case 45, 225: return BFraction(1, 1)
        case 135, 315: return BFraction(-1, 1)
        default: return nil
        }
    }

    static func arcsineDegrees(_ x: BFraction) -> Int? {
        if x.isZero { return 0 }
        if x == BFraction(1, 2) { return 30 }
        if x == 1 { return 90 }
        if x == BFraction(-1, 2) { return -30 }
        if x == -1 { return -90 }
        return nil
    }

    static func arccosineDegrees(_ x: BFraction) -> Int? {
        if x == 1 { return 0 }
        if x == BFraction(1, 2) { return 60 }
        if x.isZero { return 90 }
        if x == BFraction(-1, 2) { return 120 }
        if x == -1 { return 180 }
        return nil
    }

    static func arctangentDegrees(_ x: BFraction) -> Int? {
        if x.isZero { return 0 }
        if x == 1 { return 45 }
        if x == -1 { return -45 }
        return nil
    }
}
