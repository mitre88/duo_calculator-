import SwiftUI
import CalcEngine

/// 64 (or fewer) tappable bits, most significant first, grouped by nibbles with index labels.
struct BitGridView: View {
    let value: ProgrammerValue
    let toggle: (Int) -> Void

    private var columns: Int { value.width.rawValue >= 32 ? 32 : value.width.rawValue }

    var body: some View {
        let bits = value.bitArray
        let rows = stride(from: value.width.rawValue - 1, through: 0, by: -columns).map { top in
            Array((max(0, top - columns + 1)...top).reversed())
        }
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(row, id: \.self) { index in
                        Button {
                            toggle(index)
                        } label: {
                            Text(verbatim: bits[index] ? "1" : "0")
                                .font(.system(size: 13, weight: bits[index] ? .bold : .regular, design: .monospaced))
                                .frame(minWidth: 14, minHeight: 24)
                                .foregroundStyle(bits[index] ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, index % 4 == 0 && index != row.last ? 6 : 0)
                        .accessibilityLabel(Text(verbatim: "bit \(index)"))
                        .accessibilityValue(Text(verbatim: bits[index] ? "1" : "0"))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.snappy(duration: 0.15), value: value)
    }
}
