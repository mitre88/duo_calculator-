import SwiftUI
import UIKit

/// Shape helpers shared by keys and panels.
enum GlassShapes {
    static func keyShape(_ style: KeyShapeStyle, size: CGSize) -> AnyShape {
        switch style {
        case .circle:
            return AnyShape(Circle())
        case .roundedRectangle:
            let radius = min(size.width, size.height) * 0.36
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    static let panel = RoundedRectangle(cornerRadius: 28, style: .continuous)
}

/// Liquid Glass recipe per key family. Reduce Transparency → opaque fills; Increase Contrast → a hairline border.
struct KeyGlassModifier: ViewModifier {
    let category: KeyCategory
    let isActive: Bool
    let shape: AnyShape
    let accent: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var tint: Color? {
        if isActive { return Palette.activeTint(scheme) }
        switch category {
        case .digit, .decimal: return Palette.digitTint(scheme)
        case .binaryOperator: return Palette.operatorTint(accent)
        case .equals: return accent
        case .utility: return Palette.utilityTint(scheme)
        case .function, .memory, .constant, .parenthesis, .modeToggle: return Palette.functionTint(scheme)
        }
    }

    private var fallbackFill: Color {
        if isActive { return Palette.activeTint(scheme) }
        switch category {
        case .binaryOperator, .equals: return accent
        case .utility: return Color(uiColor: .systemGray3)
        default: return Color(uiColor: .secondarySystemFill)
        }
    }

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(fallbackFill)
                }
            }
            .glassEffect(reduceTransparency ? .identity : glass, in: shape)
            .overlay {
                if contrast == .increased {
                    shape.stroke(Color.primary.opacity(0.35), lineWidth: 1)
                }
            }
    }

    private var glass: Glass {
        if let tint {
            return .regular.tint(tint).interactive()
        }
        return .regular.interactive()
    }
}

extension View {
    func keyGlass(category: KeyCategory, isActive: Bool, shape: AnyShape, accent: Color) -> some View {
        modifier(KeyGlassModifier(category: category, isActive: isActive, shape: shape, accent: accent))
    }
}
