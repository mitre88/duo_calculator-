import Foundation

/// Pure reducer: `send(event)` mutates `state`; `snapshot(formatter:)` renders it.
///
/// Behaviour follows the iOS Calculator where it has an opinion (percent, repeat `=`, operator
/// replacement, `C`/`AC`, immediate functions) and adds cursor editing on top.
public struct CalculatorEngine: Sendable {
    public var state: CalculatorState
    public var random: any RandomSource

    public init(state: CalculatorState = CalculatorState(), random: any RandomSource = SystemRandomSource()) {
        self.state = state
        self.random = random
    }

    // MARK: - Convenience

    public var document: ExpressionDocument {
        get { state.document }
        set { state.document = newValue }
    }

    public var phase: CalculatorState.Phase {
        get { state.phase }
        set { state.phase = newValue }
    }

    private var evaluator: Evaluator { Evaluator(angleMode: state.angleMode) }

    // MARK: - Reducer

    public mutating func send(_ event: CalculatorEvent) {
        if case .error = state.phase {
            switch event {
            case .digit, .decimalSeparator, .constant, .random, .recall, .memory(.recall), .openParen, .insertText:
                resetDocument()
            case .clear, .allClear:
                allClear()
                return
            case .setAngleMode(let mode):
                state.angleMode = mode
                return
            case .toggleAngleMode:
                state.angleMode = state.angleMode.toggled
                return
            case .toggleSecond:
                state.isSecondActive.toggle()
                return
            case .memory(.clear):
                state.memory = .zero
                return
            default:
                return
            }
        }

        switch event {
        case .digit(let d): digit(d)
        case .decimalSeparator: decimalSeparator()
        case .exponentEntry: exponentEntry()
        case .toggleSign: toggleSign()
        case .percent: postfix(.percent)
        case .postfix(let op): postfix(op)
        case .binary(let op): binary(op)
        case .function(let fn): function(fn)
        case .constant(let constant): insertOperand(.constant(constant))
        case .random:
            let value = random.nextUnitValue()
            insertOperand(.number(NumberLiteral(value: value, digits: 16)))
        case .recall(let value): insertOperand(.number(NumberLiteral(value: value)))
        case .openParen: openParen()
        case .closeParen: closeParen()
        case .equals: equals()
        case .clear: clear()
        case .allClear: allClear()
        case .backspace: backspace()
        case .memory(let action): memory(action)
        case .setAngleMode(let mode): state.angleMode = mode
        case .toggleAngleMode: state.angleMode = state.angleMode.toggled
        case .toggleSecond: state.isSecondActive.toggle()
        case .cursorLeft: moveCursor(to: state.document.cursor - 1)
        case .cursorRight: moveCursor(to: state.document.cursor + 1)
        case .cursorToStart: moveCursor(to: 0)
        case .cursorToEnd: moveCursor(to: state.document.tokens.count)
        case .cursorTo(let index): moveCursor(to: index)
        case .insertText(let text): insertText(text)
        }
    }

    // MARK: - Digits & literals

    private mutating func prepareForNewOperand() {
        switch state.phase {
        case .resultShown:
            state.document.removeAll()
            state.committedTokens = []
            state.phase = .idle
        case .operandComputed:
            if let range = state.document.operandRangeBeforeCursor() {
                state.document.replace(range, with: [])
            }
            state.phase = .editing
        default:
            break
        }
    }

    /// The typed (not computed) literal right before the cursor, when digits may extend it.
    private var canExtendLiteralBeforeCursor: Bool {
        guard state.phase == .entering || state.phase == .editing,
              let literal = state.document.tokenBeforeCursor?.numberLiteral else { return false }
        return !literal.isComputed
    }

    private mutating func digit(_ d: Int) {
        prepareForNewOperand()
        if canExtendLiteralBeforeCursor {
            state.document.updateNumberBeforeCursor { literal in
                if var exponent = literal.exponent {
                    let digits = exponent.filter(\.isNumber)
                    if digits.count >= 4 { return }
                    if digits == "0" { exponent.removeLast() }
                    exponent.append(String(d))
                    literal.exponent = exponent
                    return
                }
                if literal.mantissa == "0" {
                    literal.mantissa = String(d)
                    return
                }
                if literal.significantDigitCount >= CalcPrecision.maxEntryDigits { return }
                literal.mantissa.append(String(d))
            }
            state.phase = .entering
            return
        }
        state.document.insert(.number(NumberLiteral(mantissa: String(d))))
        state.phase = .entering
    }

