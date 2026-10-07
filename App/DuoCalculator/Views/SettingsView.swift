import SwiftUI
import CalcEngine

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CalculatorModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.titleKey, bundle: .main).tag(appearance)
                        }
                    } label: { Text("settings.appearance", bundle: .main) }
                    Toggle(isOn: $settings.oledTrueBlack) { Text("settings.trueBlack", bundle: .main) }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.accent", bundle: .main)
                        AccentSwatchRow(selection: $settings.accent)
                    }
                    Toggle(isOn: $settings.auroraEnabled) { Text("settings.aurora", bundle: .main) }
                } header: { Text("settings.section.appearance", bundle: .main) }

                Section {
                    Toggle(isOn: $settings.hapticsEnabled) { Text("settings.haptics", bundle: .main) }
                    Toggle(isOn: $settings.scientificInFoldedLandscape) { Text("settings.scientificLandscape", bundle: .main) }
                    Toggle(isOn: $settings.keepScreenAwake) { Text("settings.keepAwake", bundle: .main) }
                } header: { Text("settings.section.interaction", bundle: .main) }

                Section {
                    Toggle(isOn: $settings.usesGrouping) { Text("settings.grouping", bundle: .main) }
                    LabeledContent {
                        Text(verbatim: "\(CalcPrecision.working) / \(CalcPrecision.displayRegular)")
                    } label: { Text("settings.precision", bundle: .main) }
                } header: { Text("settings.section.format", bundle: .main) }

                Section {
                    LabeledContent {
                        Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    } label: { Text("settings.version", bundle: .main) }
                    Link(destination: URL(string: "https://github.com/mitre88/duo_calculator-")!) {
                        Text("settings.source", bundle: .main)
                    }
                } header: { Text("settings.section.about", bundle: .main) }
            }
            .navigationTitle(Text("settings.title", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("settings.done", bundle: .main) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Accent swatches: a row of colored discs, the selected one ringed and checked. Faster to scan than a menu.
struct AccentSwatchRow: View {
    @Binding var selection: AppSettings.Accent

    var body: some View {
        HStack(spacing: 16) {
            ForEach(AppSettings.Accent.allCases) { accent in
                let selected = accent == selection
                Button {
                    withAnimation(Motion.keyPress) { selection = accent }
                } label: {
                    ZStack {
                        Circle().fill(accent.color)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .strokeBorder(accent.color.opacity(selected ? 0.55 : 0), lineWidth: 2)
                            .padding(-4)
                    }
                    .contentShape(Circle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accent.titleKey, bundle: .main))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
