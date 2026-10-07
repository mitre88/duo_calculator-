import SwiftUI
import Observation

/// Fold-related state that is *not* layout: the hinge (for effects) and the last resolved plan.
@Observable
final class DeviceContext {
    var hinge = HingeState()
    var plan = LayoutPlan.placeholder
    /// Bumped whenever the hinge status changes (closed ↔ partially open ↔ fully open) — drives a soft haptic and the key "wave".
    private(set) var foldTransitionTick = 0

    func update(hinge newValue: HingeState) {
        let statusChanged = newValue.status != hinge.status
        hinge = newValue
        if statusChanged { foldTransitionTick += 1 }
    }
}
