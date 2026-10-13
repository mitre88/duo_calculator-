import Testing
@testable import DuoCalculator

@MainActor
struct KeyLayoutsTests {
    @Test func gridsAreConsistent() {
        for spec in [KeyGridSpec.basic, .scientific, .scientificBook, .functionBlock] { check(spec) }
    }

    func check(_ spec: KeyGridSpec) {
        var occupied = Set<String>()
        for placement in spec.placements {
            #expect(placement.row >= 0 && placement.row < spec.rows)
            #expect(placement.column >= 0 && placement.column + placement.columnSpan <= spec.columns, "\(placement.key) overflows")
            for c in placement.column..<(placement.column + placement.columnSpan) {
                let cell = "\(placement.row):\(c)"
                #expect(!occupied.contains(cell), "overlap at \(cell) in \(spec.name)")
                occupied.insert(cell)
            }
        }
        let keys = spec.keys
        #expect(Set(keys).count == keys.count, "duplicate key in \(spec.name)")
        #expect(occupied.count == spec.rows * spec.columns, "holes in \(spec.name)")
        for key in keys { _ = KeyCatalog.definition(key) }
    }

    @Test func basicKeysAreASubsetOfScientific() {
        let basic = Set(KeyGridSpec.basic.keys)
        let scientific = Set(KeyGridSpec.scientific.keys)
        #expect(basic.isSubset(of: scientific))
        #expect(basic.count == 19)
        #expect(scientific.count == 49)
        #expect(Set(KeyGridSpec.functionBlock.keys).union(basic) == scientific)
        #expect(Set(KeyGridSpec.scientificBook.keys) == scientific)
        #expect(KeyGridSpec.scientificBook.gutterAfterColumn == 5 && KeyGridSpec.scientificBook.columns == 10)
    }

    @Test func catalogCoversEveryKey() {
        for key in KeyID.allCases {
            let definition = KeyCatalog.definition(key)
            #expect(definition.id == key)
            #expect(!definition.accessibilityKey.isEmpty)
        }
        #expect(KeyCatalog.definition(.sine).secondFace != nil)
        #expect(KeyCatalog.definition(.exponential).secondAction != nil)
    }
}
