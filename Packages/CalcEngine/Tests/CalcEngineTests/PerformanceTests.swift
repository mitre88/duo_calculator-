import Foundation
import Testing
@testable import CalcEngine

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - Measurement helpers

/// Resident set size of this process (bytes); `nil` where the platform does not expose it.
enum ProcessMemory {
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

struct LatencyStats: CustomStringConvertible {
    var samples: [Duration]

    private var sorted: [Duration] { samples.sorted() }
    func percentile(_ p: Double) -> Duration {
        let s = sorted
        guard !s.isEmpty else { return .zero }
        return s[min(s.count - 1, Int(Double(s.count - 1) * p))]
    }
    var p50: Duration { percentile(0.5) }
    var p95: Duration { percentile(0.95) }
    var worst: Duration { sorted.last ?? .zero }
    var total: Duration { samples.reduce(Duration.zero, +) }
    var perSecond: Double { total == .zero ? 0 : Double(samples.count) / (total / Duration.seconds(1)) }

    static func ms(_ d: Duration) -> String { String(format: "%.3f ms", d / Duration.milliseconds(1)) }
    var description: String {
        "p50=\(Self.ms(p50)) p95=\(Self.ms(p95)) max=\(Self.ms(worst)) n=\(samples.count) (\(String(format: "%.0f", perSecond))/s)"
    }
}

/// Budgets are stated for a release build on a phone. Debug builds inside a CI container are an order of
/// magnitude slower, so unless `CALC_PERF_STRICT=1` is set every budget is multiplied by 25: the strict
/// numbers are the product goal, the relaxed ones only catch algorithmic regressions.
enum PerfBudget {
    static let strict = ProcessInfo.processInfo.environment["CALC_PERF_STRICT"] == "1"
    static func limit(_ release: Duration) -> Duration { strict ? release : release * 25 }
}

/// Deterministic generator for the fuzz / soak tests (splitmix64).
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

/// Weighted alphabet of everything a user can press, so the soak tests walk every reducer path.
enum FuzzEvents {
    static func event(_ rng: inout SplitMix64) -> CalculatorEvent {
        let functions = UnaryFunction.allCases
        let binaries = BinaryOperator.allCases
        let postfixes = PostfixOperator.allCases
        let memory = MemoryAction.allCases
        switch rng.below(100) {
        case 0..<38: return .digit(rng.below(10))
        case 38..<44: return .decimalSeparator
        case 44..<58: return .binary(binaries[rng.below(binaries.count)])
        case 58..<65: return .function(functions[rng.below(functions.count)])
        case 65..<69: return .postfix(postfixes[rng.below(postfixes.count)])
        case 69..<75: return .equals
        case 75..<78: return .openParen
        case 78..<81: return .closeParen
        case 81..<83: return .toggleSign
        case 83..<85: return .percent
        case 85..<87: return .backspace
        case 87..<88: return .clear
        case 88..<89: return .allClear
        case 89..<91: return .constant(rng.below(2) == 0 ? .pi : .e)
        case 91..<92: return .exponentEntry
        case 92..<94: return .memory(memory[rng.below(memory.count)])
        case 94..<95: return .toggleSecond
        case 95..<96: return .toggleAngleMode
        case 96..<97: return .cursorLeft
        case 97..<98: return .cursorRight
        case 98..<99: return .cursorTo(rng.below(8))
        default: return .random
        }
    }
}

// MARK: - Tests

extension CalcEngineTests {
    /// Latency, throughput, memory and robustness. Every test prints a `[perf]` / `[mem]` line so the CI
    /// log (and `swift test -c release`) doubles as the benchmark report.
    @Suite struct PerformanceTests {
        /// A realistic 42-key session: entry, functions, parentheses, percent, memory, repeat-equals, errors.
        static let script: [CalculatorEvent] = [
            .digit(1), .digit(2), .decimalSeparator, .digit(5), .binary(.multiply), .digit(3), .equals,
            .digit(3), .digit(0), .function(.sin), .binary(.add), .digit(2), .function(.sqrt), .equals,
            .openParen, .digit(2), .binary(.add), .digit(3), .closeParen, .binary(.power), .digit(4), .equals,
            .digit(2), .digit(0), .digit(0), .binary(.add), .digit(1), .digit(0), .percent, .equals,
            .digit(9), .postfix(.factorial), .memory(.add), .memory(.recall), .binary(.divide), .digit(0), .equals,
            .allClear, .digit(7), .function(.ln), .equals, .equals,
        ]

