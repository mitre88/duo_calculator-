import SwiftUI

/// VoiceOver labels and hints for keys (localized through `Localizable.xcstrings`).
enum KeyAccessibility {
    static func label(for definition: KeyDefinition, second: Bool, override: String?) -> Text {
        if definition.id == .allClear, let override {
            return Text(LocalizedStringKey(override == "C" ? "key.clear" : "key.allClear"), bundle: .main)
        }
        if definition.id == .angleMode, let override {
            return Text(LocalizedStringKey(override == "Rad" ? "key.switchToRadians" : "key.switchToDegrees"), bundle: .main)
        }
        return Text(LocalizedStringKey(definition.accessibilityKey(second: second)), bundle: .main)
    }

    static func hint(for definition: KeyDefinition) -> Text {
        switch definition.category {
        case .function: Text("hint.function", bundle: .main)
        case .binaryOperator: Text("hint.operator", bundle: .main)
        case .memory: Text("hint.memory", bundle: .main)
        case .modeToggle: Text("hint.toggle", bundle: .main)
        default: Text(verbatim: "")
        }
    }
}
