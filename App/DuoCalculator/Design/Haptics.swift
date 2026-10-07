import SwiftUI

/// Maps semantic haptic kinds to `SensoryFeedback`.
enum Haptics {
    static func feedback(for kind: HapticKind) -> SensoryFeedback {
        switch kind {
        case .light: .impact(weight: .light, intensity: 0.7)
        case .medium: .impact(weight: .medium, intensity: 0.8)
        case .heavy: .impact(weight: .heavy, intensity: 0.8)
        case .selection: .selection
        case .success: .success
        case .error: .error
        case .soft: .impact(flexibility: .soft, intensity: 0.6)
        }
    }
}
