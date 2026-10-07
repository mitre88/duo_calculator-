import SwiftUI

/// Renders a `KeyFace` (text, SF Symbol or math notation with scripts).
struct KeyFaceView: View {
    let face: KeyFace
    let category: KeyCategory
    let keyHeight: CGFloat
    let isActive: Bool
    let accent: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            switch face {
            case .text(let text):
                Text(text)
                    .font(font)
            case .symbol(let name):
                Image(systemName: name)
                    .font(Typography.operatorKey(keyHeight: keyHeight))
                    .symbolRenderingMode(.monochrome)
            case .math(let base, let superscript, let subscriptText, let prefixSuperscript):
                HStack(alignment: .center, spacing: 0) {
                    if let prefixSuperscript {
                        Text(prefixSuperscript).font(scriptFont).baselineOffset(scriptOffset)
                    }
                    Text(base).font(font)
                    if let superscript {
                        Text(superscript).font(scriptFont).baselineOffset(scriptOffset)
                    }
                    if let subscriptText {
                        Text(subscriptText).font(scriptFont).baselineOffset(-scriptOffset * 0.5)
                    }
                }
            }
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 4)
        .contentTransition(.interpolate)
    }

    private var font: Font {
        switch category {
        case .digit, .decimal: Typography.digitKey(keyHeight: keyHeight)
        case .binaryOperator, .equals: Typography.operatorKey(keyHeight: keyHeight)
        default: Typography.functionKey(keyHeight: keyHeight)
        }
    }

    private var scriptFont: Font {
        .system(size: min(13, max(9, keyHeight * 0.19)), weight: .semibold, design: .rounded)
    }

    private var scriptOffset: CGFloat { max(5, keyHeight * 0.12) }

    private var foreground: Color {
        if isActive {
            switch category {
            case .binaryOperator, .equals: return accent
            default: return .black
            }
        }
        switch category {
        case .binaryOperator, .equals: return .white
        default: return .primary
        }
    }
}
