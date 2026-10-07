import Testing
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct ProgrammerTests {
        func run(_ events: [ProgrammerEvent], radix: Radix = .decimal, width: BitWidth = .sixtyFour, signed: Bool = true) -> ProgrammerEngine {
            var engine = ProgrammerEngine()
            engine.send(.setRadix(radix))
            engine.send(.setWidth(width))
            if !signed { engine.send(.toggleSigned) }
            for e in events { engine.send(e) }
            return engine
        }

        @Test func bitwiseAndShift() {
            #expect(run([.digit(2), .digit(5), .digit(5), .binary(.and), .digit(1), .digit(5), .equals]).primaryText == "15")
            #expect(run([.digit(1), .binary(.shiftLeft), .digit(4), .equals]).primaryText == "16")
            #expect(run([.digit(6), .binary(.or), .digit(9), .equals]).primaryText == "15")
            #expect(run([.digit(6), .binary(.xor), .digit(3), .equals]).primaryText == "5")
        }

        @Test func wrapAroundSemantics() {
            #expect(run([.digit(1), .digit(2), .digit(7), .binary(.add), .digit(1), .equals], width: .eight).primaryText == "-128")
            #expect(run([.digit(0), .binary(.subtract), .digit(1), .equals], width: .eight, signed: false).primaryText == "255")
            #expect(run([.digit(0), .unary(.not)]).primaryText == "-1")
            #expect(run([.digit(5), .unary(.twosComplement)]).primaryText == "-5")
            #expect(run([.digit(2), .digit(0), .digit(0), .binary(.multiply), .digit(2), .equals], width: .eight, signed: false).primaryText == "144")
        }

        @Test func radixEntryAndConversion() {
            var engine = run([.digit(15), .digit(15)], radix: .hexadecimal)
            #expect(engine.primaryText == "FF")
            engine.send(.setRadix(.decimal))
            #expect(engine.primaryText == "255")
            engine.send(.setRadix(.binary))
            #expect(engine.primaryText == "1111 1111")
            engine.send(.setRadix(.octal))
            #expect(engine.primaryText == "377")
            #expect(run([.digit(2)], radix: .binary).primaryText == "0")  // invalid digit ignored
            #expect(run([.digit(1), .digit(0), .digit(0), .digit(0)], radix: .decimal).primaryText == "1,000")
        }

        @Test func rotateAndFlips() {
            let v = ProgrammerValue(bits: 0x1234, width: .sixteen, isSigned: false)
            #expect(v.byteSwapped.bits == 0x3412)
            #expect(v.rotatedLeft(by: 4).bits == 0x2341)
            #expect(v.rotatedRight(by: 4).bits == 0x4123)
            let w = ProgrammerValue(bits: 0x1234_5678, width: .thirtyTwo, isSigned: false)
            #expect(w.wordSwapped.bits == 0x5678_1234)
            #expect(w.byteSwapped.bits == 0x7856_3412)
            #expect(ProgrammerValue(bits: 0b1000_0000, width: .eight, isSigned: true).shiftedRight(by: 1).bits == 0b1100_0000)
            #expect(ProgrammerValue(bits: 0b1000_0000, width: .eight, isSigned: false).shiftedRight(by: 1).bits == 0b0100_0000)
        }

        @Test func divisionByZeroIsError() {
            var engine = run([.digit(7), .binary(.divide), .digit(0), .equals])
            #expect(engine.isError)
            #expect(engine.primaryText == "Error")
            engine.send(.digit(3))
            #expect(engine.primaryText == "3")
        }

        @Test func chainedOperatorsAndRepeat() {
            #expect(run([.digit(2), .binary(.add), .digit(3), .binary(.multiply), .digit(4), .equals]).primaryText == "20") // left to right
            #expect(run([.digit(2), .binary(.add), .digit(3), .equals, .equals]).primaryText == "8")
            #expect(run([.digit(8), .binary(.add), .binary(.subtract), .digit(3), .equals]).primaryText == "5")
        }

        @Test func bitToggleAndCharacter() {
            var engine = run([])
            engine.send(.toggleBit(6))
            engine.send(.toggleBit(0))
            #expect(engine.primaryText == "65")
            #expect(engine.value.characterDescription == "A")
            #expect(engine.value.bitArray[6] && engine.value.bitArray[0] && !engine.value.bitArray[1])
        }
    }
}
