import Foundation

/// Hinge information used **only for effects** (parallax, haptics, the fold "wave") — never for layout.
struct HingeState: Hashable {
    enum Status: Hashable {
        case closed, partiallyOpen, fullyOpen, unknown
    }

    /// 0° closed … 180° flat.
    var angle: Double = 180
    var status: Status = .unknown

    /// 0 when flat, 1 when closed.
    var foldProgress: Double { max(0, min(1, (180 - angle) / 180)) }

    /// Small tilt applied to the display card in the Laptop pose (≤ 4°).
    var displayTiltDegrees: Double { status == .partiallyOpen ? min(4, foldProgress * 8) : 0 }
}