    private mutating func decimalSeparator() {
        prepareForNewOperand()
        if canExtendLiteralBeforeCursor {
            state.document.updateNumberBeforeCursor { literal in
                guard literal.exponent == nil, !literal.hasDecimalSeparator else { return }
                literal.mantissa.append(".")
            }
            state.phase = .entering
            return
        }
        state.document.insert(.number(NumberLiteral(mantissa: "0.")))
        state.phase = .entering
    }

    private mutating func exponentEntry() {
        if case .resultShown = state.phase { return }
        guard canExtendLiteralBeforeCursor || state.phase == .operandComputed,
              let literal = state.document.tokenBeforeCursor?.numberLiteral,
              !literal.isComputed, literal.exponent == nil else { return }
        state.document.updateNumberBeforeCursor { $0.exponent = "" }
        state.phase = .entering
    }

    private mutating func toggleSign() {
        switch state.phase {
        case .idle:
            return
        case .resultShown:
            state.document.updateNumberBeforeCursor { $0.isNegative.toggle() }
            state.phase = .operandComputed
            return
        case .entering, .editing:
            if let literal = state.document.tokenBeforeCursor?.numberLiteral, !literal.isComputed {
                state.document.updateNumberBeforeCursor { literal in
                    if let exponent = literal.exponent {
                        literal.exponent = exponent.hasPrefix("-") ? String(exponent.dropFirst()) : "-" + exponent
                    } else {
                        literal.isNegative.toggle()
                    }
                }
                return
            }
        default:
            break
        }
        guard let range = state.document.operandRangeBeforeCursor() else { return }
        if range.count == 1, var literal = state.document.tokens[range.lowerBound].numberLiteral {
            literal.isNegative.toggle()
            state.document.tokens[range.lowerBound] = .number(literal)
        } else if range.lowerBound > 0, state.document.isPrefixMinus(at: range.lowerBound - 1) {
            state.document.tokens.remove(at: range.lowerBound - 1)
            state.document.cursor -= 1
        } else {
            state.document.tokens.insert(.binary(.subtract), at: range.lowerBound)
            state.document.cursor += 1
        }
        state.phase = .operandComputed
    }

    // MARK: - Operands produced by keys

    /// Inserts a constant / recalled value as a complete operand.
    private mutating func insertOperand(_ token: Token) {
        prepareForNewOperand()
        if state.phase == .entering, let literal = state.document.tokenBeforeCursor?.numberLiteral, !literal.isComputed {
            // typing 2 then π means 2π; typing 0 then π replaces the placeholder zero
            if literal.mantissa == "0", literal.exponent == nil, !literal.hasDecimalSeparator {
                state.document.removeBeforeCursor()
            }
        }
        state.document.insert(token)
        settleOperand()
    }

    /// Makes sure there is an operand before the cursor for a function/postfix to act on.
    private mutating func ensureOperandBeforeCursor() {
        switch state.phase {
        case .idle:
            state.document.insert(.number(NumberLiteral(mantissa: "0")))
        case .operatorPending:
            let value = (try? previewValue()) ?? .zero
            state.document.insert(.number(NumberLiteral(value: value)))
        default:
            if state.document.operandRangeBeforeCursor() == nil {
                state.document.insert(.number(NumberLiteral(mantissa: "0")))
            }
        }
    }

    private mutating func postfix(_ op: PostfixOperator) {
        if case .resultShown = state.phase { state.committedTokens = [] }
        ensureOperandBeforeCursor()
        state.document.insert(.postfix(op))
        settleOperand()
    }

    private mutating func function(_ rawFunction: UnaryFunction) {
        let fn = state.isSecondActive ? rawFunction.secondVariant : rawFunction
        if case .resultShown = state.phase { state.committedTokens = [] }
        ensureOperandBeforeCursor()
        guard let range = state.document.operandRangeBeforeCursor() else { return }
        let operand = Array(state.document.tokens[range])
        let wrapped: [Token]
        if operand.count >= 2, case .openParen = operand[0], case .closeParen = operand[operand.count - 1] {
            // reuse the existing parentheses: (30) → sin(30)
            wrapped = [.function(fn)] + operand
        } else {
            wrapped = [.function(fn), .openParen] + operand + [.closeParen]
        }
        state.document.replace(range, with: wrapped)
        settleOperand()
    }

