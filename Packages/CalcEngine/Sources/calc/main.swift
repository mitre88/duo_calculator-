import Foundation
import CalcEngine
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Tiny command-line front end for the engine.
///
///     swift run calc "2^3^2"                 → 512
///     swift run calc --rad "sin(pi/2)"       → 1
///     swift run calc --keys "2,0,0,+,1,0,%,="  → 220   (key names as in ios_sequences.json)
///     swift run calc --canon "1/3"           → 3.33333333333333333333333333333E-1
///     swift run -c release calc --bench      → latency / throughput / memory report
struct CLI {
    static func run(_ arguments: [String]) -> Int32 {
        var args = Array(arguments.dropFirst())
        var angle = AngleMode.degrees
        var canonical = false
        var keys: String?
        var compact = false
        var locale = "en_US"

        while let first = args.first, first.hasPrefix("--") {
            args.removeFirst()
            switch first {
            case "--deg": angle = .degrees
            case "--rad": angle = .radians
            case "--canon": canonical = true
            case "--compact": compact = true
            case "--keys": keys = args.isEmpty ? nil : args.removeFirst()
            case "--locale": locale = args.isEmpty ? locale : args.removeFirst()
            case "--bench": return Bench.run(iterations: args.first.flatMap { Int($0) } ?? 50)
            case "--help", "-h": printUsage(); return 0
            default:
                FileHandle.standardError.write(Data("unknown option \(first)\n".utf8))
                return 2
            }
        }

        let formatter = DisplayFormatter(profile: compact ? .compact : .regular,
                                         separators: .named(locale), usesGrouping: true)

        if let keys {
            var engine = CalculatorEngine(random: SeededRandomSource(seed: 1))
            engine.send(.setAngleMode(angle))
            for raw in keys.split(separator: ",") {
                guard let event = CalculatorEvent(testName: String(raw)) else {
                    FileHandle.standardError.write(Data("unknown key '\(raw)'\n".utf8))
                    return 2
                }
                engine.send(event)
            }
            let snapshot = engine.snapshot(formatter: formatter)
            print(snapshot.expressionText.isEmpty ? snapshot.primary : "\(snapshot.expressionText)\n\(snapshot.primary)")
            return snapshot.isError ? 1 : 0
        }

        guard let expression = args.first else { printUsage(); return 2 }
        do {
            let value = try Evaluator.evaluate(text: expression, angleMode: angle)
            print(canonical ? value.canonicalString() : formatter.format(value))
            return 0
        } catch let error as CalcError {
            print("Error: \(error.fixtureName)")
            return 1
        } catch {
            print("Error: \(error)")
            return 1
        }
    }

    static func printUsage() {
        print("""
        usage: calc [--deg|--rad] [--canon] [--compact] [--locale ID] "expression"
               calc [--deg|--rad] --keys "2,0,0,add,1,0,pct,eq"
               calc --bench [iterations]
        """)
    }
}

