import BigInt

/// Unit categories of the converter (no currencies: no network).
public enum UnitCategory: String, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case length, mass, temperature, area, volume, speed, duration, information, energy, pressure, angle

    public var id: String { rawValue }

    /// SF Symbol used on the category picker.
    public var symbolName: String {
        switch self {
        case .length: "ruler"
        case .mass: "scalemass"
        case .temperature: "thermometer.medium"
        case .area: "square.dashed"
        case .volume: "cube"
        case .speed: "gauge.with.dots.needle.67percent"
        case .duration: "clock"
        case .information: "internaldrive"
        case .energy: "bolt"
        case .pressure: "barometer"
        case .angle: "angle"
        }
    }
}

/// Exact linear factor `value_base = x · numerator/denominator · π^piPower + constant`.
public struct UnitFactor: Sendable, Hashable, Codable {
    public var numerator: Int
    public var denominator: Int
    public var piPower: Int

    public init(_ numerator: Int, _ denominator: Int = 1, piPower: Int = 0) {
        self.numerator = numerator
        self.denominator = denominator
        self.piPower = piPower
    }

    /// `"0.3048"` → 3048 / 10000 (exact decimal).
    public init(decimal text: String) {
        let negative = text.hasPrefix("-")
        let body = negative ? String(text.dropFirst()) : text
        let parts = body.split(separator: ".", maxSplits: 1).map(String.init)
        let integer = parts[0]
        let fraction = parts.count > 1 ? parts[1] : ""
        let digits = Int(integer + fraction) ?? 0
        var denominator = 1
        for _ in 0..<fraction.count { denominator *= 10 }
        self.init(negative ? -digits : digits, denominator)
    }

    public static let one = UnitFactor(1)
    public static let zero = UnitFactor(0)

    /// Exact value (π enters as a 60-digit approximation).
    public var value: CalcValue {
        let rational = CalcValue(exact: BFraction(numerator, denominator))
        guard piPower != 0,
              let piPowered = try? MathKernel.power(MathKernel.pi(), CalcValue(piPower)),
              let scaled = try? MathKernel.multiply(rational, piPowered) else { return rational }
        return scaled
    }
}

public struct UnitDefinition: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var symbol: String
    /// Localization key: `unit.length.meter`.
    public var nameKey: String
    public var category: UnitCategory
    public var factor: UnitFactor
    public var offset: UnitFactor

    public init(id: String, symbol: String, category: UnitCategory, factor: UnitFactor, offset: UnitFactor = .zero) {
        self.id = id
        self.symbol = symbol
        self.nameKey = "unit.\(category.rawValue).\(id)"
        self.category = category
        self.factor = factor
        self.offset = offset
    }
}

/// All units, grouped by category. Base units: m, kg, K, m², L, m/s, s, B, J, Pa, rad.
public enum UnitCatalog {
    public static func units(in category: UnitCategory) -> [UnitDefinition] {
        all.filter { $0.category == category }
    }

    public static func unit(id: String) -> UnitDefinition? {
        all.first { $0.id == id }
    }

    /// Sensible defaults for the two pickers of each category.
    public static func defaultPair(for category: UnitCategory) -> (from: UnitDefinition, to: UnitDefinition) {
        switch category {
        case .length: return (unit(id: "kilometer")!, unit(id: "mile")!)
        case .mass: return (unit(id: "kilogram")!, unit(id: "pound")!)
        case .temperature: return (unit(id: "celsius")!, unit(id: "fahrenheit")!)
        case .area: return (unit(id: "squareMeter")!, unit(id: "squareFoot")!)
        case .volume: return (unit(id: "liter")!, unit(id: "gallonUS")!)
        case .speed: return (unit(id: "kilometersPerHour")!, unit(id: "milesPerHour")!)
        case .duration: return (unit(id: "hour")!, unit(id: "minute")!)
        case .information: return (unit(id: "gigabyte")!, unit(id: "gibibyte")!)
        case .energy: return (unit(id: "kilocalorie")!, unit(id: "kilojoule")!)
        case .pressure: return (unit(id: "bar")!, unit(id: "psi")!)
        case .angle: return (unit(id: "degree")!, unit(id: "radian")!)
        }
    }

