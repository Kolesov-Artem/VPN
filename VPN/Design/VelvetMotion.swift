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
        response: 0.3,
        dampingFraction: 1.0
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

    /// 50ms between items, capped so a long list does not drag. First item has no delay.
    static func staggerDelay(index: Int) -> Double {
        Double(min(max(index, 0), rowStaggerCap)) * rowStaggerStep
    }

    /// Show and hide share the same ease-out and the same 50ms steps. Hiding is slightly shorter. First item has no delay.
    static func staggeredReveal(index: Int, isHidden: Bool, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return easeOut(duration: 0.12)
        }
        let duration = isHidden ? quickDuration : contentDuration
        return easeOut(duration: duration).delay(staggerDelay(index: index))
    }

    static func connectionState(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : 0.18)
    }

    /// Island height when session stats appear or disappear — same spring as panel drag.
    static func connectionLayout(reduceMotion: Bool) -> Animation {
        panel(reduceMotion: reduceMotion)
    }

    /// Import / notice toasts — short ease-out, symmetric top edge.
    static func importToastAnimation(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : quickDuration)
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

    /// Menu that grows out of its trigger. 200ms ease-out; reduced motion keeps the fade only.
    static func popover(reduceMotion: Bool) -> Animation {
        easeOut(duration: reduceMotion ? 0.12 : quickDuration)
    }

    static func popoverTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: entranceScale, anchor: .top))
    }

    /// In-place replacement of stats and location lists. Opacity plus a 2pt blur
    /// so the two states read as one change. Reduced motion keeps the fade.
    static func providerContentTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .modifier(
            active: ProviderContentCrossfadeModifier(opacity: 0, blur: 2),
            identity: ProviderContentCrossfadeModifier(opacity: 1, blur: 0)
        )
    }

    /// Smoothstep for panel reveal-driven content (island → intermediate).
    static func revealStep(_ value: CGFloat, from: CGFloat = 0.12, to: CGFloat = 0.88) -> CGFloat {
        let progress = min(max((value - from) / max(to - from, 0.001), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// Panel detent spring settle — used to gate scroll enablement.
    static var panelSettleDelay: Duration {
        .seconds(0.35)
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
            removal: .opacity.combined(with: .offset(y: 20))
        )
    }

    static func importToast(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -12)),
            removal: .opacity.combined(with: .offset(y: -12))
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

    static func statsStrip(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .top))
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
}

extension View {
    /// Panel open and close. Tied to the panel's own progress, so a drag and a snap both stagger in and back out.
    func velvetPanelRowReveal(progress: CGFloat, index: Int, reduceMotion: Bool) -> some View {
        modifier(VelvetPanelRowReveal(progress: progress, index: index, reduceMotion: reduceMotion))
    }
}

private struct VelvetPanelRowReveal: ViewModifier {
    var progress: CGFloat
    var index: Int
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        let appearance = reduceMotion
            ? min(max(progress, 0), 1)
            : VelvetMotion.rowProgress(progress, index: index)
        content
            .opacity(appearance)
            .offset(y: reduceMotion ? 0 : VelvetMotion.chipEntranceOffsetY * (1 - appearance))
            .allowsHitTesting(appearance > 0.6)
    }
}

/// Crossfades one provider's stats or locations into the next without moving the chrome around them.
struct VelvetProviderCrossfade<ID: Hashable, Content: View>: View {
    let id: ID
    var reduceMotion: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .frame(maxWidth: .infinity, alignment: .top)
                .geometryGroup()
                .transition(VelvetMotion.providerContentTransition(reduceMotion: reduceMotion))
                .id(id)
        }
        .animation(VelvetMotion.contentCrossfade(reduceMotion: reduceMotion), value: id)
    }
}

private struct ProviderContentCrossfadeModifier: ViewModifier, Animatable {
    var opacity: Double
    var blur: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(opacity, blur) }
        set {
            opacity = newValue.first
            blur = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
    }
}