    /// After an operand was produced: evaluate it in context and move to `operandComputed` or `error`.
    private mutating func settleOperand() {
        switch focusResult() {
        case .success:
            state.phase = .operandComputed
        case .failure(let error):
            state.phase = .error(error)
        }
    }

    // MARK: - Operators & parentheses

    private mutating func binary(_ op: BinaryOperator) {
        switch state.phase {
        case .resultShown:
            state.committedTokens = []
        case .idle:
            state.document.insert(.number(NumberLiteral(mantissa: "0")))
        default:
            break
        }
        if let before = state.document.tokenBeforeCursor, case .binary(let previous) = before,
           !state.document.isPrefixMinus(at: state.document.cursor - 1) {
            if op == .subtract, previous == .multiply || previous == .divide || previous == .power {
                state.document.insert(.number(NumberLiteral(mantissa: "0", isNegative: true)))
                state.phase = .entering
                return
            }
            state.document.tokens[state.document.cursor - 1] = .binary(op)
        } else if let before = state.document.tokenBeforeCursor, before.endsOperand {
            state.document.insert(.binary(op))
        } else {
            // cursor at the start or after "(": only a sign makes sense
            guard op == .subtract else { return }
            state.document.insert(.number(NumberLiteral(mantissa: "0", isNegative: true)))
            state.phase = .entering
            return
        }
        switch Result(catching: { try previewValue() }) {
        case .success: state.phase = .operatorPending
        case .failure(let error): state.phase = .error((error as? CalcError) ?? .syntax)
        }
    }

    private mutating func openParen() {
        prepareForNewOperand()
        if state.phase == .entering, let literal = state.document.tokenBeforeCursor?.numberLiteral,
           literal.mantissa == "0", literal.exponent == nil, !literal.hasDecimalSeparator, !literal.isComputed {
            state.document.removeBeforeCursor()
        }
        state.document.insert(.openParen)
        state.phase = .editing
    }

    private mutating func closeParen() {
        guard state.document.parenthesisBalance > 0,
              let before = state.document.tokenBeforeCursor, before.endsOperand else { return }
        state.document.insert(.closeParen)
        state.phase = .editing
    }

    // MARK: - Equals

    private mutating func equals() {
        switch state.phase {
        case .idle:
            return
        case .resultShown:
            applyRepeat()
        default:
            commit()
        }
    }

    private mutating func commit() {
        let document = state.document
        do {
            let result: CalcValue
            var committed = document.tokens
            if !document.containsBinaryOperator, let repeatOperation = state.repeatOperation {
                let value = try evaluator.evaluate(PrattParser.parse(document.tokens, options: .commit))
                result = try Evaluator.applyBinary(repeatOperation.op, value, repeatOperation.operand)
                committed += [.binary(repeatOperation.op), .number(NumberLiteral(value: repeatOperation.operand))]
            } else {
                let parsed = try PrattParser.parseWithFocus(document.tokens, focusEnd: document.tokens.count, options: .commit)
                result = try evaluator.evaluate(parsed.expression)
                if let last = parsed.lastBinary {
                    let operand = try evaluator.evaluate(last.rhs)
                    state.repeatOperation = RepeatOperation(op: last.op, operand: operand)
                } else {
                    state.repeatOperation = nil
                }
                let missing = document.parenthesisBalance
                if missing > 0 { committed += Array(repeating: Token.closeParen, count: missing) }
            }
            finish(result: result, committed: committed)
        } catch {
            state.phase = .error((error as? CalcError) ?? .syntax)
        }
    }

    private mutating func applyRepeat() {
        guard let repeatOperation = state.repeatOperation, let current = state.lastResult else { return }
        do {
            let result = try Evaluator.applyBinary(repeatOperation.op, current, repeatOperation.operand)
            let committed: [Token] = [
                .number(NumberLiteral(value: current)),
                .binary(repeatOperation.op),
                .number(NumberLiteral(value: repeatOperation.operand)),
            ]
            finish(result: result, committed: committed)
        } catch {
            state.phase = .error((error as? CalcError) ?? .syntax)
        }
    }

    private mutating func finish(result: CalcValue, committed: [Token]) {
        state.lastResult = result
        state.results.append(result)
        if state.results.count > CalculatorState.maxStoredResults {
            state.results.removeFirst(state.results.count - CalculatorState.maxStoredResults)
        }
        state.committedTokens = committed
        state.document = ExpressionDocument(tokens: [.number(NumberLiteral(value: result))])
        state.phase = .resultShown
    }

    // MARK: - Clearing