    public static let all: [UnitDefinition] = [
        // length (m)
        .init(id: "nanometer", symbol: "nm", category: .length, factor: UnitFactor(1, 1_000_000_000)),
        .init(id: "micrometer", symbol: "µm", category: .length, factor: UnitFactor(1, 1_000_000)),
        .init(id: "millimeter", symbol: "mm", category: .length, factor: UnitFactor(1, 1000)),
        .init(id: "centimeter", symbol: "cm", category: .length, factor: UnitFactor(1, 100)),
        .init(id: "meter", symbol: "m", category: .length, factor: .one),
        .init(id: "kilometer", symbol: "km", category: .length, factor: UnitFactor(1000)),
        .init(id: "inch", symbol: "in", category: .length, factor: UnitFactor(decimal: "0.0254")),
        .init(id: "foot", symbol: "ft", category: .length, factor: UnitFactor(decimal: "0.3048")),
        .init(id: "yard", symbol: "yd", category: .length, factor: UnitFactor(decimal: "0.9144")),
        .init(id: "mile", symbol: "mi", category: .length, factor: UnitFactor(decimal: "1609.344")),
        .init(id: "nauticalMile", symbol: "nmi", category: .length, factor: UnitFactor(1852)),
        .init(id: "astronomicalUnit", symbol: "au", category: .length, factor: UnitFactor(149_597_870_700)),
        .init(id: "lightYear", symbol: "ly", category: .length, factor: UnitFactor(9_460_730_472_580_800)),
        // mass (kg)
        .init(id: "milligram", symbol: "mg", category: .mass, factor: UnitFactor(1, 1_000_000)),
        .init(id: "gram", symbol: "g", category: .mass, factor: UnitFactor(1, 1000)),
        .init(id: "kilogram", symbol: "kg", category: .mass, factor: .one),
        .init(id: "tonne", symbol: "t", category: .mass, factor: UnitFactor(1000)),
        .init(id: "ounce", symbol: "oz", category: .mass, factor: UnitFactor(decimal: "0.028349523125")),
        .init(id: "pound", symbol: "lb", category: .mass, factor: UnitFactor(decimal: "0.45359237")),
        .init(id: "stone", symbol: "st", category: .mass, factor: UnitFactor(decimal: "6.35029318")),
        .init(id: "carat", symbol: "ct", category: .mass, factor: UnitFactor(decimal: "0.0002")),
        // temperature (K)
        .init(id: "kelvin", symbol: "K", category: .temperature, factor: .one),
        .init(id: "celsius", symbol: "°C", category: .temperature, factor: .one, offset: UnitFactor(decimal: "273.15")),
        .init(id: "fahrenheit", symbol: "°F", category: .temperature, factor: UnitFactor(5, 9), offset: UnitFactor(45967, 180)),
        // area (m²)
        .init(id: "squareMillimeter", symbol: "mm²", category: .area, factor: UnitFactor(1, 1_000_000)),
        .init(id: "squareCentimeter", symbol: "cm²", category: .area, factor: UnitFactor(1, 10_000)),
        .init(id: "squareMeter", symbol: "m²", category: .area, factor: .one),
        .init(id: "hectare", symbol: "ha", category: .area, factor: UnitFactor(10_000)),
        .init(id: "squareKilometer", symbol: "km²", category: .area, factor: UnitFactor(1_000_000)),
        .init(id: "squareInch", symbol: "in²", category: .area, factor: UnitFactor(decimal: "0.00064516")),
        .init(id: "squareFoot", symbol: "ft²", category: .area, factor: UnitFactor(decimal: "0.09290304")),
        .init(id: "squareYard", symbol: "yd²", category: .area, factor: UnitFactor(decimal: "0.83612736")),
        .init(id: "acre", symbol: "ac", category: .area, factor: UnitFactor(decimal: "4046.8564224")),
        .init(id: "squareMile", symbol: "mi²", category: .area, factor: UnitFactor(decimal: "2589988.110336")),
        // volume (L)
        .init(id: "milliliter", symbol: "mL", category: .volume, factor: UnitFactor(1, 1000)),
        .init(id: "liter", symbol: "L", category: .volume, factor: .one),
        .init(id: "cubicMeter", symbol: "m³", category: .volume, factor: UnitFactor(1000)),
        .init(id: "teaspoonUS", symbol: "tsp", category: .volume, factor: UnitFactor(decimal: "0.00492892159375")),
        .init(id: "tablespoonUS", symbol: "tbsp", category: .volume, factor: UnitFactor(decimal: "0.01478676478125")),
        .init(id: "fluidOunceUS", symbol: "fl oz", category: .volume, factor: UnitFactor(decimal: "0.0295735295625")),
        .init(id: "cupUS", symbol: "cup", category: .volume, factor: UnitFactor(decimal: "0.2365882365")),
        .init(id: "pintUS", symbol: "pt", category: .volume, factor: UnitFactor(decimal: "0.473176473")),
        .init(id: "quartUS", symbol: "qt", category: .volume, factor: UnitFactor(decimal: "0.946352946")),
        .init(id: "gallonUS", symbol: "gal", category: .volume, factor: UnitFactor(decimal: "3.785411784")),
        .init(id: "gallonUK", symbol: "gal UK", category: .volume, factor: UnitFactor(decimal: "4.54609")),
        // speed (m/s)
        .init(id: "metersPerSecond", symbol: "m/s", category: .speed, factor: .one),
        .init(id: "kilometersPerHour", symbol: "km/h", category: .speed, factor: UnitFactor(5, 18)),
        .init(id: "milesPerHour", symbol: "mph", category: .speed, factor: UnitFactor(decimal: "0.44704")),
        .init(id: "knot", symbol: "kn", category: .speed, factor: UnitFactor(463, 900)),
        .init(id: "feetPerSecond", symbol: "ft/s", category: .speed, factor: UnitFactor(decimal: "0.3048")),
        // duration (s)
        .init(id: "millisecond", symbol: "ms", category: .duration, factor: UnitFactor(1, 1000)),
        .init(id: "second", symbol: "s", category: .duration, factor: .one),
        .init(id: "minute", symbol: "min", category: .duration, factor: UnitFactor(60)),
        .init(id: "hour", symbol: "h", category: .duration, factor: UnitFactor(3600)),
        .init(id: "day", symbol: "d", category: .duration, factor: UnitFactor(86_400)),
        .init(id: "week", symbol: "wk", category: .duration, factor: UnitFactor(604_800)),
        .init(id: "year", symbol: "yr", category: .duration, factor: UnitFactor(31_557_600)),
        // information (B)
        .init(id: "bit", symbol: "bit", category: .information, factor: UnitFactor(1, 8)),
        .init(id: "byte", symbol: "B", category: .information, factor: .one),
        .init(id: "kilobyte", symbol: "kB", category: .information, factor: UnitFactor(1000)),
        .init(id: "megabyte", symbol: "MB", category: .information, factor: UnitFactor(1_000_000)),
        .init(id: "gigabyte", symbol: "GB", category: .information, factor: UnitFactor(1_000_000_000)),
        .init(id: "terabyte", symbol: "TB", category: .information, factor: UnitFactor(1_000_000_000_000)),
        .init(id: "kibibyte", symbol: "KiB", category: .information, factor: UnitFactor(1024)),
        .init(id: "mebibyte", symbol: "MiB", category: .information, factor: UnitFactor(1_048_576)),
        .init(id: "gibibyte", symbol: "GiB", category: .information, factor: UnitFactor(1_073_741_824)),
        .init(id: "tebibyte", symbol: "TiB", category: .information, factor: UnitFactor(1_099_511_627_776)),
        // energy (J)
        .init(id: "joule", symbol: "J", category: .energy, factor: .one),
        .init(id: "kilojoule", symbol: "kJ", category: .energy, factor: UnitFactor(1000)),
        .init(id: "calorie", symbol: "cal", category: .energy, factor: UnitFactor(decimal: "4.184")),
        .init(id: "kilocalorie", symbol: "kcal", category: .energy, factor: UnitFactor(4184)),
        .init(id: "wattHour", symbol: "Wh", category: .energy, factor: UnitFactor(3600)),
        .init(id: "kilowattHour", symbol: "kWh", category: .energy, factor: UnitFactor(3_600_000)),
        .init(id: "britishThermalUnit", symbol: "BTU", category: .energy, factor: UnitFactor(decimal: "1055.05585262")),
        // pressure (Pa)
        .init(id: "pascal", symbol: "Pa", category: .pressure, factor: .one),
        .init(id: "kilopascal", symbol: "kPa", category: .pressure, factor: UnitFactor(1000)),
        .init(id: "bar", symbol: "bar", category: .pressure, factor: UnitFactor(100_000)),
        .init(id: "atmosphere", symbol: "atm", category: .pressure, factor: UnitFactor(101_325)),
        .init(id: "psi", symbol: "psi", category: .pressure, factor: UnitFactor(decimal: "6894.757293168")),
        .init(id: "millimeterOfMercury", symbol: "mmHg", category: .pressure, factor: UnitFactor(decimal: "133.322387415")),
        .init(id: "inchOfMercury", symbol: "inHg", category: .pressure, factor: UnitFactor(decimal: "3386.389")),
        // angle (rad)
        .init(id: "radian", symbol: "rad", category: .angle, factor: .one),
        .init(id: "degree", symbol: "°", category: .angle, factor: UnitFactor(1, 180, piPower: 1)),
        .init(id: "gradian", symbol: "gon", category: .angle, factor: UnitFactor(1, 200, piPower: 1)),
        .init(id: "turn", symbol: "tr", category: .angle, factor: UnitFactor(2, 1, piPower: 1)),
        .init(id: "arcminute", symbol: "′", category: .angle, factor: UnitFactor(1, 10_800, piPower: 1)),
        .init(id: "arcsecond", symbol: "″", category: .angle, factor: UnitFactor(1, 648_000, piPower: 1)),
    ]
}
