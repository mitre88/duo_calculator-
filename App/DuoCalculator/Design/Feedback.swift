import SwiftUI

/// Feedback on the result line: a soft scale pulse when `=` commits a result, a short horizontal
/// shake on an error. Keyframe-driven, anchored at the trailing edge (where the digits live), and
/// flattened to a no-op with Reduce Motion.
struct ResultFeedbackModifier: ViewModifier {
    let trigger: Int
    let isError: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let pulse: CGFloat = (!reduceMotion && !isError) ? 1.035 : 1
        let shake: CGFloat = (!reduceMotion && isError) ? 1 : 0
        content
            .keyframeAnimator(initialValue: FeedbackState(), trigger: trigger) { view, state in
                view
                    .scaleEffect(state.scale, anchor: .trailing)
                    .offset(x: state.offset)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(pulse, duration: 0.12, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.32, spring: .bouncy(duration: 0.32, extraBounce: 0.1))
                }
                KeyframeTrack(\.offset) {
                    CubicKeyframe(-10 * shake, duration: 0.05)
                    CubicKeyframe(8 * shake, duration: 0.07)
                    CubicKeyframe(-5 * shake, duration: 0.07)
                    CubicKeyframe(3 * shake, duration: 0.06)
                    CubicKeyframe(0, duration: 0.06)
                }
            }
    }
}

struct FeedbackState {
    var scale: CGFloat = 1
    var offset: CGFloat = 0
}

extension View {
    func resultFeedback(trigger: Int, isError: Bool, reduceMotion: Bool) -> some View {
        modifier(ResultFeedbackModifier(trigger: trigger, isError: isError, reduceMotion: reduceMotion))
    }
}
