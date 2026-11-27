//
//  RawdeaLoadingIndicator.swift
//  Rawdea
//

import SwiftUI

/// Droplets gather into the app logo's cell while content loads.
/// Buttons and actions keep the native ProgressView.
/// With Reduce Motion the finished cell holds still and fades gently.
struct RawdeaLoadingIndicator: View {

    fileprivate static let cycle: TimeInterval = 1.6

    private let title: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var size: CGFloat
    @State private var start = Date()

    init(_ title: String? = nil, size: CGFloat = 28) {
        self.title = title
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        VStack(spacing: RawdeaSpacing.xs) {
            TimelineView(.animation) { context in
                let cycles = context.date.timeIntervalSince(start) / Self.cycle
                let progress = cycles - cycles.rounded(.down)
                let still = reduceMotion

                CellCanvas(progress: still ? nil : progress)
                    .opacity(still ? 0.8 + 0.2 * sin(progress * 2 * .pi) : 1)
            }
            // Capped so it stays quiet at accessibility text sizes.
            .frame(width: min(size, 44), height: min(size, 44))

            if let title {
                Text(title)
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Still mark

/// The app logo's cell, at rest. Decorative.
struct RawdeaCellMark: View {

    var size: CGFloat = 44

    var body: some View {
        CellCanvas(progress: nil)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Pull to refresh

extension View {

    /// `refreshable` with the cell in place of the system spinner. The
    /// cell forms as the list is pulled, then loops until the refresh ends.
    /// iOS still owns the gesture, haptic and trigger distance. The system
    /// spinner is hidden in `RawdeaApp`. iOS 17 keeps the system spinner.
    func rawdeaRefreshable(
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(RawdeaRefreshModifier(action: action))
    }
}

private struct RawdeaRefreshModifier: ViewModifier {

    /// Pull distance at which the cell looks complete.
    private static let fullPull: CGFloat = 100

    /// The point in the cycle where the cell is whole.
    private static let formed = 0.8

    let action: @MainActor () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28
    @State private var pull: CGFloat = 0
    @State private var isPulling = false
    @State private var refreshStart: Date?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .refreshable {
                    refreshStart = Date()
                    defer { refreshStart = nil }
                    await action()
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
                } action: { _, distance in
                    pull = distance
                }
                .onScrollPhaseChange { _, phase in
                    isPulling = phase == .tracking || phase == .interacting
                }
                .overlay(alignment: .top) { indicator }
        } else {
            content.refreshable { await action() }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        // Only a finger pull shows the cell, not a bounce at the top.
        if refreshStart != nil || (isPulling && pull > 8) {
            TimelineView(.animation) { context in
                let pulled = min(1, pull / Self.fullPull)

                if let refreshStart {
                    let cycles = Self.formed
                        + context.date.timeIntervalSince(refreshStart) / RawdeaLoadingIndicator.cycle
                    let progress = cycles - cycles.rounded(.down)

                    CellCanvas(progress: reduceMotion ? nil : progress)
                        .opacity(reduceMotion ? 0.8 + 0.2 * cos(progress * 2 * .pi) : 1)
                } else {
                    CellCanvas(progress: reduceMotion ? nil : Self.formed * pulled)
                        .opacity(reduceMotion ? pulled : 1)
                }
            }
            .frame(width: min(size, 44), height: min(size, 44))
            .padding(.top, RawdeaSpacing.md)
            // The system control already speaks the refresh to VoiceOver.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Drawing

/// One frame of the cell. A nil `progress` draws the finished cell.
private struct CellCanvas: View {

    let progress: Double?

    var body: some View {
        Canvas { graphics, canvasSize in
            // A 900 unit window around the cell, leaving room
            // for the droplets and the overshoot.
            let scale = min(canvasSize.width, canvasSize.height) / 900
            graphics.scaleBy(x: scale, y: scale)
            graphics.translateBy(x: -80, y: -86)

            if let progress {
                CellLogo.drawGathering(in: graphics, progress: progress)
            } else {
                CellLogo.drawWhole(in: graphics)
            }
        }
    }
}

/// Shapes traced from the 1024 pt app icon. The logo keeps its own
/// colors in Light and Dark Mode.
private enum CellLogo {

    static func drawWhole(in graphics: GraphicsContext) {
        graphics.fill(membrane, with: .color(membraneColor))
        graphics.fill(cytoplasm, with: .color(cytoplasmColor))
        graphics.fill(nucleus, with: .color(nucleusColor))
        graphics.fill(smallDot, with: .color(smallDotColor))
        graphics.fill(largeDot, with: .color(largeDotColor))
    }

    /// One cycle, with `progress` from 0 to 1: droplets merge, the cell
    /// lands layer by layer, holds, then breaks apart again.
    static func drawGathering(in graphics: GraphicsContext, progress: Double) {
        func part(_ from: Double, _ to: Double) -> Double {
            min(1, max(0, (progress - from) / (to - from)))
        }

        let leaving = ease(part(0.86, 1))
        let keep = 1 - leaving
        let merged = ease(part(0, 0.45))

        if merged < 1 || leaving > 0 {
            let gathered = leaving > 0 ? keep : merged
            for index in 0..<6 {
                let angle = Double(index) * .pi / 3 + gathered * 1.4
                let distance = 320 * (1 - gathered)
                graphics.fill(
                    circle(
                        x: center.x + distance * cos(angle),
                        y: center.y + distance * sin(angle),
                        radius: 55 + 75 * gathered
                    ),
                    with: .color(index.isMultiple(of: 2) ? cytoplasmColor : membraneColor)
                )
            }
        }

        func layer(_ path: Path, _ color: Color, around anchor: CGPoint, scale: Double) {
            guard scale > 0.001 else { return }
            var context = graphics
            context.translateBy(x: anchor.x, y: anchor.y)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -anchor.x, y: -anchor.y)
            context.fill(path, with: .color(color))
        }

        let outer = part(0.28, 0.5)

        layer(membrane, membraneColor, around: center,
              scale: outer > 0 ? (0.55 + 0.45 * pop(outer)) * keep : 0)
        layer(cytoplasm, cytoplasmColor, around: CGPoint(x: 530, y: 550),
              scale: pop(part(0.38, 0.56)) * keep)
        layer(nucleus, nucleusColor, around: CGPoint(x: 480, y: 550),
              scale: pop(part(0.48, 0.68)) * keep)
        layer(smallDot, smallDotColor, around: CGPoint(x: 753, y: 457),
              scale: pop(part(0.58, 0.72)) * keep)
        layer(largeDot, largeDotColor, around: CGPoint(x: 706, y: 665),
              scale: pop(part(0.63, 0.76)) * keep)
    }

    private static func ease(_ x: Double) -> Double {
        x * x * (3 - 2 * x)
    }

    /// Eases from 0 to 1 with a small overshoot.
    private static func pop(_ x: Double) -> Double {
        guard x > 0 else { return 0 }
        let overshoot = 1.7
        let y = x - 1
        return 1 + (overshoot + 1) * y * y * y + overshoot * y * y
    }

    private static let center = CGPoint(x: 530, y: 536)

    private static let membraneColor = color(0xE6B6B2)
    private static let cytoplasmColor = color(0xB2394C)
    private static let nucleusColor = color(0xEFBDBD)
    private static let smallDotColor = color(0xEFB0AF)
    private static let largeDotColor = color(0x7C2033)

    private static let membrane = Path { path in
        path.move(to: CGPoint(x: 492, y: 164))
        path.addCurve(to: CGPoint(x: 753, y: 222), control1: CGPoint(x: 584, y: 169), control2: CGPoint(x: 676, y: 192))
        path.addCurve(to: CGPoint(x: 920, y: 528), control1: CGPoint(x: 862, y: 280), control2: CGPoint(x: 920, y: 400))
        path.addCurve(to: CGPoint(x: 668, y: 899), control1: CGPoint(x: 920, y: 728), control2: CGPoint(x: 826, y: 852))
        path.addCurve(to: CGPoint(x: 140, y: 522), control1: CGPoint(x: 428, y: 946), control2: CGPoint(x: 140, y: 806))
        path.addCurve(to: CGPoint(x: 492, y: 164), control1: CGPoint(x: 140, y: 334), control2: CGPoint(x: 290, y: 168))
        path.closeSubpath()
    }

    private static let cytoplasm = Path { path in
        path.move(to: CGPoint(x: 526, y: 271))
        path.addCurve(to: CGPoint(x: 775, y: 378), control1: CGPoint(x: 628, y: 271), control2: CGPoint(x: 718, y: 314))
        path.addCurve(to: CGPoint(x: 826, y: 545), control1: CGPoint(x: 808, y: 424), control2: CGPoint(x: 826, y: 482))
        path.addCurve(to: CGPoint(x: 550, y: 831), control1: CGPoint(x: 826, y: 710), control2: CGPoint(x: 714, y: 831))
        path.addCurve(to: CGPoint(x: 252, y: 690), control1: CGPoint(x: 430, y: 831), control2: CGPoint(x: 306, y: 772))
        path.addCurve(to: CGPoint(x: 232, y: 470), control1: CGPoint(x: 218, y: 634), control2: CGPoint(x: 226, y: 548))
        path.addCurve(to: CGPoint(x: 526, y: 271), control1: CGPoint(x: 246, y: 352), control2: CGPoint(x: 380, y: 271))
        path.closeSubpath()
    }

    private static let nucleus = Path { path in
        path.move(to: CGPoint(x: 494, y: 381))
        path.addCurve(to: CGPoint(x: 637, y: 486), control1: CGPoint(x: 576, y: 381), control2: CGPoint(x: 637, y: 424))
        path.addCurve(to: CGPoint(x: 537, y: 653), control1: CGPoint(x: 637, y: 556), control2: CGPoint(x: 568, y: 608))
        path.addCurve(to: CGPoint(x: 481, y: 741), control1: CGPoint(x: 522, y: 696), control2: CGPoint(x: 533, y: 741))
        path.addCurve(to: CGPoint(x: 346, y: 628), control1: CGPoint(x: 420, y: 741), control2: CGPoint(x: 366, y: 688))
        path.addCurve(to: CGPoint(x: 318, y: 564), control1: CGPoint(x: 338, y: 600), control2: CGPoint(x: 328, y: 578))
        path.addCurve(to: CGPoint(x: 368, y: 420), control1: CGPoint(x: 306, y: 510), control2: CGPoint(x: 334, y: 460))
        path.addCurve(to: CGPoint(x: 494, y: 381), control1: CGPoint(x: 396, y: 392), control2: CGPoint(x: 444, y: 381))
        path.closeSubpath()
    }

    private static let smallDot = circle(x: 753, y: 457, radius: 40)
    private static let largeDot = circle(x: 706, y: 665, radius: 73)

    private static func circle(x: Double, y: Double, radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    RawdeaLoadingIndicator("Loading posts…")
}
