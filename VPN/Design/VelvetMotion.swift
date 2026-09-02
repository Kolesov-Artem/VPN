import SwiftUI

/// Shared motion vocabulary for Velvet VPN, aligned with animations.dev
/// (Emil Kowalski): ease-out for entrances, springs for gestures, sub-300ms UI.
enum VelvetMotion {
    // MARK: - Durations (seconds)

    /// Button press feedback — 100–160ms budget.
    static let pressDuration = 0.16
    /// Tooltips, small popovers, filter chips.
    static let quickDuration = 0.2
    /// Panel content crossfades, connection state.
    static let contentDuration = 0.22
    /// Map scrim and connection tint.
    static let scrimDuration = 0.55
    /// Decorative map camera travel (on-screen movement, not UI chrome).
    static let mapCameraDuration = 0.55
    static let mapCameraReducedDuration = 0.25
    /// Onboarding globe spin-up.
    static let globeIntroDuration = 0.9
    /// Add-subscription pull-back: full globe with side margins in the header–form band.
    static let globePullbackDuration = 0.78
    /// Idle globe spin — degrees per 48ms tick (matches prior visual speed).
    static let globeSpinStepPerTick = 0.016
    static let globeSpinFrameInterval: Duration = .milliseconds(48)
    static let globeSpinRenderInterval: Duration = .milliseconds(16)
    /// Same visual spin rate as the idle globe, scaled to the 16ms render loop.
    static let globeSpinStepPerFrame = globeSpinStepPerTick * 16.0 / 48.0

    // MARK: - Physicality

    static let pressScale: CGFloat = 0.97
    static let entranceScale: CGFloat = 0.96
    static let headerControlScale: CGFloat = 0.94
    static let entranceOffsetY: CGFloat = 28
    static let chipEntranceOffsetY: CGFloat = 8

    // MARK: - Stagger

    static let rowStaggerStep = 0.05
    static let rowStaggerCap = 7
    static let rowStaggerBase = 0.08

    // MARK: - Springs

    private static let panelSpring = Animation.spring(
        response: 0.42,
        dampingFraction: 0.78,
        blendDuration: 0.12
    )
    private static let panelSpringSheet = Animation.spring(
        response: 0.42,
        dampingFraction: 0.86
    )
    private static let routeSpring = Animation.spring(
        response: 0.52,
        dampingFraction: 0.88
    )
    private static let mapSpring = Animation.spring(
        response: 0.55,
        dampingFraction: 0.92
    )

    // MARK: - Curves (cubic-bezier equivalents from animations.dev)

    /// `cubic-bezier(0.23, 1, 0.32, 1)` — strong ease-out for UI entrances.
    static func easeOut(duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }

    /// `cubic-bezier(0.77, 0, 0.175, 1)` — on-screen movement / morphing.
    static func easeInOut(duration: Double) -> Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: duration)
    }

    /// Samples the on-screen-movement curve for camera flights we drive per frame.
    static func easeInOutProgress(_ t: Double) -> Double {
        unitBezierY(x: min(max(t, 0), 1), p1x: 0.77, p1y: 0, p2x: 0.175, p2y: 1)
    }

    /// `cubic-bezier(0.23, 1, 0.32, 1)` — fast start, gentle settle (pull-back zoom).
    static func easeOutProgress(_ t: Double) -> Double {
        unitBezierY(x: min(max(t, 0), 1), p1x: 0.23, p1y: 1, p2x: 0.32, p2y: 1)
    }

    // MARK: - Composed animations

    static func press(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.1 : pressDuration)
    }

    static func panel(reduceMotion: Bool, sheetStyle: Bool = false) -> Animation {
        if reduceMotion {
            return easeOut(duration: quickDuration)
        }
        return sheetStyle ? panelSpringSheet : panelSpring
    }

    static func route(reduceMotion: Bool) -> Animation {
        reduceMotion ? easeOut(duration: quickDuration) : routeSpring
    }

    static func contentCrossfade(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.15 : contentDuration)
    }

    static func connectionState(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : 0.18)
    }

    static func queryChange(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : quickDuration)
    }

    static func mapPanEnd(reduceMotion: Bool) -> Animation {
        reduceMotion ? easeOut(duration: 0.15) : mapSpring
    }

    static func mapCamera(reduceMotion: Bool) -> Animation {
        easeInOut(duration: reduceMotion ? mapCameraReducedDuration : mapCameraDuration)
    }

    static func globePullback(reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : globePullbackDuration
    }

    static func scrim(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? easeOut(duration: quickDuration)
            : easeInOut(duration: scrimDuration)
    }

    static func keyboard(reduceMotion: Bool, duration: Double) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : easeOut(duration: duration)
    }

    static func accordion(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : quickDuration)
    }

    /// Panel detent spring settle — used to gate scroll enablement.
    static var panelSettleDelay: Duration {
        .seconds(0.48)
    }

    static var panelSettleReducedDelay: Duration {
        .seconds(0.22)
    }

    static func panelSettleDelay(reduceMotion: Bool) -> Duration {
        reduceMotion ? panelSettleReducedDelay : panelSettleDelay
    }

    // MARK: - Transitions

    static func homeContent(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: entranceOffsetY)),
            removal: .opacity.combined(with: .offset(y: 16))
        )
    }

    static func onboardingContent(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 20)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    static func headerControl(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: headerControlScale))
    }

    static func filterChip(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: -chipEntranceOffsetY))
    }

    // MARK: - Stagger helper

    /// Smoothstep row reveal as the panel opens — capped so lower rows finish.
    static func rowProgress(_ progress: CGFloat, index: Int) -> CGFloat {
        let delay = CGFloat(min(index, rowStaggerCap)) * rowStaggerStep
        let start = rowStaggerBase + delay
        let end = min(start + 0.5, 1)
        let value = min(max((progress - start) / max(end - start, 0.001), 0), 1)
        return value * value * (3 - 2 * value)
    }

    /// Newton–Raphson sample of a unit cubic Bézier, matching CSS `cubic-bezier`.
    private static func unitBezierY(
        x: Double,
        p1x: Double,
        p1y: Double,
        p2x: Double,
        p2y: Double
    ) -> Double {
        var guess = x
        for _ in 0..<8 {
            let currentX = bezierSample(guess, p1x, p2x)
            let delta = currentX - x
            if abs(delta) < 1e-6 { break }
            let derivative = bezierDerivative(guess, p1x, p2x)
            guard abs(derivative) > 1e-6 else { break }
            guess = min(max(guess - delta / derivative, 0), 1)
        }
        return bezierSample(guess, p1y, p2y)
    }

    private static func bezierSample(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * t * p1 + 3 * oneMinus * t * t * p2 + t * t * t
    }

    private static func bezierDerivative(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * p1 + 6 * oneMinus * t * (p2 - p1) + 3 * t * t * (1 - p2)
    }
}
