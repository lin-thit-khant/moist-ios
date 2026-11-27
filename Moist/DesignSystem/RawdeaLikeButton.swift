import SwiftUI

// The post Like control's motion, shared by the post row and post detail.
// `pop` changes only when the server accepts a like, so unliking never animates.

struct RawdeaLikeSymbol: View {

    let isLiked: Bool
    let pop: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rawdeaLikePressed) private var isPressed

    var body: some View {

        // A liked heart does not dip: unliking is instant.
        let dips = !isLiked && !reduceMotion
        let isStill = reduceMotion

        Image(systemName: isLiked ? "heart.fill" : "heart")
            .font(.body)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .foregroundStyle(
                isLiked
                ? RawdeaPalette.accent
                : RawdeaPalette.secondaryText
            )
            .keyframeAnimator(initialValue: 1.0, trigger: pop) { symbol, scale in
                symbol.scaleEffect(isStill ? 1 : scale)
            } keyframes: { _ in
                CubicKeyframe(1.38, duration: 0.16)
                CubicKeyframe(0.92, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.14, spring: Spring(duration: 0.14, bounce: 0.5))
            }
            .scaleEffect(isPressed && dips ? 0.88 : 1)
            // Press feedback where there is no dip.
            .opacity(isPressed && !dips ? 0.6 : 1)
            // Below both, so the system cannot fade an unlike.
            .animation(dips ? .easeOut(duration: 0.1) : nil, value: isPressed)
            .accessibilityHidden(true)
    }
}

// Passes the press to the heart, so a count inside the button stays still.
struct RawdeaLikeButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.rawdeaLikePressed, configuration.isPressed)
    }
}

extension EnvironmentValues {
    @Entry var rawdeaLikePressed = false
}

extension View {

    // The count rolls up on a like and changes instantly on an unlike.
    func rawdeaLikeCount(_ count: Int, isLiked: Bool) -> some View {
        modifier(RawdeaLikeCountMotion(count: count, isLiked: isLiked))
    }
}

private struct RawdeaLikeCountMotion: ViewModifier {

    let count: Int
    let isLiked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(
                reduceMotion ? .opacity : .numericText(value: Double(count))
            )
            .animation(
                !isLiked ? nil
                : reduceMotion ? .easeInOut(duration: 0.2)
                : .snappy(duration: 0.3),
                value: count
            )
    }
}