        @Test func keyPressLatency() {
            var engine = CalculatorEngine(random: SeededRandomSource(seed: 7))
            // Warm-up builds BigDecimal's constant caches (π, Spouge coefficients) outside the measurement.
            for event in Self.script { engine.send(event); _ = engine.snapshot(formatter: .regularUS) }
            let clock = ContinuousClock()
            var samples: [Duration] = []
            for _ in 0..<25 {
                for event in Self.script {
                    let start = clock.now
                    engine.send(event)
                    _ = engine.snapshot(formatter: .regularUS)
                    samples.append(clock.now - start)
                }
            }
            let stats = LatencyStats(samples: samples)
            print("[perf] key press (send + snapshot): \(stats)")
            #expect(stats.p50 < PerfBudget.limit(.milliseconds(2)), "p50 over budget: \(stats)")
            #expect(stats.p95 < PerfBudget.limit(.milliseconds(16)), "p95 over budget: \(stats)")
        }

        @Test func evaluatorThroughput() throws {
            let cases: [(name: String, expr: String, angle: AngleMode, budget: Duration)] = [
                ("arithmetic", "12345.678*98765.4321/3-2^10+(7-2)*(3+4)", .degrees, .microseconds(400)),
                ("exact rational", "1/3*3-1+0.1+0.2", .degrees, .microseconds(300)),
                ("trig deg", "sin(30)+cos(60)*tan(45)", .degrees, .milliseconds(4)),
                ("trig rad", "sin(37)+cos(2)^2*ln(10)", .radians, .milliseconds(12)),
                ("hyperbolic", "sinh(10)+cosh(3)-tanh(0.5)", .radians, .milliseconds(12)),
                ("powers & roots", "2^0.5*root(27,3)+log10(1000)", .degrees, .milliseconds(12)),
            ]
            let clock = ContinuousClock()
            for item in cases {
                _ = try Evaluator.evaluate(text: item.expr, angleMode: item.angle)   // warm-up
                var samples: [Duration] = []
                for _ in 0..<20 {
                    let start = clock.now
                    _ = try Evaluator.evaluate(text: item.expr, angleMode: item.angle)
                    samples.append(clock.now - start)
                }
                let stats = LatencyStats(samples: samples)
                print("[perf] evaluate \(item.name): \(stats)")
                #expect(stats.p50 < PerfBudget.limit(item.budget), "\(item.name) over budget: \(stats)")
            }
        }

