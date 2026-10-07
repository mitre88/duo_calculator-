import SwiftUI
import Observation

/// User preferences, persisted in `UserDefaults`.
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
        var titleKey: LocalizedStringKey {
            switch self {
            case .system: "settings.appearance.system"
            case .light: "settings.appearance.light"
            case .dark: "settings.appearance.dark"
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case amber, indigo, mint, graphite
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .amber: Color(red: 1.0, green: 0.627, blue: 0.2)
            case .indigo: Color(red: 0.369, green: 0.361, blue: 0.902)
            case .mint: Color(red: 0.388, green: 0.902, blue: 0.745)
            case .graphite: Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
        var titleKey: LocalizedStringKey {
            switch self {
            case .amber: "settings.accent.amber"
            case .indigo: "settings.accent.indigo"
            case .mint: "settings.accent.mint"
            case .graphite: "settings.accent.graphite"
            }
        }
    }

    var appearance: Appearance { didSet { store(appearance.rawValue, "appearance") } }
    var accent: Accent { didSet { store(accent.rawValue, "accent") } }
    var oledTrueBlack: Bool { didSet { store(oledTrueBlack, "oledTrueBlack") } }
    var hapticsEnabled: Bool { didSet { store(hapticsEnabled, "haptics") } }
    var soundEnabled: Bool { didSet { store(soundEnabled, "sound") } }
    var usesGrouping: Bool { didSet { store(usesGrouping, "grouping") } }
    /// Folded + landscape shows the compact scientific keypad (iPhone convention) instead of the basic one.
    var scientificInFoldedLandscape: Bool { didSet { store(scientificInFoldedLandscape, "sciLandscape") } }
    var auroraEnabled: Bool { didSet { store(auroraEnabled, "aurora") } }
    var keepScreenAwake: Bool { didSet { store(keepScreenAwake, "keepAwake") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "duo.settings.appearance") ?? "") ?? .system
        accent = Accent(rawValue: defaults.string(forKey: "duo.settings.accent") ?? "") ?? .amber
        oledTrueBlack = defaults.object(forKey: "duo.settings.oledTrueBlack") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "duo.settings.haptics") as? Bool ?? true
        soundEnabled = defaults.object(forKey: "duo.settings.sound") as? Bool ?? false
        usesGrouping = defaults.object(forKey: "duo.settings.grouping") as? Bool ?? true
        scientificInFoldedLandscape = defaults.object(forKey: "duo.settings.sciLandscape") as? Bool ?? true
        auroraEnabled = defaults.object(forKey: "duo.settings.aurora") as? Bool ?? true
        keepScreenAwake = defaults.object(forKey: "duo.settings.keepAwake") as? Bool ?? false
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: "duo.settings." + key)
    }
}