/// `calc --bench`: the same measurements as the package's PerformanceTests, printed as a table, so the
/// numbers can be taken on a Mac (or an iPhone through a tiny harness) without running the test suite.
enum Bench {
    static func run(iterations: Int) -> Int32 {
        let clock = ContinuousClock()
        func ms(_ d: Duration) -> String { String(format: "%8.3f ms", d / Duration.milliseconds(1)) }
        func stats(_ samples: [Duration]) -> String {
            let s = samples.sorted()
            guard !s.isEmpty else { return "n/a" }
            let p50 = s[(s.count - 1) / 2], p95 = s[min(s.count - 1, Int(Double(s.count - 1) * 0.95))]
            let total = s.reduce(Duration.zero, +)
            return "p50 \(ms(p50))  p95 \(ms(p95))  max \(ms(s[s.count - 1]))  \(String(format: "%9.0f", Double(s.count) / (total / Duration.seconds(1))))/s"
        }
        print("Duo Calculator engine benchmark — \(iterations) iterations, working precision \(CalcPrecision.working) digits")
        print(String(repeating: "─", count: 96))

        // 1. Key latency on a realistic script.
        let script: [CalculatorEvent] = [
            .digit(1), .digit(2), .decimalSeparator, .digit(5), .binary(.multiply), .digit(3), .equals,
            .digit(3), .digit(0), .function(.sin), .binary(.add), .digit(2), .function(.sqrt), .equals,
            .openParen, .digit(2), .binary(.add), .digit(3), .closeParen, .binary(.power), .digit(4), .equals,
            .digit(2), .digit(0), .digit(0), .binary(.add), .digit(1), .digit(0), .percent, .equals,
            .digit(9), .postfix(.factorial), .memory(.add), .memory(.recall), .binary(.divide), .digit(0), .equals,
            .allClear, .digit(7), .function(.ln), .equals, .equals,
        ]
        var engine = CalculatorEngine(random: SeededRandomSource(seed: 7))
        for event in script { engine.send(event); _ = engine.snapshot(formatter: .regularUS) }
        var samples: [Duration] = []
        for _ in 0..<iterations {
            for event in script {
                let start = clock.now
                engine.send(event)
                _ = engine.snapshot(formatter: .regularUS)
                samples.append(clock.now - start)
            }
        }
        print("key press (send + snapshot)      \(stats(samples))")

        // 2. Evaluator throughput per expression family.
        let expressions: [(String, String, AngleMode)] = [
            ("arithmetic", "12345.678*98765.4321/3-2^10+(7-2)*(3+4)", .degrees),
            ("exact rational", "1/3*3-1+0.1+0.2", .degrees),
            ("trig deg", "sin(30)+cos(60)*tan(45)", .degrees),
            ("trig rad", "sin(37)+cos(2)^2*ln(10)", .radians),
            ("hyperbolic", "sinh(10)+cosh(3)-tanh(0.5)", .radians),
            ("powers & roots", "2^0.5*root(27,3)+log10(1000)", .degrees),
            ("20000!", "20000!", .degrees),
            ("99999^99999", "99999^99999", .degrees),
        ]
        for (name, expression, angle) in expressions {
            _ = try? Evaluator.evaluate(text: expression, angleMode: angle)
            var runs: [Duration] = []
            for _ in 0..<max(3, iterations / 5) {
                let start = clock.now
                _ = try? Evaluator.evaluate(text: expression, angleMode: angle)
                runs.append(clock.now - start)
            }
            print("evaluate \(name.padding(toLength: 24, withPad: " ", startingAt: 0))\(stats(runs))")
        }

        // 3. Memory: resident size after a long random session (Linux / Darwin).
        if let before = residentBytes() {
            var rng: UInt64 = 0xD1CE_F00D
            func next() -> Int { rng &+= 0x9E37_79B9_7F4A_7C15; var z = rng; z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9; z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB; return Int((z ^ (z >> 31)) % 100) }
            var soak = CalculatorEngine(random: SeededRandomSource(seed: 3))
            for _ in 0..<20_000 {
                let r = next()
                let event: CalculatorEvent = r < 45 ? .digit(r % 10) : r < 60 ? .binary(BinaryOperator.allCases[r % BinaryOperator.allCases.count])
                    : r < 70 ? .function(UnaryFunction.allCases[r % UnaryFunction.allCases.count]) : r < 80 ? .equals
                    : r < 85 ? .openParen : r < 90 ? .closeParen : r < 94 ? .postfix(PostfixOperator.allCases[r % PostfixOperator.allCases.count])
                    : r < 97 ? .backspace : .allClear
                soak.send(event)
                _ = soak.snapshot(formatter: .regularUS)
            }
            let after = residentBytes() ?? before
            let payload = (try? JSONEncoder().encode(soak.state).count) ?? 0
            print(String(repeating: "─", count: 96))
            print("resident memory: \(before / 1_048_576) MiB → \(after / 1_048_576) MiB after 20k random key events (Δ \((after - before) / 1024) KiB); persisted state \(payload) B")
        }
        return 0
    }

    static func residentBytes() -> Int? {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : nil
        #elseif os(Linux)
        guard let contents = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8) else { return nil }
        let fields = contents.split(separator: " ")
        guard fields.count >= 2, let pages = Int(fields[1]) else { return nil }
        return pages * Int(sysconf(Int32(_SC_PAGESIZE)))
        #else
        return nil
        #endif
    }
}

exit(CLI.run(CommandLine.arguments))
