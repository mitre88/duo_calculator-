import SwiftUI
import CalcEngine

/// One key: a glass button whose identity (`glassEffectID`) survives every layout change.
struct KeyButton: View {
    let definition: KeyDefinition
    let showsSecondFace: Bool
    let isActive: Bool
    let shape: KeyShapeStyle
    let keySize: CGSize
    let accent: Color
    let labelOverride: String?
    let namespace: Namespace.ID
    let onPress: () -> Void

    var body: some View {
        let resolvedShape = GlassShapes.keyShape(shape, size: keySize)
        Button(action: onPress) {
            KeyFaceView(face: face, category: definition.category, keyHeight: keySize.height, isActive: isActive, accent: accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(resolvedShape)
        }
        .buttonStyle(KeyPressStyle())
        .keyGlass(category: definition.category, isActive: isActive, shape: resolvedShape, accent: accent)
        .glassEffectID(definition.id.identifier, in: namespace)
        .glassEffectTransition(.materialize)
        .accessibilityLabel(KeyAccessibility.label(for: definition, second: showsSecondFace, override: labelOverride))
        .accessibilityHint(KeyAccessibility.hint(for: definition))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityIdentifier("key." + definition.id.identifier)
    }

    private var face: KeyFace {
        if let labelOverride { return .text(labelOverride) }
        return definition.face(second: showsSecondFace)
    }
}

/// Interactive glass already scales and shimmers on touch; we only add a brightness nudge so the
/// press reads even with Reduce Transparency.
struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(Motion.keyPress, value: configuration.isPressed)
    }
}
