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
                    Picker(selection: $settings.accent) {
                        ForEach(AppSettings.Accent.allCases) { accent in
                            HStack {
                                Circle().fill(accent.color).frame(width: 14, height: 14)
                                Text(accent.titleKey, bundle: .main)
                            }.tag(accent)
                        }
                    } label: { Text("settings.accent", bundle: .main) }
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
