import Foundation
import CalcEngine

/// Tiny command-line front end for the engine.
///
///     swift run calc "2^3^2"                 → 512
///     swift run calc --rad "sin(pi/2)"       → 1
///     swift run calc --keys "2,0,0,+,1,0,%,="  → 220   (key names as in ios_sequences.json)
///     swift run calc --canon "1/3"           → 3.33333333333333333333333333333E-1
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
        """)
    }
}

exit(CLI.run(CommandLine.arguments))
