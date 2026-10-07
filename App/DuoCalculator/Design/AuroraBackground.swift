import SwiftUI

/// Canvas + a very slow mesh gradient. Glass needs something behind it to refract; pure black
/// would look flat. The mesh runs at 24 fps at most, and pauses after a few idle seconds or
/// with Reduce Motion, so the GPU (and the battery) rest when nothing is happening.
struct AuroraBackground: View {
    let scheme: ColorScheme
    let trueBlack: Bool
    let enabled: Bool
    let reduceMotion: Bool
    let accent: Color
    /// Changes on every interaction; restarts the idle timer.
    let interactionTick: Int

    @State private var idle = false

    private static let idleDelay: Duration = .seconds(12)

    var body: some View {
        ZStack {
            Palette.canvas(scheme, trueBlack: trueBlack)
            if enabled {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || idle)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    MeshGradient(width: 3, height: 3, points: Self.points(at: reduceMotion ? 0 : t),
                                 colors: Palette.auroraColors(scheme, accent: accent))
                        .opacity(scheme == .dark ? 0.16 : 0.22)
                        .blur(radius: 48)
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .task(id: interactionTick) {
            idle = false
            try? await Task.sleep(for: Self.idleDelay)
            if !Task.isCancelled { idle = true }
        }
    }

    /// 3×3 control points; the inner ones drift on slow Lissajous curves.
    static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func drift(_ phase: Double, _ amplitude: Float) -> Float {
            Float(sin(t * 0.07 + phase)) * amplitude
        }
        return [
            SIMD2(0, 0), SIMD2(0.5 + drift(0.3, 0.08), 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + drift(1.1, 0.08)), SIMD2(0.5 + drift(2.0, 0.12), 0.5 + drift(2.9, 0.12)), SIMD2(1, 0.5 + drift(3.7, 0.08)),
            SIMD2(0, 1), SIMD2(0.5 + drift(4.6, 0.08), 1), SIMD2(1, 1),
        ]
    }
}
