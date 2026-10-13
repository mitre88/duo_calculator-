import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────────────────────
// iPhone Duo SDK adapters (iOS 27.1). These are the ONLY places that touch the fold-specific
// SwiftUI APIs; if a signature differs in the final SDK, fix it here and nothing else moves.
//
//   GeometryProxy.reservedRegions(kind: .division | .occlusion, options: [.includeInactive])
//        → regions with `frame`, `margins`, `isActive`
//   View.onHingeChange { old, new in … }  → `new.hinge` (DeviceHinge?) with `.angle` and `.status`
// ─────────────────────────────────────────────────────────────────────────────────────────────

extension GeometryProxy {
    /// Fold and camera regions in this proxy's coordinate space (inactive ones included, so the
    /// layout can keep an even column count whenever a fold *exists*).
    func duoReservedRegions() -> [ReservedRegionInfo] {
        var result: [ReservedRegionInfo] = []
        for region in reservedRegions(kind: .division, options: [.includeInactive]) {
            result.append(ReservedRegionInfo(kind: .division, frame: region.frame, margins: region.margins, isActive: region.isActive))
        }
        for region in reservedRegions(kind: .occlusion, options: [.includeInactive]) {
            result.append(ReservedRegionInfo(kind: .occlusion, frame: region.frame, margins: region.margins, isActive: region.isActive))
        }
        return result
    }
}

extension HingeState {
    init(deviceHinge hinge: DeviceHinge?) {
        guard let hinge else {
            self.init(angle: 180, status: .unknown)
            return
        }
        let status: Status
        switch hinge.status {
        case .closed: status = .closed
        case .partiallyOpen: status = .partiallyOpen
        case .fullyOpen: status = .fullyOpen
        // `DeviceHinge.Status` is a struct of static constants, not an enum: a plain default covers new values.
        default: status = .unknown
        }
        self.init(angle: hinge.angle.degrees, status: status)
    }
}

struct HingeObserver: ViewModifier {
    @Environment(DeviceContext.self) private var deviceContext

    func body(content: Content) -> some View {
        content.onHingeChange { _, context in
            deviceContext.update(hinge: HingeState(deviceHinge: context.hinge))
        }
    }
}

extension View {
    /// Feeds `DeviceContext.hinge` from the system hinge sensor.
    func observesHinge() -> some View { modifier(HingeObserver()) }
}