    private mutating func clear() {
        if state.phase == .entering, let before = state.document.tokenBeforeCursor, case .number = before {
            state.document.removeBeforeCursor()
            if state.document.isEmpty {
                state.phase = .idle
            } else if let token = state.document.tokenBeforeCursor, token.isBinaryOperator {
                state.phase = .operatorPending
            } else {
                state.phase = .editing
            }
            return
        }
        allClear()
    }

    private mutating func allClear() {
        state.document.removeAll()
        state.committedTokens = []
        state.repeatOperation = nil
        state.phase = .idle
    }

    private mutating func resetDocument() {
        state.document.removeAll()
        state.committedTokens = []
        state.phase = .idle
    }

    private mutating func backspace() {
        switch state.phase {
        case .idle, .resultShown:
            return
        default:
            break
        }
        guard let before = state.document.tokenBeforeCursor else { return }
        switch before {
        case .number(let literal) where !literal.isComputed:
            var removed = false
            state.document.updateNumberBeforeCursor { literal in
                if var exponent = literal.exponent {
                    if exponent.isEmpty {
                        literal.exponent = nil
                    } else {
                        exponent.removeLast()
                        literal.exponent = exponent == "-" ? "" : exponent
                    }
                    return
                }
                literal.mantissa.removeLast()
                if literal.mantissa.isEmpty { removed = true }
            }
            if removed { state.document.removeBeforeCursor() }
        case .closeParen, .postfix, .binary, .constant, .comma:
            state.document.removeBeforeCursor()
        case .number:
            state.document.removeBeforeCursor()
        case .openParen:
            state.document.removeBeforeCursor()
            if let token = state.document.tokenBeforeCursor {
                switch token {
                case .function, .namedBinary: state.document.removeBeforeCursor()
                default: break
                }
            }
        case .function, .namedBinary:
            state.document.removeBeforeCursor()
        }
        if state.document.isEmpty {
            state.phase = .idle
        } else if let literal = state.document.tokenBeforeCursor?.numberLiteral, !literal.isComputed, state.phase == .entering {
            state.phase = .entering
        } else if let token = state.document.tokenBeforeCursor, token.isBinaryOperator {
            state.phase = .operatorPending
        } else {
            state.phase = .editing
        }
    }

    // MARK: - Memory

    private mutating func memory(_ action: MemoryAction) {
        switch action {
        case .clear:
            state.memory = .zero
        case .add:
            if let value = currentValue(), let sum = try? MathKernel.add(state.memory, value) { state.memory = sum }
        case .subtract:
            if let value = currentValue(), let difference = try? MathKernel.subtract(state.memory, value) { state.memory = difference }
        case .recall:
            if state.phase == .entering, let literal = state.document.tokenBeforeCursor?.numberLiteral, !literal.isComputed {
                state.document.removeBeforeCursor()
            }
            insertOperand(.number(NumberLiteral(value: state.memory)))
        }
    }

    // MARK: - Cursor & paste

    private mutating func moveCursor(to index: Int) {
        if case .error = state.phase { return }
        if state.document.isEmpty { return }
        if case .resultShown = state.phase { state.committedTokens = [] }
        state.document.cursor = min(max(0, index), state.document.tokens.count)
        if let token = state.document.tokenBeforeCursor, token.isBinaryOperator, !state.document.isPrefixMinus(at: state.document.cursor - 1) {
            state.phase = .operatorPending
        } else {
            state.phase = .editing
        }
    }

    private mutating func insertText(_ text: String) {
        guard let tokens = try? ExpressionTokenizer.tokenize(text), !tokens.isEmpty else { return }
        if case .resultShown = state.phase { resetDocument() }
        if state.document.tokens.count + tokens.count > OperatorTable.maxTokens { return }
        state.document.insert(contentsOf: tokens)
        state.phase = .editing
    }

    // MARK: - Evaluation helpers

