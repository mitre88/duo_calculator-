import SwiftUI
import CalcEngine

/// What a key does.
enum KeyAction: Hashable {
    case event(CalculatorEvent)
    case toggleSecond
    case toggleAngle
    case none
}

/// What a key shows.
enum KeyFace: Hashable {
    case text(String)
    /// SF Symbol name.
    case symbol(String)
    /// `base` with an optional superscript / subscript (`x²`, `10ˣ`, `log₁₀`, `ʸ√x`).
    case math(base: String, superscript: String? = nil, subscriptText: String? = nil, prefixSuperscript: String? = nil)

    /// Plain text for accessibility fallbacks and tests.
    var plainText: String {
        switch self {
        case .text(let t): t
        case .symbol(let s): s
        case .math(let base, let sup, let sub, let pre): (pre ?? "") + base + (sup ?? "") + (sub ?? "")
        }
    }
}

/// Visual family of a key: drives glass tint, haptics and VoiceOver hints.
enum KeyCategory: Hashable {
    case digit, decimal, binaryOperator, equals, utility, function, memory, constant, modeToggle, parenthesis

    var haptic: HapticKind {
        switch self {
        case .digit, .decimal, .constant, .parenthesis: .light
        case .binaryOperator, .function, .memory, .utility: .medium
        case .equals: .heavy
        case .modeToggle: .selection
        }
    }
}

struct KeyDefinition: Identifiable, Hashable {
    var id: KeyID
    var face: KeyFace
    var secondFace: KeyFace?
    var category: KeyCategory
    var action: KeyAction
    var secondAction: KeyAction?
    /// Localization keys (`key.sine`), resolved by `KeyAccessibility`.
    var accessibilityKey: String
    var secondAccessibilityKey: String?

    init(_ id: KeyID, face: KeyFace, secondFace: KeyFace? = nil, category: KeyCategory,
         action: KeyAction, secondAction: KeyAction? = nil,
         accessibilityKey: String, secondAccessibilityKey: String? = nil) {
        self.id = id
        self.face = face
        self.secondFace = secondFace
        self.category = category
        self.action = action
        self.secondAction = secondAction
        self.accessibilityKey = accessibilityKey
        self.secondAccessibilityKey = secondAccessibilityKey
    }

    func face(second: Bool) -> KeyFace { (second ? secondFace : nil) ?? face }
    func accessibilityKey(second: Bool) -> String { (second ? secondAccessibilityKey : nil) ?? accessibilityKey }
}
