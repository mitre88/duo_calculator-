import Testing
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct UnitConversionTests {
        func convert(_ value: String, _ from: String, _ to: String) throws -> CalcValue {
            try UnitConverter.convert(Numeric.value(value), from: UnitCatalog.unit(id: from)!, to: UnitCatalog.unit(id: to)!)
        }

        @Test func exactLinearConversions() throws {
            #expect(try convert("1", "inch", "centimeter") == Numeric.value("2.54"))
            #expect(try convert("1", "kilometer", "mile").isExact)
            #expect(DisplayFormatter().format(try convert("1", "kilometer", "mile")) == "0.621371192237334")
            #expect(try convert("1", "gibibyte", "megabyte") == Numeric.value("1073.741824"))
            #expect(try convert("1", "hour", "minute") == CalcValue(60))
            #expect(DisplayFormatter().format(try convert("100", "kilometersPerHour", "metersPerSecond")) == "27.77777777777778")
        }

        @Test func temperatureOffsets() throws {
            #expect(try convert("100", "celsius", "fahrenheit") == CalcValue(212))
            #expect(try convert("32", "fahrenheit", "celsius") == .zero)
            #expect(try convert("-40", "celsius", "fahrenheit") == CalcValue(-40))
            #expect(try convert("0", "kelvin", "celsius") == Numeric.value("-273.15"))
            #expect(try convert("98.6", "fahrenheit", "celsius") == CalcValue(37))
        }

        @Test func anglesUsePi() throws {
            let rad = try convert("180", "degree", "radian")
            #expect(!rad.isExact)
            #expect(DisplayFormatter().format(rad) == "3.141592653589793")
            #expect(DisplayFormatter().format(try convert("1", "turn", "degree")) == "360")
        }

        @Test func catalogIntegrity() {
            let ids = UnitCatalog.all.map(\.id)
            #expect(Set(ids).count == ids.count)
            for category in UnitCategory.allCases {
                #expect(UnitCatalog.units(in: category).count >= 3, "\(category)")
                let pair = UnitCatalog.defaultPair(for: category)
                #expect(pair.from.category == category && pair.to.category == category)
            }
            #expect(throws: CalcError.domain) {
                try UnitConverter.convert(.one, from: UnitCatalog.unit(id: "meter")!, to: UnitCatalog.unit(id: "gram")!)
            }
        }
    }
}