        @Test func formatterThroughput() throws {
            let formatter = DisplayFormatter(profile: .regular, separators: .named("es_MX"), usesGrouping: true)
            var values: [CalcValue] = []
            for i in 1...200 {
                values.append(try #require(CalcValue(literal: "1234567.8901234\(i)")))
                values.append(try MathKernel.divide(CalcValue(i), CalcValue(7)))
                values.append(try MathKernel.power(CalcValue(10), CalcValue(i)))
            }
            let clock = ContinuousClock()
            let start = clock.now
            for _ in 0..<10 { for value in values { _ = formatter.format(value) } }
            let elapsed = clock.now - start
            let count = values.count * 10
            let perValue = elapsed / count
            print("[perf] format 16 digits: \(LatencyStats.ms(perValue)) per value, \(count) values in \(LatencyStats.ms(elapsed))")
            #expect(perValue < PerfBudget.limit(.microseconds(40)), "formatting too slow: \(LatencyStats.ms(perValue))")
        }

        @Test func memoryStaysBoundedOverALongSession() throws {
            var rng = SplitMix64(state: 0xD1CE_F00D)
            var engine = CalculatorEngine(random: SeededRandomSource(seed: 3))
            let formatter = DisplayFormatter.regularUS
            // Warm-up: caches that legitimately grow once (π at each precision, gamma constants) fill up here.
            for _ in 0..<2_000 { engine.send(FuzzEvents.event(&rng)); _ = engine.snapshot(formatter: formatter) }
            let baseline = ProcessMemory.residentBytes()
            var peakTokens = 0, peakResults = 0
            for _ in 0..<20_000 {
                engine.send(FuzzEvents.event(&rng))
                _ = engine.snapshot(formatter: formatter)
                peakTokens = max(peakTokens, engine.document.tokens.count)
                peakResults = max(peakResults, engine.state.results.count)
            }
            let after = ProcessMemory.residentBytes()
            let payload = try JSONEncoder().encode(engine.state).count
            if let baseline, let after {
                let growth = after - baseline
                print("[mem] rss baseline=\(baseline / 1_048_576) MiB after=\(after / 1_048_576) MiB growth=\(growth / 1024) KiB over 20k events; persisted state=\(payload) B; peak tokens=\(peakTokens) results=\(peakResults)")
                #expect(growth < 24 * 1_048_576, "resident memory grew \(growth / 1024) KiB over 20k events")
            } else {
                print("[mem] resident size unavailable on this platform; state=\(payload) B; peak tokens=\(peakTokens) results=\(peakResults)")
            }
            #expect(peakTokens <= OperatorTable.maxTokens)
            #expect(peakResults <= CalculatorState.maxStoredResults)
            #expect(payload < 64 * 1024, "persisted state is \(payload) bytes")
        }

        @Test(arguments: [UInt64(1), 2, 3, 4, 5])
        func randomSessionsNeverCrashOrStall(seed: UInt64) {
            var rng = SplitMix64(state: seed &* 0x2545_F491_4F6C_DD1D)
            var engine = CalculatorEngine(random: SeededRandomSource(seed: seed))
            let formatter = DisplayFormatter(profile: .compact, separators: .named("de_DE"), usesGrouping: true)
            let clock = ContinuousClock()
            var slowest: (event: String, duration: Duration) = ("", .zero)
            var snapshots = 0
            for step in 0..<10_000 {
                let event = FuzzEvents.event(&rng)
                let start = clock.now
                engine.send(event)
                if step % 5 == 0 {
                    let snapshot = engine.snapshot(formatter: formatter)
                    snapshots += 1
                    #expect(!snapshot.primary.isEmpty)
                    _ = engine.currentValue()
                }
                let elapsed = clock.now - start
                if elapsed > slowest.duration { slowest = (String(describing: event), elapsed) }
                #expect(elapsed < .seconds(5), "event \(event) took \(elapsed) at step \(step)")
            }
            print("[perf] fuzz seed \(seed): 10k events, \(snapshots) snapshots, slowest \(slowest.event) = \(LatencyStats.ms(slowest.duration))")
        }

        @Test func parserHandlesMaximumComplexityAndRejectsBeyond() throws {
            let full = Array(repeating: "1", count: 256).joined(separator: "+")        // 511 tokens
            #expect(try Evaluator.evaluate(text: full) == CalcValue(256))
            let tooMany = Array(repeating: "1", count: 257).joined(separator: "+")     // 513 tokens
            do {
                _ = try Evaluator.evaluate(text: tooMany)
                Issue.record("513 tokens should be rejected as too complex")
            } catch CalcError.tooComplex {
            } catch {
                Issue.record("unexpected error \(error)")
            }
            let nested = String(repeating: "(", count: 60) + "1" + String(repeating: ")", count: 60)
            #expect(try Evaluator.evaluate(text: nested) == .one)
            let tooDeep = String(repeating: "(", count: 80) + "1" + String(repeating: ")", count: 80)
            do {
                _ = try Evaluator.evaluate(text: tooDeep)
                Issue.record("80 nested parentheses should be rejected as too complex")
            } catch CalcError.tooComplex {
            } catch {
                Issue.record("unexpected error \(error)")
            }
        }
    }
}