    /// Value of the operand right before the cursor, resolved in context (`200 + 10%` → `20`).
    private func focusResult() -> Result<CalcValue, CalcError> {
        do {
            let parsed = try PrattParser.parseWithFocus(state.document.tokens, focusEnd: state.document.cursor, options: .preview)
            if let focus = parsed.focus {
                return .success(try evaluator.evaluate(focus))
            }
            if let range = state.document.operandRangeBeforeCursor() {
                let expression = try PrattParser.parse(Array(state.document.tokens[range]), options: .preview)
                return .success(try evaluator.evaluate(expression))
            }
            return .success(try evaluator.evaluate(parsed.expression))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.syntax)
        }
    }

    /// Live value of the whole document (auto-closed; a trailing operator previews its left operand).
    private func previewValue() throws -> CalcValue {
        let expression = try PrattParser.parse(state.document.tokens, options: .preview)
        return try evaluator.evaluate(expression)
    }

    /// Full-expression preview shown under the expression line while typing.
    private func fullPreviewValue() -> CalcValue? {
        guard let last = state.document.tokens.last, !last.isBinaryOperator else { return nil }
        guard let expression = try? PrattParser.parse(state.document.tokens, options: .commit) else { return nil }
        return try? evaluator.evaluate(expression)
    }

    /// The number the display currently shows (for `M+`, `M−`, copy).
    public func currentValue() -> CalcValue? {
        switch state.phase {
        case .idle: return .zero
        case .error: return nil
        case .resultShown: return state.lastResult
        case .entering, .editing:
            if let literal = state.document.tokenBeforeCursor?.numberLiteral { return literal.value }
            return try? previewValue()
        case .operandComputed:
            return try? focusResult().get()
        case .operatorPending:
            return try? previewValue()
        }
    }

    // MARK: - Snapshot

    public func snapshot(formatter: DisplayFormatter) -> DisplaySnapshot {
        var primary = "0"
        var primaryValue: CalcValue? = .zero
        var isError = false
        var errorReason: CalcError?
        var showsResult = false
        var preview: String?

        func show(_ value: CalcValue?) {
            if let value {
                primary = formatter.format(value)
                primaryValue = value
            }
        }

        switch state.phase {
        case .idle:
            break
        case .error(let error):
            primary = "Error"
            primaryValue = nil
            isError = true
            errorReason = error
        case .entering:
            if let literal = state.document.tokenBeforeCursor?.numberLiteral {
                primary = formatter.formatEntry(literal)
                primaryValue = literal.value
            }
        case .operandComputed:
            show(try? focusResult().get())
        case .operatorPending:
            show(try? previewValue())
        case .editing:
            if let literal = state.document.tokenBeforeCursor?.numberLiteral, !literal.isComputed {
                primary = formatter.formatEntry(literal)
                primaryValue = literal.value
            } else if let value = try? previewValue() {
                show(value)
            } else if let literal = state.document.tokenBeforeCursor?.numberLiteral {
                show(literal.value)
            }
        case .resultShown:
            showsResult = true
            show(state.lastResult)
        }

        if !isError, !showsResult, state.document.tokens.count > 1, let value = fullPreviewValue() {
            let text = formatter.format(value)
            if text != primary { preview = text }
        }

        let expressionTokens = showsResult ? state.committedTokens : state.document.tokens
        var segments = ExpressionRenderer.render(expressionTokens, cursor: showsResult ? nil : state.document.cursor, formatter: formatter)
        if showsResult {
            segments.append(DisplaySegment(id: segments.count, text: " =", kind: .equals, tokenIndex: nil))
        }
        let expressionText = segments.map(\.text).joined()

        var pendingOperator: BinaryOperator?
        if state.phase == .operatorPending, let token = state.document.tokenBeforeCursor, case .binary(let op) = token {
            pendingOperator = op
        }

        return DisplaySnapshot(
            expression: segments,
            expressionText: expressionText,
            primary: primary,
            primaryValue: primaryValue,
            preview: preview,
            isError: isError,
            errorReason: errorReason,
            clearLabel: state.phase == .entering ? .clear : .allClear,
            memoryActive: !state.memory.isZero,
            angleMode: state.angleMode,
            isSecondActive: state.isSecondActive,
            pendingOperator: pendingOperator,
            cursor: state.document.cursor,
            tokenCount: state.document.tokens.count,
            showsResult: showsResult,
            isEntering: state.phase == .entering)
    }
}

extension UnaryFunction {
    /// The function shown on the same key when `2nd` is active.
    public var secondVariant: UnaryFunction {
        switch self {
        case .sin: .asin
        case .cos: .acos
        case .tan: .atan
        case .asin: .sin
        case .acos: .cos
        case .atan: .tan
        case .sinh: .asinh
        case .cosh: .acosh
        case .tanh: .atanh
        case .asinh: .sinh
        case .acosh: .cosh
        case .atanh: .tanh
        case .log10: .log2
        case .log2: .log10
        case .pow10: .pow2
        case .pow2: .pow10
        default: self
        }
    }
}
