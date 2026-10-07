/// Where a key sits in a grid (column/row are zero-based; `columnSpan` for the wide `0`).
nonisolated struct KeyPlacement: Hashable, Codable {
    var key: KeyID
    var column: Int
    var row: Int
    var columnSpan: Int = 1
}

/// A keypad arrangement. `gutterAfterColumn` marks where the Book-pose channel may widen.
nonisolated struct KeyGridSpec: Hashable, Codable {
    var name: String
    var columns: Int
    var rows: Int
    var placements: [KeyPlacement]
    var gutterAfterColumn: Int?

    var keys: [KeyID] { placements.map(\.key) }

    func placement(of key: KeyID) -> KeyPlacement? { placements.first { $0.key == key } }

    /// Builds placements from rows of key ids (`nil` = empty cell, spans are given explicitly).
    static func grid(_ name: String, columns: Int, gutterAfterColumn: Int? = nil, _ rows: [[(KeyID, Int)]]) -> KeyGridSpec {
        var placements: [KeyPlacement] = []
        for (rowIndex, row) in rows.enumerated() {
            var column = 0
            for (key, span) in row {
                placements.append(KeyPlacement(key: key, column: column, row: rowIndex, columnSpan: span))
                column += span
            }
        }
        return KeyGridSpec(name: name, columns: columns, rows: rows.count, placements: placements, gutterAfterColumn: gutterAfterColumn)
    }
}

extension KeyGridSpec {
    /// iOS basic calculator: 4 × 5.
    static let basic = KeyGridSpec.grid("basic", columns: 4, [
        [(.allClear, 1), (.toggleSign, 1), (.percent, 1), (.divide, 1)],
        [(.digit(7), 1), (.digit(8), 1), (.digit(9), 1), (.multiply, 1)],
        [(.digit(4), 1), (.digit(5), 1), (.digit(6), 1), (.subtract, 1)],
        [(.digit(1), 1), (.digit(2), 1), (.digit(3), 1), (.add, 1)],
        [(.digit(0), 2), (.decimal, 1), (.equals, 1)],
    ])

    /// The 30 scientific keys alone (6 × 5) — used above the basic keypad when the width is medium.
    static let functionBlock = KeyGridSpec.grid("functionBlock", columns: 6, [
        [(.openParen, 1), (.closeParen, 1), (.memoryClear, 1), (.memoryAdd, 1), (.memorySubtract, 1), (.memoryRecall, 1)],
        [(.second, 1), (.square, 1), (.cube, 1), (.power, 1), (.exponential, 1), (.powerOfTen, 1)],
        [(.reciprocal, 1), (.squareRoot, 1), (.cubeRoot, 1), (.nthRoot, 1), (.naturalLog, 1), (.log10, 1)],
        [(.factorial, 1), (.sine, 1), (.cosine, 1), (.tangent, 1), (.eulerNumber, 1), (.exponentEntry, 1)],
        [(.angleMode, 1), (.hyperbolicSine, 1), (.hyperbolicCosine, 1), (.hyperbolicTangent, 1), (.pi, 1), (.random, 1)],
    ])

    /// Full scientific keypad (iOS order): 6 function columns + 4 basic columns = 10 (even, as the HIG
    /// asks whenever a division region exists). Used on the flat inner display and in the Laptop pose.
    static let scientific = KeyGridSpec.grid("scientific", columns: 10, gutterAfterColumn: 6, [
        [(.openParen, 1), (.closeParen, 1), (.memoryClear, 1), (.memoryAdd, 1), (.memorySubtract, 1), (.memoryRecall, 1),
         (.allClear, 1), (.toggleSign, 1), (.percent, 1), (.divide, 1)],
        [(.second, 1), (.square, 1), (.cube, 1), (.power, 1), (.exponential, 1), (.powerOfTen, 1),
         (.digit(7), 1), (.digit(8), 1), (.digit(9), 1), (.multiply, 1)],
        [(.reciprocal, 1), (.squareRoot, 1), (.cubeRoot, 1), (.nthRoot, 1), (.naturalLog, 1), (.log10, 1),
         (.digit(4), 1), (.digit(5), 1), (.digit(6), 1), (.subtract, 1)],
        [(.factorial, 1), (.sine, 1), (.cosine, 1), (.tangent, 1), (.eulerNumber, 1), (.exponentEntry, 1),
         (.digit(1), 1), (.digit(2), 1), (.digit(3), 1), (.add, 1)],
        [(.angleMode, 1), (.hyperbolicSine, 1), (.hyperbolicCosine, 1), (.hyperbolicTangent, 1), (.pi, 1), (.random, 1),
         (.digit(0), 2), (.decimal, 1), (.equals, 1)],
    ])

    /// Book pose (active vertical fold): the same keys in the same order, but split **5 | 5** so the channel
    /// sits exactly on the hinge. A 6 | 4 split cannot keep 44 pt keys on a 626 pt display: each half has
    /// 273 pt beside an 80 pt fold region, which gives 36.8 pt keys for six columns and 45.8 pt for five.
    static let scientificBook: KeyGridSpec = {
        var spec = KeyGridSpec.scientific
        spec.name = "scientificBook"
        spec.gutterAfterColumn = 5
        return spec
    }()
}
